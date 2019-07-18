# Bolt plan to update packages on Linux host
plan patching::linux (
  TargetSpec       $nodes,
  Boolean          $filter_offline_nodes = false,
  String[1]        $log_file       = '/var/log/patching.log',
  #Optional[String] $snapshot_plan = 'patching::vmware_snapshot',
  Optional[String] $snapshot_plan  = undef,
  String           $reboot_message = 'NOTICE: This system is currently being updated.',
) {
  # TODO content promotion

  # TODO pre patching plan/task/etc

  # TODO monitoring disable plan

  ## Reduce offline nodes
  $nodes_check_puppet = run_plan('patching::check_puppet',
                                 nodes => $nodes,
                                 filter_offline_nodes => $filter_offline_nodes)
  $nodes_all = $nodes_check_puppet['all']

  ## Group all of the nodes based on their 'patching_order' var
  $ordered_groups = run_plan('patching::ordered_groups', nodes => $nodes_all)

  # we can now use the $ordered_keys array above to index into our $ordered_hash
  # pretty cool huh?
  $ordered_groups.each |$group_hash| {
    $ordered_nodes = $group_hash['nodes']
    if $ordered_nodes.empty {
      fail_plan("Nodes not assigned the var: 'patching_order'")
    }

    # do normal patching
    ## Check for updates on hosts
    $available_results = run_plan('patching::available_updates',
                                  nodes  => $ordered_nodes,
                                  format => "pretty")
    $update_targets = $available_results['has_updates']
    if $update_targets.empty {
      next()
    }

    ## Create VM snapshots
    if $snapshot_plan {
      run_plan($snapshot_plan,
               nodes  => $update_targets,
               action => 'create')
    }

    ## Run pre-patching script.
    # TODO custom pre patch task/script/plan/etc
    run_plan('patching::pre_patch', $update_targets)

    ############################################################
    # start here
    return()

    ## Run package update.
    $update_result = run_task('patching::update', $update_targets,
      log_file      => $log_file,
      _catch_errors => true,
    )

    ## Collect list of successful updates
    ## Collect list of failed updates
    $update_success_targets = $up_result.ok_set.targets
    $update_failed_targets = $up_result.error_set.targets

    ## Display hosts with failed updates.
    if !$update_failed_targets.empty {
      alert('The following hosts failed during update:')
      $update_failed_targets.each |$t| { alert(" ! ${$item.name}") }
      $status = 'WARNING: Errors detected during update.'
    } else {
      $status = 'OK: No errors detected.'
    }

    ## Run post-patching script.
    if !$update_success_targets.empty {
      run_task('patching::patch_helper', $update_success_targets,
               action => 'post')

      ## Check if reboot required and reboot if true.
      $reboot_required_results = run_plan('patching::reboot_required',
                                          nodes=> $update_success_targets)
      $reboot_targets = $reboot_required_results['reboot_required']

      ## Reboot the host that require it
      run_plan('reboot',
               nodes             => $reboot_targets,
               reconnect_timeout => 300,
               message           => $reboot_message,
               _catch_errors     => true,
              )
    }

    ## Remove VM snapshots
    if $snapshot_plan {
      run_plan($snapshot_plan,
               nodes  => $success,
               action => 'delete')
    }

  }

  ## Collect summary report
  $report = run_plan('patching::collect_update_history',
    nodes       => $online,
    environment => get_targets($online)[0].vars['patch_env'],
    mail_to     => get_targets($online)[0].vars['mail_to'],
    #failed      => $failed,
  )

  ## Display final status
  return()

}
