#!/bin/bash

# Run our OS tests, export OS_RELEASE
source "${PT__installdir}/patching/files/bash/os_test.sh"

# default
export REBOOT_REQUIRED="false"

case $OS_RELEASE in
################################################################################  
  RHEL | CENTOS | FEDORA | ROCKY | OL | ALMALINUX)
    # RedHat variant
    source "${PT__installdir}/patching/files/bash/reboot_required_rh.sh"
    ;;
################################################################################
  DEBIAN | UBUNTU)
    # Debian variant
    source "${PT__installdir}/patching/files/bash/reboot_required_deb.sh"
    ;;
################################################################################  
  SLES)
    # SUSE variant
    source "${PT__installdir}/patching/files/bash/reboot_required_sles.sh"
    ;;
################################################################################
  *)
    echo "ERROR - Unknown Operating System: ${OS_RELEASE}"
    exit 2
    ;;
esac

echo "{\"reboot_required\": ${REBOOT_REQUIRED} }"
exit 0

