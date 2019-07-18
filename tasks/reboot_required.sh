#!/bin/bash
DEBTEST=$(lsb_release -a 2> /dev/null | grep Distributor | awk '{print $3}')
RHTEST=$(cat /etc/redhat-release 2> /dev/null | sed -e "s~\(.*\)release.*~\1~g")

# default
REBOOT_REQUIRED="false"

################################################################################
if [[ -n "$RHTEST" ]]; then
  RH_RELEASE=$(sed -r -e 's/^.* release ([0-9]+(\.[0-9]+)?).*$/\1/' /etc/redhat-release)
  RH_MAJOR="${RH_RELEASE%%.*}"

  # needs-restarting comes with yum-utils package, sometimes this isn't installed
  if [[ -x /usr/bin/needs-restarting ]]; then
    if [[ $RH_MAJOR -eq 6 ]]; then
      ## Need to do some jumps to make this work on RHEL6 like RHEL7
      check=$(needs-restarting)
      if [[ -n $check ]]; then
        REBOOT_REQUIRED='true'
      fi
    elif [[ $RH_MAJOR -ge 7 ]]; then
      check=$(needs-restarting -r)
      EXIT_STATUS=$?
      if [[ $EXIT_STATUS -eq 1 ]]; then
        REBOOT_REQUIRED='true'
      fi
    else
      echo "ERROR - Unknown RedHat/CentOS version: RH_RELEASE=${RH_RELEASE} RH_MAJOR=${RH_MAJOR}" >&2
      exit 3
    fi
  else
    echo "ERROR - /usr/bin/needs-restarting isn't present on a RedHat/CentOS host. You probably need to install the package: yum-utils" >&2
    exit 4
  fi

################################################################################
elif [[ -n "$DEBTEST" ]]; then
  if [[ -f /var/run/reboot-required ]]; then
    REBOOT_REQUIRED="true"
  fi

################################################################################  
else
  echo "ERROR - Unknown Operating System: DEBTEST=${DEBTEST} RHTEST=${RHTEST}"
  exit 2
fi

echo "{\"reboot_required\": ${REBOOT_REQUIRED} }"
exit 0

