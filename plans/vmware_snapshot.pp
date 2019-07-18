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
# NOTE3: This plan will attempt to collect vCenter parameters from the inventory
#        file for the vCenter host name, username, password and datacenter based
#        on the variables for the first node specified in TargetSpec.
#
plan patching::vmware_snapshot (
  TargetSpec $nodes,
  Enum['create', 'delete'] $action,
  String[1] $snapshot_name      = 'Bolt Patching Snapshot',
  String[1] $vcenter_host       = get_targets($nodes)[0].vars['vcenter_host'],
  String[1] $vcenter_username   = get_targets($nodes)[0].vars['vcenter_username'],
  String[1] $vcenter_password   = get_targets($nodes)[0].vars['vcenter_password'],
  String[1] $vcenter_datacenter = get_targets($nodes)[0].vars['vcenter_datacenter'],
  Boolean $vcenter_insecure     = get_targets($nodes)[0].vars['vcenter_insecure'],
  String $snapshot_description  = '',
  Boolean $snapshot_memory      = false,
  Boolean $snapshot_quiesce     = false,
) {
  # Create array of node names
  $vm_names = get_targets($nodes).map |$n| { $n.name }

  # Display status message
  if $action == 'create' {
    notice("Creating VM snapshot '${snapshot_name}' for:")
    get_targets($nodes).each |$i| {
      notice(" + ${i.name}")
    }
  } else {
    warning("Deleting VM snapshot '${snapshot_name}' for:")
    get_targets($nodes).each |$i| {
      warning(" - ${i.name}")
    }
  }

  return patching::vmware_snapshot($vm_names,
                                   $snapshot_name,
                                   $vcenter_host,
                                   $vcenter_username,
                                   $vcenter_password,
                                   $vcenter_datacenter,
                                   $vcenter_insecure,
                                   $snapshot_description,
                                   $snapshot_memory,
                                   $snapshot_quiesce,
                                   $action)
}
