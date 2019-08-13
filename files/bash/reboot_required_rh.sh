#!/bin/bash

RH_RELEASE=$(sed -r -e 's/^.* release ([0-9]+(\.[0-9]+)?).*$/\1/' /etc/redhat-release)
RH_MAJOR="${RH_RELEASE%%.*}"

# default
export REBOOT_REQUIRED="false"

# needs-restarting comes with yum-utils package, sometimes this isn't installed
if [[ -x /usr/bin/needs-restarting ]]; then
  if [[ $RH_MAJOR -eq 6 ]]; then
    ## needs-restarting on RHEL6 prints things to STDOUT when a restart is needed
    ## otherwise it prints nothing, so we check to see if the STDOUT contains data
    ## to determine if we need to reboot
    check=$(needs-restarting)
    if [[ -n $check ]]; then
      export REBOOT_REQUIRED="true"
    fi
  elif [[ $RH_MAJOR -ge 7 ]]; then
    ## needs-restarting on RHEL7 returns an exit code of 1 if a reboot is needed, otherwise
    ## a reboot is not required
    check=$(needs-restarting -r)
    EXIT_STATUS=$?
    if [[ $EXIT_STATUS -eq 1 ]]; then
      export REBOOT_REQUIRED="true"
    fi
  else
    echo "ERROR - Unknown RedHat/CentOS version: RH_RELEASE=${RH_RELEASE} RH_MAJOR=${RH_MAJOR}" >&2
    exit 3
  fi
else
  echo "ERROR - /usr/bin/needs-restarting isn't present on a RedHat/CentOS host. You probably need to install the package: yum-utils" >&2
  exit 4
fi
