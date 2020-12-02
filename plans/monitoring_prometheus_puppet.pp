# @summary Disable Prometheus monitoring by updating a given puppet fact and re-populating the prometheus targets file
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
# @param [Optional[String[1]]] prometheus_targets_file
#   Path to the targets file on the Prometheus server
#
# @param [Boolean] noop
#   Flag to enable noop mode. When noop mode is enabled no snapshots will be created or deleted.
#
# @example Remote target definition for $monitoring_target
#   vars:
#     patching_monitoring_target: 'prometheus'
#     patching_monitoring_puppet_fact: 'monitoring_enabled'
#     prometheus_targets_file: '/etc/prometheus/file_sd_config.d/targets.json'
#     puppetdb_server: 'puppetdb'
#     puppetdb_port: 8081
#     puppet_ssl_dir: '/etc/puppetlabs/puppet/ssl'
#
#   groups:
#     - name: prometheus
#       config:
#         transport: ssh
#         ssh:
#           username: 'domain\svc_bolt_prom'
#           password:
#             _plugin: pkcs7
#             encrypted_value: >
#               ENC[PKCS7,xxx]
#       targets:
#         - prometheus.domain.tld
#
plan patching::monitoring_prometheus_puppet (
  TargetSpec                $targets,
  Enum['enable', 'disable'] $action,
  Optional[String[1]]       $monitoring_puppet_fact = undef,
  TargetSpec                $monitoring_target = get_targets($targets)[0].vars['patching_monitoring_target'],
  String                    $prometheus_targets_file = get_targets($targets)[0].vars['prometheus_targets_file'],
  Optional[String[1]]       $puppetdb_server = undef,
  Optional[String[1]]       $puppetdb_port = undef,
  Optional[String[1]]       $puppet_ssl_dir = undef,
  Boolean                   $noop = false,
) {
  $_targets = run_plan('patching::get_targets', $targets)
  $group_vars = $_targets[0].vars
  $_monitoring_puppet_fact = pick($monitoring_puppet_fact,
                                  $group_vars['patching_monitoring_puppet_fact'],
                                  'monitoring_enabled')
  $_puppetdb_server = pick($puppetdb_server,
                            $group_vars['puppetdb_server'],
                            'puppetdb')
  $_puppetdb_port = pick($puppetdb_port,
                          $group_vars['puppetdb_port'],
                          '8081')
  $_puppet_ssl_dir = pick($puppet_ssl_dir,
                          $group_vars['puppet_ssl_dir'],
                          '/etc/puppetlabs/puppet/ssl')

  # Display status message
  case $action {
    'enable': {
      out::message('Enabling monitoring for:')
      $_targets.each |$n| {
        out::message(" + ${n}")
      }
      $fact_new_value = 'true'
    }
    'disable': {
      out::message('Disabling monitoring for:')
      $_targets.each |$n| {
        out::message(" - ${n}")
      }
      $fact_new_value =	'false'
    }
    default: {
      fail_plan("Unknown action: ${action}")
    }
  }

  if !$noop {
    run_plan('patching::puppet_fact_update', $_targets,
      fact_name  => $_monitoring_puppet_fact,
      fact_value => $fact_new_value,
    )

    # Run the query script and write the result to the given targets file in Prometheus
    $script_args = ['--server', $_puppetdb_server, '--port', $_puppetdb_port, '--ssl-dir', $_puppet_ssl_dir, '--monitoring-fact', $_monitoring_puppet_fact]
    $prom_targets = run_script('patching/python/puppetdb-query-nodes.py', $targets, 'arguments' => $script_args)

    # The write_file command creates a file with 600 permissions and the prometheus service will throw an error that it can't
    # read the file unless we save it to a different file, change the permissions, and then move the file where we want
    write_file($prom_targets.results[0]['stdout'], "${prometheus_targets_file}.tmp", $monitoring_target)
    run_command("chmod 644 ${prometheus_targets_file}.tmp", $monitoring_target)
    run_command("mv ${prometheus_targets_file}.tmp ${prometheus_targets_file}", $monitoring_target)
  }
}