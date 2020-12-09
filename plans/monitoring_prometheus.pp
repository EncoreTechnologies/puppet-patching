# @summary Disable Prometheus monitoring by Creating a silence for each target
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
# @param [Optional[Enum['name', 'uri']]] monitoring_puppet_fact
#   Name of the Puppet fact the determines whether a VM should be monitored or not
#
# @param [TargetSpec] monitoring_target
#   Name or reference to the remote transport target of the Prometheus server.
#   The remote transport should have the following properties:
#     - [String] username
#         Username for authenticating with Prometheus
#     - [Password] password
#         Password for authenticating with Prometheus
#
# @param [Boolean] noop
#   Flag to enable noop mode. When noop mode is enabled no snapshots will be created or deleted.
#
# @example Remote target definition for $monitoring_target
#   vars:
#     patching_monitoring_target: 'prometheus'
#     patching_monitoring_silence_duration: 24
#     patching_monitoring_silence_units: 'hours'
#
#   groups:
#     - name: prometheus
#       config:
#         transport: remote
#         remote:
#           username: 'domain\prom_user'
#           password:
#             _plugin: pkcs7
#             encrypted_value: >
#               ENC[PKCS7,xxx]
#       targets:
#         - prometheus.domain.tld
#
plan patching::monitoring_prometheus (
  TargetSpec                $targets,
  Enum['enable', 'disable'] $action,
  Integer                   $monitoring_silence_duration = get_targets($targets)[0].vars['patching_monitoring_silence_duration'],
  String[1]                 $monitoring_silence_units = get_targets($targets)[0].vars['patching_monitoring_silence_units'],
  TargetSpec                $monitoring_target = 'prometheus',
  Boolean                   $noop = false,
) {
  $_targets = run_plan('patching::get_targets', $targets)
  $group_vars = $_targets[0].vars

  # Set the silence to last for 2 hours by default
  $_monitoring_silence_duration = pick($monitoring_silence_duration,
                                  $group_vars['patching_monitoring_silence_duration'],
                                  2)
  $_monitoring_silence_units = pick($monitoring_silence_units,
                                $group_vars['patching_monitoring_silence_units'],
                                'hours')

  # Create array of node names
  $target_names = patching::target_names($_targets, 'name')

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
    run_task('patching::monitoring_prometheus', $monitoring_target,
      targets           => $target_names,
      action            => $action,
      prometheus_server => $monitoring_target,
      silence_duration  => $_monitoring_silence_duration,
      silence_units     => $_monitoring_silence_units,
    )
  }
}