# Azure Fabric Capacity Automation - Setup Guide

This guide provides step-by-step instructions for setting up the Azure Automation components of the solution for automating the start and stop of Microsoft Fabric capacities.

## Prerequisites

Before you begin, ensure you have:

- An Azure subscription with permissions to create resources
- A Microsoft Fabric F2 capacity
- PowerShell 7.0 or later
- Azure PowerShell modules installed
- Access to create an Azure AD application (service principal)

## Setup Steps

### 1. Install Required PowerShell Modules

Open a PowerShell window and run the following commands to install the required modules:

```powershell
# Install the Azure PowerShell module
Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force

# Install the Azure Automation module
Install-Module -Name Az.Automation -AllowClobber -Scope CurrentUser -Force
```

### 2. Create a Self-Signed Certificate

Create a self-signed certificate that will be used for authenticating the service principal:

```powershell
# Set certificate parameters
$certName = "FabricCapacityAutomation"
$certPath = "$env:TEMP\$certName.pfx"
$certPassword = ConvertTo-SecureString -String "YourStrongPassword" -Force -AsPlainText
$certExpiryYears = 2

# Create the certificate
$cert = New-SelfSignedCertificate -Subject "CN=$certName" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256 -NotAfter (Get-Date).AddYears($certExpiryYears).AddHours(1)

# Export the certificate to a PFX file
Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $certPassword

# Export the certificate to a CER file (public key only)
Export-Certificate -Cert $cert -FilePath "$env:TEMP\$certName.cer" -Type CERT

# Get the certificate thumbprint
$thumbprint = $cert.Thumbprint
Write-Host "Certificate thumbprint: $thumbprint"
Write-Host "Certificate exported to: $certPath"
```

### 3. Create an Azure AD Application (Service Principal)

Create an Azure AD application and service principal that will be used to authenticate to Azure:

```powershell
# Connect to Azure
Connect-AzAccount

# Connect-AzAccount -DeviceCode if the browser pop-up does not work. This will require you to navigate to https://microsoft.com/devicelogin and paste in a code.
```

```powershell
# Set variables
$appName = "FabricCapacityAutomation"
$certPath = "$env:TEMP\$certName.cer"

# Create the Azure AD application
$app = New-AzADApplication -DisplayName $appName

# Create a service principal for the application
$sp = New-AzADServicePrincipal -ApplicationId $app.AppId

# Add the certificate to the application
$certBytes = [System.IO.File]::ReadAllBytes($certPath)
$certBase64 = [System.Convert]::ToBase64String($certBytes)
$certStartDate = Get-Date
$certEndDate = $certStartDate.AddYears($certExpiryYears)

New-AzADAppCredential -ApplicationId $app.AppId -CertValue $certBase64 -StartDate $certStartDate -EndDate $certEndDate

# Output the application ID
Write-Host "Application ID: $($app.AppId)"
Write-Host "Service Principal Object ID: $($sp.Id)"
```

### 4. Assign Permissions to the Service Principal

Assign the necessary permissions to the service principal to control the Fabric capacity:

```powershell
# Set variables
$subscriptionId = "YourSubscriptionId"
$resourceGroupName = "YourResourceGroupName"
$capacityName = "YourCapacityName"
$spObjectId = $sp.Id

# Get the Fabric capacity resource ID
$capacityId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Fabric/capacities/$capacityName"

# Assign the Fabric Capacity Administrator role to the service principal
New-AzRoleAssignment -ObjectId $spObjectId -RoleDefinitionName "Fabric Capacity Administrator" -Scope $capacityId

Write-Host "Permissions assigned to the service principal."
```

### 5. Create an Azure Automation Account

Create an Azure Automation account that will host the runbooks:

```powershell
# Set variables
$automationAccountName = "FabricCapacityAutomation"
$location = "EastUS" # Change to your preferred region

# Create a resource group for the Automation account
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

# Create the Automation account
New-AzAutomationAccount -ResourceGroupName $resourceGroupName -Name $automationAccountName -Location $location

Write-Host "Automation account created: $automationAccountName"
```

### 6. Upload the Certificate to the Automation Account

Upload the certificate to the Automation account:

```powershell
# Set variables
$certPath = "$env:TEMP\$certName.pfx"
$certPassword = ConvertTo-SecureString -String "YourStrongPassword" -Force -AsPlainText

# Import the certificate to the Automation account
$cert = New-AzAutomationCertificate -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Path $certPath -Name $certName -Password $certPassword -Exportable

Write-Host "Certificate uploaded to the Automation account."
```

### 7. Import the PowerShell Runbooks

Import the PowerShell runbooks to the Automation account:

```powershell
# Set variables
$runbooksPath = "C:\Path\To\Runbooks" # Change to the path where you saved the runbooks

# Import the runbooks
$runbooks = @(
    "Start-FabricCapacity.ps1",
    "Stop-FabricCapacity.ps1",
    "Get-FabricCapacityStatus.ps1",
    "Schedule-FabricCapacity.ps1",
    "Create-FabricCapacityWebhooks.ps1"
)

foreach ($runbook in $runbooks) {
    $runbookPath = Join-Path -Path $runbooksPath -ChildPath $runbook
    $runbookName = [System.IO.Path]::GetFileNameWithoutExtension($runbook)
    
    Import-AzAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Path $runbookPath -Name $runbookName -Type PowerShell -Force
    
    # Publish the runbook
    Publish-AzAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $runbookName
    
    Write-Host "Runbook imported and published: $runbookName"
}
```

