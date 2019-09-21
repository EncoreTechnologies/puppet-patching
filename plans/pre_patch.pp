plan patching::pre_patch (
  TargetSpec $nodes,
  Optional[String[1]] $script_linux   = get_targets($nodes)[0].vars['patching_linux_pre_patch_script'],
  Optional[String[1]] $script_windows = get_targets($nodes)[0].vars['patching_windows_pre_patch_script'],
  Boolean             $noop          = false,
) {
  out::message("pre_patch - noop = ${noop}")
  return run_plan('patching::patch_helper',
                  nodes          => $nodes,
                  task           => 'patching::pre_patch',
                  script_linux   => $script_linux,
                  script_windows => $script_windows,
                  noop           => $noop)
}
