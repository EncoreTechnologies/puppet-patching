#!/bin/bash

# Run our OS tests, exports OS_TEST_DEB and OS_TEST_RH
source "${PT__installdir}/patching/files/bash/os_test.sh"

################################################################################
if [[ -n "$OS_TEST_RH" ]]; then
  source "${PT__installdir}/patching/files/bash/available_updates_rh.sh"
################################################################################
elif [[ -n "$OS_TEST_DEB" ]]; then
  source "${PT__installdir}/patching/files/bash/available_updates_deb.sh"
################################################################################  
else
  echo "Unknown Operating System: OS_TEST_DEB=${OS_TEST_DEB} RHTEST=${OS_TEST_RH}"
  exit 2
fi
