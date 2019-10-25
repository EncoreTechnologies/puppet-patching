#!/bin/bash

# Run our OS tests, exports OS_TEST_DEB and OS_TEST_RH
source "${PT__installdir}/patching/files/bash/os_test.sh"

if [[ -n "$PT__noop" && "$PT__noop" == "true" ]]; then
  echo '{"message": "noop - cache was not updated"}'
  exit 0
fi

################################################################################
if [[ -n "$OS_TEST_RH" ]]; then
  # update yum cache
  OUTPUT=$(yum clean expire-cache 2>&1)
  STATUS=$?
  if [[ $STATUS -ne 0 ]]; then
    ERROR="yum clean expire-cache FAILED, you probably forgot to run this as sudo or there is a network error."
  fi
################################################################################  
elif [[ -n "$OS_TEST_DEB" ]]; then
  ## Update apt cache
  OUTPUT=$(apt-get -y update 2>&1)
  STATUS=$?
  if [[ $STATUS -ne 0 ]]; then
    ERROR="apt-get -y update FAILED, you probably forgot to run this as sudo or there is a network error."
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
