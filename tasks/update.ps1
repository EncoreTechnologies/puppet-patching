[CmdletBinding()]
Param(
  # Mandatory is set to false. If Set to $True then a dialog box appears to get the missing information
  # We will do a variable check later
  # https://blogs.technet.microsoft.com/heyscriptingguy/2011/05/22/use-powershell-to-make-mandatory-           parameters/
  [Parameter(Mandatory = $False)]
  [String]$names,
  # NICK START HERE (write results to file)
  # TODO write results to file
  [String]$result_file,
  [String]$log_file,
  [String]$provider,
  [String]$_installdir
)

Import-Module "$_installdir\patching\files\powershell\TaskUtils.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Update-Windows([String]$_installdir) {
  $script_block = {
    param (
      [string]$_installdir = 'Nothing passed in'
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    Import-Module "$_installdir\patching\files\powershell\TaskUtils.ps1"
        
    $exitStatus = 0
    try {
      $windowsOsVersion = [System.Environment]::OSVersion.Version
      $updateSession = Create-WindowsUpdateSession
      $updateList = Search-WindowsUpdate -session $updateSession
      $patchingResultList = @()
      $updatesToDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl'
      $updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

      # for each update, accept the EULA, add it to our list to download
      foreach ($updateAndServer in $updateList) {
        $serverSelection = $updateAndServer['server_selection']
        $update = $updateAndServer['update']
        $updateId = $update.Identity.UpdateID
        $updateDate = $update.LastDeploymentChangeTime.ToString('yyyy-MM-dd')
        $update.AcceptEula() | Out-Null
      
        if (!$update.IsDownloaded) {
          $updatesToDownload.Add($update) | Out-Null # need to use .Add() here because it's a special type
        }

        $updatesToInstall.Add($update) | Out-Null # need to use .Add() here because it's a special type
      
        $kbIds = @()
        foreach ($kb in $update.KBArticleIDs) {
          $kbIds += $kb
        }
        $patchingResultList += @{
          'name' = $update.Title;
          'id' = $updateId;
          'version' = $update.Identity.RevisionNumber;
          'kb_ids' = $kbIds;
          'server_selection' = $serverSelection;
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
          $update = $updatesToInstall.Item($i)  # need to use .Item() here because it's a special type
          $patchingResult = $patchingResultList[$i]
          $updateInstallationResult = $installationResult.GetUpdateResult($i)
          $patchingResult['result_code'] = $updateInstallationResult.ResultCode
          $patchingResult['reboot_required'] = $updateInstallationResult.RebootRequired
      
          # interpret the result code and have us exit with an error if any of the patches error
          # https://docs.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-operationresultcode
          switch ($patchingResult['result_code'])
          {
            0 { $patchingResult["result"] = "not_started"; break }
            1 { $patchingResult["result"] = "in_progress"; break }
            2 { $patchingResult["result"] = "succeeded"; break }
            3 { $patchingResult["result"] = "succeeded_with_errors"; break }
            4 {
              $patchingResult["result"] = "_failed"
              $exitStatus = 2
              break
            }
            5 {
              $patchingResult["result"] = "aborted"
              $exitStatus = 2;
              break
            }
            default { $patchingResult["result"] = "unknown"; break }
          }
        }
      }
      # Because this thing is running inside of a ScheduledTask and all of the output
      # is written to a log file and then returned back to us as a string, we need a way
      # to pass structured data from this script block, back to the caller of Invoke-CommandAsLocal
      # to do this structured data passing we serialize the data to JSON and then parse it below
      ConvertTo-Json -Depth 100 @{'upgraded' = @($patchingResultList);
                                  'installed' = @();}
    }
    Catch {
      $exception_str = $_ | Out-String
      ConvertTo-Json -Depth 100 @{'exception' = $exception_str;}
      exit 99
    }
    exit $exitStatus
  }

  # The script block above returns the command output as JSON, however PowerShell returns
  # the output as an array of lines, so we need to concat these strings into one big blob
  # so we can parse the JSON back into an object.
  $script_args = "-_installdir $_installdir"
  $update_results = Invoke-CommandAsLocal -ScriptBlock $script_block -ScriptArgs $script_args -KeepLogFile $true
  # only get CommandOutput if it is not null, otherwise grab the ErrorMessage which is set
  # when an exception occurs in the Invoke-CommandAsLocal function's code
  if ($update_results.CommandOutput -ne $null) {
    $result_str = $update_results.CommandOutput -join "`r`n"
  }
  else {
    $result_str = $update_results.ErrorMessage -join "`r`n"
  }

  # if we succeeded, we expect JSON, if there is an error then it might be something else
  if ($update_results.ExitCode -eq 0) {
    # try parsing the output as JSON, if that fails then just return the raw string
    try {
      # ConvertFrom-Json returns a "custom object", not a hashtable so we have to
      # convert it to a hashtable
      $result = ConvertFrom-Json $result_str | Convert-PSObjectToHashtable
    }
    catch {
      $result = $result_str
    }
  }
  else {
    $result = $result_str
  }
  return @{
    'result' = $result;
    'exit_code' = $update_results.ExitCode;
  }
}

