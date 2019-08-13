#!/bin/bash

## TODO: don't return any updated packages if we didn't do anything
##       (right now we're pulling out last history from log files which might be from a previous
##        run if no patches were installed)

export PACKAGES="$PT_names"
export RESULT_FILE="$PT_result_file"
export LOG_FILE="$PT_log_file"
if [[ -z "$LOG_FILE" ]]; then
  export LOG_FILE="/var/log/patching.log"
fi
if [[ -z "$RESULT_FILE" ]]; then
  export RESULT_FILE="/var/log/patching.json"
fi
if [[ ! -e "$LOG_FILE" ]]; then
  touch "$LOG_FILE"
fi
if [[ ! -e "$RESULT_FILE" ]]; then
  touch "$RESULT_FILE"
fi

# Run our OS tests, exports OS_TEST_DEB and OS_TEST_RH
source "${PT__installdir}/patching/files/bash/os_test.sh"

STATUS=0
################################################################################
if [[ -n "$OS_TEST_RH" ]]; then
  source "${PT__installdir}/patching/files/bash/update_rh.sh"
  STATUS=$?
################################################################################  
elif [[ -n "$OS_TEST_DEB" ]]; then
  source "${PT__installdir}/patching/files/bash/update_deb.sh"
  STATUS=$?
################################################################################
else
  echo "Unknown Operating System: OS_TEST_DEB=${OS_TEST_DEB} OS_TEST_RH=${OS_TEST_RH}"
  exit 2
fi

exit $STATUS
