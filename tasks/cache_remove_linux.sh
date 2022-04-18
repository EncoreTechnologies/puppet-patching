#!/bin/bash

# Run our OS tests, export OS_RELEASE
source "${PT__installdir}/patching/files/bash/os_test.sh"

case $OS_RELEASE in
################################################################################  
  RHEL | CENTOS | FEDORA | ROCKY | OL | ALMALINUX)
    # RedHat variant
    # clean yum cache
    OUTPUT=$(yum clean all 2>&1)
    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      ERROR="yum clean all FAILED, you probably forgot to run this as sudo or there is a network error."
    fi
    ;;
################################################################################  
  DEBIAN | UBUNTU)
    # Debian variant
    ## Clean apt cache
    OUTPUT=$(apt-get clean 2>&1)
    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      ERROR="apt-get clean FAILED, you probably forgot to run this as sudo or there is a network error."
    fi
    ;;
################################################################################
  SLES)
    # SUSE variant
    # clean zypper cache
    OUTPUT=$(zypper clean 2>&1)
    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      ERROR="zypper clean FAILED, you probably forgot to run this as sudo or there is a network error."
    fi
    ;;
################################################################################
  *)
    ERROR="Unknown Operating System: ${OS_RELEASE}"
    STATUS=2
    ;;
esac

if [[ $STATUS -ne 0 ]]; then
  echo "ERROR: $ERROR"
  echo "Output: $OUTPUT"
fi
exit $STATUS
