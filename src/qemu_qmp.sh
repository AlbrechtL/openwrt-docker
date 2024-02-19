#!/bin/sh
# Source: https://www.redhat.com/sysadmin/arguments-options-bash-scripts

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
while getopts ":hvrqs" option; do
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
     \?) # Invalid option
         echo "Error: Invalid option"
         Help
         exit;;
   esac
done

