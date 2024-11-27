import pytest

import os
import subprocess
import polling2
import json
import requests
import base64
import time
import yaml
import re

# Workaround to make parameters global accessible
@pytest.fixture(scope='session')
def parameter(request):
    if hasattr(request,'param'):
        return request.param
    else:
        return None

# Adapt docker-compose.yml to our test needs
@pytest.fixture(scope="session")
def docker_compose_file(pytestconfig, parameter, docker_compose_project_name):
        
    compose_file_template = os.path.join(str(pytestconfig.rootdir), "tests", "docker-compose.yml.template")
    compose_file = os.path.join(str(pytestconfig.rootdir), "tests", "docker-compose.yml.generated")

    # Open template
    with open(compose_file_template) as f:
        list_doc = yaml.safe_load(f)

    if parameter:
        # Change environment variables
        if len(parameter) >= 2:
            env_var = parameter[0]
            value = parameter[1]
            if env_var != "": 
                list_doc['services']['openwrt']['environment'][env_var] = value

        # Load volume data
        if len(parameter) == 3:
            # We don't care about the first two parameters, see above
            # Let's use only the third one
            data_volume_backup = parameter[2]
            vackup_dir = os.path.join(str(pytestconfig.rootdir), "docker-vackup")
            vackup = os.path.join(vackup_dir, "vackup") # Funny name ;-)
            
            os.system(f"cd {vackup_dir}/../test_data/ && {vackup} import {data_volume_backup} {docker_compose_project_name}_data >/dev/null 2>/dev/null")

    # Save docker-compose file
    with open(compose_file, "w") as f:
        yaml.dump(list_doc, f)

    return compose_file

def run_openwrt_shell_command(command, *arg):
    # Add double quotes
    command = "\"" + command + "\""

    # Build argument array
    arguments = "["
    for val in arg:
        arguments += "\"" + val + "\","
    arguments = arguments[:-1] # Remove the last ","
    arguments += "]"

    # Call qemu guest tools function 'guest-exec'. This is only working if OpenWrt is booted and the qemu guest tools are running
    process = subprocess.run(['docker','exec','openwrt','sh','-c',r"""echo -ne '{"execute":"guest-exec", "arguments": { "path": """ + command + ", \"arg\":" + arguments + r""","capture-output": true}}' | nc -w 1 -U /run/qga.sock"""], 
                         stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, 
                         universal_newlines=True)
    
    if process.returncode != 0:
        return None
    
    if process.stdout == "":
        return None
    
    # Sometime it happens that also the previous command return is included which results in two or more json strings.
    jsons = process.stdout.split('\n')

    # Search for 'pid' and give back the last occurrence index
    idx = next((i for i, s in reversed(list(enumerate(jsons))) if 'pid' in s), -1)

    # Assume json here, parse it
    ret = json.loads(jsons[idx])

    if 'return' not in ret:
        return None
    
    if 'pid' not in ret['return']:
        return None

    pid = ret['return']['pid']

    # Get stdout of process
    time.sleep(5) # Give command 5 seconds time to respond. It would be better to implement a real timeout.
    # Call qemu guest tools function 'guest-exec-status'. This is only working if OpenWrt is booted and the qemu guest tools are running
    process = subprocess.run(['docker','exec','openwrt','sh','-c',r"""echo -ne '{"execute":"guest-exec-status", "arguments": { "pid": """ + str(pid) + r"""}}' | nc -w 1 -U /run/qga.sock"""], 
                         stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, 
                         universal_newlines=True)
    
    if process.returncode != 0:
        return None
    
    if process.stdout == "":
        return None

    # Sometime it happens that also the previous command return is included which results in two or more json strings.
    jsons = process.stdout.split('\n')

    # Search for 'return' and give back the last occurrence index
    idx = next((i for i, s in reversed(list(enumerate(jsons))) if 'return' in s), -1)

    # Assume json here, parse it
    ret = json.loads(jsons[idx])

    data = ret['return']

    # decode output
    if 'err-data' in data:
        data['err-data'] = base64.b64decode(data['err-data']).decode()

    if 'out-data' in data:
        data['out-data'] = base64.b64decode(data['out-data']).decode()

    return data

