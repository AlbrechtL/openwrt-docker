#!/usr/bin/env bash
set -eu

# Configure QEMU for graceful shutdown

QEMU_MONPORT=7100
QEMU_POWERDOWN_TIMEOUT=8

_QEMU_PID=/run/qemu.pid
_QEMU_SHUTDOWN_COUNTER=/run/qemu.counter

rm -f "${_QEMU_PID}"
rm -f "${_QEMU_SHUTDOWN_COUNTER}"

_trap(){
    func="$1" ; shift
    for sig ; do
        trap "$func $sig" "$sig"
    done
}

snore()
{
    local IFS
    [[ -n "${_snore_fd:-}" ]] || exec {_snore_fd}<> <(:)
    read ${1:+-t "$1"} -u $_snore_fd || :
}

_graceful_shutdown(){

  local QEMU_MONPORT="${QEMU_MONPORT:-7100}"
  local QEMU_POWERDOWN_TIMEOUT="${QEMU_POWERDOWN_TIMEOUT:-8}"

  [ -f "${_QEMU_SHUTDOWN_COUNTER}" ] && return

  set +e
  echo
  echo "Received $1 signal, shutting down..."
  echo 0 > "${_QEMU_SHUTDOWN_COUNTER}"

  # Send the shutdown (system_powerdown) command to the QMP monitor
  echo 'system_powerdown' | nc -q 1 -w 1 localhost "${QEMU_MONPORT}">/dev/null

  while [ "$(cat ${_QEMU_SHUTDOWN_COUNTER})" -lt "${QEMU_POWERDOWN_TIMEOUT}" ]; do

    # Increase the counter
    echo $(($(cat ${_QEMU_SHUTDOWN_COUNTER})+1)) > ${_QEMU_SHUTDOWN_COUNTER}

    # Try to connect to qemu
    if echo 'info version'| nc -q 1 -w 1 localhost "${QEMU_MONPORT:-7100}">/dev/null; then

      sleep 1
      echo "Shutting down, waiting... ($(cat ${_QEMU_SHUTDOWN_COUNTER})/${QEMU_POWERDOWN_TIMEOUT})"

    fi
  done

  echo
  echo "Quitting..."
  echo 'quit' | nc -q 1 -w 1 localhost "${QEMU_MONPORT:-7100}">/dev/null || true

  return
}

_trap _graceful_shutdown SIGTERM SIGHUP SIGINT SIGABRT SIGQUIT

KVM_MON_OPTS="-monitor telnet:localhost:${QEMU_MONPORT:-7100},server,nowait,nodelay"
