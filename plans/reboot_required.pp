# Bolt plan to check if targets need reboot and have patch_reboot flag set.
plan patching::reboot_required (
  TargetSpec $nodes,
) {
  $targets = run_plan('patching::get_targets', nodes => $nodes)

  ## Check if reboot required.
  $reboot_results = run_task('patching::reboot_required', $targets)

  # print out pretty message
  out::message("Host reboot required status: ('+' reboot required; '-' reboot NOT required)")
  $reboot_required = $reboot_results.filter_set|$res| { !$res['reboot_required'] }.targets
  $reboot_not_required = $reboot_results.filter_set|$res| { $res['reboot_required'] }.targets
  $reboot_results.each|$res| {
    $symbol = ($res['reboot_required']) ? { true => '+' , default => '-' }
    out::message(" ${symbol} ${res.target.name}")
  }

  # return our results
  return({
    'required'     => $reboot_required,
    'not_required' => $reboot_not_required,
  })
}
