[CmdletBinding()]
Param(
  # Mandatory is set to false. If Set to $True then a dialog box appears to get the missing information
  # https://blogs.technet.microsoft.com/heyscriptingguy/2011/05/22/use-powershell-to-make-mandatory-parameters/
  [Parameter(Mandatory = $False)]
  [String]$provider,
  [String]$_installdir
)

Import-Module "$_installdir\patching\files\powershell\TaskUtils.ps1"

function AvailableUpdates-Windows() {
  $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
  $updateSearcher = $updateSession.CreateUpdateSearcher()
  # https://docs.microsoft.com/en-us/windows/win32/api/wuapicommon/ne-wuapicommon-serverselection
  #
  # typedef enum tagServerSelection {
  #   ssDefault,       # 0
  #   ssManagedServer, # 1
  #   ssWindowsUpdate, # 2
  #   ssOthers         # 3
  # } ServerSelection;
  #
  # search for updates that you see in the Windows Update application
  $updateSearcher.ServerSelection = 2
  # https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatesearcher-search
  # search for updates that aren't installed yet
  $searchCriteria = 'IsInstalled=0'
  $searchResult = $updateSearcher.Search($searchCriteria)
  $updateList = @()
  foreach ($update in $searchResult.Updates) {
    $kbIds = @()
    foreach ($kb in $update.KBArticleIDs) {
      $kbIds += $kb
    }
    $updateList += @{
      'name' = $update.Title;
      'kb_ids' = $kbIds;
      'provider' = 'windows';
    } 
  }
  return @($updateList | Sort-Object)
}

function AvailableUpdates-Chocolatey([bool]$choco_required) {
  $updateList = @()
  if (-not (Test-CommandExists 'choco')) {
    if ($choco_required) {
      Write-Error "Unable to find required command: choco"
      exit 2
    } else {
      # chocolatey wasn't required, simply return an empty list
      return $updateList
    }
  }

  # determine what chocolatey packages need upgrading
  # run command: choco outdated
  $output = iex "& choco outdated --limit-output"
  # output is in the format:
  # package name|current version|available version|pinned?
  foreach ($line in $output) {
    $parts = $line.split('|')
    $updateList += @{
      'name' = $parts[0];
      'version' = $parts[2];
      'pinned' = $parts[3];
      'provider' = 'chocolatey';
    }
  }
  
  return @($updateList | Sort-Object)
}

if ($provider -eq '') {
  $provider = 'all'
}

if ($provider -eq 'windows') {
  $result = @{"updates" = (AvailableUpdates-Windows)}
} elseif ($provider -eq 'chocolatey') {
  $result = @{"updates" = @(AvailableUpdates-Chocolatey($True))}
} elseif ($provider -eq 'all') {
  $updates_windows = @(AvailableUpdates-Windows)
  $updates_chocolatey = @(AvailableUpdates-Chocolatey($False))
  $result = @{"updates" = @($updates_windows + $updates_chocolatey)}
} else {
  Write-Error "Unknown provider! Expected 'windows', 'chocolatey', 'all'. Got: $provider"
  exit 100
}

ConvertTo-Json -Depth 100 $result
