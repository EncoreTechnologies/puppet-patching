[CmdletBinding()]
Param(
  # Mandatory is set to false. If Set to $True then a dialog box appears to get the missing information
  # We will do a variable check later
  # https://blogs.technet.microsoft.com/heyscriptingguy/2011/05/22/use-powershell-to-make-mandatory-           parameters/
  [Parameter(Mandatory = $False)]
  [String]$names,
  [String]$result_file,
  [String]$log_file,
  [String]$provider,
  [String]$_installdir
)

Import-Module "$_installdir\patching\files\powershell\TaskUtils.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Update-Windows(
  [String]$log_file,
  [String]$_installdir
) {
  Log-Timestamp -Path $log_file -Value "========================================="
  Log-Timestamp -Path $log_file -Value "= Starting Update-Windows"

  $script_block = {
    param (
      [string]$log_file,
      [string]$_installdir = 'Nothing passed in'
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    Import-Module "$_installdir\patching\files\powershell\TaskUtils.ps1"

    $exitStatus = 0
    $package_failures = @()
    try {
      Log-Timestamp -Path $log_file -Value "========================================="
      Log-Timestamp -Path $log_file -Value "= Starting Update-Windows in scheduled task"
      $windowsOsVersion = [System.Environment]::OSVersion.Version
      $updateSession = Create-WindowsUpdateSession
      Log-Timestamp -Path $log_file -Value "Starting search for updates..."
      # search for and deduped updates between server selections
      $allUpdatesList = Search-WindowsUpdate -session $updateSession
      Log-Timestamp -Path $log_file -Value "Finished search for updates..."
      
      # organize updates by serverSelection
      # we do this so we can patch each serverSelection, in bulk, one server at a time
      $serverUpdatesHash = @{}
      foreach ($updateAndServer in $allUpdatesList) {
        $serverSelection = $updateAndServer['server_selection']
        $update = $updateAndServer['update']
        if ($serverUpdatesHash.ContainsKey($serverSelection)) {
          $serverUpdatesHash[$serverSelection] += $update
        } else {
          $serverUpdatesHash[$serverSelection] = @($update)
        }
      }
      
      $patchingResultList = @()

      # Iterate over each serverSelection independently
      # if we try to batch the downloads + installs for multiple server selections
      # into one udpate set, then we get random errors like:
      # Exception calling "Download" with "0" argument(s)
      # Exception calling "Install" with "0" argument(s)
      #
      # Instead perform bulk updates on a serverSelection level.
      foreach ($serverSelection in ($serverUpdatesHash.keys | Sort-Object)) {
        Log-Timestamp -Path $log_file -Value "==============="
        Log-Timestamp -Path $log_file -Value "= Starting server selection: $serverSelection"
        $updatesList = $serverUpdatesHash[$serverSelection]
        Log-Timestamp -Path $log_file -Value "Number of updates returned from search: $($updatesList.Count)"
        
        $updatesToDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl'
        $updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'
        $serverPatchingResultList = @()
        
        # for each update, accept the EULA, add it to our list to download
        foreach ($update in $updatesList) {
          $updateId = $update.Identity.UpdateID
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
          $serverPatchingResultList += @{
            'name' = $update.Title;
            'id' = $updateId;
            'version' = $update.Identity.RevisionNumber;
            'kb_ids' = $kbIds;
            'server_selection' = $serverSelection;
            'provider' = 'windows';
          }
        }

        Log-Timestamp -Path $log_file -Value "Number of updates to install: $($updatesToInstall.Count)"
        Log-Timestamp -Path $log_file -Value "Number of updates to download: $($updatesToDownload.Count)"
        $updatesJson = ConvertTo-Json -Depth 100 @($serverPatchingResultList)
        Log-Timestamp -Path $log_file -Value "Updates to be installed: $updatesJson"

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
          Log-Timestamp -Path $log_file -Value "Starting to download updates..."
          $downloadResult = $updateDownloader.Download()
          Log-Timestamp -Path $log_file -Value "Finished downloading updates..."
        }

        if ($updatesToInstall.Count) {
          $updateInstaller = $updateSession.CreateUpdateInstaller()
          $updateInstaller.Updates = $updatesToInstall
          Log-Timestamp -Path $log_file -Value "Starting update installs..."
          $installationResult = $updateInstaller.Install()
          Log-Timestamp -Path $log_file -Value "Finished update installs..."
          Log-Timestamp -Path $log_file -Value "Parsing update results..."

          # Windows update interface doesn't just return us usable statuses
          # or even an array of results... we have to ask the result object for indexes
          # to determine the results of each patch based on the index in our input array... sorry
          for ($i = 0; $i -lt $updatesToInstall.Count; ++$i) {
            $update = $updatesToInstall.Item($i) # need to use .Item() here because it's a special type
            $patchingResult = $serverPatchingResultList[$i]
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
                $patchingResult["result"] = "failed"
                $exitStatus = 2
                $package_failures += @{
                  'name' = $update.Title;
                  'error' = "Installation failed";
                  'provider' = 'windows'
                }
                break
              }
              5 {
                $patchingResult["result"] = "aborted"
                $exitStatus = 2
                $package_failures += @{
                  'name' = $update.Title;
                  'error' = "Installation aborted";
                  'provider' = 'windows'
                }
                break
              }
              default { $patchingResult["result"] = "unknown"; break }
            }
          }
        }
        # add this server's results to the master list
        $patchingResultList += @($serverPatchingResultList)
        Log-Timestamp -Path $log_file -Value "= Finished server selection: $serverSelection"
        Log-Timestamp -Path $log_file -Value "==============="
      }
      # Because this thing is running inside of a ScheduledTask and all of the output
      # is written to a log file and then returned back to us as a string, we need a way
      # to pass structured data from this script block, back to the caller of Invoke-CommandAsLocal
      # to do this structured data passing we serialize the data to JSON and then parse it below
      ConvertTo-Json -Depth 100 @{'upgraded' = @($patchingResultList);
                                  'installed' = @();
                                  'exit_code' = $exitStatus;
                                  'failures' = $package_failures;
                                 }
      exit $exitStatus
    }
    Catch {
      $exception_str = $_ | Out-String
      Log-Timestamp -Path $log_file -Value "********** ERROR in scheduled task ************"
      Log-Timestamp -Path $log_file -Value $exception_str
      ConvertTo-Json -Depth 100 @{'exception' = $exception_str;
                                  'exit_code' = 99;
                                  'failures' = $package_failures;
                                 }
      exit 99
    }
  }

  # The script block above returns the command output as JSON, however PowerShell returns
  # the output as an array of lines, so we need to concat these strings into one big blob
  # so we can parse the JSON back into an object.
  $script_args = "-_installdir $_installdir -log_file $log_file"
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
  # try parsing the error as JSON, if that fails then just return the raw string
  try {
    # ConvertFrom-Json returns a "custom object", not a hashtable so we have to
    # convert it to a hashtable
    $result = ConvertFrom-Json $result_str | Convert-PSObjectToHashtable
    # FYI $update_results.ExitCode isn't 100% reliable we've found, so we
    # pass back JSON with an 'exit_code' property just to be save.
    # we haven't seen issues since some recent changes, but still... ugh
    $exit_code = $result['exit_code']
  }
  catch {
    $result = $result_str
    # if the scheduled task's exit code was actually bad, return the bad details
    if ($update_results.ExitCode -ne 0) {
      $exit_code = $update_results.ExitCode
    }
    else {
      # JSON parsing failed, something went wrong, we're setting an arbitrary bad exit code
      $exit_code = 33
    }
  }
  
  Log-Timestamp -Path $log_file -Value "= Finishing Update-Windows"
  Log-Timestamp -Path $log_file -Value "========================================="
  return @{
    'result' = $result;
    'exit_code' = $exit_code
  }
}

