[CmdletBinding()]
Param(
  # Mandatory is set to false. If Set to $True then a dialog box appears to get the missing information
  # We will do a variable check later
  # https://blogs.technet.microsoft.com/heyscriptingguy/2011/05/22/use-powershell-to-make-mandatory-           parameters/
  [Parameter(Mandatory = $False)]
  [String]$name,
  # TODO write results to file
  [String]$result_file,
  [String]$log_file,
  [String]$provider,
  [String]$_installdir
)

Import-Module "$_installdir\patching\files\powershell\TaskUtils.ps1"

function Update-Windows {
  $script_block = {
    $exitStatus = 0

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $windowsOsVersion = [System.Environment]::OSVersion.Version
    $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
    $updateSession.ClientApplicationID = 'windows-update-installer'

    $updatesToDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl'
    $updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'
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
    # TODO search all servers
    $updateSearcher.ServerSelection = 2
    # https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatesearcher-search
    # search for updates that aren't installed yet
    $searchCriteria = 'IsInstalled=0'
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
        'provider' = 'windows';
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
        # https://docs.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-operationresultcode
        switch ($patchingResult['result_code'])
        {
          0 { $patchingResult["result"] = "not_started" }
          1 { $patchingResult["result"] = "in_progress" }
          2 { $patchingResult["result"] = "succeeded" }
          3 { $patchingResult["result"] = "succeeded_with_errors" }
          4 {
            $patchingResult["result"] = "_failed"
            $exitStatus = 2
          }
          5 {
            $patchingResult["result"] = "aborted"
            $exitStatus = 2
          }
          default { $patchingResult["result"] = "unknown" }
        }
      }
    }
    # Because this thing is running inside of a ScheduledTask and all of the output
    # is written to a log file and then returned back to us as a string, we need a way
    # to pass structured data from this script block, back to the caller of Invoke-CommandAsLocal
    # to do this structured data passing we serialize the data to JSON and then parse it below
    ConvertTo-Json -Depth 100 @{'upgraded' = @($patchingResultList)}
    exit $exitStatus
  }

  # The script block above returns the command output as JSON, however PowerShell returns
  # the output as an array of lines, so we need to concat these strings into one big blob
  # so we can parse the JSON back into an object.
  $update_results = Invoke-CommandAsLocal -ScriptBlock $script_block
  $result_json_str = $update_results.CommandOutput -join "`r`n"
  # note $result_obj is a "custom object", not a hashtable
  $result_hash = ConvertFrom-Json $result_json_str | Convert-PSObjectToHashtable
  return @{
    'result' = $result_hash;
    'exit_code' = $update_results.ExitCode;
  }
}

################################################################################

function Update-Chocolatey([bool]$choco_required) {
  $updateList = @()
  # todo put this into a function
  if (-not (Test-CommandExists 'choco')) {
    if ($choco_required) {
      throw "Unable to find required command: choco"
    } else {
      # chocolatey wasn't required, simply return an empty list
      return $updateList
    }
  }

  # Upgrade all chocolatey packages
  # TODO support only updating specific packages
  $output = iex "& choco upgrade all --yes --limit-output --no-progress"
  $exit_code = $LastExitCode
  # TODO write output to log file
  
  # output is in the format:
  # package name|current version|available version|pinned?
  $package_versions = @{}
  $package_success = @()
  for ($i=0; $i -lt $output.Count; $i++) {
    $line = $output[$i]
    if ($line -match "(.*?)\|(.*?)\|(.*?)\|(.*)") {
      $name = $Matches.1
      $version_old = $Matches.2
      $version_new = $Matches.3
      $pinned = $Matches.4
      
      $package_versions[$name] =  @{
        'name' = $name;
        'version' = $version_new;
        'version_old' = $version_old;
        'pinned' = $pinned;
        'provider' = 'chocolatey';
      }
    }
    if ($line -match " The upgrade of (.*) was successful\.") {
      $name = $Matches.1
      if ($package_versions.ContainsKey($name)) {
        $package_success += $package_versions[$name]
      }
    }
  }
  
  return @{
    'result' = @{'upgraded' = @($package_success)};
    'exit_code' = $exit_code;
  }
}

################################################################################

if ($provider -eq '') {
  $provider = 'all'
}

if ($provider -eq 'windows') {
  $data = Update-Windows
  $result = $data['result']
  $exit_code = $data['exit_code']
} elseif ($provider -eq 'chocolatey') {
  $data = Update-Chocolatey $True
  $result = $data['result']
  $exit_code = $data['exit_code']
} elseif ($provider -eq 'all') {
  # Windows Update
  $data_windows = Update-Windows
  $result_windows = $data_windows['result']
  $exit_code = $data_windows['exit_code']
  if ($exit_code -ne 0) {
    Write-Error "Updating windows provider failed!"
    exit $exit_code
  }

  # Chocolatey upgrade
  $data_chocolatey = Update-Chocolatey $False
  $result_chocolatey = $data_chocolatey['result']
  $exit_code = $data_chocolatey['exit_code']
  if ($exit_code -ne 0) {
    Write-Error "Updating chocolatey provider failed!"
    exit $exit_code
  }

  # combine results
  $result = @{
    'upgraded' = @($result_windows['upgraded']) + @($result_chocolatey['upgraded']);
  }
} else {
  Write-Error "Unknown provider! Expected 'windows', 'chocolatey', 'all'. Got: $provider"
  exit 100
}

ConvertTo-Json -Depth 100 $result
exit $exit_code
