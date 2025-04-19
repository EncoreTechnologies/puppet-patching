# Function: build_workflow
# Builds a workflow for patching based on provided parameters.
#
# @param update_provider_group The update provider for the group.
# @param monitoring_plan_group The monitoring plan for the group.
# @param snapshot_plan_group The snapshot plan for the group.
# @param pre_update_plan_group The pre-update plan for the group.
# @param post_update_plan_group The post-update plan for the group.
# @param reboot_strategy_group The reboot strategy for the group.
# @param reboot_message_group The reboot message for the group.
# @param reboot_wait_group The wait time before reboot for the group.
# @param disconnect_wait_group The wait time before checking disconnect for the group.
# @param noop Flag to enable noop mode for the underlying plans and tasks.
#
# @return Returns a structured data representing the workflow to be executed.
# [
#   Update patching cache (yum update, apt-get update, etc)
#   { 'name' => 'patching::cache_update', 'type' => 'task', 'params' => { '_noop' => $noop, '_catch_errors' => true } },
#   Check for available updates
#   { 'name' => 'patching::available_updates', 'type' => 'plan', 'params' => {
#     'provider' => $update_provider_group,
#     'format' => 'pretty',
#     'noop' => $noop
#   } },
#   Disable monitoring
#   { 'name' => $monitoring_plan_group, 'type' => 'plan', 'params' => {
#     'action' => 'disable',
#     'noop' => $noop
#   } },
#   Create VM snapshots
#   { 'name' => $snapshot_plan_group, 'type' => 'plan', 'params' => {
#     'action' => 'create',
#     'noop' => $noop
#   } },
#   Run pre-patching script
#   { 'name' => $pre_update_plan_group, 'type' => 'plan', 'params' => { 'noop' => $noop } },
#   Run package updates
#   { 'name' => 'patching::update', 'type' => 'task', 'params' => {
#     'provider' => $update_provider_group,
#     '_catch_errors' => true,
#     'noop' => $noop
#   } },
#   Run post-patching script
#   { 'name' => $post_update_plan_group, 'type' => 'plan', 'params' => { 'noop' => $noop } },
#   Check if reboot required
#   { 'name' => 'patching::reboot_required', 'type' => 'plan', 'params' => {
#     'strategy' => $reboot_strategy_group,
#     'message' => $reboot_message_group,
#     'wait' => $reboot_wait_group,
#     'disconnect_wait' => $disconnect_wait_group,
#     'noop' => $noop
#   } },
#   Remove VM snapshots
#   { 'name' => $snapshot_plan_group, 'type' => 'plan', 'params' => {
#     'action' => 'delete',
#     'noop' => $noop
#   } },
#   Enable monitoring
#   { 'name' => $monitoring_plan_group, 'type' => 'plan', 'params' => {
#     'action' => 'enable',
#     'noop' => $noop
#   } },
# ]
function patching::build_workflow(
  Optional[String]  $update_provider_group,
  Optional[Boolean] $monitoring_enabled_group,
  Optional[String]  $monitoring_plan_group,
  Optional[Boolean]  $snapshot_create_group,
  Optional[Boolean] $snapshot_delete_group,
  Optional[String]  $snapshot_plan_group,
  Optional[String]  $pre_update_plan_group,
  Optional[String]  $post_update_plan_group,
  Optional[Enum['only_required', 'never', 'always']] $reboot_strategy_group,
  Optional[String]  $reboot_message_group,
  Optional[Integer] $reboot_wait_group,
  Optional[Integer] $disconnect_wait_group,
  Boolean $noop
) >> Array[Hash] {
  # Initialize an array with tasks/plans that are always included
  $initial = [
    {
      'name' => 'patching::cache_update',
      'type' => 'task',
      'params' => {
        '_noop' => $noop,
        '_catch_errors' => true,
      }
    },
    {
      'name' => 'patching::available_updates',
      'type' => 'plan',
      'params' => {
        'provider' => $update_provider_group,
        'format' => 'pretty',
        'noop' => $noop,
      }
    },
  ]

  # Determine if monitoring should be disabled
  if $monitoring_enabled_group and $monitoring_plan_group and $monitoring_plan_group != 'disabled' {
    $monitoring_plan = [
      {
        'name' => $monitoring_plan_group,
        'type' => 'plan',
        'params' => {
          'action' => 'disable',
          'noop' => $noop,
        }
      },
    ]
    $monitoring_reenable_group = true
  } else {
    $monitoring_plan = []
    $monitoring_reenable_group = false
  }

  # Determine if snapshots should be created
  if $snapshot_create_group and $snapshot_plan_group and $snapshot_plan_group != 'disabled' {
    $snapshot_plan = [
      {
        'name' => $snapshot_plan_group,
        'type' => 'plan',
        'params' => {
          'action' => 'create',
          'noop' => $noop,
        }
      },
    ]
  } else {
    $snapshot_plan = []
  }

  # Continue adding the rest of the tasks/plans in order
  $update = [
    {
      'name' => $pre_update_plan_group,
      'type' => 'plan',
      'params' => {
        'noop' => $noop,
      }
    },
    {
      'name' => 'patching::update',
      'type' => 'task',
      'params' => {
        'provider' => $update_provider_group,
        '_catch_errors' => true,
        '_noop' => $noop,
      }
    },
    {
      'name' => $post_update_plan_group,
      'type' => 'plan',
      'params' => {
        'noop' => $noop,
      }
    },
    {
      'name' => 'patching::reboot_required',
      'type' => 'plan',
      'params' => {
        'strategy' => $reboot_strategy_group,
        'message' => $reboot_message_group,
        'wait' => $reboot_wait_group,
        'disconnect_wait' => $disconnect_wait_group,
        'noop' => $noop,
      }
    },
  ]

  # Conditionally append the remove VM snapshots and enable monitoring plans at the end
  if $snapshot_delete_group and $snapshot_plan_group and $snapshot_plan_group != 'disabled' {
    $snapshot_delete = [
      {
        'name' => $snapshot_plan_group,
        'type' => 'plan',
        'params' => {
          'action' => 'delete',
          'noop' => $noop,
        }
      },
    ]
  } else {
    $snapshot_delete = []
  }

  if $monitoring_reenable_group and $monitoring_plan_group and $monitoring_plan_group != 'disabled' {
    $monitoring_reenable = [
      {
        'name' => $monitoring_plan_group,
        'type' => 'plan',
        'params' => {
          'action' => 'enable',
          'noop' => $noop,
        }
      },
    ]
  } else {
    $monitoring_reenable = []
  }

  # Return the complete workflow array
  return $initial + $monitoring_plan + $snapshot_plan + $update + $snapshot_delete + $monitoring_reenable
}
