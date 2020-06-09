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
  foreach ($updateAndServer in $updateList) {
    $serverSelection = $updateAndServer['server_selection']
    $update = $updateAndServer['update']
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
      'server_selection' = $serverSelection;
      'provider' = 'windows';
    }
  }
  return @{
    'result' = @($availableUpdateList | Sort-Object);
    'exit_code' = $exit_code;
  }
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
  # TODO handle unfound packages more gracefully
  
  if ($exit_code -eq 0) {
    # output is in the format:
    # package name|current version|available version|pinned?
    foreach ($line in $output) {
      $parts = @($line.split('|'))
      if ($parts.Length -lt 4) {
        return @{
          'result' = $output;
          'exit_code' = 102;
          'error' = '"choco outdated" command returned data in an unknown format (couldnt find at least 4x "|" characters). Check the "result" parameter for the raw output from the command. Guessing there was some unexpected error and "choco outdated" still returned an exit code of 0.';
        }
      }
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
  } else {
    return @{
      'result' = $output;
      'exit_code' = $exit_code;
    }
  }
}

if ($provider -eq '') {
  $provider = 'all'
}

$exit_code = 0
if ($provider -eq 'windows') {
  $data_windows = AvailableUpdates-Windows
  $exit_code = $data_windows['exit_code']
  if ($exit_code -eq 0) {
    $result = @{"updates" = @($data_windows['result'])}
  }
  else {
    $result = @{'error_windows' = $data_windows}
  }
} elseif ($provider -eq 'chocolatey') {
  $data_chocolatey = AvailableUpdates-Chocolatey($True)
  $exit_code = $data_chocolatey['exit_code']
  if ($exit_code -eq 0) {
    $result = @{"updates" = @($data_chocolatey['result'])}
  }
  else {
    $result = @{'error_chocolatey' = $data_chocolatey}
  }
} elseif ($provider -eq 'all') {
  $result = @{"updates" = @()}
  $exit_code = 0
  
  $data_windows = AvailableUpdates-Windows
  $result_windows = $data_windows['result']
  $exit_code_windows = $data_windows['exit_code']
  if ($exit_code_windows -eq 0) {
    $result['updates'] += @($result_windows)
  }
  else {
    $result['error_windows'] = $result_windows
    $exit_code = $exit_code_windows
  }

  $data_chocolatey = AvailableUpdates-Chocolatey($False)
  $result_chocolatey = $data_chocolatey['result']
  $exit_code_chocolatey = $data_chocolatey['exit_code']
  if ($exit_code_chocolatey -eq 0) {
    $result['updates'] += @($result_chocolatey)
  }
  else {
    $result['error_chocolatey'] = $result_chocolatey
    $exit_code = $exit_code_chocolatey
  }
} else {
  Write-Error "Unknown provider! Expected 'windows', 'chocolatey', 'all'. Got: $provider"
  exit 100
}

ConvertTo-Json -Depth 100 $result
exit $exit_code