def get_openwrt_info():
    # Call qemu guest tools function 'guest-get-osinfo'. This is only working if OpenWrt is booted and the qemu guest tools are running
    process = subprocess.run(['docker','exec','openwrt','sh','-c',r"""echo -ne '{"execute":"guest-get-osinfo"}' | nc -w 1 -U /run/qga.sock"""], 
                         stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, 
                         universal_newlines=True)
    
    if process.returncode != 0:
        return None
    
    if process.stdout == "":
        return None

    # Sometime it happens that also the previous command return is included which results in two or more json strings.
    jsons = process.stdout.split('\n')

    # Search for 'return' and give back the last occurrence index
    idx = next((i for i, s in reversed(list(enumerate(jsons))) if 'return' in s), -1)

    if idx == -1:
        return None

    # Assume json here, parse it
    info = json.loads(jsons[idx])
    
    if 'name' not in info['return']:
        return None

    return info['return']

def get_logs():
    process = subprocess.run(['docker','logs','openwrt'], 
        stdout=subprocess.PIPE, 
        stderr=subprocess.STDOUT,
        universal_newlines=True)
    
    return process.stdout

def get_container_status():
    process = subprocess.run(['docker','inspect','openwrt'], 
        stdout=subprocess.PIPE, 
        stderr=subprocess.STDOUT,
        universal_newlines=True)
    
    ret = json.loads(process.stdout)
    status = ret[0]['State']['Status']

    if(status != 'running'):
        raise Exception(f"Container not running. Status '{status}'")
    
    return True

def is_openwrt_booted():
    if get_container_status() == False:
        return False
    
    service_status = get_openwrt_info()

    if service_status != None:
        return True
    else:
        return False
    
def is_specific_log(log_text):
    if get_container_status() == False:
        return False
    
    return log_text in get_logs()

def is_container_running():
    if get_container_status() == False:
        return False

    try:
        response = requests.get("http://localhost:8006")
        if response.status_code == 200:
            return True
        else:
         return False   
    except Exception:
        return False

def wait_for_container_startup(docker_services):
    try:
        docker_services.wait_until_responsive(
            timeout=90.0, pause=1, check=lambda: is_container_running()
        )
    except Exception as excinfo:
            print(get_logs())
            pytest.fail(f"Unexpected exception raised: {excinfo}")

def wait_for_openwrt_startup(docker_services):
    try:
        docker_services.wait_until_responsive(
            timeout=360.0, pause=1, check=lambda: is_openwrt_booted()
        )
    except Exception as excinfo:
            print(get_logs())
            pytest.fail(f"Unexpected exception raised: {excinfo}")

def wait_for_specific_log(docker_services, log):
    try:
        docker_services.wait_until_responsive(
        timeout=180.0, pause=1, check=lambda: is_specific_log(log)
    )
    except Exception as excinfo:
            print(get_logs())
            pytest.fail(f"Unexpected exception raised: {excinfo}")

# ************************ Tests ************************

def test_basic_container_start(docker_services):
    wait_for_container_startup(docker_services)

    return


def test_openwrt_booted(docker_services):
    wait_for_openwrt_startup(docker_services)

    info = get_openwrt_info()
    print(f"Running '{info['pretty-name'].rstrip()}'", end=' ')

    assert 'OpenWrt' == info['name']


@pytest.mark.parametrize("parameter", 
    [('LAN_IF','veth'),('LAN_IF','veth,nofixedip'),('LAN_IF','ens5'),('LAN_IF',''),('LAN_IF','host')], indirect=True,
    ids=['LAN_IF=veth','LAN_IF=veth,nofixedip', 'LAN_IF=ens5', 'LAN_IF=""', 'LAN_IF="host"'])
def test_openwrt_lan(docker_services, parameter):
    wait_for_openwrt_startup(docker_services)
    
    match parameter[1]:
        case 'veth':
            try:
                response = polling2.poll(lambda: os.system("ping -c 1 172.31.1.1 >/dev/null") == 0, step=1, timeout=90)
            except polling2.TimeoutException:
                assert True, 'ping timeout'
            return

        case 'veth,nofixedip':
            # Get all IPv4 addresses 
            process = subprocess.run(['sh','-c','ip addr show veth-openwrt0 | grep -oP "(?<=inet\s)\d+(\.\d+){3}"'], 
                stdout=subprocess.PIPE, 
                stderr=subprocess.STDOUT,
                universal_newlines=True)
    
            # No IP address shall be found
            assert ('' in process.stdout) == True
            return


        case '' | 'host':
            response = run_openwrt_shell_command("ip", "addr", "add", "192.168.1.15/24", "dev", "br-lan")
            assert response['exitcode'] == 0

            response = run_openwrt_shell_command("ping", "-c1", "-W2", "-w2", "192.168.1.2")
            assert response['exitcode'] == 0
            return
        
        case _: # Usage of real Ethernet interface e.g. 'eth0'
            # This test is most likely only working in a github action environment because multiple VM are necessary to test it. See the action file, please.
            # Try to ping LAN-VM
            response = run_openwrt_shell_command("ping", "-c1", "-W2", "-w2", "172.31.1.2")
            assert response['exitcode'] == 0
            return
    
    assert False, 'Unknown parameter'


