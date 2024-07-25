# @summary Our generic and semi-opinionated workflow.
#
# It serves as a showcase of how all of the building blocks in this module
# can be tied together to create a full blown patching workflow.
# This is a great initial workflow to patch servers.
# We fully expect others to take this workflow as a build-block and customize
# it to meet their needs.
#
# @param [TargetSpec] targets
#   Set of targets to run against.
#
# @param [Boolean] filter_offline_targets
#   Flag to determine if offline targets should be filtered out of the list of targets
#   returned by this plan. If true, when running the <code>puppet_agent::version</code>
#   check, any targets that return an error will be filtered out and ignored.
#   Those targets will not be returned in any of the data structures in the result of
#   this plan. If false, then any targets that are offline will cause this plan to error
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
# @param [Optional[String]] update_provider
#   What update provider to use. For Linux (RHEL, Debian, SUSE, etc.) this parameter
#   is not used. For Windows the available values are: 'windows', 'chocolatey', 'all'
#   (both 'windows' and 'chocolatey'). The default value for Windows is 'all'. If 'all'
#   is passed and Chocolatey isn't installed then Chocolatey will simply be skipped.
#   If 'chocolatey' is passed and Chocolatey isn't installed, then this will error.
#
# @param [Optional[String]] pre_update_plan
#   Name of the plan to use for executing the pre-update step of the workflow.
#
# @param [Optional[String]] post_update_plan
#   Name of the plan to use for executing the post-update step of the workflow.
#
# @param [Optional[String]] reboot_message
#   Message displayed to the user prior to the system rebooting
#
# @param [Optional[Enum['only_required', 'never', 'always']]] reboot_strategy
#   Determines the reboot strategy for the run.
#
#    - 'only_required' only reboots hosts that require it based on info reported from the OS
#    - 'never' never reboots the hosts
#    - 'always' will reboot the host no matter what
#
# @param [Optional[Integer]] reboot_wait
#   Time in seconds that the plan waits before continuing after a reboot. This is necessary in case one
#   of the groups affects the availability of a previous group.
#   Two use cases here:
#    1. A later group is a hypervisor. In this instance the hypervisor will reboot causing the
#       VMs to go offline and we need to wait for those child VMs to come back up before
#       collecting history metrics.
#    2. A later group is a linux router. In this instance maybe the patching of the linux router
#       affects the reachability of previous hosts.
#
# @param [Integer] disconnect_wait How long (in seconds) to wait before checking whether the server has rebooted. Defaults to 10.
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
# @param [Optional[Enum['none', 'pretty', 'csv']]] report_format
#   The method of formatting the report data.
#
# @param [Optional[String]] report_file
#   Path of the filename where the report should be written. Default = 'patching_report.csv'.
#   If you would like to disable writing the report file, specify a value of 'disabled'.
#   NOTE: If you're running PE, then you'll need to disable writing reports because it will
#   fail when running from the console.
#
# @param [Boolean] noop
#   Flag to enable noop mode for the underlying plans and tasks.
#
# @example CLI - Basic usage
#   bolt plan run patching --targets linux_patching,windows_patching
#
# @example CLI - Disable snapshot creation, because an old patching run failed and we have an old snapshot to rely on
#   bolt plan run patching --targets linux_patching,windows_patching snapshot_create=false
#
# @example CLI - Disable snapshot deletion, because we want to wait for app teams to test.
#   bolt plan run patching --targets linux_patching,windows_patching snapshot_delete=true
#
#   # sometime in the future, delete the snapshots
#   bolt plan run patching::snapshot_vmare --targets linux_patching,windows_patching action='delete'
#
# @example CLI - Customize the pre/post update plans to use your own module's version
#   bolt plan run patching --targets linux_patching pre_update_plan='mymodule::pre_update' post_update_plan='mymodule::post_update'
#
# @example CLI - Wait 10 minutes for systems to become available as some systems take longer to reboot.
#   bolt plan run patching --targets linux_patching,windows_patching --reboot_wait 600
#
plan patching (
  TargetSpec        $targets,
  Boolean           $filter_offline_targets = false,
  Optional[Boolean] $monitoring_enabled   = undef,
  Optional[String]  $monitoring_plan      = undef,
  Optional[String]  $pre_update_plan      = undef,
  Optional[String]  $update_provider      = undef,
  Optional[String]  $post_update_plan     = undef,
  Optional[Enum['only_required', 'never', 'always']] $reboot_strategy = undef,
  Optional[String]  $reboot_message       = undef,
  Optional[Integer] $reboot_wait          = undef,
  Optional[Integer] $disconnect_wait      = undef,
  Optional[String]  $snapshot_plan        = undef,
  Optional[Boolean] $snapshot_create      = undef,
  Optional[Boolean] $snapshot_delete      = undef,
  Optional[Enum['none', 'pretty', 'csv']] $report_format = undef,
  Optional[String]  $report_file          = undef,
  Boolean           $noop                 = false,
) {
  ## Filter offline targets
  $check_puppet_result = run_plan('patching::check_puppet', $targets,
  filter_offline_targets => $filter_offline_targets)
  # use all targets, both with and without puppet
  $_targets = $check_puppet_result['all']

  # read variables for plan-level settings
  $plan_vars = $_targets[0].vars
  $reboot_wait_plan = pick($reboot_wait,
    $plan_vars['patching_reboot_wait'],
  300)
  $report_format_plan = pick($report_format,
    $plan_vars['patching_report_format'],
  'pretty')
  $report_file_plan = pick($report_file,
    $plan_vars['patching_report_file'],
  'patching_report.csv')

  ## Group all of the targets based on their 'patching_order' var
  $ordered_groups = run_plan('patching::ordered_groups', $_targets)

  ## Loop through each group and patch
  ## If a group fails, we will collect the failed targets and fail the plan at the end
  $update_failed_targets = $ordered_groups.reduce({}) |$failed_targets, $group_hash| {
    $ordered_targets = $group_hash['targets']
    if $ordered_targets.empty {
      fail_plan("Targets not assigned the var: 'patching_order'")
    }

    # override configurable parameters on a per-group basis
    # if there is no customization for this group, it defaults to the global setting
    # set at the plan level above
    $group_vars = $ordered_targets[0].vars
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
    $update_provider_group = pick_default($update_provider,
      $group_vars['patching_update_provider'],
    undef)
    $reboot_wait_group = pick($reboot_wait,
      $group_vars['patching_reboot_wait'],
    300)
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
    $disconnect_wait_group = pick($disconnect_wait,
      $group_vars['patching_disconnect_wait'],
    10)

    $tasks_plans = patching::build_workflow(
      $update_provider_group,
      $monitoring_enabled_group,
      $monitoring_plan_group,
      $snapshot_create_group,
      $snapshot_delete_group,
      $snapshot_plan_group,
      $pre_update_plan_group,
      $post_update_plan_group,
      $reboot_strategy_group,
      $reboot_message_group,
      $reboot_wait_group,
      $disconnect_wait_group,
      $noop
    )

    # Hash of tasks/plans to run
    # $tasks_plans = [
    #   ## Update patching cache (yum update, apt-get update, etc)
    #   { 'name' => 'patching::cache_update', 'type' => 'task', 'params' => { '_noop' => $noop, '_catch_errors' => true } },
    #   ## Check for available updates
    #   { 'name' => 'patching::available_updates', 'type' => 'plan', 'params' => { 'provider' => $update_provider_group, 'format' => 'pretty', 'noop' => $noop } },
    #   ## Disable monitoring
    #   { 'name' => $monitoring_plan_group, 'type' => 'plan', 'params' => { 'action' => 'disable', 'noop' => $noop } },
    #   ## Create VM snapshots
    #   { 'name' => $snapshot_plan_group, 'type' => 'plan', 'params' => { 'action' => 'create', 'noop' => $noop } },
    #   ## Run pre-patching script
    #   { 'name' => $pre_update_plan_group, 'type' => 'plan', 'params' => { 'noop' => $noop } },
    #   ## Run package updates
    #   { 'name' => 'patching::update', 'type' => 'task', 'params' => { 'provider' => $update_provider_group, '_catch_errors' => true, 'noop' => $noop } },
    #   ## Run post-patching script
    #   { 'name' => $post_update_plan_group, 'type' => 'plan', 'params' => { 'noop' => $noop } },
    #   ## Check if reboot required
    #   { 'name' => 'patching::reboot_required', 'type' => 'plan', 'params' => { 'strategy' => $reboot_strategy_group, 'message' => $reboot_message_group, 'wait' => $reboot_wait_group, 'disconnect_wait' => $disconnect_wait_group, 'noop' => $noop } },
    #   ## Remove VM snapshots
    #   { 'name' => $snapshot_plan_group, 'type' => 'plan', 'params' => { 'action' => 'delete', 'noop' => $noop } },
    #   ## Enable monitoring
    #   { 'name' => $monitoring_plan_group, 'type' => 'plan', 'params' => { 'action' => 'enable', 'noop' => $noop } },
    # ]

    # do normal patching

    $results_hash = {
      'failed_results' => {},
      'remaining_targets' => $ordered_targets,
      'no_updates' => [],
      'monitoring_disabled' => false,
      'monitoring_enable' => [],
    }

    # run each task/plan in the workflow and return a hash of results matching the $results_hash
    $patching_results = $tasks_plans.reduce($results_hash) |$acc, $task_plan| {
      # if no remaining targets (ie all targets have failed), break out of loop
      if $acc['remaining_targets'].empty {
        out::message('No remaining targets to run against')
        break()
      }

      $remaining_targets = $acc['remaining_targets']

      out::message("Targets to run against: ${remaining_targets}")
      if $task_plan['type'] == 'task' {
        $result = run_task($task_plan['name'], $remaining_targets, $task_plan['params'])
      } else {
        $result = run_plan($task_plan['name'], $remaining_targets, $task_plan['params'])
      }

      $filtered_results = patching::handle_errors($result, $task_plan['name'])

      $task_result = {
        'failed_results' => $acc['failed_results'],
        'remaining_targets' => $filtered_results['ok_targets'],
        'no_updates' => $acc['no_updates'] + $filtered_results['no_updates'],
        'monitoring_disabled' => $acc['monitoring_disabled'],
        'monitoring_enable' => $acc['monitoring_enable'],
      }

      # if using monitoring plan, once disabled we need to re-enable monitoring at the end
      if $task_plan['name'] == $monitoring_plan_group and !$acc['monitoring_disabled'] {
        $monitoring_flag = { 'monitoring_disabled' => true }
      } elsif $acc['monitoring_disabled'] {
        $monitoring_flag = { 'monitoring_disabled' => true }
      } else {
        $monitoring_flag = { 'monitoring_disabled' => false }
      }

      if !$filtered_results['failed_results'].empty {
        # track hosts that need monitoring re-enabled when monitoring is disabled
        if $acc['monitoring_disabled'] {
          $failed_results = {
            'monitoring_enable' => $filtered_results['failed_results'].keys + $acc['monitoring_enable'],
            'failed_results' => $filtered_results['failed_results'] + $acc['failed_results'],
          }
        } else {
          $failed_results = $acc['failed_results'] + { 'failed_results' => $filtered_results['failed_results'] }
        }
        # merge the results of the task with the failed results and monitoring flag
        $task_result + $failed_results + $monitoring_flag
      } else {
        $failed_results = {}
        $task_result + $failed_results + $monitoring_flag
      }
    }

    # if targets failed with monitoring turned off we need to re-enable
    if !$patching_results['monitoring_enable'].empty {
      out::message('ENABLING MONITORING ON FAILED HOSTS!!!!!!!!!!!')
      run_plan($monitoring_plan_group, $patching_results['monitoring_enable'], action => 'enable', noop => $noop)
    }
    $patching_results
  }

  ## Re-establish all targets availability after reboot
  # This is necessary in case one of the groups affects the availability of a previous group.
  # Two use cases here:
  #  1. A later group is a hypervisor. In this instance the hypervisor will reboot causing the
  #     VMs to go offline and we need to wait for those child VMs to come back up before
  #     collecting history metrics.
  #  2. A later group is a linux router. In this instance maybe the patching of the linux router
  #     affects the reachability of previous hosts.
  wait_until_available($_targets, wait_time => $reboot_wait_plan)

  ## Collect summary report
  run_plan('patching::update_history', $_targets,
    format      => $report_format_plan,
  report_file => $report_file_plan)

  if !$update_failed_targets['failed_results'].empty {
    $message = patching::process_errors($update_failed_targets)
    fail_plan($message)
  }

  ## Display final status
  return()
}
