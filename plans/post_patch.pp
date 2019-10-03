plan patching::post_patch (
  TargetSpec $nodes,
  String[1] $script_linux   = '/opt/patching/bin/post_patch.sh',
  String[1] $script_windows = 'C:\ProgramData\PuppetLabs\patching\post_patch.ps1',
  Boolean   $noop           = false,
) {
  $targets = run_plan('patching::get_targets', nodes => $nodes)
  $group_vars = $targets[0].vars
  $_script_linux = pick($group_vars['patching_post_patch_script_linux'], $script_linux)
  $_script_windows = pick($group_var['patching_post_patch_script_windows']s, $script_windows)

  return run_plan('patching::patch_helper',
                  nodes          => $targets,
                  task           => 'patching::post_patch',
                  script_linux   => $_script_linux,
                  script_windows => $_script_windows,
                  noop           => $noop)
}
