#!/bin/sh
#
# Copyright Albrecht Lohofener 2025 <albrechtloh@gmx.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.


VERSION=0.1

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "Small helper to interact with qemu QMP"
   echo
   echo "Syntax: qemu_qmp [-r|h|v]"
   echo "options:"
   echo "r     Reset VM."
   echo "h     Print this Help."
   echo "v     Print software version and exit."
   echo
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################
############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hvrqsSVRc" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      v) # Show version
         echo $VERSION
         exit;;
      r) # Reset VM
         echo -ne '{ "execute": "qmp_capabilities" } { "execute": "system_reset" }' | nc -w 1 -U /run/qmp-sock
         exit;;
      q) # Quit Qemu
         echo -ne '{ "execute": "qmp_capabilities" } { "execute": "quit" }' | nc -w 1 -U /run/qmp-sock
         exit;;
      s) # Shutdown VM
         echo -ne '{ "execute": "qmp_capabilities" } { "execute": "system_powerdown" }' | nc -w 1 -U /run/qmp-sock
         exit;;
      S) # Shutdown VM grateful, package qemu-ga needs to be installed
         echo -ne '{"execute":"guest-shutdown"}' | nc -w 1 -U /run/qga.sock
         exit;;
      V) # Get VM infos, package qemu-ga needs to be installed
         echo -ne '{"execute":"guest-get-osinfo"}' | nc -w 1 -U /run/qga.sock
         exit;;
      R) # Reboot, package qemu-ga needs to be installed
         echo -ne '{"execute": "guest-exec", "arguments": { "path": "reboot"}}' | nc -w 1 -U /run/qga.sock
         exit;;
      c) # Run shell command inside OpenWrt, package qemu-ga needs to be installed
         # Execute command in OpenWrt
         INPUT_DATA=`echo "$2" | base64 -w 0`
         RETURN_JSON=`echo '{"execute": "guest-exec", "arguments": { "path": "/bin/sh", "input-data": "'${INPUT_DATA}'", "capture-output": true }}' | nc -w 1 -U /run/qga.sock`         
         PID=`echo $RETURN_JSON | sed -n 's/.*"pid": \([0-9]*\).*/\1/p'` # Process return and extract PID
         #echo >&2 "RETURN_JSON: $RETURN_JSON"
         [ -z "$PID" ] && echo >&2 "Command error: PID is empty! RETURN_JSON: $RETURN_JSON" && exit 1
         while true; do # Wait for command exit
            RETURN_JSON=`echo '{"execute": "guest-exec-status", "arguments": { "pid": '${PID}'}}' | nc -w 1 -U /run/qga.sock`
            #echo >&2 "RETURN_JSON: $RETURN_JSON"
            export EXITCODE=`echo $RETURN_JSON | sed -n 's/.*"exitcode": \([0-9]*\).*/\1/p'`
            export OUT_DATA=`echo $RETURN_JSON | sed -n 's/.*"out-data": "\([^"]*\).*/\1/p' | base64 -d -w 0`
            export ERR_DATA=`echo $RETURN_JSON | sed -n 's/.*"err-data": "\([^"]*\).*/\1/p' | base64 -d -w 0`
            export EXITED=`echo $RETURN_JSON | sed -n 's/.*"exited": \(true\|false\).*/\1/p'`
            if [ "$EXITED" = "true" ]; then
               break
            fi
            sleep 1
         done
         if [ -n "$OUT_DATA" ]; then 
            echo "$OUT_DATA" # Return stdout
         fi
         if [ -z "$EXITCODE" ]; then # Exit code handling
            exit 1
         else
            if [ $EXITCODE != 0 ]; then
               echo >&2 "Command error \"$ERR_DATA\" (exit code \"$EXITCODE\")"
            fi
            exit "$EXITCODE"
         fi;;
     \?) # Invalid option
         echo "Error: Invalid option"
         Help
         exit;;
   esac 
done

