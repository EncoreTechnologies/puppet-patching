# @summary Executes a custom post-update script on each node.
#
# Often in patching it is necessary to run custom commands before/after updates are
# applied to a host. This plan allows for that customization to occur.
#
# By default it executes a Shell script on Linux and a PowerShell script on Windows hosts.
# The default script paths are:
#   - Linux: `/opt/patching/bin/post_update.sh`
#   - Windows: `C:\ProgramData\patching\bin\post_update.ps1`
#
# One can customize the script paths by overriding them on the CLI, or when calling the plan
# using the `script_linux` and `script_windows` parameters.
#
# The script paths can also be customzied in the inventory configuration `vars`:
# Example:
#
# ``` yaml
# vars:
#   patching_post_update_script_windows: C:\scripts\patching.ps1
#   patching_post_update_script_linux: /usr/local/bin/mysweetpatchingscript.sh
#
# groups:
#   # these targets will use the pre patching script defined in the vars above
#   - name: regular_nodes
#     targets:
#       - tomcat01.domain.tld
#
#   # these targets will use the customized patching script set for this group
#   - name: sql_nodes
#     vars:
#       patching_post_update_script_linux: /bin/sqlpatching.sh
#     targets:
#       - sql01.domain.tld
# ```
#
# @param [TargetSpec] targets
#   Set of targets to run against.
# @param [String[1]] script_linux
#   Path to the script that will be executed on Linux targets.
# @param [String[1]] script_windows
#   Path to the script that will be executed on Windows targets.
# @param [Boolean] noop
#   Flag to enable noop mode for the underlying plans and tasks.
#
# @return [ResultSet]
#   Returns the ResultSet from the underlying `run_task('patching::post_update')`
#
# @example CLI - Basic usage
#   bolt plan run patching::post_update --targets all_hosts
#
# @example CLI - Custom scripts
#   bolt plan run patching::post_update --targets all_hosts script_linux='/my/sweet/script.sh' script_windows='C:\my\sweet\script.ps1'
#
# @example Plan - Basic usage
#   run_plan('patching::post_update', $all_hosts)
#
# @example Plan - Custom scripts
#   run_plan('patching::post_update', $all_hosts,
#            script_linux   => '/my/sweet/script.sh',
#            script_windows => 'C:\my\sweet\script.ps1')
#
plan patching::post_update (
  TargetSpec $targets,
  String[1] $script_linux   = '/opt/patching/bin/post_update.sh',
  String[1] $script_windows = 'C:\ProgramData\patching\bin\post_update.ps1',
  Boolean   $noop           = false,
) {
  $_targets = run_plan('patching::get_targets', $targets)
  $group_vars = $_targets[0].vars
  $_script_linux = pick($group_vars['patching_post_update_script_linux'], $script_linux)
  $_script_windows = pick($group_vars['patching_post_update_script_windows'], $script_windows)

  return run_plan('patching::pre_post_update', $_targets,
    task           => 'patching::post_update',
    script_linux   => $_script_linux,
    script_windows => $_script_windows,
  noop           => $noop)
}
