$appstoRemove = @("OutlookforWindows", "BingSearch", "QuickAssist", "MSTeams", "Edge.GameAssist", "Onedrive")

foreach ($app in $appstoremove) {
	try {
		Get-AppxPackage -AllUsers -Name "*$app*" | Remove-AppxPackage 
	    }
	Catch { Write-Warning "Script execution failed : $($_.Exception.Message)" }
}
