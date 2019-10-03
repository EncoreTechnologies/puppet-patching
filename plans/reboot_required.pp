# Bolt plan to check if targets need reboot and have patch_reboot flag set.
plan patching::reboot_required (
  TargetSpec $nodes,
  Boolean $reboot = false,
  String $message = 'NOTICE: This system is currently being updated.',
  Boolean $noop   = false,
) {
  $targets = run_plan('patching::get_targets', nodes => $nodes)
  $group_vars = $targets[0].vars
  $_reboot = pick($group_vars['patching_reboot'], $reboot)
  $_reboot_message = pick($group_vars['patching_reboot_message'], $reboot_message)

  ## Check if reboot required.
  $reboot_results = run_task('patching::reboot_required', $targets)

  # print out pretty message
  out::message("Host reboot required status: ('+' reboot required; '-' reboot NOT required)")
  $nodes_reboot_required = $reboot_results.filter_set|$res| { $res['reboot_required'] }.targets
  $nodes_reboot_not_required = $reboot_results.filter_set|$res| { !$res['reboot_required'] }.targets
  $reboot_results.each|$res| {
    $symbol = ($res['reboot_required']) ? { true => '+' , default => '-' }
    out::message(" ${symbol} ${res.target.name}")
  }

  ## Reboot the hosts that require it
  ## skip if we're in noop mode (the reboot plan doesn't support $noop)
  if $_reboot and !$nodes_reboot_required.empty() and !$noop {
    run_plan('reboot',
             nodes             => $nodes_reboot_required,
             reconnect_timeout => 300,
             message           => $_message,
             _catch_errors     => true)
  }

  # return our results
  return({
    'required'     => $nodes_reboot_required,
    'not_required' => $nodes_reboot_not_required,
  })
}
