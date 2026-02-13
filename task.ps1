$location = "northcentralus"
$resourceGroupName = "mate-task-11-north"
$availabilitySetName = "myAvSet"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$sshKeyName = "linuxboxsshkey"

$vmImage = "Ubuntu2204"
$vmSize = "Standard_B2ats_v2"

$vmName1 = "matebox-1"
$vmName2 = "matebox-2"
$sshKeyPublicKey = Get-Content "$HOME/.ssh/id_ed25519.pub"

Write-Host "Creating Resource Group..." -ForegroundColor Cyan
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

Write-Host "Creating Availability Set..." -ForegroundColor Cyan
New-AzAvailabilitySet -Location $location `
                      -Name $availabilitySetName `
                      -ResourceGroupName $resourceGroupName `
                      -Sku aligned `
                      -PlatformFaultDomainCount 2 `
                      -PlatformUpdateDomainCount 5

Write-Host "Creating SSH Key..." -ForegroundColor Cyan
if (!(Get-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -ErrorAction SilentlyContinue)) {
    New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey
}

Write-Host "Creating NSG..." -ForegroundColor Cyan
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH -Force

Write-Host "Creating VNet..." -ForegroundColor Cyan
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.0.0/24" -NetworkSecurityGroup $nsg
New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name $virtualNetworkName -AddressPrefix "10.0.0.0/16" -Subnet $subnetConfig -Force

$cred = Get-Credential -UserName "azureuser" -Message "Enter password (ignored by SSH)"

Write-Host "Creating VM 1..." -ForegroundColor Yellow
New-AzVM -ResourceGroupName $resourceGroupName `
    -Name $vmName1 `
    -Location $location `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName `
    -SecurityGroupName $networkSecurityGroupName `
    -AvailabilitySetName $availabilitySetName `
    -Image $vmImage `
    -Size $vmSize `
    -SshKeyName $sshKeyName `
    -Credential $cred `
    -PublicIpAddressName $null `
    -OpenPorts 22

Write-Host "Creating VM 2..." -ForegroundColor Yellow
New-AzVM -ResourceGroupName $resourceGroupName `
    -Name $vmName2 `
    -Location $location `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName `
    -SecurityGroupName $networkSecurityGroupName `
    -AvailabilitySetName $availabilitySetName `
    -Image $vmImage `
    -Size $vmSize `
    -SshKeyName $sshKeyName `
    -Credential $cred `
    -PublicIpAddressName $null `
    -OpenPorts 22

Write-Host "Done!" -ForegroundColor Green