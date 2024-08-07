# @summary Querys a targets operating system to determine if a reboot is required and then reboots the targets that require rebooting.
#
# Patching in different environments comes with various unique requirements, one of those
# is rebooting hosts. Sometimes hosts need to always be reboot, othertimes never rebooted.
#
# To provide this flexibility we created this function that wraps the `reboot` plan with
# a `strategy` that is controllable as a parameter. This provides flexibilty in
# rebooting specific targets in certain ways (by group). Along with the power to expand
# our strategy offerings in the future.
#
# @param [TargetSpec] targets
#   Set of targets to run against.
# @param [Enum['only_required', 'never', 'always']] strategy
#   Determines the reboot strategy for the run.
#
#    - 'only_required' only reboots hosts that require it based on info reported from the OS
#    - 'never' never reboots the hosts
#    - 'always' will reboot the host no matter what
#
# @param [String] message
#   Message displayed to the user prior to the system rebooting
#
# @param [Integer] wait
#   Time in seconds that the plan waits before continuing after a reboot. This is necessary in case one
#   of the groups affects the availability of a previous group.
#   Two use cases here:
#    1. A later group is a hypervisor. In this instance the hypervisor will reboot causing the
#       VMs to go offline and we need to wait for those child VMs to come back up before
#       collecting history metrics.
#    2. A later group is a linux router. In this instance maybe the patching of the linux router
#       affects the reachability of previous hosts.
#
# @param [Integer] disconnect_wait How long (in seconds) to wait before checking whether the server has rebooted. Defaults to 10.
#
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
  TargetSpec  $targets,
  Enum['only_required', 'never', 'always'] $strategy = undef,
  String     $message = undef,
  Integer    $wait    = undef,
  Integer    $disconnect_wait = undef,
  Boolean    $noop    = false,
) {
  $_targets = run_plan('patching::get_targets', $targets)
  $group_vars = $_targets[0].vars
  $_strategy = pick($strategy,
    $group_vars['patching_reboot_strategy'],
  'only_required')
  $_message = pick($message,
    $group_vars['patching_reboot_message'],
  'NOTICE: This system is currently being updated.')
  $_wait = pick($wait,
    $group_vars['patching_reboot_wait'],
  300)
  $_disconnect_wait = pick($disconnect_wait,
    $group_vars['patching_disconnect_wait'],
  10)

  ## Check if reboot required.
  $reboot_results = run_task('patching::reboot_required', $_targets)

  # print out pretty message
  out::message("Reboot strategy: ${_strategy}")
  out::message("Host reboot required status: ('+' reboot required; '-' reboot NOT required)")
  $targets_reboot_required = $reboot_results.filter_set|$res| { $res['reboot_required'] }.targets
  $targets_reboot_not_required = $reboot_results.filter_set|$res| { !$res['reboot_required'] }.targets
  $reboot_results.each|$res| {
    $symbol = ($res['reboot_required']) ? { true => '+' , default => '-' }
    out::message(" ${symbol} ${res.target.name}")
  }

  ## Reboot the hosts that require it
  ## skip if we're in noop mode (the reboot plan doesn't support $noop)
  if !$noop {
    case $_strategy {
      'only_required': {
        if !$targets_reboot_required.empty() {
          $targets_reboot_attempted = $targets_reboot_required
          $reboot_resultset = run_plan('reboot', $targets_reboot_required,
            reconnect_timeout => $_wait,
            disconnect_wait   => $_disconnect_wait,
            message           => $_message,
          _catch_errors     => true)
        }
        else {
          $targets_reboot_attempted = []
          $reboot_resultset = ResultSet([])
        }
      }
      'always': {
        $targets_reboot_attempted = $targets
        $reboot_resultset = run_plan('reboot', $targets,
          reconnect_timeout => $_wait,
          disconnect_wait   => $_disconnect_wait,
          message           => $_message,
        _catch_errors     => true)
      }
      'never': {
        $targets_reboot_attempted = []
        $reboot_resultset = ResultSet([])
      }
      default: {
        fail_plan("Invalid strategy: ${_strategy}")
      }
    }
  }
  else {
    out::message('Noop specified, skipping all reboots.')
    $targets_reboot_attempted = []
    $reboot_resultset = ResultSet([])
  }

  # return our results
  return({
      'required'     => $targets_reboot_required,
      'not_required' => $targets_reboot_not_required,
      'attempted'    => $targets_reboot_attempted,
      'resultset'    => $reboot_resultset,
  })
}
