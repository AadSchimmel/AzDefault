$installAD = Get-WindowsFeature -name AD-Domain-Services
while ($installAD.'InstallState' -ne 'Installed'){ 
    try {
        Write-Host "Installing ADDS." -ForegroundColor Yellow
        Install-WindowsFeature -name AD-Domain-Services -IncludeManagementTools
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host $ErrorMessage
    }
}
Write-Host "Installed ADDS." -ForegroundColor Yellow

$CheckAD = Get-ADDomain
Write-Host "Installing ADDS Forest..." -ForegroundColor Yellow
while (!$CheckAD) {
    try {
        Write-Host "Configuring ADDS Forest." -ForegroundColor Yellow
        Install-ADDSForest @Params
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host $ErrorMessage
        #($CheckADVM.Statuses[1].DisplayStatus -eq 'Running')
    }
}
Write-Host "Finished configuring ADDS Forest." -ForegroundColor Green
