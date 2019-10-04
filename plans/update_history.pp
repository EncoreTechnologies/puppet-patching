# Bolt plan to collect update history from hosts
plan patching::update_history (
  TargetSpec       $nodes,
  Optional[ResultSet] $history = undef,
  String           $environment = 'default',
  String           $report_file = 'patching_report.csv',
  Optional[String] $mail_from = undef,
  Optional[String] $mail_to = undef,
  # TODO CSV and JSON outputs
  Enum['none', 'pretty', 'csv'] $format = 'pretty',
) {
  $targets = run_plan('patching::get_targets', nodes => $nodes)

  ## Collect update history
  if $history {
    $real_history = $history
  }
  else {
    $real_history = run_task('patching::update_history', $targets)
  }

  ## Format the report
  case $format {
    'none': {
      return($real_history)
    }
    'pretty': {
      $row_format = '%-30s | %-8s | %-8s'
      $header = sprintf($row_format, 'host', 'upgraded', 'installed')
      $divider = '-----------------------------------------------------'
      $output = $real_history.map|$hist| {
        $num_upgraded = $hist['upgraded'].size
        $num_installed = $hist['installed'].size
        $row_format = '%-30s | %-8s | %-8s'
        $message = sprintf($row_format, $hist.target.name, $num_upgraded, $num_installed)
        $message
      }

      ## Build report
      $report = join([$header, $divider] + $output + [''], "\n")
    }
    'csv': {
      $header = 'host,action,name,version (linux only),kb (windows only)\n'
      $report = $available_results.reduce($csv_header) |$res_memo, $res| {
        $hostname = $res.target.host
        $num_updates = $res['upgraded'].length
        $host_updates = $res['upgraded'].reduce('') |$up_memo, $up| {
          $name = $up['name']
          $version = ('version' in $up) ? {
            true    => $up['version'],
            default => '',
          }
          if 'kb_ids' in $up {
            # create a new line for each KB article
            $csv_line = $up['kb_ids'].reduce('') |$kb_memo, $kb| {
              $kb_line = "${hostname},upgraded,${name},${version},${kb}"
              "${kb_memo}${kb_line}\n"
            }
          }
          else {
            # create one line per update/upgrade
            $csv_line = "${hostname},upgraded,${name},${version},"
          }
          "${up_memo}${csv_line}\n"
        }
        "${res_memo}${host_updates}"
      }
    }
    default: {
      fail_plan("unknown format: ${format}")
    }
  }

  out::message($report)

  ## Write report to file
  if $report_file {
    file::write($report_file, $report)
  }

  ## Email report if mail_to supplied.
  if $mail_to {
    run_task('patching::mailx', 'localhost',
      subject => "Update Summary Report for [${environment}]",
      to      => $mail_to,
      from    => $mail_from,
      body    => $final_report,
    )
  }
  return($report)
}
