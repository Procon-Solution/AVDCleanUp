$appstoRemove = @("OutlookforWindows", "BingSearch", "QuickAssist", "MSTeams", "Edge.GameAssist", "Onedrive")

foreach ($app in $appstoremove) {
	try {
		Get-AppxPackage -All -Name "*$app*" | Remove-AppxPackage -AllUsers
	    }
	Catch { Write-Warning "Script execution failed : $($_.Exception.Message)" }
}