@pytest.mark.parametrize("parameter", 
    [('WAN_IF','host'),('WAN_IF','none'),('WAN_IF','ens4'),('WAN_IF','')], indirect=True,
    ids=['WAN_IF=host', 'WAN_IF=none', 'WAN_IF=ens4', 'WAN_IF=""'])
def test_openwrt_wan(docker_services, parameter):
    wait_for_openwrt_startup(docker_services)
    
    match parameter[1]:
        case '' | 'host':
            # For some reason ping is not working at github actions, so use nslookup to test internet connection
            response = run_openwrt_shell_command("nslookup", "google.com")
            assert response['exitcode'] == 0
            return
        
        case 'none':
            # We are looking for eth1. It should not existing
            response = run_openwrt_shell_command("ip", "addr")        
            assert ('eth1' in response['out-data']) == False
            return
        
        case _: # Usage of real Ethernet interface e.g. 'eth0'
            # This test is most likely only working in a github action environment because multiple VM are necessary to test it. See the action file, please
            # Try to get IP address from WAN-VM
            response = run_openwrt_shell_command("udhcpc", "-i", "eth1")
            assert ('udhcpc: setting default routers: 192.168.22.1' in response['out-data']) == True

            # Finally try Internet
            response = run_openwrt_shell_command("nslookup", "google.com")
            assert response['exitcode'] == 0

            return

    assert False, 'Unknown parameter'

@pytest.mark.parametrize("parameter", 
    [('FORWARD_LUCI','true'),('FORWARD_LUCI','false')], indirect=True,
    ids=['FORWARD_LUCI=true', 'FORWARD_LUCI=false'])
def test_nginx_luci_forwarding_access(docker_services, parameter):
    wait_for_openwrt_startup(docker_services)

    if parameter[1] == 'true':
        try:
            response = requests.get("https://localhost:9000", verify=False)
            assert ('LuCI - Lua Configuration Interface' in response.content.decode()) == True
        except Exception as excinfo:
            #print(get_logs())
            #os.system("ip addr")
            #os.system("ping -c 1 172.31.1.1")
            
            #print(run_openwrt_shell_command("ip", "addr")['out-data'])
            #print(run_openwrt_shell_command("ping", "-c1", "-W2", "-w2", "172.31.1.2")['out-data'])
            
            pytest.fail(f"Unexpected exception raised: {excinfo}")

    if parameter[1] == 'false':
        try:
            response = requests.get("https://localhost:9000", verify=False)
            pytest.fail(f'LuCI forwarding is active')
        except Exception as excinfo: 
            return


@pytest.mark.parametrize("parameter", 
    [('CPU_COUNT',1),('CPU_COUNT',2),('CPU_COUNT',3),('CPU_COUNT',4)], indirect=True,
    ids=['CPU_COUNT=1', 'CPU_COUNT=2', 'CPU_COUNT=3', 'CPU_COUNT=4'])
def test_cpu_num(docker_services, parameter):
    wait_for_openwrt_startup(docker_services)
    # Get number of processors
    response = run_openwrt_shell_command("cat", "/proc/cpuinfo")
    cpu_num = response['out-data'].count('processor')
    assert parameter[1] == cpu_num


@pytest.mark.parametrize("parameter", 
    [('','','20240922_test_volume_openwrt_23.05.4_ext4'),('','','20241114_test_volume_openwrt_23.05.5')], indirect=True,
    ids=['20240922_test_volume_openwrt_23.05.4 ext4', '20241114_test_volume_openwrt_23.05.5'])
def test_openwrt_migrate_existing_volume(docker_services):
    wait_for_specific_log(docker_services, 'Booting image using QEMU emulator')

    assert ('upgrade: Saving config files' in get_logs()) == True
    assert ('upgrade: Restoring config files' in get_logs()) == True


