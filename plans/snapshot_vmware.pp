# @summary Creates or deletes VM snapshots on nodes in VMware.
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
# @param [TargetSpec] nodes
#   Set of targets to run against.
#
# @param [Enum['create', 'delete']] action
#   What action to perform on the snapshots:
#
#     - `create` creates a new snapshot
#     - 'delete' deletes snapshots by matching the `snapshot_name` passed in.
#
# @param [Enum['name', 'uri']] vm_name_property
#   Determines what property on the Target object will be used as the VM name when
#   mapping the Target to a VM in vSphere.
#
#    - `uri` : use the `uri` property on the Target. This is preferred because
#       If you specify a list of Targets in the inventory file, the value shown in that
#       list is set as the `uri` and not the `name`, in this case `name` will be `undef`.
#    - `name` : use the `name` property on the Target, this is not preferred because
#       `name` is usually a short name or nickname.
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
# @param [String[1]] snapshot_name
#   Name of the snapshot
#
# @param [String] snapshot_description
#   Description of the snapshot
#
# @param [Boolean] snapshot_memory
#   Capture the VMs memory in the snapshot
#
# @param [Boolean] snapshot_quiesce
#   Quiesce/flush the filesystem when snapshotting the VM. This requires VMware tools be installed
#   in the guest OS to work properly.
#
# @param [Boolean] noop
#   Flag to enable noop mode. When noop mode is enabled no snapshots will be created or deleted.
#
plan patching::snapshot_vmware (
  TargetSpec $nodes,
  Enum['create', 'delete'] $action,
  Enum['name', 'uri']  $vm_name_property = 'uri',
  String[1] $vsphere_host       = get_targets($nodes)[0].vars['vsphere_host'],
  String[1] $vsphere_username   = get_targets($nodes)[0].vars['vsphere_username'],
  String[1] $vsphere_password   = get_targets($nodes)[0].vars['vsphere_password'],
  String[1] $vsphere_datacenter = get_targets($nodes)[0].vars['vsphere_datacenter'],
  Boolean $vsphere_insecure     = get_targets($nodes)[0].vars['vsphere_insecure'],
  String[1] $snapshot_name      = 'Bolt Patching Snapshot',
  String $snapshot_description  = '',
  Boolean $snapshot_memory      = false,
  Boolean $snapshot_quiesce     = true,
  Boolean $noop                 = false,
) {
  $targets = run_plan('patching::get_targets', nodes => $nodes)
  $group_vars = $targets[0].vars
  $_vm_name_property = pick($group_vars['patching_vm_name_property'], $vm_name_property)
  $_snapshot_name = pick($group_vars['patching_snapshot_name'], $snapshot_name)
  $_snapshot_description = pick_default($group_vars['patching_snapshot_description'], $snapshot_description)
  $_snapshot_memory = pick($group_vars['patching_snapshot_memory'], $snapshot_memory)
  $_snapshot_quiesce = pick($group_vars['patching_snapshot_quiesce'], $snapshot_quiesce)

  # Create array of node names
  $vm_names = $targets.map |$n| {
    case $_vm_name_property {
      'name': {
        $n.name
      }
      'uri': {
        $n.uri
      }
      default: {
        fail_plan("Unsupported vm_name_property: ${_vm_name_property}")
      }
    }
  }

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
