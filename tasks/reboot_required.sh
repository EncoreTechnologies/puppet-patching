#!/bin/bash

# Run our OS tests, exports OS_TEST_DEB and OS_TEST_RH
source "${PT__installdir}/patching/files/bash/os_test.sh"

# default
export REBOOT_REQUIRED="false"

################################################################################
if [[ -n "$OS_TEST_RH" ]]; then
  source "${PT__installdir}/patching/files/bash/reboot_required_rh.sh"
################################################################################
elif [[ -n "$OS_TEST_DEB" ]]; then
  source "${PT__installdir}/patching/files/bash/reboot_required_deb.sh"
################################################################################  
else
  echo "ERROR - Unknown Operating System: OS_TEST_DEB=${OS_TEST_DEB} OS_TEST_RH=${OS_TEST_RH}"
  exit 2
fi

echo "{\"reboot_required\": ${REBOOT_REQUIRED} }"
exit 0