@pytest.mark.parametrize("parameter", 
    [('','','20240922_test_volume_openwrt_23.05.4_ext4'),('','','20241114_test_volume_openwrt_23.05.5')], indirect=True,
    ids=['20240922_test_volume_openwrt_23.05.4', '20241114_test_volume_openwrt_23.05.5'])
def test_openwrt_migrate_settings(docker_services):
    wait_for_openwrt_startup(docker_services)

    # Here we test a custom configuration that is stored in the existing volume.
    # Currently hostname and an additional interface are configured.
    
    # Check for host name 'TestRouter'
    response = run_openwrt_shell_command("uci", "get", "system.@system[0].hostname")
    assert ('TestRouter' in response['out-data']) == True

    # Check for test LAN
    response = run_openwrt_shell_command("uci", "show", "network.TestLan")
    assert ("network.TestLan.ipaddr='192.168.40.1'" in response['out-data']) == True


def test_kvm(docker_services):
    wait_for_specific_log(docker_services, 'Checking for KVM')
    time.sleep(1)
    assert ('KVM detected' in get_logs()) == True


def test_alpine_version_output(docker_services):
    wait_for_specific_log(docker_services, 'Booting image using QEMU emulator')

    logs = get_logs()
    assert ('NAME="Alpine Linux"' in logs) == True

    version = re.findall("ID=alpine\nVERSION_ID=.+", logs)[0].split("=")
    print(f"'Version: {version[2]}'", end=' ')


def test_novnc(docker_services):
    wait_for_openwrt_startup(docker_services)
    # Here we only test if novnc is running, not if the connection to qemu is successful. To test this selenium is necessary.
    response = requests.get("http://localhost:8006/novnc")
    assert ('<title>noVNC</title>' in response.content.decode()) == True


def test_api_reboot(docker_services):
    wait_for_openwrt_startup(docker_services)
    response = requests.get("http://localhost:8006/api/reboot")
    assert ('{"command":"/run/qemu_qmp.sh [\\"-R\\"]' in response.content.decode()) == True


def test_api_reset(docker_services):
    wait_for_openwrt_startup(docker_services)
    response = requests.get("http://localhost:8006/api/reset")
    assert ('{"command":"/run/qemu_qmp.sh [\\"-r\\"]' in response.content.decode()) == True


def test_api_get_openwrt_info(docker_services):
    wait_for_openwrt_startup(docker_services)
    response = requests.get("http://localhost:8006/api/get_openwrt_info")
    assert ('{"command":"/run/qemu_qmp.sh [\\"-V\\"]' in response.content.decode()) == True


def test_api_get_container_info(docker_services):  
    wait_for_container_startup(docker_services)
    response = requests.get("http://localhost:8006/api/get_container_info")
    assert ('Content of /var/vm/' in response.content.decode()) == True


def test_api_get_factory_reset(docker_services):
    wait_for_container_startup(docker_services)
    response = requests.get("http://localhost:8006/api/factory_reset")
    assert ('{"command":"/run/factory_reset.sh []"' in response.content.decode()) == True


def test_mdns(docker_services):
    wait_for_openwrt_startup(docker_services)
    try:
        polling2.poll(lambda: os.system("ping -c 1 openwrt.local >/dev/null 2>/dev/null") == 0, step=1, timeout=240)
    except polling2.TimeoutException:
        assert True, 'ping timeout'
    return


@pytest.mark.parametrize("parameter", 
    [('WAN_IF','host'),('WAN_IF','')], indirect=True,
    ids=['WAN_IF=host', 'WAN_IF=""'])
def test_port_8000_luci(docker_services):
    wait_for_openwrt_startup(docker_services)

    response = run_openwrt_shell_command("fw_wan_open_http", "")
    assert response['exitcode'] == 0
    
    response = requests.get("http://localhost:8000")
    assert ('LuCI - Lua Configuration Interface' in response.content.decode()) == True


@pytest.mark.parametrize("parameter", 
    [('WAN_IF','host'),('WAN_IF','')], indirect=True,
    ids=['WAN_IF=host', 'WAN_IF=""'])
def test_port_8022_ssh(docker_services):
    wait_for_openwrt_startup(docker_services)

    response = run_openwrt_shell_command("fw_wan_open_ssh", "")
    assert response['exitcode'] == 0
    
    process = subprocess.run(['timeout','2','ssh','root@localhost','-p 8022','-oStrictHostKeyChecking=no'], 
        stdout=subprocess.PIPE, 
        stderr=subprocess.STDOUT,
        universal_newlines=True)
    
    assert ('OpenWrt' in process.stdout) == True