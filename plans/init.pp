# @summary Our generic and semi-opinionated workflow.
#
# It serves as a showcase of how all of the building blocks in this module
# can be tied together to create a full blown patching workflow.
# This is a great initial workflow to patch servers.
# We fully expect others to take this workflow as a build-block and customize
# it to meet their needs.
#
# @param [TargetSpec] nodes
#   Set of targets to run against.
#
# @param [Boolean] filter_offline_nodes
#   Flag to determine if offline nodes should be filtered out of the list of targets
#   returned by this plan. If true, when running the <code>puppet_agent::version</code>
#   check, any nodes that return an error will be filtered out and ignored.
#   Those targets will not be returned in any of the data structures in the result of
#   this plan. If false, then any nodes that are offline will cause this plan to error
#   immediately when performing the online check. This will result in a halt of the
#   patching process.
#
# @param [Optional[Boolean]] monitoring_enabled
#   Flag to enable/disable the execute of the monitoring_plan.
#   This is useful if you don't want to call out to a monitoring system during provisioning.
#   To configure this globally, use the `patching_monitoring_enabled` var.
#
# @param [Optional[String]] monitoring_plan
#   Name of the plan to use for disabling/enabling monitoring steps of the workflow.
#   To configure this globally, use the `patching_monitoring_plan` var.
#
# @param [Optional[String]] pre_update_plan
#   Name of the plan to use for executing the pre-update step of the workflow.
#
# @param [Optional[String]] post_update_plan
#   Name of the plan to use for executing the post-update step of the workflow.
#
# @param [Optional[Enum['only_required', 'never', 'always']]] reboot_strategy
#   Determines the reboot strategy for the run.
#
#    - 'only_required' only reboots hosts that require it based on info reported from the OS
#    - 'never' never reboots the hosts
#    - 'always' will reboot the host no matter what
#
# @param [Optional[String]] reboot_message
#   Message displayed to the user prior to the system rebooting
#
# @param [Optional[String]] snapshot_plan
#   Name of the plan to use for executing snaphot creation and deletion steps of the workflow
#   You can also pass `'disabled'` or `undef'` as an easy way to disable both creation and deletion.
#
# @param [Optional[Boolean]] snapshot_create
#   Flag to enable/disable creating snapshots before patching groups.
#   A common usecase to disabling snapshot creation is that, say you run patching
#   with `snapshot_create` enabled and something goes wrong during patching and
#   the run fails. The sanpshot still exists and you want to retry patching
#   but don't want to create ANOTHER snapshot on top of the one we already have.
#   In this case we would pass in `snapshot_create=false` when running the second time.
#
# @param [Optional[Boolean]] snapshot_delete
#   Flag to enable/disable deleting snapshots after patching groups.
#   A common usecase to disable snapshot deletion is that, say you want to patch your
#   hosts and wait a few hours for application teams to test after you're done patching.
#   In this case you can run with `snapshot_delete=false` and then a few hours later
#   you can run the `patching::snapshot_vmware action=delete` sometime in the future.
#
# @param [Boolean] noop
#   Flag to enable noop mode for the underlying plans and tasks.
#
# @example CLI - Basic usage
#   bolt plan run patching --nodes linux_patching,windows_patching
#
# @example CLI - Disable snapshot creation, because an old patching run failed and we have an old snapshot to rely on
#   bolt plan run patching --nodes linux_patching,windows_patching snapshot_create=false
#
# @example CLI - Disable snapshot deletion, because we want to wait for app teams to test.
#   bolt plan run patching --nodes linux_patching,windows_patching snapshot_delete=true
#
#   # sometime in the future, delete the snapshots
#   bolt plan run patching::snapshot_vmare --nodes linux_patching,windows_patching action='delete'
#
# @example CLI - Customize the pre/post update plans to use your own module's version
#   bolt plan run patching --nodes linux_patching pre_update_plan='mymodule::pre_update' post_update_plan='mymodule::post_update'
#
plan patching (
  TargetSpec       $nodes,
  Boolean           $filter_offline_nodes = false,
  Optional[Boolean] $monitoring_enabled   = undef,
  Optional[String]  $monitoring_plan      = undef,
  Optional[String]  $pre_update_plan      = undef,
  Optional[String]  $post_update_plan     = undef,
  Optional[Enum['only_required', 'never', 'always']] $reboot_strategy = undef,
  Optional[String]  $reboot_message       = undef,
  Optional[String]  $snapshot_plan        = undef,
  Optional[Boolean] $snapshot_create      = undef,
  Optional[Boolean] $snapshot_delete      = undef,
  Boolean           $noop                 = false,
) {
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
    # Prescedence: CLI > Config > Default
    $monitoring_plan_group = pick($monitoring_plan,
                                  $group_vars['patching_monitoring_plan'],
                                  'patching::monitoring_solarwinds')
    $monitoring_enabled_group = pick($monitoring_enabled,
                                      $group_vars['patching_monitoring_enabled'],
                                      true)
    $reboot_strategy_group = pick($reboot_strategy,
                                  $group_vars['patching_reboot_strategy'],
                                  'only_required')
    $reboot_message_group = pick($reboot_message,
                                  $group_vars['patching_reboot_message'],
                                  'NOTICE: This system is currently being updated.')
    $pre_update_plan_group = pick($pre_update_plan,
                                  $group_vars['patching_pre_update_plan'],
                                  'patching::pre_update')
    $post_update_plan_group = pick($post_update_plan,
                                    $group_vars['patching_post_update_plan'],
                                    'patching::post_update')
    $snapshot_plan_group = pick($snapshot_plan,
                                $group_vars['patching_snapshot_plan'],
                                'patching::snapshot_vmware')
    $snapshot_create_group = pick($snapshot_create,
                                  $group_vars['patching_snapshot_create'],
                                  true)
    $snapshot_delete_group = pick($snapshot_delete,
                                  $group_vars['patching_snapshot_delete'],
                                  true)

    # do normal patching

    ## Update patching cache (yum update, apt-get update, etc)
    run_task('patching::cache_update', $ordered_nodes,
              _noop => $noop)

    ## Check for updates on hosts
    $available_results = run_plan('patching::available_updates',
                                  nodes  => $ordered_nodes,
                                  format => 'pretty',
                                  noop   => $noop)
    $update_targets = $available_results['has_updates']
    if $update_targets.empty {
      next()
    }

    ## Disable monitoring
    if $monitoring_enabled_group and $monitoring_plan_group and $monitoring_plan_group != 'disabled' {
      run_plan($monitoring_plan_group,
                nodes  => $update_targets,
                action => 'disable',
                noop   => $noop)
    }

    ## Create VM snapshots
    if $snapshot_create_group and $snapshot_plan_group and $snapshot_plan_group != 'disabled'{
      run_plan($snapshot_plan_group,
                nodes  => $update_targets,
                action => 'create',
                noop   => $noop)
    }

    ## Run pre-patching script.
    run_plan($pre_update_plan_group,
              nodes => $update_targets,
              noop  => $noop)

    ## Run package update.
    $update_result = run_task('patching::update', $update_targets,
                              _catch_errors  => true,
                              _noop          => $noop)

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
      run_plan($post_update_plan_group,
                nodes => $update_ok_targets,
                noop  => $noop)

      ## Check if reboot required and reboot if true.
      run_plan('patching::reboot_required',
                nodes    => $update_ok_targets,
                strategy => $reboot_strategy_group,
                message  => $reboot_message_group,
                noop     => $noop)

      ## Remove VM snapshots
      if $snapshot_delete_group and $snapshot_plan_group and $snapshot_plan_group != 'disabled' {
        run_plan($snapshot_plan_group,
                  nodes  => $update_ok_targets,
                  action => 'delete',
                  noop   => $noop)
      }
    }
    # else {
    #   # TODO should we break here?
    # }

    ## enable monitoring
    if $monitoring_enabled_group and $monitoring_plan_group and $monitoring_plan_group != 'disabled'  {
      run_plan($monitoring_plan_group,
                nodes  => $update_targets,
                action => 'enable',
                noop   => $noop)
    }
  }

  ## Re-establish all targets availability after reboot
  # This is necessary in case one of the groups affects the availability of a previous group.
  # Two use cases here:
  #  1. A later group is a hypervisor. In this instance the hypervisor will reboot causing the 
  #     VMs to go offline and we need to wait for those child VMs to come back up before
  #     collecting history metrics.
  #  2. A later group is a linux router. In this instance maybe the patching of the linux router
  #     affects the reachability of previous hosts.
  wait_until_available($targets, wait_time => 300)

  ## Collect summary report
  run_plan('patching::update_history',
            nodes  => $targets,
            format => 'pretty')

  ## Display final status
  return()
}
