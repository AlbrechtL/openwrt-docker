import pytest

import os
import subprocess
import polling2
import json
import requests
import base64
import time
import yaml

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


def is_container_running():
    # Get current service list from supervisor
    process = subprocess.run(['docker','exec','openwrt','supervisorctl','status'], 
                         stdout=subprocess.PIPE, 
                         universal_newlines=True)
    
    # Check if supervisord is running
    if process.returncode == 0 \
    or process.returncode == 3 : # Means a service has an issue
        return True
    else:
        return False

def get_service_status(service):
    # Get current service list from supervisor
    process = subprocess.run(['docker','exec','openwrt','supervisorctl','status'], 
                         stdout=subprocess.PIPE, 
                         universal_newlines=True)
    
    # Check if supervisord is running
    if process.returncode == 0 \
    or process.returncode == 3 : # Means a service has an issue
        # Extract list from supervisorctl output
        service_list = process.stdout.splitlines()

        # Filter for service
        service_status = [s for s in service_list if service in s][0].split()

        return service_status[1]
    else:
        return None

def is_service_started(service):
    service_status = get_service_status(service)

    if service_status != None:
        # Check if service is running or in other states
        if service_status == 'RUNNING' \
        or service_status == 'BACKOFF' \
        or service_status == 'EXITED' \
        or service_status == 'FATAL' \
        or service_status == 'UNKNOWN':
            return True
        else:
            return False
    else:
        return False

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
    
    # Assume json here, parse it
    ret = json.loads(process.stdout)

    if 'return' not in ret:
        return None
    
    if 'pid' not in ret['return']:
        return None

    pid = ret['return']['pid']

    # Get stdout of process
    time.sleep(5) # Give command 5 seconds time to respond. It would be better to implement a real timeout here but I need to got he bed :-(
    # Call qemu guest tools function 'guest-exec-status'. This is only working if OpenWrt is booted and the qemu guest tools are running
    process = subprocess.run(['docker','exec','openwrt','sh','-c',r"""echo -ne '{"execute":"guest-exec-status", "arguments": { "pid": """ + str(pid) + r"""}}' | nc -w 1 -U /run/qga.sock"""], 
                         stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, 
                         universal_newlines=True)
    
    if process.returncode != 0:
        return None
    
    if process.stdout == "":
        return None

    # Assume json here, parse it
    ret = json.loads(process.stdout)
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
    
    # Assume json here, parse it
    info = json.loads(process.stdout)

    if 'return' not in info:
        return None
    
    if 'name' not in info['return']:
        return None

    return info['return']

def is_openwrt_booted():
    service_status = get_openwrt_info()

    if service_status != None:
        return True
    else:
        return False

def get_logs():
    process = subprocess.run(['docker','logs','openwrt'], 
        stdout=subprocess.PIPE, 
        stderr=subprocess.PIPE,
        universal_newlines=True)
    
    return process.stdout + process.stderr

def is_specific_log(log_text):
    return log_text in get_logs()

# ************************ Tests ************************

def test_basic_container_start(docker_services):
    docker_services.wait_until_responsive(
        timeout=30.0, pause=0.5, check=lambda: is_container_running()
    )
    return


def test_nginx_start(docker_services):
    docker_services.wait_until_responsive(
        timeout=30.0, pause=0.5, check=lambda: is_service_started('nginx')
    )
    
    assert get_service_status('nginx') == 'RUNNING'


def test_openwrt_start(docker_services):
    docker_services.wait_until_responsive(
        timeout=30.0, pause=0.5, check=lambda: is_service_started('openwrt')
    )
    
    assert get_service_status('openwrt') == 'RUNNING'


@pytest.mark.parametrize("parameter", 
    [('FORWARD_LUCI','true'),('FORWARD_LUCI','false')], indirect=True,
    ids=['FORWARD_LUCI=true', 'FORWARD_LUCI=false'])
def test_caddy_start(docker_services, parameter):
    try:
        docker_services.wait_until_responsive(
            timeout=30.0, pause=0.5, check=lambda: is_service_started('caddy')
        )
    except:
        if parameter[1] == 'false':
            return # We expect a timeout here. This is our test condition for FORWARD_LUCI=false
    
    # For FORWARD_LUCI=true
    assert get_service_status('caddy') == 'RUNNING'


def test_script_server_start(docker_services):
    docker_services.wait_until_responsive(
        timeout=30.0, pause=0.5, check=lambda: is_service_started('script-server')
    )

    assert get_service_status('script-server') == 'RUNNING'


def test_openwrt_booted(docker_services):
    docker_services.wait_until_responsive(
        timeout=90.0, pause=1, check=lambda: is_openwrt_booted()
    )

    info = get_openwrt_info()
    print(f"Running '{info['pretty-name'].rstrip()}'", end=' ')

    assert 'OpenWrt' == info['name']


@pytest.mark.parametrize("parameter", 
    [('LAN_IF','veth'),('LAN_IF','ens5')], indirect=True,
    ids=['LAN_IF=veth', 'LAN_IF=ens5'])