################################################################################

function Update-Chocolatey(
  [string]$log_file,
  [bool]$choco_required
) {
  Log-Timestamp -Path $log_file -Value "========================================="
  Log-Timestamp -Path $log_file -Value "= Starting Update-Chocolatey"
  $exit_code = 0
  # todo put this into a function
  Log-Timestamp -Path $log_file -Value "Searching for choco command"
  if (-not (Test-CommandExists 'choco')) {
    if ($choco_required) {
      Log-Timestamp -Path $log_file -Value "Unable to find choco command, and it IS required erroring!!!"
      throw "Unable to find required command: choco"
    } else {
      # Write-Error "Unable to find required command: choco"
      # exit 2
      # TODO make a chocolatey required parameter

      # chocolatey wasn't required, simply return an empty result
      Log-Timestamp -Path $log_file -Value "Unable to find choco command, but it isn't required, ignorning"
      Log-Timestamp -Path $log_file -Value "= Finishing Update-Chocolatey"
      Log-Timestamp -Path $log_file -Value "========================================="
      return @{
        'result' = @{'upgraded' = @();
                     'installed' = @()};
        'exit_code' = $exit_code;
      }
    }
  } else {
    Log-Timestamp -Path $log_file -Value "choco command exists!"
  }

  # Upgrade all chocolatey packages
  # TODO support only updating specific packages
  Log-Timestamp -Path $log_file -Value "Executing: choco upgrade all --yes --limit-output --no-progress --ignore-unfound"
  $output = iex "& choco upgrade all --yes --limit-output --no-progress --ignore-unfound"
  $exit_code = $LastExitCode
  Log-Timestamp -Path $log_file -Value "Finished: choco ugprade ...  exit_code = $exit_code"
  Log-Timestamp -Path $log_file -Value ($output -join "`r`n")
  if ($exit_code -eq 0) {
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
  
              $package_versions[$name] = @{
                  'name' = $name
                  'version' = $version_new
                  'version_old' = $version_old
                  'pinned' = $pinned
                  'provider' = 'chocolatey'
              }
          }
          if ($line -match " The upgrade of (.*) was successful\.") {
              $name = $Matches.1
              if ($package_versions.ContainsKey($name)) {
                  $package_success += $package_versions[$name]
              }
          }
      }
  
      Log-Timestamp -Path $log_file -Value "= Finishing Update-Chocolatey"
      Log-Timestamp -Path $log_file -Value "========================================="
      return @{
          'result' = @{
              'upgraded' = @($package_success)
              'installed' = @()
          }
          'exit_code' = $exit_code
      }
  } else {
      # Chocolatey output is in the following format:
      # Upgrading the following packages:
      # all
      # By upgrading you accept licenses for the packages.
      # alert_logic_agent|2.19.0.0|2.19.0.0|false
      # chocolatey|0.10.15|0.10.15|false
      # fluent-package|5.1.0|5.1.0|false
      # prometheus_windows_exporter|0.15.0|0.15.0|false
      # puppet-agent|7.29.1|7.29.1|false
      # sentinelone|24.1.2.188|24.1.2.188|false
      # td-agent|4.0.1|4.0.2|false

      # td-agent v4.0.2
      # td-agent package files upgrade completed. Performing other installation steps.
      # Attempt to use original download file name failed for 'C:\ProgramData\chocolatey\lib\td-agent\tools\tools\td-agent-4.0.1-x64.msi'.
      # Copying td-agent
      #   from 'C:\ProgramData\chocolatey\lib\td-agent\tools\tools\td-agent-4.0.1-x64.msi'
      # Installing td-agent...
      # WARNING: Generic MSI Error. This is a local environment error, not an issue with a package or the MSI itself - it could mean a pending reboot is necessary prior to install or something else (like the same version is already installed). Please see MSI log if available. If not, try again adding '--install-arguments="'/l*v c:\td-agent_msi_install.log'"'. Then search the MSI Log for "Return Value 3" and look above that for the error.
      # ERROR: Running ["C:\Windows\System32\msiexec.exe" /i "C:\Users\alex.chrystal\AppData\Local\Temp\2\chocolatey\td-agent\4.0.2\td-agentInstall.MSI" /qn /norestart /l*v "C:\Users\alex.chrystal\AppData\Local\Temp\2\chocolatey\td-agent.4.0.2.MsiInstall.log" ] was not successful. Exit code was '1603'. Exit code indicates the following: Generic MSI Error. This is a local environment error, not an issue with a package or the MSI itself - it could mean a pending reboot is necessary prior to install or something else (like the same version is already installed). Please see MSI log if available. If not, try again adding '--install-arguments="'/l*v c:\td-agent_msi_install.log'"'. Then search the MSI Log for "Return Value 3" and look above that for the error..
      # The upgrade of td-agent was NOT successful.
      # Error while running 'C:\ProgramData\chocolatey\lib\td-agent\tools\tools\chocolateyinstall.ps1'.
      # See log for details.
      # telegraf|1.18.0|1.18.0|false

      # Chocolatey upgraded 0/8 packages. 1 packages failed.
      # See the log for details (C:\ProgramData\chocolatey\logs\chocolatey.log).

      # Failures
      # - td-agent (exited 1603) - Error while running 'C:\ProgramData\chocolatey\lib\td-agent\tools\tools\chocolateyinstall.ps1'.
      # See log for details.
      $package_failures = @()
      $current_error_message = $null
      for ($i=0; $i -lt $output.Count; $i++) {
        $line = $output[$i]
        # Check for error message line
        if ($line -match "ERROR:\s*(.*)") {
          $current_error_message = $Matches[1]
        }
        # Check for package failure line
        if ($line -match "The upgrade of (.*) was NOT successful\.\s*") {
          $current_package = $Matches[1]
          if ($current_error_message -ne $null) {
            $package_failures += @{
              'name' = $current_package;
              'error' = $current_error_message;
              'provider' = 'chocolatey'
            }
            $current_error_message = $null  # Reset current error message after associating it with the package
          }
        }
      }
      Log-Timestamp -Path $log_file -Value "= Finishing Update-Chocolatey"
      Log-Timestamp -Path $log_file -Value "========================================="
      return @{
        'result' = $package_failures
        'exit_code' = $exit_code
      }
  }
}

