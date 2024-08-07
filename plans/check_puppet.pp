# @summary Checks each node to see if Puppet is installed, then gather Facts on all targets.
#
# Executes the <code>puppet_agent::version</code> task to check if Puppet is installed
# on all of the targets. Once finished, the result is split into two groups:
#
#  1. Targets with puppet
#  2. Targets with no puppet
#
# The targets with puppet are queried for facts using the <code>patching::puppet_facts</code> plan.
# Targets without puppet are queried for facts using the simpler <code>facts</code> plan.
#
# This plan is designed to be the first plan executed in a patching workflow.
# It can be used to stop the patching process if any hosts are offline by setting
# <code>filter_offline_targets=false</code> (default). It can also be used
# to patch any hosts that are currently available and ignoring any offline targets
# by setting <code>filter_offline_targets=true</code>.
#
# @param [TargetSpec] targets
#   Set of targets to run against.
# @param [Boolean] filter_offline_targets
#   Flag to determine if offline targets should be filtered out of the list of targets
#   returned by this plan. If true, when running the <code>puppet_agent::version</code>
#   check, any targets that return an error will be filtered out and ignored.
#   Those targets will not be returned in any of the data structures in the result of
#   this plan. If false, then any targets that are offline will cause this plan to error
#   immediately when performing the online check. This will result in a halt of the
#   patching process.
#
# @return [Struct[{has_puppet => Array[TargetSpec],
#                  no_puppet => Array[TargetSpec],
#                  all => Array[TargetSpec]}]]
#
# @example CLI - Basic usage (error if any targets are offline)
#   bolt plan run patching::check_puppet --targets linux_hosts
#
# @example CLI - Filter offline targets (only return online targets)
#   bolt plan run patching::check_puppet --targets linux_hosts filter_offline_targets=true
#
# @example Plan - Basic usage (error if any targets are offline)
#   $results = run_plan('patching::check_puppet', $linux_hosts)
#   $targets_has_puppet = $results['has_puppet']
#   $targets_no_puppet = $results['no_puppet']
#   $targets_all = $results['all']
#
# @example Plan - Filter offline targets (only return online targets)
#   $results = run_plan('patching::check_puppet', $linux_hosts,
#                       filter_offline_targets => true)
#   $targets_online_has_puppet = $results['has_puppet']
#   $targets_online_no_puppet = $results['no_puppet']
#   $targets_online = $results['all']
#
plan patching::check_puppet (
  TargetSpec $targets,
  Boolean $filter_offline_targets = false,
) {
  $_targets = get_targets($targets)
  ## This will check all targets to verify online by checking their Puppet agent version
  $targets_version = run_task('puppet_agent::version', $_targets,
  _catch_errors => $filter_offline_targets)
  # if we're filtering out offline targets, then only accept the ok_set from the task above
  if $filter_offline_targets {
    $targets_filtered = $targets_version.ok_set
  }
  else {
    $targets_filtered = $targets_version
  }
  # targets without puppet will return a value {'verison' => undef}
  $targets_with_puppet = $targets_filtered.filter_set |$res| { $res['version'] != undef }.targets
  $targets_no_puppet = $targets_filtered.filter_set |$res| { $res['version'] == undef }.targets

  ## get facts from each node
  if !$targets_with_puppet.empty() {
    # run `puppet facts` on targets with Puppet because it returns a more complete
    # set of facts than just running `facter`
    run_plan('patching::puppet_facts', $targets_with_puppet)
  }
  if !$targets_no_puppet.empty() {
    # run `facter` if it's available otherwise get basic facts
    run_plan('facts', $targets_no_puppet)
  }

  return({
      'has_puppet' => $targets_with_puppet,
      'no_puppet' => $targets_no_puppet,
      'all' => $targets_with_puppet + $targets_no_puppet,
  })
}
