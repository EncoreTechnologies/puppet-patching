[CmdletBinding()]
Param(
  # Mandatory is set to false. If Set to $True then a dialog box appears to get the missing information
  # We will do a variable check later
  # https://blogs.technet.microsoft.com/heyscriptingguy/2011/05/22/use-powershell-to-make-mandatory-           parameters/
  [Parameter(Mandatory = $False)]
  [String]$_installdir,
  [Boolean]$_noop = $false
)

# TODO 
# - WUA: run wuactl?
# - Chocolatey: ?


# if ($_noop) {
#   Write-Output '{"message": "noop - cache was not updated"}'
#   exit 0
# }

# Import-Module "$_installdir\patching\files\powershell\TaskUtils.ps1"

# Set-StrictMode -Version Latest
# $ErrorActionPreference = 'Stop'
# $ProgressPreference = 'SilentlyContinue'

# # Restart the Windows Update service
# Restart-Service -Name wuauserv 

# $exitStatus = 0

# # search all windows update servers
# $cacheResultHash = @{"servers" = @()}
# $updateSession = Create-WindowsUpdateSession
# $searchResultHash = Search-WindowsUpdateResults -session $updateSession
# foreach ($serverSelection in ($searchResultHash.keys | Sort-Object)) {
#   $value = $searchResultHash[$serverSelection]
#   $searchResult = $value['result']
  
#   # interpret the result code and have us exit with an error if any of the patches error
#   $result = @{
#     'name' = $value['name'];
#     'server_selection' = $serverSelection;
#     'result_code' = $searchResult.ResultCode;
#   }
#   switch ($searchResult.ResultCode)
#   {
#     0 { $result['result'] = 'Not Started'; break }
#     1 { $result['result'] = 'In Progress'; break }
#     2 { $result['result'] = 'Succeeded'; break }
#     3 { $result['result'] = 'Succeeded With Errors'; break }
#     4 {
#       $result['result'] = 'Failed'
#       $exitStatus = 2
#       break
#     }
#     5 {
#       $result['result'] = 'Aborted'
#       $exitStatus = 2
#       break
#     }
#     default { $result['result'] = 'Unknown'; break }
#   }
  
#   $cacheResultHash['servers'] += $result
# }

# ConvertTo-Json -Depth 100 $cacheResultHash
# exit $exitStatus

exit 0
