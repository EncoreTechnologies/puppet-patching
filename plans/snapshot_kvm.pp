# @summary Creates or deletes VM snapshots on targets in KVM/Libvirt.
#
# Runs commands on the CLI of the KVM/Libvirt hypervisor host.
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
##
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
# @param [TargetSpec] hypervisor_targets
#   Name or reference to the targets of the KVM hypervisors.
#   We will login to this host an run the snapshot tasks so that the local CLI can be used.
#   Default target name is "kvm_hypervisors", this can be a group of targets too!
#
# @param [Boolean] noop
#   Flag to enable noop mode. When noop mode is enabled no snapshots will be created or deleted.
#
plan patching::snapshot_kvm (
  TargetSpec $targets,
  Enum['create', 'delete'] $action,
  Optional[Enum['hostname', 'name', 'uri']] $target_name_property = undef,
  Optional[String[1]] $snapshot_name      = undef,
  Optional[String] $snapshot_description  = undef,
  Optional[Boolean] $snapshot_memory      = undef,
  Optional[Boolean] $snapshot_quiesce     = undef,
  Optional[TargetSpec] $hypervisor_targets = undef,
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
  'Bolt Patching Snapshot')
  $_snapshot_memory = pick($snapshot_memory,
    $group_vars['patching_snapshot_memory'],
  false)
  $_snapshot_quiesce = pick($snapshot_quiesce,
    $group_vars['patching_snapshot_quiesce'],
  false)
  $_hypervisor_targets = pick($hypervisor_targets,
    $group_vars['patching_snapshot_kvm_hypervisor_targets'],
  'kvm_hypervisors')

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
    return(run_task('patching::snapshot_kvm', $_hypervisor_targets,
        vm_names => $vm_names,
        snapshot_name => $_snapshot_name,
        snapshot_description => $_snapshot_description,
        snapshot_memory => $_snapshot_memory,
        snapshot_quiesce => $_snapshot_quiesce,
    action => $action))
  }
}
