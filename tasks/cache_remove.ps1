# Stop the Windows Update service
Stop-Service -Name wuauserv 

# Remove the downloaded updates
Remove-Item $env:systemroot\SoftwareDistribution\Download -force -Confirm:$false -Recurse  -ErrorAction SilentlyContinue 

# Start the Windows Update service
Start-Service -Name wuauserv 
exit 0
