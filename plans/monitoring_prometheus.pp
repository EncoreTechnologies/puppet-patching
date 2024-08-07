# @summary Create or remove alert silences for hosts in Prometheus.
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
# @param [Optional[Integer]] monitoring_silence_duration
#   How long the alert silence will be alive for
#
# @param [Optional[Enum['minutes', 'hours', 'days', 'weeks']]] monitoring_silence_units
#   Goes with the silence duration to determine how long the alert silence will be alive for
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
  TargetSpec                                          $targets,
  Enum['enable', 'disable']                           $action,
  Optional[Integer]                                   $monitoring_silence_duration = undef,
  Optional[Enum['minutes', 'hours', 'days', 'weeks']] $monitoring_silence_units = undef,
  Optional[TargetSpec]                                $monitoring_target = undef,
  Boolean                                             $noop = false,
  Boolean                                             $ssl_verify = get_targets($targets)[0].vars['patching_monitoring_ssl'],
  String                                              $ssl_cert = get_targets($targets)[0].vars['patching_monitoring_ssl_cert'],
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
  $_monitoring_target = pick($monitoring_target,
    $group_vars['patching_monitoring_target'],
  'prometheus')

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
    run_task('patching::monitoring_prometheus', $_monitoring_target,
      targets           => $target_names,
      action            => $action,
      prometheus_server => get_target($_monitoring_target).uri,
      silence_duration  => $_monitoring_silence_duration,
      silence_units     => $_monitoring_silence_units,
      ssl_verify        => $ssl_verify,
      ssl_cert          => $ssl_cert,
    )
  }
}