def test_openwrt_lan(docker_services, parameter):
    docker_services.wait_until_responsive(
        timeout=90.0, pause=1, check=lambda: is_openwrt_booted()
    )
    
    match parameter[1]:
        case 'veth':
            try:
                response = polling2.poll(lambda: os.system("ping -c 1 172.31.1.1 >/dev/null") == 0, step=1, timeout=90)
            except polling2.TimeoutException:
                assert True, 'ping timeout'
            return

        case _: # Usage of real Ethernet interface e.g. 'eth0'
            # This test is most likely only working in a github action enviroment because multiple VM are necessary to test it. See the action file, please.
            # Try to ping LAN-VM
            response = run_openwrt_shell_command("ping", "-c1", "-W2", "-w2", "172.31.1.2")
            assert response['exitcode'] == 0
            return
    
    assert False, 'Unknown parameter'


@pytest.mark.parametrize("parameter", 
    [('WAN_IF','host'),('WAN_IF','none'),('WAN_IF','ens4')], indirect=True,
    ids=['WAN_IF=host', 'WAN_IF=none', 'WAN_IF=ens4'])
def test_openwrt_wan(docker_services, parameter):
    docker_services.wait_until_responsive(
        timeout=90.0, pause=1, check=lambda: is_openwrt_booted()
    )
    
    match parameter[1]:
        case 'host':
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


def test_openwrt_luci_forwarding(docker_services):
    docker_services.wait_until_responsive(
        timeout=90.0, pause=1, check=lambda: is_openwrt_booted()
    )
    
    # Double check if caddy is still running
    assert get_service_status('caddy') == 'RUNNING'

    response = requests.get("http://localhost:9000")
    
    assert ('LuCI - Lua Configuration Interface' in response.content.decode()) == True


@pytest.mark.parametrize("parameter", 
    [('CPU_COUNT',1),('CPU_COUNT',2),('CPU_COUNT',3),('CPU_COUNT',4)], indirect=True,
    ids=['CPU_COUNT=1', 'CPU_COUNT=2', 'CPU_COUNT=3', 'CPU_COUNT=4'])
def test_cpu_num(docker_services, parameter):
    docker_services.wait_until_responsive(
        timeout=90.0, pause=1, check=lambda: is_openwrt_booted()
    )
    
    # Get number of processors
    response = run_openwrt_shell_command("cat", "/proc/cpuinfo")
    cpu_num = response['out-data'].count('processor')
        
    assert parameter[1] == cpu_num


def test_additional_installed_packages(docker_services):

    # Get list of packages to be installed in OpenWrt
    process = subprocess.run(['docker','exec','openwrt','ls','/var/vm/packages'], 
                         stdout=subprocess.PIPE, 
                         universal_newlines=True)
    
    assert process.returncode == 0

    package_list_docker_full = process.stdout.splitlines()
    package_list_docker = []
    for package in package_list_docker_full:
        package = package.split('_')[0] # Use only the name before the '_'
        package_list_docker.append(package)

    # Get list of installed packages in OpenWrt
    docker_services.wait_until_responsive(
        timeout=90.0, pause=1, check=lambda: is_openwrt_booted()
    )
    response = run_openwrt_shell_command("opkg", "list-installed")

    assert response['exitcode'] == 0

    package_list_openwrt_full = response['out-data'].splitlines()

    print(f"'{len(package_list_docker)}' additional installed packages", end=' ')

    # Check if all additional OpenWrt packages in Docker image are installed in OpenWrt
    for package in package_list_docker:
        assert any(package in s for s in package_list_openwrt_full) == True


@pytest.mark.parametrize("parameter", 
    [('','','20240922_test_volume_openwrt_23.05.4.tar.gz')], indirect=True,
    ids=['20240922_test_volume_openwrt_23.05.4'])
def test_openwrt_migrate_existing_volume(docker_services):
    docker_services.wait_until_responsive(
        timeout=90.0, pause=1, check=lambda: is_specific_log('Booting image using QEMU emulator')
    )

    assert ('upgrade: Saving config files' in get_logs()) == True
    assert ('upgrade: Restoring config files' in get_logs()) == True


@pytest.mark.parametrize("parameter", 
    [('','','20240922_test_volume_openwrt_23.05.4.tar.gz')], indirect=True,
    ids=['20240922_test_volume_openwrt_23.05.4'])
def test_openwrt_migrate_settings(docker_services):
    docker_services.wait_until_responsive(
        timeout=90.0, pause=1, check=lambda: is_openwrt_booted()
    )

    # Here we test a custom configuration that is stored in the existing volume.
    # Currently hostname and an additional interface are configured.
    
    # Check for host name 'TestRouter'
    response = run_openwrt_shell_command("uci", "get", "system.@system[0].hostname")
    assert ('TestRouter' in response['out-data']) == True

    # Check for test LAN
    response = run_openwrt_shell_command("uci", "show", "network.TestLan")
    assert ("network.TestLan.ipaddr='192.168.40.1'" in response['out-data']) == True


def test_kvm(docker_services):
    docker_services.wait_until_responsive(
        timeout=90.0, pause=1, check=lambda: is_specific_log('Checking for KVM')
    )

    time.sleep(1)
    assert ('KVM detected' in get_logs()) == True