[CmdletBinding()]
Param(
  # Mandatory is set to false. If Set to $True then a dialog box appears to get the missing information
  # We will do a variable check later
  # https://blogs.technet.microsoft.com/heyscriptingguy/2011/05/22/use-powershell-to-make-mandatory-           parameters/
  [Parameter(Mandatory = $False)]
  [String]$result_file,
  [String]$_installdir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$pattern_matches = Select-String -Path $result_file -Pattern "^{$"
if ($pattern_matches) {
  # get the LAST matching line number of { , the start of a JSON document
  $last_line = $pattern_matches[-1].LineNumber

  # find the total number of lines in the file
  $measure = Get-Content -Path $result_file | Measure-Object -Line

  # compute how many lines we need to read off the tail of the file
  # based on total lines - last line we found it + 1
  $num_tail_lines = 1 + $measure.Lines - $last_line
  
  # read the last N lines from the file (starting at our match)
  $data = Get-Content -Path $result_file -Tail $num_tail_lines;
  
  Write-Output $data
}
