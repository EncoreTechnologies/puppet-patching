[CmdletBinding()]
Param(
  # Mandatory is set to false. If Set to $True then a dialog box appears to get the missing information
  # We will do a variable check later
  # https://blogs.technet.microsoft.com/heyscriptingguy/2011/05/22/use-powershell-to-make-mandatory-parameters/
  [Parameter(Mandatory = $False)]
  [String]$_installdir
)

Import-Module "$_installdir\patching\files\powershell\TaskUtils.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script_block = {
  
  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  
  function Test-PendingReboot
  {
    $systemInformation = New-Object -ComObject 'Microsoft.Update.SystemInfo'
    if ($systemInformation.RebootRequired) {
      return $true
    }

    # https://ilovepowershell.com/2015/09/10/how-to-check-if-a-server-needs-a-reboot/
    # Adapted from https://gist.github.com/altrive/5329377
    # Based on <http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542>
    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
    try { 
      $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
      $status = $util.DetermineIfRebootPending()
      if(($status -ne $null) -and $status.RebootPending){
        return $true
      }
    } catch {}
  
    return $false
  }

  if (Test-PendingReboot) {
    exit 1
  }
  exit 0
}

$reboot_needed = Invoke-CommandAsLocal -ScriptBlock $script_block

# Passing back the whole $reboot_needed.CommandOutput results in extra data in the bolt return
# So using exit code to get the neccessary code we need
$return_value = @{"reboot_required" = $false}
if ($reboot_needed.ExitCode -eq 1) {
  $return_value.reboot_required = $true
}

$return_value | ConvertTo-Json
exit 0
