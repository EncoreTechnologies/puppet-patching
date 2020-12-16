# @summary Disable monitoring for targets in multiple services
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
# @param [Boolean] noop
#   Flag to enable noop mode.
#
# @example Remote target definition for $monitoring_target
#   vars:
#     patching_monitoring_plan: 'patching::monitoring_multiple'
#     patching_monitoring_plan_multiple:
#       - 'patching::monitoring_solarwinds'
#       - 'patching::monitoring_prometheus'
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
plan patching::monitoring_multiple (
  TargetSpec                $targets,
  Enum['enable', 'disable'] $action,
  Array                     $monitoring_plan = get_targets($targets)[0].vars['patching_monitoring_plan_multiple'],
  Boolean                   $noop = false,
) {

  # Loop over and run each monitoring plan
  $monitoring_plan.each |String $plan| {
    run_plan($plan, $targets,
              action => $action,
              noop   => $noop)
  }
}
