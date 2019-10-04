# Checks each node to see if Puppet is installed, if it is then gather Facts
plan patching::check_puppet (
  TargetSpec $nodes,
  Boolean $filter_offline_nodes = false,
) {
  $targets = get_targets($nodes)
  ## This will check all nodes to verify online by checking their Puppet agent version
  $targets_version = run_task('puppet_agent::version', $targets,
                              _catch_errors => $filter_offline_nodes)
  # if we're filtering out offline nodes, then only accept the ok_set from the task above
  if $filter_offline_nodes {
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
    run_plan('patching::puppet_facts',
              nodes => $targets_with_puppet)
  }
  if !$targets_no_puppet.empty() {
    # run `facter` if it's available otherwise get basic facts
    run_plan('facts',
              nodes => $targets_no_puppet)
  }

  return({
    'has_puppet' => $targets_with_puppet,
    'no_puppet' => $targets_no_puppet,
    'all' => $targets_with_puppet + $targets_no_puppet,
  })
}
