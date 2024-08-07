# @summary Common entry point for executing the pre/post update custom scripts
#
# @see patching::pre_update
# @see patching::post_update
#
# @param [TargetSpec] targets
#   Set of targets to run against.
#
# @param [String[1]] task
#   Name of the pre/post update task to execute.
#
# @param [Optional[String[1]]] script_linux
#   Path to the script that will be executed on Linux targets.
#
# @param [Optional[String[1]]] script_windows
#   Path to the script that will be executed on Windows targets.
#
# @param [Boolean] noop
#   Flag to enable noop mode for the underlying plans and tasks.
#
# @return [ResultSet] Returns the ResultSet from the execution of `task`.
plan patching::pre_post_update (
  TargetSpec $targets,
  String[1] $task,
  Optional[String[1]] $script_linux   = undef,
  Optional[String[1]] $script_windows = undef,
  Boolean             $noop           = false,
) {
  out::message("pre_post_update - noop = ${noop}")
  $_targets = run_plan('patching::get_targets', $targets)

  # split into linux vs Windows
  $targets_linux = $_targets.filter |$t| { facts($t)['os']['family'] != 'windows' }
  $targets_windows = $_targets.filter |$t| { facts($t)['os']['family'] == 'windows' }

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
