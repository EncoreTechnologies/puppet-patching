# Bolt plan to update hosts (linux and windows together)
plan patching (
  TargetSpec       $nodes,
  Boolean          $filter_offline_nodes = pick(patching::vars()['patching_filter_offline_nodes'], false),
  String[1]        $log_file        = pick(patching::vars()['patching_log_file'], '/var/log/patching.log'),
  String           $pre_patch_plan  = pick(patching::vars()['patching_pre_patch_plan'], 'patching::pre_patch'),
  String           $post_patch_plan = pick(patching::vars()['patching_post_patch_plan'], 'patching::post_patch'),
  Boolean          $reboot          = pick(patching::vars()['patching_reboot'], true),
  String           $reboot_message  = pick(patching::vars()['patching_reboot_message'], 'NOTICE: This system is currently being updated.'),
  Optional[String] $snapshot_plan   = pick(patching::vars()['patching_snapshot_plan'], 'patching::snapshot_vmware'),
  Boolean          $snapshot_create = pick(patching::vars()['patching_snapshot_create'], true),
  Boolean          $snapshot_delete = pick(patching::vars()['patching_snapshot_delete'], true),
  Boolean          $noop            = false,
) {

  # TODO content promotion

  # TODO pre patching plan/task/etc

  # TODO monitoring disable plan

  ## Filter offline nodes
  $check_puppet_result = run_plan('patching::check_puppet',
                                  nodes                => $nodes,
                                  filter_offline_nodes => $filter_offline_nodes)
  # use all targets, both with and without puppet
  $targets = $check_puppet_result['all']

  ## Group all of the nodes based on their 'patching_order' var
  $ordered_groups = run_plan('patching::ordered_groups', nodes => $targets)

  # we can now use the $ordered_keys array above to index into our $ordered_hash
  # pretty cool huh?
  $ordered_groups.each |$group_hash| {
    $ordered_nodes = $group_hash['nodes']
    if $ordered_nodes.empty {
      fail_plan("Nodes not assigned the var: 'patching_order'")
    }

    # override configurable parameters on a per-group basis
    # if there is no customization for this group, it defaults to the global setting
    # set at the plan level above
    $group_vars = $ordered_nodes[0].vars
    $reboot_group = pick($group_vars['patching_reboot'], $reboot)
    $reboot_message_group = pick($group_vars['patching_reboot_message'], $reboot_message)
    $pre_patch_plan_group = pick($group_vars['patching_pre_patch_plan'], $pre_patch_plan)
    $post_patch_plan_group = pick($group_vars['patching_post_patch_plan'], $post_patch_plan)
    $snapshot_plan_group = pick($group_vars['patching_snapshot_plan'], $snapshot_plan)
    $snapshot_create_group = pick($group_vars['patching_snapshot_create'], $snapshot_create)
    $snapshot_delete_group = pick($group_vars['patching_snapshot_delete'], $snapshot_delete)

    # do normal patching

    ## Update patching cache (yum update, apt-get update, etc)
    run_task('patching::cache_update', $ordered_nodes,
             _noop => $noop)

    ## Check for updates on hosts
    $available_results = run_plan('patching::available_updates',
                                  nodes  => $ordered_nodes,
                                  format => "pretty",
                                  noop   => $noop)
    $update_targets = $available_results['has_updates']
    if $update_targets.empty {
      next()
    }

    ## Create VM snapshots
    if $snapshot_create_group and $snapshot_plan_group and $snapshot_plan_group != ''{
      run_plan($snapshot_plan_group,
               nodes  => $update_targets,
               action => 'create',
               noop   => $noop)
    }

    ## Run pre-patching script.
    run_plan($pre_patch_plan_group,
             nodes => $update_targets,
             noop  => $noop)

    ## Run package update.
    $update_result = run_task('patching::update', $update_targets,
                              log_file      => $log_file,
                              _catch_errors => true,
                              _noop         => $noop)

    ## Collect list of successful updates
    $update_ok_targets = $update_result.ok_set.targets
    ## Collect list of failed updates
    $update_errors = $update_result.error_set

    ## Check if any hosts with failed updates.
    if $update_errors.empty {
      $status = 'OK: No errors detected.'
    } else {
      # TODO print out the full error message for each of these
      alert('The following hosts failed during update:')
      alert($update_errors)
      $status = 'WARNING: Errors detected during update.'
    }

    if !$update_ok_targets.empty {
      ## Run post-patching script.
      run_plan($post_patch_plan_group,
               nodes => $update_ok_targets,
               noop  => $noop)

      ## Check if reboot required and reboot if true.
      run_plan('patching::reboot_required',
               nodes   => $update_ok_targets,
               reboot  => $reboot_group,
               message => $reboot_message_group,
               noop    => $noop)

      ## Remove VM snapshots
      if $snapshot_delete_group and $snapshot_plan_group and $snapshot_plan_group != '' {
        run_plan($snapshot_plan_group,
                 nodes  => $update_ok_targets,
                 action => 'delete',
                 noop   => $noop)
      }
    }
    # else {
    #   # TODO should we break here?
    # }
  }

  ## Collect summary report
  run_plan('patching::update_history',
           nodes  => $targets,
           format => 'pretty')

  ## Display final status
  return()
}
