# Bolt plan to update hosts (linux and windows together)
plan patching (
  TargetSpec       $nodes,
  Boolean          $filter_offline_nodes = false,
  String[1]        $log_file       = '/var/log/patching.log',
  Optional[String] $snapshot_plan  = 'patching::snapshot_vmware',
  Boolean          $snapshot_create = true,
  Boolean          $snapshot_delete = true,
  Boolean          $reboot          = true,
  String           $reboot_message  = 'NOTICE: This system is currently being updated.',
) {
  # TODO content promotion

  # TODO pre patching plan/task/etc

  # TODO monitoring disable plan

  ## Filter offline nodes
  $check_puppet_result = run_plan('patching::check_puppet',
                                  nodes => $nodes,
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

    # do normal patching

    ## Update patching cache (yum update, apt-get update, etc)
    run_task('patching::cache_update', $ordered_nodes)

    ## Check for updates on hosts
    $available_results = run_plan('patching::available_updates',
                                  nodes  => $ordered_nodes,
                                  format => "pretty")
    $update_targets = $available_results['has_updates']
    if $update_targets.empty {
      next()
    }

    ## Create VM snapshots
    if $snapshot_create and  $snapshot_plan and $snapshot_plan != ''{
      run_plan($snapshot_plan,
               nodes  => $update_targets,
               action => 'create')
    }

    ## Run pre-patching script.
    # TODO custom pre patch task/script/plan/etc
    run_plan('patching::pre_patch', nodes => $update_targets)

    ## Run package update.
    $update_result = run_task('patching::update', $update_targets,
                              log_file      => $log_file,
                              _catch_errors => true)

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
      # TODO custom pre patch task/script/plan/etc
      run_plan('patching::post_patch',
               nodes => $update_ok_targets)

      ## Check if reboot required and reboot if true.
      run_plan('patching::reboot_required',
               nodes => $update_ok_targets,
               reboot => $reboot,
               message => $reboot_message)
    }

    ## Remove VM snapshots
    if $snapshot_delete and $snapshot_plan and $snapshot_plan != '' {
      run_plan($snapshot_plan,
               nodes  => $update_ok_targets,
               action => 'delete')
    }

  }

  ## Collect summary report
  run_plan('patching::update_history',
           nodes => $targets,
           format => 'pretty')

  ## Display final status
  return()

}
