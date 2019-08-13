# Bolt plan to collect update history hosts
plan encore_rp::collect_update_history (
  TargetSpec $nodes,
  String $environment = 'default',
  String $report_file = '/opt/encore/log/patch_summary_report.csv',
  String $mail_from = 'svc_encore@encore.tech',
  String $mail_to = '',
  Array $failed = [],
) {
  $targets = run_plan('patching::get_targets', nodes => $nodes)

  ## Collect summary information
  $summary = run_task('encore_rp::update_summary', $online)

  ## Build report
  $subject = "Update Summary Report for [${environment}]"
  $header = 'HOSTNAME                      , ID     , LOGIN USER               , DATE AND TIME    , ACTION(S)      , ALTERED'
  $sum_all = $summary.map |$i| { $i.message }
  $report = join([$header] + $sum_all, "\n")

  ## Display summary report.
  warning($subject)
  warning($report)

  ## Display failed nodes if any.
  if !$failed.empty {
    $failed_nodes = get_targets($failed).map |$item| { $item.name }
    $header2 = 'FAILED NODES:'
    $report2 = join([$header2] + $failed_nodes, "\n ! ")
    $final_report = join([$report] + [$report2], "\n\n")
    alert($report2)
  } else {
    $final_report = $report
  }

  ## Write summary report.
  file::write($report_file, $final_report)

  ## Email report if mail_to supplied.
  if !$mail_to.empty {
    run_task('encore_rp::mailx', 'localhost',
      subject => $subject,
      to      => $mail_to,
      from    => $mail_from,
      body    => $final_report,
    )
  }
}
