# @summary Querys a nodes operating system to determine if a reboot is required and then reboots the nodes that require rebooting.
#
# Patching in different environments comes with various unique requirements, one of those
# is rebooting hosts. Sometimes hosts need to always be reboot, othertimes never rebooted.
#
# To provide this flexibility we created this function that wraps the `reboot` plan with
# a `strategy` that is controllable as a parameter. This provides flexibilty in
# rebooting specific nodes in certain ways (by group). Along with the power to expand
# our strategy offerings in the future.
#
# @param [TargetSpec] nodes
#   Set of targets to run against.
# @param [Enum['only_required', 'never', 'always']] strategy
#   Determines the reboot strategy for the run.
#
#    - 'only_required' only reboots hosts that require it based on info reported from the OS
#    - 'never' never reboots the hosts
#    - 'always' will reboot the host no matter what
# @param [String] message
#   Message displayed to the user prior to the system rebooting
# @param [Boolean] noop
#   Flag to determine if this should be a noop operation or not.
#   If this is a noop, no hosts will ever be rebooted, however the "reboot required" information
#   will still be queried and returned.
#
# @return [Struct[{'required' => Array[TargetSpec], 'not_required' => Array[TargetSpec], 'attempted' => Array[TargetSpec], 'resultset' => ResultSet}]]
#
#    - `required` : array of targets whose host OS reported a reboot is required
#    - `not_required` : array of targets whose host OS did not report a reboot being required
#    - `attempted` : array of targets where a reboot was attempted (potentially empty array)
#    - `resultset` : results from the `reboot` plan for the attempted hosts (potentially an empty `ResultSet`)
#
plan patching::reboot_required (
  TargetSpec $nodes,
  Enum['only_required', 'never', 'always'] $strategy = 'only_required',
  String $message = 'NOTICE: This system is currently being updated.',
  Boolean $noop   = false,
) {
  $targets = run_plan('patching::get_targets', nodes => $nodes)
  $group_vars = $targets[0].vars
  $_strategy = pick($group_vars['patching_reboot_strategy'], $strategy)
  $_message = pick($group_vars['patching_reboot_message'], $message)

  ## Check if reboot required.
  $reboot_results = run_task('patching::reboot_required', $targets)

  # print out pretty message
  out::message("Reboot strategy: ${_strategy}")
  out::message("Host reboot required status: ('+' reboot required; '-' reboot NOT required)")
  $nodes_reboot_required = $reboot_results.filter_set|$res| { $res['reboot_required'] }.targets
  $nodes_reboot_not_required = $reboot_results.filter_set|$res| { !$res['reboot_required'] }.targets
  $reboot_results.each|$res| {
    $symbol = ($res['reboot_required']) ? { true => '+' , default => '-' }
    out::message(" ${symbol} ${res.target.name}")
  }

  ## Reboot the hosts that require it
  ## skip if we're in noop mode (the reboot plan doesn't support $noop)
  if !$noop {
    case $_strategy {
      'only_required': {
        if !$nodes_reboot_required.empty() {
          $nodes_reboot_attempted = $nodes_reboot_required
          $reboot_resultset = run_plan('reboot',
                                        nodes             => $nodes_reboot_required,
                                        reconnect_timeout => 300,
                                        message           => $_message,
                                        _catch_errors     => true)
        }
        else {
          $nodes_reboot_attempted = []
          $reboot_resultset = ResultSet([])
        }
      }
      'always': {
        $nodes_reboot_attempted = $targets
        $reboot_resultset = run_plan('reboot',
                                      nodes             => $nodes,
                                      reconnect_timeout => 300,
                                      message           => $_message,
                                      _catch_errors     => true)
      }
      'never': {
        $nodes_reboot_attempted = []
        $reboot_resultset = ResultSet([])
      }
      default: {
        fail_plan("Invalid strategy: ${_strategy}")
      }
    }
  }
  else {
    out::message('Noop specified, skipping all reboots.')
  }

  # return our results
  return({
    'required'     => $nodes_reboot_required,
    'not_required' => $nodes_reboot_not_required,
    'attempted'    => $nodes_reboot_attempted,
    'resultset'    => $reboot_resultset,
  })
}
