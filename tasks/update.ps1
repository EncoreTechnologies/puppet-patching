[CmdletBinding()]
Param(
  # Mandatory is set to false. If Set to $True then a dialog box appears to get the missing information
  # We will do a variable check later
  # https://blogs.technet.microsoft.com/heyscriptingguy/2011/05/22/use-powershell-to-make-mandatory-           parameters/
  [Parameter(Mandatory = $False)]
  [String]$name,
  [String]$log_file,
  [String]$_installdir
)

Import-Module "$_installdir\patching\files\powershell\TaskUtils.ps1"


$script_block = {
  # https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatesearcher-search
  # search for updates that aren't installed yet
  $exitStatus = 0
  $searchCriteria = 'IsInstalled=0'

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'

  $windowsOsVersion = [System.Environment]::OSVersion.Version
  $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
  $updateSession.ClientApplicationID = 'windows-update-installer'

  $updatesToDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl'
  $updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'
  $updateSearcher = $updateSession.CreateUpdateSearcher()
  $searchResult = $updateSearcher.Search($searchCriteria)

  $patchingResultList = @()
  for ($i = 0; $i -lt $searchResult.Updates.Count; ++$i) {
    $update = $searchResult.Updates.Item($i)
    $updateDate = $update.LastDeploymentChangeTime.ToString('yyyy-MM-dd')
    $update.AcceptEula() | Out-Null

    if (!$update.IsDownloaded) {
      $updatesToDownload.Add($update) | Out-Null
    }

    $updatesToInstall.Add($update) | Out-Null
    
    $kbIds = @()
    foreach ($kb in $update.KBArticleIDs) {
      $kbIds += $kb
    }
    $patchingResultList += @{
      'name' = $update.Title;
      'kb_ids' = $kbIds;
    }
  }

  if ($updatesToDownload.Count) {
    $updateDownloader = $updateSession.CreateUpdateDownloader()

    # https://docs.microsoft.com/en-us/windows/desktop/api/winnt/ns-winnt-_osversioninfoexa#remarks
    # if Windows 8 / Windows Server 2012 or newer
    if (($windowsOsVersion.Major -gt 6) -or ($windowsOsVersion.Major -eq 6 -and $windowsOsVersion.Minor -gt 1)) {
      $updateDownloader.Priority = 4 # 1 (dpLow), 2 (dpNormal), 3 (dpHigh), 4 (dpExtraHigh).
    } else {
      # Windows 7 / Windows Server 2008
      # Highest prioirty is 3
      $updateDownloader.Priority = 3 # 1 (dpLow), 2 (dpNormal), 3 (dpHigh).
    }
    $updateDownloader.Updates = $updatesToDownload
    $downloadResult = $updateDownloader.Download()
  }

  if ($updatesToInstall.Count) {
    $updateInstaller = $updateSession.CreateUpdateInstaller()
    $updateInstaller.Updates = $updatesToInstall
    $installationResult = $updateInstaller.Install()

    # Windows update interface doesn't just return us usable statuses
    # or even an array of results... we have to ask the result object for indexes
    # to determine the results of each patch based on the index in our input array... sorry
    for ($i = 0; $i -lt $updatesToInstall.Count; ++$i) {
      $update = $updatesToInstall[$i]
      $patchingResult = $patchingResultList[$i]
      $updateInstallationResult = $installationResult.GetUpdateResult($i)
      $patchingResult['result_code'] = $updateInstallationResult.ResultCode
      $patchingResult['reboot_required'] = $updateInstallationResult.RebootRequired
      
      # interpret the result code and have us exit with an error if any of the patches error
      switch ($patchingResult['result_code'])
      {
        0 { $patchingResult["result"] = "Not Started" }
        1 { $patchingResult["result"] = "In Progress" }
        2 { $patchingResult["result"] = "Succeeded" }
        3 { $patchingResult["result"] = "Succeeded With Errors" }
        4 {
          $patchingResult["result"] = "Failed"
          $exitStatus = 2
        }
        5 {
          $patchingResult["result"] = "Aborted"
          $exitStatus = 2
        }
        default { $patchingResult["result"] = "Unknown" }
      }
    }
  }
  ConvertTo-Json -Depth 100 @{"upgraded" = $patchingResultList}
  exit $exitStatus
}

$install_updatesnow = Invoke-CommandAsLocal -ScriptBlock $script_block

# Passing back the whole $install_updatesnow.CommandOutput results in extra data in the bolt return
# So using exit code to get the neccessary code we need

$output_str = $install_updatesnow.CommandOutput -join "`r`n" | Out-String
$return_value = ConvertFrom-Json $output_str

ConvertTo-Json -Depth 100 $return_value
exit 0
