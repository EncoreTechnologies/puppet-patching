# Checks each node to see if Puppet is installed, if it is then gather Facts
plan patching::check_puppet (
  TargetSpec $nodes,
  Boolean $filter_offline_nodes = false,
) {
  ## This will check all nodes to verify online by checking their Puppet agent version
  $nodes_version = run_task('puppet_agent::version', $nodes,
                            _catch_errors => $filter_offline_nodes)
  # if we're filtering out offline nodes, then only accept the ok_set from the task above
  if $filter_offline_nodes {
    $nodes_filtered = $nodes_version.ok_set
  }
  else {
    $nodes_filtered = $nodes_version
  }
  # nodes without puppet will return a value {'verison' => undef}
  $nodes_with_puppet = $nodes_filtered.filter_set |$res| { $res['version'] != undef }.targets
  $nodes_no_puppet = $nodes_filtered.filter_set |$res| { $res['version'] == undef }.targets

  ## get facts from each node
  if !$nodes_with_puppet.empty() {
    # run `puppet facts` on nodes with Puppet because it returns a more complete
    # set of facts than just running `facter`
    run_plan('patching::puppet_facts', nodes => $nodes_with_puppet)
  }
  if !$nodes_no_puppet.empty() {
    # run `facter` if it's available otherwise get basic facts
    run_plan('facts', nodes => $nodes_no_puppet)
  }

  return({
    'has_puppet' => $nodes_with_puppet,
    'no_puppet' => $nodes_no_puppet,
    'all' => $nodes_with_puppet + $nodes_no_puppet,
  })
}
