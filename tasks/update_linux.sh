#!/bin/bash

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

# Run our OS tests, export OS_RELEASE
source "${PT__installdir}/patching/files/bash/os_test.sh"

# default
STATUS=0

case $OS_RELEASE in
################################################################################  
  RHEL | CENTOS | FEDORA | ROCKY | OL | ALMALINUX)
    # RedHat variant
    source "${PT__installdir}/patching/files/bash/update_rh.sh"
    STATUS=$?
    ;;
################################################################################  
  DEBIAN | UBUNTU)
    # Debian variant
    source "${PT__installdir}/patching/files/bash/update_deb.sh"
    STATUS=$?
    ;;
################################################################################
  SLES)
    # SUSE variant
    source "${PT__installdir}/patching/files/bash/update_sles.sh"
    STATUS=$?
    ;;
################################################################################
  *)
    echo "Unknown Operating System: ${OS_RELEASE}"
    STATUS=2
    ;;
esac

exit $STATUS
