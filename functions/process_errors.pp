# Function to process patching results with targets that failed
function patching::process_errors(
  Hash $patching_results,
) >> String {
  $failed_results = $patching_results['failed_results']
  $start = ['Patching failed for the following hosts:']
  $error_messages = $failed_results.reduce($start) |$acc, $result| {
    $host = $result[0]
    $task = $result[1]['plan_or_task_name']
    $message = $result[1]['message']
    log::info("${host} - ${task}: ${message}")
    $acc + ["${host} - ${task}"]
  }

  return $error_messages.join("\n")
}
