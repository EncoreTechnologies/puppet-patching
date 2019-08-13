#!/bin/bash
export OS_TEST_DEB=$(lsb_release -a 2> /dev/null | grep Distributor | awk '{print $3}')
export OS_TEST_RH=$(cat /etc/redhat-release 2> /dev/null | sed -e "s~\(.*\)release.*~\1~g")
