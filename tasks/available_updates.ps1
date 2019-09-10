[CmdletBinding()]
Param(
  # Mandatory is set to false. If Set to $True then a dialog box appears to get the missing information
  # https://blogs.technet.microsoft.com/heyscriptingguy/2011/05/22/use-powershell-to-make-mandatory-parameters/
  [Parameter(Mandatory = $False)]
  [String]$provider,
  [String]$_installdir
)

Import-Module "$_installdir\patching\files\powershell\TaskUtils.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function AvailableUpdates-Windows() {
  $exit_code = 0
  $updateSession = Create-WindowsUpdateSession
  $updateList = Search-WindowsUpdate -session $updateSession
  $availableUpdateList = @()

  # for each update, collect information about it
  foreach ($update in $updateList) {
    #Write-Host "update = $update"
    $updateId = $update.Identity.UpdateID    
    $kbIds = @()
    foreach ($kb in $update.KBArticleIDs) {
      $kbIds += $kb
    }
    $availableUpdateList += @{
      'name' = $update.Title;
      'id' = $updateId;
      'version' = $update.Identity.RevisionNumber;
      'kb_ids' = $kbIds;
      'provider' = 'windows';
    }
  }
  return @($availableUpdateList | Sort-Object)
}

function AvailableUpdates-Chocolatey([bool]$choco_required) {
  $exit_code = 0
  $updateList = @()
  if (-not (Test-CommandExists 'choco')) {
    if ($choco_required) {
      Write-Error "Unable to find required command: choco"
      exit 2
    } else {
      # Write-Error "Unable to find required command: choco"
      # exit 2
      # TODO make a chocolatey required parameter
      # chocolatey wasn't required, simply return an empty list
      return @{
        'result' = @($updateList);
        'exit_code' = $exit_code;
      }
    }
  }

  # determine what chocolatey packages need upgrading
  # run command: choco outdated
  $output = iex "& choco outdated --limit-output --ignore-unfound"
  $exit_code = $LastExitCode
  # Write-Host "chocolatey output: $output"
  # Write-Host "chocolatey exit code: $exit_code"
  # TODO on failure capture output
  # TODO handle unfound packages more gracefully
  
  # output is in the format:
  # package name|current version|available version|pinned?
  foreach ($line in $output) {
    $parts = $line.split('|')
    $updateList += @{
      'name' = $parts[0];
      'version_old' = $parts[1];
      'version' = $parts[2];
      'pinned' = $parts[3];
      'provider' = 'chocolatey';
    }
  }
  return @{
    'result' = @($updateList | Sort-Object);
    'exit_code' = $exit_code;
  }
}

if ($provider -eq '') {
  $provider = 'all'
}

$exit_code = 0
if ($provider -eq 'windows') {
  $result = @{"updates" = @(AvailableUpdates-Windows)}
} elseif ($provider -eq 'chocolatey') {
  $result_chocolatey = AvailableUpdates-Chocolatey($True)
  $result = @{"updates" = @($result_chocolatey['result'])}
  $exit_code = $result_chocolatey['exit_code']
} elseif ($provider -eq 'all') {
  $updates_windows = @(AvailableUpdates-Windows)
  $result_chocolatey = AvailableUpdates-Chocolatey($False)
  $updates_chocolatey = @($result_chocolatey['result'])
  $result = @{"updates" = @($updates_windows + $updates_chocolatey)}
  $exit_code = $result_chocolatey['exit_code']
} else {
  Write-Error "Unknown provider! Expected 'windows', 'chocolatey', 'all'. Got: $provider"
  exit 100
}

ConvertTo-Json -Depth 100 $result
exit $exit_code
