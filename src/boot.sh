#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${BOOT_MODE:="legacy"}"  # Boot mode

SECURE=""
BOOT_OPTS=""

case "${BOOT_MODE,,}" in
  uefi)
    ROM="OVMF_CODE_4M.fd"
    VARS="OVMF_VARS_4M.fd"
    ;;
  secure)
    ROM="OVMF_CODE_4M.secboot.fd"
    VARS="OVMF_VARS_4M.secboot.fd"
    ;;
  windows)
    ROM="OVMF_CODE_4M.ms.fd"
    VARS="OVMF_VARS_4M.ms.fd"
    ;;
  legacy)
    BOOT_OPTS=""
    ;;
  *)
    info "Unknown boot mode '${BOOT_MODE}', defaulting to 'legacy'"
    BOOT_MODE="legacy"    
    ;;
esac

if [[ "${BOOT_MODE,,}" != "legacy" ]]; then

  BOOT_OPTS=""
  OVMF="/usr/share/OVMF"
  DEST="$STORAGE/${BOOT_MODE,,}"

  if [ ! -f "$DEST.rom" ]; then
    [ ! -f "$OVMF/$ROM" ] && error "UEFI boot file ($OVMF/$ROM) not found!" && exit 44
    cp "$OVMF/$ROM" "$DEST.rom"
  fi

  if [ ! -f "$DEST.vars" ]; then
    [ ! -f "$OVMF/$VARS" ] && error "UEFI vars file ($OVMF/$VARS) not found!" && exit 45
    cp "$OVMF/$VARS" "$DEST.vars"
  fi

  if [[ "${BOOT_MODE,,}" != "uefi" ]]; then
    SECURE=",smm=on"
    BOOT_OPTS="$BOOT_OPTS -global driver=cfi.pflash01,property=secure,value=on"
  fi

  BOOT_OPTS="$BOOT_OPTS -drive file=$DEST.rom,if=pflash,unit=0,format=raw,readonly=on"
  BOOT_OPTS="$BOOT_OPTS -drive file=$DEST.vars,if=pflash,unit=1,format=raw"

  if [[ "${BOOT_MODE,,}" == "windows" ]]; then

    BOOT_OPTS="$BOOT_OPTS -chardev socket,id=chrtpm,path=/dev/shm/tpm/swtpm-sock"
    BOOT_OPTS="$BOOT_OPTS -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0"

    mkdir -p /dev/shm/tpm
    swtpm socket -t -d --tpmstate dir=/dev/shm/tpm --ctrl type=unixio,path=/dev/shm/tpm/swtpm-sock --tpm2

  fi

fi

return 0
