#!/bin/bash

# Run our OS tests, export OS_RELEASE
source "${PT__installdir}/patching/files/bash/os_test.sh"

case $OS_RELEASE in
################################################################################  
  RHEL | CENTOS | FEDORA | ROCKY | OL | ALMALINUX)
    # RedHat variant
    source "${PT__installdir}/patching/files/bash/available_updates_rh.sh"
    ;;
################################################################################  
  DEBIAN | UBUNTU)
    # Debian variant
    source "${PT__installdir}/patching/files/bash/available_updates_deb.sh"
    ;;
################################################################################  
  SLES)
    # SUSE variant
    source "${PT__installdir}/patching/files/bash/available_updates_sles.sh"
    ;;
################################################################################
  *)
    echo "Unknown Operating System: ${OS_RELEASE}"
    exit 2
    ;;
esac
