# Bolt plan to check if targets need reboot
# Targets will be rebooted based on the $strategy
#  - 'only_required' only reboots hosts that require it based on info reported from the OS
#  - 'never' never reboots the hosts
#  - 'always' will reboot the host no matter what
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
        $nodes_reboot_attempted = $nodes
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
    }
  }
  else {
    out::message("Noop specified, skipping all reboots.")
  }

  # return our results
  return({
    'required'     => $nodes_reboot_required,
    'not_required' => $nodes_reboot_not_required,
    'attempted'    => $nodes_reboot_attempted,
    'resultset'    => $reboot_resultset,
  })
}
