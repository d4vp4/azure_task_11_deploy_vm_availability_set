# --- 1. Налаштування змінних ---
$location = "northcentralus"      # Новий регіон (щоб обійти ліміти WestUS2)
$resourceGroupName = "mate-task-11-north"
$availabilitySetName = "myAvSet"
$vmSize = "Standard_B2ats_v2"
$vmImage = "Ubuntu2204"
$adminUser = "azureuser"

$vmName1 = "matebox-1"
$vmName2 = "matebox-2"

# --- 2. Створення інфраструктури ---
Write-Host "Creating Resource Group..." -ForegroundColor Cyan
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

Write-Host "Creating Availability Set..." -ForegroundColor Cyan
$avSet = New-AzAvailabilitySet -Location $location `
                      -Name $availabilitySetName `
                      -ResourceGroupName $resourceGroupName `
                      -Sku aligned `
                      -PlatformFaultDomainCount 2 `
                      -PlatformUpdateDomainCount 5

Write-Host "Creating Network Resources..." -ForegroundColor Cyan
$nsg = New-AzNetworkSecurityGroup -Name "defaultnsg" -ResourceGroupName $resourceGroupName -Location $location -SecurityRules (New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow)
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name "vnet" -AddressPrefix "10.0.0.0/16" -Subnet (New-AzVirtualNetworkSubnetConfig -Name "default" -AddressPrefix "10.0.0.0/24" -NetworkSecurityGroup $nsg)

# --- 3. Створення SSH ключа ---
Write-Host "Setting up SSH Key..." -ForegroundColor Cyan
$sshKeyName = "linuxboxsshkey"
$sshPublicKeyContent = Get-Content "$HOME/.ssh/id_ed25519.pub"

if (!(Get-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -ErrorAction SilentlyContinue)) {
    New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshPublicKeyContent
}

# --- 4. Створення VM (Manual Config) ---
Function Create-VM {
    param ( $Name )

    Write-Host "Configuring VM: $Name..." -ForegroundColor Yellow

    # 1. NIC
    $nic = New-AzNetworkInterface -Name "$Name-nic" -ResourceGroupName $resourceGroupName -Location $location -SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $nsg.Id

    # 2. Config (AvSet ID)
    $vmConfig = New-AzVMConfig -VMName $Name -VMSize $vmSize -AvailabilitySetId $avSet.Id

    # 3. OS
    $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $Name -Credential (Get-Credential -UserName $adminUser -Message "Enter temp password (will be ignored by SSH check)")

    # 4. Image
    $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest"

    # 5. Network
    $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

    # 6. SSH Key (Explicit path)
    $vmConfig = Add-AzVMSshPublicKey -VM $vmConfig -KeyData $sshPublicKeyContent -Path "/home/$adminUser/.ssh/authorized_keys"

    # 7. Create
    New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig
}

# Create VMs
Create-VM -Name $vmName1
Create-VM -Name $vmName2

Write-Host "Done! VMs created with SSH keys." -ForegroundColor Green