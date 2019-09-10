Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Procedure for resetting WSUS documented here:
# https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-resources
# https://gallery.technet.microsoft.com/scriptcenter/Reset-WindowsUpdateps1-e0c5eb78

# Stop the Windows Update service
Write-Host "Stopping service... bits"
Stop-Service -Name bits
Write-Host "Stopping service... wuauserv"
Stop-Service -Name wuauserv

# Remove the downloaded updates
Write-Host "Removing downloaded updates... $env:systemroot\SoftwareDistribution\Download"
Remove-Item "$env:systemroot\SoftwareDistribution\Download" -force -Confirm:$false -Recurse  -ErrorAction SilentlyContinue
Write-Host "Removing downloaded updates... $env:allusersprofile\Application Data\Microsoft\Network\Downloader\qmgr*.dat"
Remove-Item "$env:allusersprofile\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -force -Confirm:$false -ErrorAction SilentlyContinue 

# Re-register all WSUS DLLs
Write-Host "Re-registering WSUS DLLs"
Set-Location $env:systemroot\system32 
regsvr32.exe /s atl.dll 
regsvr32.exe /s urlmon.dll 
regsvr32.exe /s mshtml.dll 
regsvr32.exe /s shdocvw.dll 
regsvr32.exe /s browseui.dll 
regsvr32.exe /s jscript.dll 
regsvr32.exe /s vbscript.dll 
regsvr32.exe /s scrrun.dll 
regsvr32.exe /s msxml.dll 
regsvr32.exe /s msxml3.dll 
regsvr32.exe /s msxml6.dll 
regsvr32.exe /s actxprxy.dll 
regsvr32.exe /s softpub.dll 
regsvr32.exe /s wintrust.dll 
regsvr32.exe /s dssenh.dll 
regsvr32.exe /s rsaenh.dll 
regsvr32.exe /s gpkcsp.dll 
regsvr32.exe /s sccbase.dll 
regsvr32.exe /s slbcsp.dll 
regsvr32.exe /s cryptdlg.dll 
regsvr32.exe /s oleaut32.dll 
regsvr32.exe /s ole32.dll 
regsvr32.exe /s shell32.dll 
regsvr32.exe /s initpki.dll 
regsvr32.exe /s wuapi.dll 
regsvr32.exe /s wuaueng.dll 
regsvr32.exe /s wuaueng1.dll 
regsvr32.exe /s wucltui.dll 
regsvr32.exe /s wups.dll 
regsvr32.exe /s wups2.dll 
regsvr32.exe /s wuweb.dll 
regsvr32.exe /s qmgr.dll 
regsvr32.exe /s qmgrprxy.dll 
regsvr32.exe /s wucltux.dll 
regsvr32.exe /s muweb.dll 
regsvr32.exe /s wuwebv.dll 

# Start the Windows Update service
Write-Host "Starting service... bits"
Start-Service -Name bits
Write-Host "Starting service... wuauserv"
Start-Service -Name wuauserv

# Force WSUS discovery
Write-Host "Forcing WSUS re-auth and discovery..."
wuauclt /resetauthorization /detectnow

exit 0
