# @summary
plan patching::patch_helper (
  TargetSpec $nodes,
  String[1] $task,
  Optional[String[1]] $script_linux   = undef,
  Optional[String[1]] $script_windows = undef,
  Boolean             $noop           = false,
) {
  out::message("patch_helper - noop = ${noop}")
  $targets = run_plan('patching::get_targets',
                      nodes => $nodes)

  # split into linux vs Windows
  # TODO: we might want to split into "RedHat" vs "Windows" vs "Debian"
  $targets_linux = $targets.filter |$t| { facts($t)['os']['family'] != 'windows' }
  $targets_windows = $targets.filter |$t| { facts($t)['os']['family'] == 'windows' }

  # run pre-patch scripts
  if !$targets_linux.empty() {
    $results_linux = run_task($task, $targets_linux,
                              script => $script_linux,
                              _noop  => $noop).results
  }
  else {
    $results_linux = []
  }
  if !$targets_windows.empty() {
    $results_windows = run_task($task, $targets_windows,
                                script => $script_windows,
                                _noop  => $noop).results
  }
  else {
    $results_windows = []
  }

  # TODO pretty print any scripts that were run

  return ResultSet($results_linux + $results_windows)
}
