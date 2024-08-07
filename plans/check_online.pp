# @summary Checks each node to see they're online.
#
# Online checks are done querying for the node's Puppet version using the
# <code>puppet_agent::version</code> task.
# This plan is designed to be used ad-hoc as a quick health check of your inventory.
# It is the intention of this plan to be used as "first pass" when onboarding new targets
# into a Bolt rotation.
# One would build their inventory file of all targets from their trusted data sources.
# Then take the inventory files and run this plan against them to isolate problem targets
# and remediate them.
# Once this plan runs successfuly on your inventory, you know that Bolt can connect
# and can begin the patching proces.
#
# There are no results returned by this plan, instead data is pretty-printed to the screen in
# two lists:
#
#   1. List of targets that failed to connect. This list is a YAML list where each line
#      is the name of a Target that failed to connect.
#      The intention here is that you can use this YAML list to modify your inventory
#      and remove these problem hosts from your groups.
#   2. Details for each failed target. This provides details about the error that
#      occured when connecting. Failures can occur for many reasons, host being offline
#      host not listening on the right port, firewall blocking, invalid credentials, etc.
#      The idea here is to give the end-user a easily digestible summary so that action
#      can be taken to remediate these hosts.
#
# @param [TargetSpec] targets
#   Set of targets to run against.
#
# @example CLI - Basic usage
#   bolt plan run patching::check_online
#
plan patching::check_online (
  TargetSpec $targets,
) {
  $_targets = get_targets($targets)
  ## This will check all targets to verify online by checking their Puppet agent version
  $targets_version = run_task('puppet_agent::version', $_targets,
  _catch_errors => true)
  # if we're filtering out offline targets, then only accept the ok_set from the task above
  if !$targets_version.error_set.empty() {
    $errors_array = Array($targets_version.error_set)
    $sorted_errors = $errors_array.sort|$a, $b| {
      compare($a.target.name, $b.target.name)
    }
    out::message('###################################')
    out::message('List of targets that failed to connect')
    $sorted_errors.each |$res| {
      $name = $res.target.name
      out::message("- ${name}")
    }
    out::message('###################################')
    out::message('Details for each failed target')
    $sorted_errors.each |$res| {
      $name = $res.target.name
      $issue_code = $res.error.issue_code
      $msg = $res.error.msg
      out::message("- name: ${name}")
      out::message("  error: [${issue_code}] ${msg}")
    }
    fail_plan('Unable to connect to the targets above!')
  }
  else {
    out::message('All targets succeeded!')
  }
}
