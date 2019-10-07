# @summary Checks all nodes for available updates reported by their Operating System.
#
# This uses the <code>patching::available_updates</code> task to query each Target's
# Operating System for available updates. The results from the OS are parsed and formatted
# into easy to consume JSON data, such that further code can be written against the
# output.
#
#  - RHEL: This ultimately performs a <code>yum check-update</code>.
#  - Ubuntu: This ultimately performs a <code>apt upgrade --simulate</code>.
#  - Windows:
#    - Windows Update API: Queries the WUA for updates. This is the standard update mechanism
#      for Windows.
#    - Chocolatey: If installed, runs <code>choco outdated</code>. If not installed, Chocolatey is ignored.
#
# @param [TargetSpec] nodes
#   Set of targets to run against.
# @param [Enum['none', 'pretty', 'csv']] format
#   Output format for printing user-friendly information during the plan run.
#   This also determines the format of the information returned from this plan.
#
#     - 'none' : Prints no data to the screen. Returns the raw ResultSet from the patching::available_updates task
#     - 'pretty' : Prints the data out in a easy to consume format, one line per host, showing the number of available updates per host. Returns a Hash containing two keys: 'has_updates' - an array of TargetSpec that have updates available, 'no_updates' - an array of hosts that have no updates available.
#     - 'csv' : Prints and returns CSV formatted data, one row for each update of each host.
# @param [Boolean] noop
#   Run this plan in noop mode, meaning no changes will be made to end systems.
#   In this case, noop mode has no effect.
#
# @example CLI - Basic Usage
#   bolt plan run patching::available_updates --nodes linux_hosts
#
# @example CLI - Get available update information in CSV format for creating reports
#   bolt plan run patching::available_updates --nodes linux_hosts format=csv
#
# @example Plan - Basic Usage
#   run_plan('patching::available_updates',
#            nodes => $linux_hosts)
#
# @example Plan - Get available update information in CSV format for creating reports
#   run_plan('patching::available_updates',
#            nodes  => $linux_hosts,
#            format => 'csv')
#
plan patching::available_updates (
  TargetSpec $nodes,
  # TODO JSON
  Enum['none', 'pretty', 'csv'] $format = 'pretty',
  Boolean                       $noop   = false,
) {
  $available_results = run_task('patching::available_updates', $nodes,
                                _noop => $noop)
  case $format {
    'none': {
      return($available_results)
    }
    'pretty': {
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
    'csv': {
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
