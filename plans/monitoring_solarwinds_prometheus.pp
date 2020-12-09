# @summary Disable monitoring for targets in SolarWinds and Prometheus
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
#     patching_monitoring_plan: 'patching::monitoring_solarwinds_prometheus'
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
plan patching::monitoring_solarwinds_prometheus (
  TargetSpec                $targets,
  Enum['enable', 'disable'] $action,
  Boolean                   $noop = false,
) {
  run_plan('patching::monitoring_solarwinds', $targets,
            action => $action,
            noop   => $noop)

  run_plan('patching::monitoring_prometheus', $targets,
            action => $action,
            noop   => $noop)
}