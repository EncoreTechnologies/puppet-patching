#!/bin/bash

# default
export REBOOT_REQUIRED="false"

# from the man page:
# needs-rebooting
#           Checks if the reboot-needed flag was set by a previous update or install of a core library or service. + The reboot-needed flag is set when a package from a predefined list (/etc/zypp/needreboot) is updated or installed.
#           Exit code ZYPPER_EXIT_INF_REBOOT_NEEDED indicates that a reboot is needed, otherwise the exit code is set to ZYPPER_EXIT_OK.
#
# 102 - ZYPPER_EXIT_INF_REBOOT_NEEDED
#           Returned after a successful installation of a patch which requires reboot of computer.

check=$(zypper needs-rebooting)
EXIT_STATUS=$?
if [[ $EXIT_STATUS -eq 102 ]]; then
  export REBOOT_REQUIRED="true"
fi
