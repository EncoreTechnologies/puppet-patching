# This function allows the user to execute a command as if it is running on
# the local machine as the local system user. This is important because microsoft
# blocks access to some commands from remote access.
# Usage:
# Output from the script and the exit code  is captured and returned
# to the user as an object.
# Input: ScriptBlock to be run in the script file
# SciptBlocks are created by putting a command or series of commands in {}
# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_script_blocks?view=powershell-6
# EX:
#  $script_block = {New-Item -Path C:\ -Name "testfile1.txt" -ItemType "file" -Value "This is a text string."}
#  $test = Invoke-CommandAsLocal -ScriptBlock $script_block
#  $test.CommandOutput
#  $test.ExitCode
function Invoke-CommandAsLocal ([parameter(Mandatory=$true)]
                                [ValidateNotNullOrEmpty()]$ScriptBlock,
                                [String]$ScriptArgs = '',
                                [String]$ExecutionTimeLimit = "PT3H",
                                [Boolean]$KeepLogFile = $false,
                                [String]$_installdir = '')
{
  # Build new object to return to user
  $return_object = New-Object -TypeName psobject

  # We are formating the time stamp this way because
  # Get-Date -Format "o" which is the ISO format for windows
  # returns: 2019-03-27T15:50:10.9461924-04:00 which windows
  # will not allow in file names
  $time_stamp = Get-Date -Format "yyyyMMddThhmmss"
  $task_name = "bolt_task_$($time_stamp)"

  # Write script to file and create log file
  $script_file_name = Join-Path ([System.IO.Path]::GetTempPath()) "bolt_script_$($time_stamp).ps1"
  $log_file_name = Join-Path ([System.IO.Path]::GetTempPath()) "bolt_logfile_$($time_stamp).log"
  
  Try {
    New-Item -Path $log_file_name -ItemType "file" | Out-Null
    New-Item -Path $script_file_name -ItemType "file" -Value $ScriptBlock | Out-Null

    # We have to create the Scheduled task this way because Windows Server 2008 R2 does not have
    # access to the New-ScheduledTask cmdlets.
    $scheduler_service = New-Object -ComObject "Schedule.Service"
    $scheduler_service.Connect()
    $new_task = $scheduler_service.NewTask($null)
    $new_task.XmlText = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<RegistrationInfo />
<Principals>
  <Principal id="Author">
    <UserId>NT AUTHORITY\SYSTEM</UserId>
    <RunLevel>HighestAvailable</RunLevel>
  </Principal>
</Principals>
<Settings>
  <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
  <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
  <ExecutionTimeLimit>$ExecutionTimeLimit</ExecutionTimeLimit>
  <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
  <Priority>5</Priority>
  <AllowHardTerminate>true</AllowHardTerminate>
  <StartWhenAvailable>false</StartWhenAvailable>
  <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
  <AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled>
  <Hidden>false</Hidden>
  <RunOnlyIfIdle>false</RunOnlyIfIdle>
  <WakeToRun>false</WakeToRun>
  <IdleSettings>
    <StopOnIdleEnd>false</StopOnIdleEnd>
    <RestartOnIdle>false</RestartOnIdle>
  </IdleSettings>
  <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
</Settings>
<Triggers />
<Actions Context="Author">
  <Exec>
    <Command>C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe</Command>
    <Arguments>-Command &amp;{ $script_file_name $ScriptArgs *> $log_file_name }; exit `$LASTEXITCODE</Arguments>
  </Exec>
</Actions>
</Task>
"@
    $schduled_tasks_root = $scheduler_service.GetFolder("\")
    # https://docs.microsoft.com/en-us/windows/desktop/taskschd/taskfolder-registertaskdefinition
    # Parameters Positions [0]name [1]task definition [2]task creation flag [3]userid [4]password [5]logon type [6]security descriptor
    # [2]task creation flag - 6: TASK_CREATE_OR_UPDATE
    # [5]logon type - 0: TASK_LOGON_NONE
    $task = $schduled_tasks_root.RegisterTaskDefinition($task_name, $new_task, 6, $null, $null, 0, $null)

    # https://docs.microsoft.com/en-us/windows/desktop/taskschd/registeredtask-state
    # Task States:
    # 0 - TASK_STATE_UNKNOWN
    # 1 - TASK_STATE_DISABLED
    # 2 - TASK_STATE_QUEUED
    # 3 - TASK_STATE_READY
    # 4 - TASK_STATE_RUNNING
    # We need to wait for the task to be in a "Ready" state before we
    # run the task and wait for it to finish being in a
    # "Running" State. If we do not do this then we create a race
    # condition where the task is not in a ready state so it cannot be ran
    while ($task.State -ne 3) {
      Start-Sleep -s 1
    }

    # Start task
    $task.Run($null) | Out-Null

    # Wait for task to finish
    while (($task.State -eq 4) -or ($task.State -eq 2)) {
      Start-Sleep -s 1
    }

    # Get the task exit code and any logging information
    $output = Get-Content $log_file_name
    $exit_code = $task.LastTaskResult

    $return_object | Add-Member -MemberType NoteProperty -Name CommandOutput -Value $output
    $return_object | Add-Member -MemberType NoteProperty -Name ErrorMessage -Value $null
    $return_object | Add-Member -MemberType NoteProperty -Name ExitCode -Value $exit_code
  }
  Catch {
    $ErrorMessage = $_.Exception.Message
    $return_object | Add-Member -MemberType NoteProperty -Name CommandOutput -Value $null
    $return_object | Add-Member -MemberType NoteProperty -Name ErrorMessage -Value $ErrorMessage
    $return_object | Add-Member -MemberType NoteProperty -Name ExitCode -Value 1
  }
  Finally {
    # Clean up all items created for this function
    # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/nf-taskschd-itaskfolder-deletetask
    # Parameters Positions [0]task name [1]additional flags
    $schduled_tasks_root.DeleteTask($task_name, $null) | Out-Null
    if ($KeepLogFile)  {
      $return_object | Add-Member -MemberType NoteProperty -Name LogFile -Value $log_file_name
    }
    else {
      Remove-Item -Path $log_file_name -Force | Out-Null
    }
    Remove-Item -Path $script_file_name -Force | Out-Null
    # Close Schedule Service connection
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($scheduler_service) | Out-Null
  }

  return $return_object
}


# Tests if a command (cli or cmdlet) exists or not
# if it exists, returns true, otherwise false
function Test-CommandExists([String]$command) {
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = 'stop'
  try {
    Get-Command $command
    return $True
  } catch {
    return $False
  }
  Finally {
    $ErrorActionPreference=$oldPreference
  }
}

################################################################################

# inspired by 
# https://stackoverflow.com/questions/22002748/hashtables-from-convertfrom-json-have-different-type-from-powershells-built-in-h
function Convert-PSObjectToHashtable ([Parameter(ValueFromPipeline)]
                                      $InputObject)
{
  process
  {
    if ($null -eq $InputObject) {
      return $null
    }

    if ($InputObject -is [System.Collections.IList]) {
      $array = @()
      foreach ($object in $InputObject) {
        if ($object -is [System.Collections.IList]) {
          $array += @(Convert-PSObjectToHashtable @($object))
        } else {
          $array += (Convert-PSObjectToHashtable $object)
        }
      }
      return @($array)
    } elseif ($InputObject -is [System.Collections.IDictionary]) {
      $hash = @{}
      foreach ($key in $InputObject.Keys) {
        if ($InputObject[$key]-is [System.Collections.IList]) {
          $hash[$key] = @(Convert-PSObjectToHashtable @($InputObject[$key]))
        } else {
          $hash[$key] = Convert-PSObjectToHashtable $InputObject[$key]
        }
      }
      return $hash
    } elseif ($InputObject -is [psobject]) {
      $hash = @{}
      foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.Value -is [System.Collections.IList]) {
          $hash[$property.Name] = @(Convert-PSObjectToHashtable @($property.Value))
        } else {
          $hash[$property.Name] = Convert-PSObjectToHashtable $property.Value
        }
      }
      return $hash
    } else {
      return $InputObject
    }
  }
}

################################################################################

function Create-DirectoryIfNotExists(
  [string]$Path
) {
  if (Test-Path -Path $Path) {
    # path already exists
  } else {
    New-Item -ItemType Directory -Path $Path
  }
}

function Create-FileIfNotExists(
  [string]$Path
) {
  if ([System.IO.Path]::GetExtension($Path)) {
    $dir = [System.IO.Path]::GetDirectoryName($Path)
    Create-DirectoryIfNotExists -Path $Dir
    if (Test-Path -Path $Path) {
      # path already exists
    } else {
      New-Item -ItemType File -Path $Path
    }
  } else {
    Create-DirectoryIfNotExists -Path $Path
  }
}

################################################################################

function Log-Timestamp(
  [string]$Path,
  [string]$Value
) {
  Add-Content -Path $Path -Value "[$(Get-Date -Format 'o')] $Value"
}

################################################################################

# Creates a new Windows Update API session
# https://docs.microsoft.com/en-us/windows/win32/api/wuapi/nn-wuapi-iupdatesession
function Create-WindowsUpdateSession {
  $session = New-Object -ComObject 'Microsoft.Update.Session'
  $session.ClientApplicationID = 'windows-update-installer'
  return $session
}

# Searches Windows Update API for all available updates and returns them in a list
# This performs a search across all possible Server Selection options. 
# This returns a list of IUpdateResults, the caller is responsible for 
# interpreting those results.
function Search-WindowsUpdateResults (
  $session,
  [String]$criteria ='IsInstalled=0'
) {
  # criteria above, searches for updates that aren't installed yet 
  # https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatesearcher-search
  $updateSearcher = $session.CreateUpdateSearcher()
  
  # https://docs.microsoft.com/en-us/windows/win32/api/wuapicommon/ne-wuapicommon-serverselection
  #
  # typedef enum tagServerSelection {
  #   ssDefault,       # 0
  #   ssManagedServer, # 1
  #   ssWindowsUpdate, # 2
  #   ssOthers         # 3
  # } ServerSelection;
  #
  # search all servers
  $serverSelectionList = @(0, 1, 2)
  $resultHash = @{}
  foreach ($serverSelection in $serverSelectionList) {
    # try/catch is used because sometimes certain servers fail to get updates and it throws
    # this way we can get updates from all available servers without causing the whole script
    # to fail
    try {
      $updateSearcher.ServerSelection = $serverSelection
      $searchResult = $updateSearcher.Search($criteria)

      # interpret the result code and have us exit with an error if the search errored
      # https://docs.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-operationresultcode
      switch ($searchResult.ResultCode)
      {
        0 { # not started
          break
        }
        1 { # in progress
          break
        }
        2 { # succeeded
          break
        }
        3 {
          throw "Search result for server selection $serverSelection succeeded with errors"
          break
        }
        4 {
          throw "Search result for server selection $serverSelection failed!"
          break
        }
        5 {
          throw "Search result for server selection $serverSelection aborted!"
          break
        }
        default {  
          throw "Search result for server selection $serverSelection is unknown: $($searchResult.ResultCode)"
          break
        }
      }
      
      $value = @{ 'result' = $searchResult; }
      switch ($serverSelection)
      {
        0 { $value['name'] = 'Default'; break }
        1 { $value['name'] = 'ManagedServer'; break }
        2 { $value['name'] = 'WindowsUpdate'; break }
        default { $value['name'] = 'Other'; break }
      }
      $resultHash[$serverSelection] = $value
    } catch {
      # error occurred with this particular server selection
    }
  }
  return $resultHash
}

# Searches Windows Update API for all available updates and returns them in a list
# This performs a search across all possible Server Selection options. 
# This returns a de-duplicated list of IUpdate objects found across all update servers.
function Search-WindowsUpdate (
  $session,
  [String]$criteria ='IsInstalled=0'
) {
  $updateList = @()
  $updatesById = @{}
  $searchResultHash = Search-WindowsUpdateResults -session $session -criteria $criteria
  foreach ($serverSelection in ($searchResultHash.keys | Sort-Object)) {
    $value = $searchResultHash[$serverSelection]
    $searchResult = $value['result']
    foreach ($update in $searchResult.Updates) {
      $updateId = $update.Identity.UpdateID
      
      # keep a list of de-duplicated updates, based on update ID
      # we need to do this since we're searching multiple servers and the same
      # update may be available from >1 source
      if ($updatesById.ContainsKey($updateId)) {
        continue;
      }
      $updatesById[$updateId] = $update
      $updateList += @{'update' = $update;
                       'server_selection' = $serverSelection}
    }
  }
  return @($updateList)
}

