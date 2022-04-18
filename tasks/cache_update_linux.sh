#!/bin/bash

if [[ -n "$PT__noop" && "$PT__noop" == "true" ]]; then
  echo '{"message": "noop - cache was not updated"}'
  exit 0
fi


# Run our OS tests, export OS_RELEASE
source "${PT__installdir}/patching/files/bash/os_test.sh"

case $OS_RELEASE in
################################################################################
  RHEL | CENTOS | FEDORA | ROCKY | OL | ALMALINUX)
    # RedHat variant
    # update yum cache
    OUTPUT=$(yum clean expire-cache 2>&1)
    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      ERROR="yum clean expire-cache FAILED, you probably forgot to run this as sudo or there is a network error."
    fi
    ;;
################################################################################  
  DEBIAN | UBUNTU)
    # Debian variant
    ## Update apt cache
    OUTPUT=$(apt-get -y update 2>&1)
    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      ERROR="apt-get -y update FAILED, you probably forgot to run this as sudo or there is a network error."
    fi
    ;;
################################################################################
  SLES)
    # SUSE variant
    ## Update zypper cache
    OUTPUT=$(zypper ref 2>&1)
    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      ERROR="zypper ref FAILED, you probably forgot to run this as sudo or there is a network error."
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
