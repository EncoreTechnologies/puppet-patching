[CmdletBinding()]
Param(
  # Mandatory is set to false. If Set to $True then a dialog box appears to get the missing information
  # We will do a variable check later
  # https://blogs.technet.microsoft.com/heyscriptingguy/2011/05/22/use-powershell-to-make-mandatory-parameters/
  [Parameter(Mandatory = $False)]
  [String]$script,
  [String]$_task
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

If (-not $script) {
  If ($_task -eq 'patching::pre_update') {
    $script = 'C:\ProgramData\patching\bin\pre_update.ps1'
  } elseif ($_task -eq 'patching::post_update') {
    $script = 'C:\ProgramData\patching\bin\post_update.ps1'
  } else {
    Write-Error "ERROR - 'script' wasn't specified and we were called with an unknown task: $_task"
    exit 2
  }
}

If ($script -and (Test-Path $script -PathType Leaf)) {
  & $script
  exit $LASTEXITCODE
} else {
  Write-Output "WARNING: Script doesn't exist: $script"
  exit 0
}
