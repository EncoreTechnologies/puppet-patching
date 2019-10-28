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
# @param [Enum['enable', 'disable']] action
#   What action to perform on the monitored nodes:
#
#     - `enable` Resumes monitoring alerts
#     - 'disable' Supresses monitoring alerts
#
# @param [Optional[Enum['name', 'uri']]] target_name_property
#   Determines what property on the Target object will be used as the name when
#   mapping the Target to a Node in SolarWinds.
#
#    - `uri` : use the `uri` property on the Target. This is preferred because
#       If you specify a list of Targets in the inventory file, the value shown in that
#       list is set as the `uri` and not the `name`, in this case `name` will be `undef`.
#    - `name` : use the `name` property on the Target, this is not preferred because
#       `name` is usually a short name or nickname.
#
# @param [TargetSpec] monitoring_target
#   Name or reference to the remote transport target of the Monitoring server.
#   This will be used when to determine how to communicate with the SolarWinds API.
#   The remote transport should have the following properties:
#     - [Integer] port
#         Port to use when communicating with SolarWinds API (default: 17778)
#     - [String] username
#         Username for authenticating with the SolarWinds API
#     - [Password] password
#         Password for authenticating with the SolarWinds API
#
# @param [Boolean] noop
#   Flag to enable noop mode. When noop mode is enabled no snapshots will be created or deleted.
#
# @example Remote target definition for $monitoring_target
#   vars:
#     patching_monitoring_plan: 'patching::monitoring_solarwinds'
#     patching_monitoring_target: 'solarwinds'
#
#   groups:
#     - name: solarwinds
#       config:
#         transport: remote
#         remote:
#           port: 17778
#           username: 'domain\svc_bolt_sw'
#           password:
#             _plugin: pkcs7
#             encrypted_value: >
#               ENC[PKCS7,xxx]
#       targets:
#         - solawrinds.domain.tld
#
plan patching::monitoring_solarwinds (
  TargetSpec                    $nodes,
  Enum['enable', 'disable']     $action,
  Optional[Enum['name', 'uri']] $target_name_property = undef,
  TargetSpec $monitoring_target = get_targets($nodes)[0].vars['patching_monitoring_target'],
  Boolean    $noop              = false,
) {
  $targets = run_plan('patching::get_targets', nodes => $nodes)
  $group_vars = $targets[0].vars
  $_target_name_property = pick($target_name_property,
                                $group_vars['patching_monitoring_target_name_property'],
                                'uri')

  # Create array of node names
  $target_names = patching::target_names($targets, $_target_name_property)

  # Display status message
  case $action {
    'enable': {
      out::message('Enabling monitoring for:')
      $target_names.each |$n| {
        out::message(" + ${n}")
      }
    }
    'disable': {
      out::message('Disabling monitoring for:')
      $target_names.each |$n| {
        out::message(" - ${n}")
      }
    }
    default: {
      fail_plan("Unknown action: ${action}")
    }
  }

  if !$noop {
    return run_task('patching::monitoring_solarwinds', $monitoring_target,
                    nodes  => $vm_names,
                    action => $action)
  }
}