################################################################################

function Update-Chocolatey([bool]$choco_required) {
  $updateList = @()
  $exit_code = 0
  # todo put this into a function
  if (-not (Test-CommandExists 'choco')) {
    if ($choco_required) {
      throw "Unable to find required command: choco"
    } else {
      # Write-Error "Unable to find required command: choco"
      # exit 2
      # TODO make a chocolatey required parameter

      # chocolatey wasn't required, simply return an empty result
      return @{
        'result' = @{'upgraded' = @();
                     'installed' = @()};
        'exit_code' = $exit_code;
      }
    }
  }

  # Upgrade all chocolatey packages
  # TODO support only updating specific packages
  $output = iex "& choco upgrade all --yes --limit-output --no-progress --ignore-unfound"
  $exit_code = $LastExitCode
  if ($exit_code -eq 0) {
    # Write-Host "chocolatey output: $output"
    # Write-Host "chocolatey exit code: $exit_code"
    # TODO write output to log file
    # TODO on failure, capture output
    # TODO handle unfound packages more gracefully
    
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
      'result' = @{'upgraded' = @($package_success);
                   'installed' = @()};
      'exit_code' = $exit_code;
    }
  }
  else {
    return @{
      'result' = $output;
      'exit_code' = $exit_code;
    }
  }
}

################################################################################

if ($provider -eq '') {
  $provider = 'all'
}

if ($provider -eq 'windows') {
  $data = Update-Windows -_installdir $_installdir
  $result = $data['result']
  $exit_code = $data['exit_code']
} elseif ($provider -eq 'chocolatey') {
  $data = Update-Chocolatey $True
  $result = $data['result']
  $exit_code = $data['exit_code']
} elseif ($provider -eq 'all') {
  $result = @{'upgraded' = @();
              'installed' = @();}
  $exit_code = 0

  # Windows Update
  $data_windows = Update-Windows -_installdir $_installdir
  $result_windows = $data_windows['result']
  $exit_code_windows = $data_windows['exit_code']
  if ($exit_code_windows -eq 0) {
    $result['upgraded'] += @($result_windows['upgraded'])
    $result['installed'] += @($result_windows['installed'])
  }
  else {
    $result['error_windows'] = $result_windows
    $exit_code = $exit_code_windows
  }

  # Chocolatey upgrade
  $data_chocolatey = Update-Chocolatey $False
  $result_chocolatey = $data_chocolatey['result']
  $exit_code_chocolatey = $data_chocolatey['exit_code']
  if ($exit_code_chocolatey -eq 0) {
    $result['upgraded'] += @($result_chocolatey['upgraded'])
    $result['installed'] += @($result_chocolatey['installed'])
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
