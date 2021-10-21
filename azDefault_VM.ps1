$LogFile = "azDefault_Log_" + $(Get-Date).ToString('MMdd-hhmmss') + ".txt"
Start-Transcript -Path $LogFile
$Location = "westeurope"
$CustomerName = "SKYR" # probeer kort te houden
$RG_prefixes = "RG-PRD-", "RG-NETWORK-" #, "RG-AVD-", "RG-SIG-"
$VMNames = "AD01" #,"SQL01","APP01"
$VirtualNetworks = (Get-Content .\azNetworks.json | ConvertFrom-Json).VirtualNetworks
$ResourceGroups = foreach ($RG_prefix in $RG_prefixes) { $RG_prefix + $CustomerName }

Write-Host "Enter credentials in popup window." -ForegroundColor Yellow
Connect-AzAccount

Write-Host "Select the subscription in popup window." -ForegroundColor Yellow
$Subscription = Get-AzSubscription | Out-GridView -Title "Select Azure Subscription" -PassThru
Select-AzSubscription $Subscription.SubscriptionId
Write-Host "Checking Azure Subscription permissions..." -ForegroundColor Yellow
$CheckRoleAssignment = Get-AzRoleAssignment -Scope /subscriptions/$($Subscription.SubscriptionId) | Where-Object {$_.DisplayName -eq 'AdminAgents'}
if ($CheckRoleAssignment.RoleDefinitionName -ne "Owner" -and $CheckRoleAssignment.RoleDefinitionName -ne "Contributor") {
     Write-Host "You don't have Owner or Contributor rights on $($Subscription.Name) ($($Subscription.SubscriptionId))." -ForegroundColor Red
     exit
    } else {
     Write-Host "Permissions OK on $($Subscription.Name) ($($Subscription.SubscriptionId)), continuing..." -ForegroundColor Green
    }

    Write-Host "Choose a VM size." -ForegroundColor Yellow
    $VMSize = Get-AzVMSize -Location $Location | Out-GridView -PassThru
    Write-Host "Choose a OS version." -ForegroundColor Yellow
    $OSVersion = Get-AzVMImageSku -Location $Location -PublisherName MicrosoftWindowsServer -Offer WindowsServer | Out-GridView -PassThru
    $adminUsername = Read-Host -Prompt "Enter the local administrator username" 
    $adminPassword = Read-Host -Prompt "Enter the local administrator password (min. 12 characters)" -AsSecureString

foreach ($RG in $ResourceGroups) {
   Write-Host "Checking for Resource Group: $($RG)" -ForegroundColor Yellow
   if (!(Get-AzResourceGroup -Name $RG -ErrorAction SilentlyContinue)){ 
       Write-Host "Creating new Resource Group: $($RG)" -ForegroundColor Green
       #New-AzResourceGroup -Name $RG -Location $Location 
   } else { 
       Write-Host "Resource Group $($RG) already exists, continuing..." -ForegroundColor Yellow
   }

    $NSGName = $RG.trim("RG-") + "-NSG"
    $vNETName = $RG.trim("RG-") + "-vNET"
    $subNETName = $RG.trim("RG-") + "-subNET"
    $Subnet = $VirtualNetworks | Where-Object -Property Purpose -like "$($NSGName[0..2] -join '')*" 

    if ($RG -eq "RG-PRD-" + $($CustomerName)) {
        foreach ($VMName in $VMNames) { 
            $VMName = $RG.trim("RG-") + "-$($VMName)"
            $nicName = $VMName + "-nic"
   $ParamObject = @{
    'adminUsername'                 = $adminUsername
    'adminPassword'                 = [string]$adminPassword
    'location'                      = $Location
    'vmName'                        = $VMName
    'nsgName'                       = $NSGName
    'virtualNetworkName'            = $vNETName
    'subnetName'                    = $subNETName
    'virtualNetworkAddressPrefix'   = $($Subnet.vNET)
    'subnetAddressPrefix'           = $($Subnet.subNET)
    'nicName'                       = $nicName
    'virtualNetworkResourceGroup'   = $RG
    'OSVersion'                     = $($OSVersion.skus)
    'VMSize'                        = $($VMSize.Name)
    }

   $Parameters = @{
    'Name'                      = 'LimeDefaultDeployment-' + (Get-Random)
    'ResourceGroupName'         = $RG
    'TemplateFile'              = '.\azVirtualMachine.json'
    'TemplateParameterObject'   = $ParamObject
    'Verbose'                   = $true
    }
    New-AzResourceGroupDeployment @Parameters
    } 
   } else {
      $vNETCheck = Get-AzVirtualNetwork -ResourceGroupName $RG -ResourceName  $vNETName -ErrorAction SilentlyContinue
      if (!$vNETCheck){
          Write-Host "Creating: $NSGName" -ForegroundColor Green
          $NSG = New-AzNetworkSecurityGroup -ResourceGroupName $RG -Location $Location -Name $NSGName
          Write-Host "Setting: $subNETName with $($Subnet.subNET)" -ForegroundColor Green
          $vNETsubNET = New-AzVirtualNetworkSubnetConfig -Name $subNETName -AddressPrefix $Subnet.subNET -NetworkSecurityGroup $NSG
          Write-Host "Creating: $vNETName with $($Subnet.vNET)" -ForegroundColor Green
          New-AzVirtualNetwork -Name $vNETName -ResourceGroupName $RG -Location $Location -AddressPrefix $Subnet.vNET -Subnet $vNETsubNET
          } elseif ($vNETCheck) {
          Write-Host "Virtual Network $($vNETName) already exists, continuing..." -ForegroundColor Yellow
      }
  }
} 

Stop-Transcript


