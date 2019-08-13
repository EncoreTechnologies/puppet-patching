#!/bin/bash

# default
export REBOOT_REQUIRED="false"
if [[ -f /var/run/reboot-required ]]; then
  export REBOOT_REQUIRED="true"
fi
