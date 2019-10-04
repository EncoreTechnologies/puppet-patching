# Checks each node to see if Puppet is installed, if it is then gather Facts
plan patching::check_online (
  TargetSpec $nodes,
) {
  $targets = get_targets($nodes)
  ## This will check all nodes to verify online by checking their Puppet agent version
  $targets_version = run_task('puppet_agent::version', $targets,
                              _catch_errors => true)
  # if we're filtering out offline nodes, then only accept the ok_set from the task above
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
    out::message('All nodes succeeded!')
  }
}
