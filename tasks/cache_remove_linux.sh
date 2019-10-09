#!/bin/bash

# Run our OS tests, exports OS_TEST_DEB and OS_TEST_RH
source "${PT__installdir}/patching/files/bash/os_test.sh"

################################################################################
if [[ -n "$OS_TEST_RH" ]]; then
  # clean yum cache
  OUTPUT=$(yum clean all 2>&1)
  STATUS=$?
  if [[ $STATUS -ne 0 ]]; then
    ERROR="yum clean all FAILED, you probably forgot to run this as sudo or there is a network error."
  fi
################################################################################  
elif [[ -n "$OS_TEST_DEB" ]]; then
  ## Clean apt cache
  OUTPUT=$(apt-get clean 2>&1)
  STATUS=$?
  if [[ $STATUS -ne 0 ]]; then
    ERROR="apt-get clean FAILED, you probably forgot to run this as sudo or there is a network error."
  fi
################################################################################
else
  echo "Unknown Operating System: OS_TEST_DEB=${OS_TEST_DEB} OS_TEST_RH=${OS_TEST_RH}"
  exit 2
fi

if [[ $STATUS -ne 0 ]]; then
  echo "ERROR: $ERROR"
  echo "Output: $OUTPUT"
fi
exit $STATUS
