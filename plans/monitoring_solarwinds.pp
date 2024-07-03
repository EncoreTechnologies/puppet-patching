# @summary Enable or disable monitoring alerts on hosts in SolarWinds.
#
# TODO config variables
#
# @param [TargetSpec] targets
#   Set of targets to run against.
#
# @param [Enum['enable', 'disable']] action
#   What action to perform on the monitored targets:
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
# @param [Optional[String[1]]] monitoring_name_property
#   Determines what property to match in SolarWinds when looking up targets.
#   By default we determine if the target's name is an IP address, if it is then we
#   use the 'IPAddress' property, otherwise we use whatever property this is set to.
#   Available options that we've seen used are 'DNS' if the target's name is a DNS FQDN,
#   or 'Caption' if you're looking up by a nick-name for the target.
#   This can really be any field on the Orion.Nodes table.
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
#         - solarwinds.domain.tld
#
plan patching::monitoring_solarwinds (
  TargetSpec                    $targets,
  Enum['enable', 'disable']     $action,
  Optional[Enum['name', 'uri']] $target_name_property = undef,
  Optional[TargetSpec]          $monitoring_target = undef,
  Optional[String[1]]           $monitoring_name_property = undef,
  Boolean                       $noop = false,
) {
  $_targets = run_plan('patching::get_targets', $targets)
  $group_vars = $_targets[0].vars
  $_target_name_property = pick($target_name_property,
    $group_vars['patching_monitoring_target_name_property'],
  'uri')
  $_monitoring_name_property = pick($monitoring_name_property,
    $group_vars['patching_monitoring_name_property'],
  'DNS')
  $_monitoring_target = pick($monitoring_target,
    $group_vars['patching_monitoring_target'],
  'solarwinds')

  # Create array of node names
  $target_names = patching::target_names($_targets, $_target_name_property)

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
    return run_task('patching::monitoring_solarwinds', $_monitoring_target,
      targets       => $target_names,
      action        => $action,
    name_property => $_monitoring_name_property)
  }
}
