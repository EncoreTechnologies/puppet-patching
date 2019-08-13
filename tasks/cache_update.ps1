# Restart the Windows Update service
Restart-Service -Name wuauserv 

# perform a new search for Windows Updates, this forces a refresh
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

# interpret the result code and have us exit with an error if any of the patches error
$result = @{"result" = ""}
switch ($searchResult.ResultCode)
{
  0 { $result["result"] = "Not Started" }
  1 { $result["result"] = "In Progress" }
  2 { $result["result"] = "Succeeded" }
  3 { $result["result"] = "Succeeded With Errors" }
  4 {
    $result["result"] = "Failed"
    $exitStatus = 2
  }
  5 {
    $result["result"] = "Aborted"
    $exitStatus = 2
  }
  default { $result["result"] = "Unknown" }
}

ConvertTo-Json -Depth 100 $result
exit $exitStatus
