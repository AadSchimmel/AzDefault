# run in azDefaultVM.ps1 ?
# Invoke-AzVMRunCommand -ResourceGroupName $RG -Name $VMName -CommandId 'RunPowerShellScript' -ScriptPath 'blobstorage?' -Parameter @{"arg1" = "var1";"arg2" = "var2"}

$CheckADVM = Get-AzVM | Where-Object { $_.Name -like '*AD01' }
$CheckADVM = Get-AzVM -ResourceGroupName $CheckADVM.ResourceGroupName -Name $CheckADVM.Name -Status
Write-Host "Starting $($CheckADVM.Name)..." -ForegroundColor Yellow
if ($CheckADVM.Statuses[1].DisplayStatus -ne 'Running') {
    try {
        Start-AzVM -ResourceGroupName $CheckADVM.ResourceGroupName -Name $CheckADVM.Name
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host $ErrorMessage
        #($CheckADVM.Statuses[1].DisplayStatus -eq 'Running')
    }
}
Write-Host "Started $($CheckADVM.Name)..." -ForegroundColor Green

Invoke-AzVMRunCommand -ResourceGroupName $RG -Name $($CheckADVM.Name) -CommandId 'RunPowerShellScript' -ScriptPath '.\azConfigADDS.ps1'`
    -Parameter $ParamsAD

$ParamObjectAD = @{
    'adminUsername'                 = $adminUsername
    'SafeModeAdministratorPassword' = [string]$adminPassword
    'location'                      = $Location
    'vmName'                        = $VMName
    'ResourceGroup'                 = $RG
    'DatabasePath'                  = 'C:\Windows\NTDS'
    'DomainMode'                    = 'WinThreshold'
    'DomainName'                    = $DomainName + ".local"
    'DomainNetbiosName'             = $DomainName
    'InstallDns'                    = $true
    'LogPath'                       = 'C:\Windows\NTDS'
    'NoRebootOnCompletion'          = $true
    'SysvolPath'                    = 'C:\Windows\SYSVOL'
    'Force'                         = $true
}
    
$ParamsAD = @{
    'Name'                    = 'LimeDefaultADDeployment' + (Get-Random)
    'ResourceGroupName'       = $RG
    'TemplateFile'            = '.\azVirtualMachine.json'
    'TemplateParameterObject' = $ParamObjectAD
    'Verbose'                 = $true
}