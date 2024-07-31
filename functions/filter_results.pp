# modules/your_module/plans/process_results.pp
# Function to abstract the processing/error handling of patching results
function patching::filter_results(
  Variant[ResultSet, Hash] $results,
  String $task_plan_name
) >> Hash {
  if $results =~ Hash {
    if $task_plan_name == 'patching::available_updates' {
      $result = {
        'ok_targets' => $results['has_updates'],
        'failed_results' => $results['failed_results'],
        'no_updates' => $results['no_updates'],
      }
      return $result
    } else {
      $result = {
        'ok_targets' => $results['ok_targets'],
        'failed_results' => $results['failed_results'],
      }
      return $result
    }
  }

  $failed_results = if !$results.error_set.empty {
    # Return the result of iterating over the error_set to populate the failed_results hash
    $results.error_set.reduce({}) |$memo, $error| {
      $name = $error.target.name
      if $error.value['_output'] {
        $message = $error.value['_output']
      } else {
        $message = $error.error.message
      }
      $details = {
        'plan_or_task_name' => $task_plan_name,
        'message' => $message,
      }
      $memo + { $name => $details }
    }
  } else {
    {}
  }

  # Log the failed targets if any
  if !$results.error_set.empty {
    alert("The following hosts failed during ${task_plan_name}:")
    alert($failed_results.keys.join("\n"))
    log::info($failed_results)
  }

  # Extract the list of targets that succeeded
  $ok_targets = $results.ok_set.targets.map |$target| { $target.name }

  $result_set = {
    'ok_targets' => $ok_targets,
    'failed_results' => $failed_results,
  }

  # Return a hash containing the ok_targets and failed_results
  return $result_set
}
