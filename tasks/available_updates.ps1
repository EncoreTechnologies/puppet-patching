$updateSession = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher = $updateSession.CreateUpdateSearcher()
# https://docs.microsoft.com/en-us/windows/desktop/api/wuapicommon/ne-wuapicommon-tagserverselection
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
  }
  
}
$updateListSorted = $updateList | Sort-Object

$result = @{"updates" = $updateListSorted}
ConvertTo-Json -Depth 100 $result
