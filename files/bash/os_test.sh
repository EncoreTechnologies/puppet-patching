#!/bin/bash

if [ -e /etc/os-release ]; then
  export OS_RELEASE=$(sed -n -e "/^ID=/p" /etc/os-release | sed -e 's~\(.*\)=\(.*\)~\U\2~g' -e 's~[" ]~~g')
else
# fall back to older methods for OS that do not use systemd
  export OS_TEST_DEB=$(lsb_release -a 2> /dev/null | grep Distributor | awk '{print $3}')
  export OS_TEST_RH=$(sed -e "s~\(.*\)release.*~\1~g" /etc/redhat-release 2> /dev/null)

  if [[ -n "$OS_TEST_RH" ]]; then
    export OS_RELEASE='RHEL'
  elif [[ -n "$OS_TEST_DEB" ]]; then
    # treat as Ubuntu, but Debian would also work
    export OS_RELEASE='UBUNTU'
  else
    # default
    export OS_RELEASE='UNKNOWN'
  fi
fi
