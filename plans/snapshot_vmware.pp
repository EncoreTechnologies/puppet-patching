# Creates or deletes VM snapshot on supplied nodes.
#
# NOTE1: rbvmomi gem must be installed on the localhost for this plan to function.
#        /opt/puppetlabs/bolt/bin/gem install --user-install rbvmomi
#
# NOTE2: rbvmomi requires the following packages:
#        - zlib-devel
#        - libxslt-devel
#        - patch
#        - gcc
#
# NOTE3: This plan will attempt to collect vsphere parameters from the inventory
#        file for the vsphere host name, username, password and datacenter based
#        on the variables for the first node specified in TargetSpec.
#
plan patching::snapshot_vmware (
  TargetSpec $nodes,
  Enum['create', 'delete'] $action,
  String[1] $snapshot_name      = 'Bolt Patching Snapshot',
  String[1] $vsphere_host       = get_targets($nodes)[0].vars['vsphere_host'],
  String[1] $vsphere_username   = get_targets($nodes)[0].vars['vsphere_username'],
  String[1] $vsphere_password   = get_targets($nodes)[0].vars['vsphere_password'],
  String[1] $vsphere_datacenter = get_targets($nodes)[0].vars['vsphere_datacenter'],
  Boolean $vsphere_insecure     = get_targets($nodes)[0].vars['vsphere_insecure'],
  String $snapshot_description  = '',
  Boolean $snapshot_memory      = false,
  Boolean $snapshot_quiesce     = true,
  Boolean $noop                 = false,
) {
  # Create array of node names
  $vm_names = get_targets($nodes).map |$n| { $n.uri }

  # Display status message
  if $action == 'create' {
    out::message("Creating VM snapshot '${snapshot_name}' for:")
    $vm_names.each |$n| {
      out::message(" + ${n}")
    }
  } else {
    out::message("Deleting VM snapshot '${snapshot_name}' for:")
    $vm_names.each |$n| {
      out::message(" - ${n}")
    }
  }

  if !$noop {
    return patching::snapshot_vmware($vm_names,
                                     $snapshot_name,
                                     $vsphere_host,
                                     $vsphere_username,
                                     $vsphere_password,
                                     $vsphere_datacenter,
                                     $vsphere_insecure,
                                     $snapshot_description,
                                     $snapshot_memory,
                                     $snapshot_quiesce,
                                     $action)
  }
}
