# @summary Creates or deletes VM snapshots on targets in VMware.
#
# Communicates to the vSphere API from the local Bolt control node using
# the [rbvmomi](https://github.com/vmware/rbvmomi) Ruby gem.
#
# To install the rbvmomi gem on the bolt control node:
# ```shell
#   /opt/puppetlabs/bolt/bin/gem install --user-install rbvmomi
# ```
#
# TODO config variables
#
# @param [TargetSpec] targets
#   Set of targets to run against.
#
# @param [Enum['create', 'delete']] action
#   What action to perform on the snapshots:
#
#     - `create` creates a new snapshot
#     - 'delete' deletes snapshots by matching the `snapshot_name` passed in.
#
# @param [Optional[Enum['hostname', 'name', 'uri']]] target_name_property
#   Determines what property on the Target object will be used as the VM name when
#   mapping the Target to a VM in vSphere.
#
#    - `uri` : use the `uri` property on the Target. This is preferred because
#       If you specify a list of Targets in the inventory file, the value shown in that
#       list is set as the `uri` and not the `name`, in this case `name` will be `undef`.
#    - `name` : use the `name` property on the Target, this is not preferred because
#       `name` is usually a short name or nickname.
#    - `hostname`: use the `hostname` value to use host component of `uri` property on the Target
#      this can be useful if VM name doesn't include domain name
#
# @param [String[1]] vsphere_host
#   Hostname of the vSphere server that we're going to use to create snapshots via the API.
#
# @param [String[1]] vsphere_username
#   Username to use when authenticating with the vSphere API.
#
# @param [String[1]] vsphere_password
#   Password to use when authenticating with the vSphere API.
#
# @param [String[1]] vsphere_datacenter
#   Name of the vSphere datacenter to search for VMs under.
#
# @param [Boolean] vsphere_insecure
#   Flag to enable insecure HTTPS connections by disabling SSL server certificate verification.
#
# @param [Optional[String[1]]] snapshot_name
#   Name of the snapshot
#
# @param [Optional[String]] snapshot_description
#   Description of the snapshot
#
# @param [Optional[Boolean]] snapshot_memory
#   Capture the VMs memory in the snapshot
#
# @param [Optional[Boolean]] snapshot_quiesce
#   Quiesce/flush the filesystem when snapshotting the VM. This requires VMware tools be installed
#   in the guest OS to work properly.
#
# @param [Boolean] noop
#   Flag to enable noop mode. When noop mode is enabled no snapshots will be created or deleted.
#
plan patching::snapshot_vmware (
  TargetSpec $targets,
  Enum['create', 'delete'] $action,
  Optional[Enum['hostname', 'name', 'uri']] $target_name_property = undef,
  String[1] $vsphere_host       = get_targets($targets)[0].vars['vsphere_host'],
  String[1] $vsphere_username   = get_targets($targets)[0].vars['vsphere_username'],
  String[1] $vsphere_password   = get_targets($targets)[0].vars['vsphere_password'],
  String[1] $vsphere_datacenter = get_targets($targets)[0].vars['vsphere_datacenter'],
  Boolean $vsphere_insecure     = get_targets($targets)[0].vars['vsphere_insecure'],
  Optional[String[1]] $snapshot_name      = undef,
  Optional[String] $snapshot_description  = undef,
  Optional[Boolean] $snapshot_memory      = undef,
  Optional[Boolean] $snapshot_quiesce     = undef,
  Boolean $noop                 = false,
) {
  $_targets = run_plan('patching::get_targets', $targets)
  $group_vars = $_targets[0].vars
  # Order: CLI > Config > Default
  $_target_name_property = pick($target_name_property,
    $group_vars['patching_snapshot_target_name_property'],
  'uri')
  $_snapshot_name = pick($snapshot_name,
    $group_vars['patching_snapshot_name'],
  'Bolt Patching Snapshot')
  $_snapshot_description = pick_default($snapshot_description,
    $group_vars['patching_snapshot_description'],
  '')
  $_snapshot_memory = pick($snapshot_memory,
    $group_vars['patching_snapshot_memory'],
  false)
  $_snapshot_quiesce = pick($snapshot_quiesce,
    $group_vars['patching_snapshot_quiesce'],
  true)

  # Create array of node names
  $vm_names = patching::target_names($_targets, $_target_name_property)

  # Display status message
  if $action == 'create' {
    out::message("Creating VM snapshot '${_snapshot_name}' for:")
    $vm_names.each |$n| {
      out::message(" + ${n}")
    }
  } else {
    out::message("Deleting VM snapshot '${_snapshot_name}' for:")
    $vm_names.each |$n| {
      out::message(" - ${n}")
    }
  }

  if !$noop {
    return patching::snapshot_vmware($vm_names,
      $_snapshot_name,
      $vsphere_host,
      $vsphere_username,
      $vsphere_password,
      $vsphere_datacenter,
      $vsphere_insecure,
      $_snapshot_description,
      $_snapshot_memory,
      $_snapshot_quiesce,
    $action)
  }
}
