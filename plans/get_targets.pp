plan patching::get_targets (
  TargetSpec $nodes,
) {
  $targets = get_targets($nodes)
  $target_first_facts = facts($targets[0])
  if !$target_first_facts['os'] or !$target_first_facts['os']['family'] {
    run_plan('patching::check_puppet', nodes => $targets)
  }
  return $targets
}