################################################################################
try {
  if ($provider -eq '') {
    $provider = 'all'
  }
  if ($log_file -eq '') {
    $log_file = 'C:\ProgramData\patching\log\patching.log'
  }
  if ($result_file -eq '') {
    $result_file = 'C:\ProgramData\patching\log\patching.json'
  }
  # create directories for log files, if they don't exist
  New-Item -ItemType Directory -Force -Path (Split-Path -Path $log_file) | Out-Null
  New-Item -ItemType Directory -Force -Path (Split-Path -Path $result_file) | Out-Null

  Log-Timestamp -Path $log_file -Value "=================================================================================="
  Log-Timestamp -Path $log_file -Value "= Starting Update"
  Log-Timestamp -Path $log_file -Value "provider = $provider"

  if ($provider -eq 'windows') {
    $data = Update-Windows -log_file $log_file -_installdir $_installdir
    $result = $data['result']
    $exit_code = $data['exit_code']
  } elseif ($provider -eq 'chocolatey') {
    $data = Update-Chocolatey -log_file $log_file -choco_required -$True
    $result = $data['result']
    $exit_code = $data['exit_code']
  } elseif ($provider -eq 'all') {
    $result = @{'upgraded' = @();
                'installed' = @();}
    $exit_code = 0

    # Windows Update
    $data_windows = Update-Windows -log_file $log_file -_installdir $_installdir
    $result_windows = $data_windows['result']
    $exit_code_windows = $data_windows['exit_code']
    if ($exit_code_windows -eq 0) {
      $result['upgraded'] += @($result_windows['upgraded'])
      $result['installed'] += @($result_windows['installed'])
    }
    else {
      $result['failed'] = $result_windows
      $exit_code = $exit_code_windows
    }
    Log-Timestamp -Path $log_file -Value "exit_code_windows = $exit_code_windows"

    # Chocolatey upgrade
    $data_chocolatey = Update-Chocolatey -log_file $log_file -choco_required $False
    $result_chocolatey = $data_chocolatey['result']
    $exit_code_chocolatey = $data_chocolatey['exit_code']
    if ($exit_code_chocolatey -eq 0) {
      $result['upgraded'] += @($result_chocolatey['upgraded'])
      $result['installed'] += @($result_chocolatey['installed'])
    }
    else {
      $result['failed'] = $result_chocolatey
      $exit_code = $exit_code_chocolatey
    }
    Log-Timestamp -Path $log_file -Value "exit_code_chocolatey = $exit_code_chocolatey"
  } else {
    Write-Error "Unknown provider! Expected 'windows', 'chocolatey', 'all'. Got: $provider"
    exit 100
  }
  
  Log-Timestamp -Path $log_file -Value "exit_code = $exit_code"

  # convert results to JSON
  $result_json = ConvertTo-Json -Depth 100 $result

  # write results to results file
  Log-Timestamp -Path $log_file -Value "Adding results to results file..."
  Add-Content -Path $result_file -Value $result_json

  # write results to stdout
  Log-Timestamp -Path $log_file -Value "Writing results to stdout"
  Write-Output $result_json

  Log-Timestamp -Path $log_file -Value "= Finished Update"
  Log-Timestamp -Path $log_file -Value "=================================================================================="

  exit $exit_code
} Catch {
  $exception_str = $_ | Out-String
  Log-Timestamp -Path $log_file -Value "********** ERROR in main task ************"
  Log-Timestamp -Path $log_file -Value $exception_str
  ConvertTo-Json -Depth 100 @{ "_error" = @{
                                 "msg" = "Exception occurred.";
                                 "kind" = "puppetlabs.tasks/task-error";
                                 "details" = @{ "exitcode" = 1;
                                                "exception" = $exception_str;
                                              };
                               };
                             };
  exit 1
}