### 8. Create Webhooks for the Runbooks

Create webhooks for the runbooks that will be used by the Power BI dashboard:

```powershell
# Set variables
$capacityId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Fabric/capacities/$capacityName"
$tenantId = (Get-AzContext).Tenant.Id
$applicationId = $app.AppId
$certificateThumbprint = $thumbprint
$webhookExpiryInDays = 365
$outputFilePath = "$env:USERPROFILE\FabricCapacityWebhooks.json"

# Run the Create-FabricCapacityWebhooks runbook
$params = @{
    ResourceGroupName = $resourceGroupName
    AutomationAccountName = $automationAccountName
    CapacityId = $capacityId
    TenantId = $tenantId
    ApplicationId = $applicationId
    CertificateThumbprint = $certificateThumbprint
    WebhookExpiryInDays = $webhookExpiryInDays
    OutputFilePath = $outputFilePath
}

Start-AzAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "Create-FabricCapacityWebhooks" -Parameters $params

Write-Host "Webhooks created. The webhook URLs are saved to: $outputFilePath"
```

### 9. Create Schedules for Automatic Start/Stop (Optional)

Create schedules for automatically starting and stopping the Fabric capacity:

```powershell
# Set variables
$startTime = "08:00:00" # 8:00 AM
$stopTime = "18:00:00" # 6:00 PM
$timeZone = "Eastern Standard Time" # Change to your time zone
$weekDaysOnly = $true

# Run the Schedule-FabricCapacity runbook
$params = @{
    ResourceGroupName = $resourceGroupName
    AutomationAccountName = $automationAccountName
    CapacityId = $capacityId
    TenantId = $tenantId
    ApplicationId = $applicationId
    CertificateThumbprint = $certificateThumbprint
    StartTime = $startTime
    StopTime = $stopTime
    TimeZone = $timeZone
    WeekDaysOnly = $weekDaysOnly
}

Start-AzAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "Schedule-FabricCapacity" -Parameters $params

Write-Host "Schedules created for automatic start/stop."
```

### 10. Test the Runbooks

Test the runbooks to ensure they are working correctly:

```powershell
# Test the Get-FabricCapacityStatus runbook
$params = @{
    CapacityId = $capacityId
    TenantId = $tenantId
    ApplicationId = $applicationId
    CertificateThumbprint = $certificateThumbprint
}

$job = Start-AzAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "Get-FabricCapacityStatus" -Parameters $params

# Wait for the job to complete
$jobOutput = Wait-AzAutomationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Id $job.JobId -TimeoutInMinutes 5
$jobOutput = Get-AzAutomationJobOutput -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Id $job.JobId -Stream Output

Write-Host "Runbook test output:"
$jobOutput.Summary
```

## Troubleshooting

### Certificate Authentication Issues

If you encounter issues with certificate authentication, check the following:

1. Ensure the certificate is valid and has not expired
2. Verify that the certificate thumbprint is correct
3. Check that the certificate has been uploaded to the Automation account
4. Confirm that the service principal has the necessary permissions

To check the certificate in the Automation account:

```powershell
Get-AzAutomationCertificate -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $certName
```

### Webhook Issues

If you encounter issues with webhooks, check the following:

1. Ensure the webhooks have not expired
2. Verify that the webhook URLs are correct
3. Check that the runbooks are published

To recreate the webhooks:

```powershell
# Run the Create-FabricCapacityWebhooks runbook again
$params = @{
    ResourceGroupName = $resourceGroupName
    AutomationAccountName = $automationAccountName
    CapacityId = $capacityId
    TenantId = $tenantId
    ApplicationId = $applicationId
    CertificateThumbprint = $certificateThumbprint
    WebhookExpiryInDays = $webhookExpiryInDays
    OutputFilePath = $outputFilePath
}

Start-AzAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "Create-FabricCapacityWebhooks" -Parameters $params
```

### Runbook Execution Issues

If you encounter issues with runbook execution, check the following:

1. Check the runbook job output for error messages
2. Verify that the service principal has the necessary permissions
3. Ensure the Fabric capacity exists and is accessible

To check the runbook job output:

```powershell
# Get the latest job for a specific runbook
$job = Get-AzAutomationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -RunbookName "Get-FabricCapacityStatus" | Select-Object -First 1

# Get the job output
$jobOutput = Get-AzAutomationJobOutput -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Id $job.JobId -Stream Any

# Display the job output
$jobOutput | ForEach-Object { $_.Summary }
```

## Next Steps

After completing the Azure Automation setup, proceed to the [Power BI Dashboard Setup Guide](./PowerBI-Dashboard-Setup.md) to create the Power BI dashboard and Power Automate flows.

## Additional Resources

- [Azure Automation Documentation](https://docs.microsoft.com/en-us/azure/automation/)
- [Microsoft Fabric Documentation](https://docs.microsoft.com/en-us/fabric/)
- [Power BI Documentation](https://docs.microsoft.com/en-us/power-bi/)
- [Power Automate Documentation](https://docs.microsoft.com/en-us/power-automate/)
