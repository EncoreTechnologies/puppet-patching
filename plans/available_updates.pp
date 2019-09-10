plan patching::available_updates (
  TargetSpec $nodes,
  # TODO CSV and JSON outputs
  Enum["none", "pretty", "csv"] $format = "pretty",
  Boolean                       $noop   = false,
) {
  $available_results = run_task('patching::available_updates', $nodes,
                                _noop => $noop)
  case $format {
    "none": {
      return($available_results)
    }
    "pretty": {
      out::message("Host update status: ('+' has available update; '-' no update) [num updates]")
      $has_updates = $available_results.filter_set|$res| { !$res['updates'].empty() }.targets
      $no_updates = $available_results.filter_set|$res| { $res['updates'].empty() }.targets
      $available_results.each|$res| {
        $num_updates = $res['updates'].size
        $symbol = ($num_updates > 0) ? { true => '+' , default => '-' }
        out::message(" ${symbol} ${res.target.name} [${num_updates}]")
      }
      return({
        'has_updates' => $has_updates,
        'no_updates'  => $no_updates,
      })
    }
    "csv": {
      $csv_header = 'hostname,num_updates,name,version (linux only),kbs (windows only)\n'
      $csv = $available_results.reduce($csv_header) |$res_memo, $res| {
        $hostname = $res.target.host
        $num_updates = $res['updates'].length
        $host_updates = $res['updates'].reduce('') |$up_memo, $up| {
          $name = $up['name']
          $version = ('version' in $up) ? {
            true    => $up['version'],
            default => '',
          }
          $kb_ids = ('kb_ids' in $up) ? {
            true    => $up['kb_ids'].join(','),
            default => '',
          }
          $csv_line = "${hostname},${num_updates},${name},${version},${kb_ids}"
          out::message($csv_line)
          "${up_memo}${csv_line}\n"

        }
        "${res_memo}${host_updates}"
      }
      file::write('available_updates.csv', $csv)
      out::message($csv)
      return($csv)
    }
    default: {
      fail_plan("unknown format: ${format}")
    }
  }

}
