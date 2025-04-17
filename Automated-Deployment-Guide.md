# Automated Deployment Guide

This guide explains how to automate the deployment of the Azure Fabric Capacity Automation solution using the included deployment scripts or ARM templates.

## Prerequisites

Before running the deployment, ensure you have:

1. **PowerShell 7.0 or later** installed
2. **Azure PowerShell modules** installed
   - **IMPORTANT:** Run PowerShell as Administrator and update Az modules with:
     ```powershell
     # Uninstall existing Az modules
     Uninstall-Module -Name Az -AllVersions -Force

     # Install the latest Az module
     Install-Module -Name Az -Repository PSGallery -Force -AllowClobber
     
     # Close and reopen PowerShell before proceeding
     ```
3. **Sufficient permissions** in your Azure subscription to:
   - Create resource groups
   - Create Azure Automation accounts
   - Create service principals
   - Assign RBAC roles
4. **Microsoft Fabric capacity** already provisioned in your Azure subscription (optional if using ARM template with create new option)

## Deployment Options

You can deploy the solution using one of the following methods:

### Option 1: ARM Template Deployment (Recommended)

1. Clone or download the repository to your local machine
2. Open PowerShell 7.0 or later
3. Navigate to the repository folder
4. Deploy using the ARM template:

```powershell
# Sign in to Azure
Connect-AzAccount

# Set subscription context if needed
Set-AzContext -SubscriptionId "your-subscription-id"

# Create a resource group if needed
New-AzResourceGroup -Name "fabric-automation-rg" -Location "eastus"

# Deploy the ARM template
New-AzResourceGroupDeployment `
  -ResourceGroupName "fabric-automation-rg" `
  -TemplateFile "./arm-templates/azuredeploy.json" `
  -automationAccountName "fabric-automation" `
  -fabricCapacityName "your-fabric-capacity-name" `
  -createNewAutomationAccount $true `
  -createNewFabricCapacity $false `
  -startTime "06:00:00" `
  -scaleDownTime "06:10:00" `
  -stopTime "18:00:00" `
  -timeZone "Pacific Standard Time" `
  -weekDaysOnly $true `
  -createWebhooks $true `
  -webhookExpiryInDays 365
```

#### Creating New Resources

The ARM template allows you to create all required resources during deployment:

* **Create new Automation Account**: Set `-createNewAutomationAccount $true` to create a new Automation account. If set to `$false`, the Automation account specified by `-automationAccountName` must already exist.

* **Create new Fabric Capacity**: Set `-createNewFabricCapacity $true` to create a new Microsoft Fabric capacity. You can also specify the SKU tier with `-fabricCapacitySku "F2"`. Valid SKU options include F2, F4, F8, F16, F32, F64, F128, F256, F512, and F1024.

Example with all new resources:

```powershell
New-AzResourceGroupDeployment `
  -ResourceGroupName "fabric-automation-rg" `
  -TemplateFile "./arm-templates/azuredeploy.json" `
  -automationAccountName "fabric-automation" `
  -createNewAutomationAccount $true `
  -fabricCapacityName "new-fabric-capacity" `
  -createNewFabricCapacity $true `
  -fabricCapacitySku "F2" `
  -startTime "06:00:00" `
  -scaleDownTime "06:10:00" `
  -stopTime "18:00:00" `
  -timeZone "Pacific Standard Time" `
  -weekDaysOnly $true `
  -createWebhooks $true `
  -webhookExpiryInDays 365
```

### Option 2: PowerShell Script Deployment

1. Clone or download the repository to your local machine
2. Open PowerShell 7.0 or later
3. Navigate to the repository folder
4. Run the deployment script with appropriate parameters

```powershell
./azure-runbooks/Deploy-FabricAutomation.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "fabric-automation-rg" `
    -AutomationAccountName "fabric-automation" `
    -FabricCapacityName "your-fabric-capacity-name"
```

### Option 3: Azure DevOps Pipeline

1. Import the repository into Azure DevOps
2. Create a pipeline using the following YAML template:

```yaml
trigger:
- main

pool:
  vmImage: 'windows-latest'

steps:
- task: PowerShell@2
  displayName: 'Deploy Fabric Automation'
  inputs:
    filePath: 'azure-runbooks/Deploy-FabricAutomation.ps1'
    arguments: >
      -SubscriptionId "$(subscriptionId)"
      -ResourceGroupName "$(resourceGroupName)"
      -AutomationAccountName "$(automationAccountName)"
      -FabricCapacityName "$(fabricCapacityName)"
      -ServicePrincipalName "$(servicePrincipalName)"
    pwsh: true
  env:
    AZURE_CREDENTIALS: $(azureCredentials)
```

3. Set up the pipeline variables or variable group with:
   - `subscriptionId`
   - `resourceGroupName`
   - `automationAccountName`
   - `fabricCapacityName`
   - `servicePrincipalName`
   - `azureCredentials` (service connection)

### Option 4: GitHub Actions

#### Using ARM Template

1. Import the repository into GitHub
2. Set up the following repository secrets:
   - `AZURE_CREDENTIALS` (service principal JSON)
   - `TEST_RESOURCE_GROUP`
   - `TEST_FABRIC_CAPACITY_NAME`
3. Run the CI/CD workflow manually or it will run automatically on changes to the ARM templates or runbooks

#### Using PowerShell Script

1. Import the repository into GitHub
2. Create a GitHub workflow using the following YAML template:

```yaml
name: Deploy Fabric Automation

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Deploy Fabric Automation
      shell: pwsh
      run: |
        ./azure-runbooks/Deploy-FabricAutomation.ps1 `
          -SubscriptionId "${{ secrets.AZURE_SUBSCRIPTION_ID }}" `
          -ResourceGroupName "${{ vars.RESOURCE_GROUP_NAME }}" `
          -AutomationAccountName "${{ vars.AUTOMATION_ACCOUNT_NAME }}" `
          -FabricCapacityName "${{ vars.FABRIC_CAPACITY_NAME }}" `
          -ServicePrincipalName "${{ vars.SERVICE_PRINCIPAL_NAME }}"
```

3. Configure the repository secrets and variables with:
   - `AZURE_CREDENTIALS` (service principal JSON)
   - `AZURE_SUBSCRIPTION_ID`
   - `RESOURCE_GROUP_NAME`
   - `AUTOMATION_ACCOUNT_NAME`
   - `FABRIC_CAPACITY_NAME`
   - `SERVICE_PRINCIPAL_NAME`

## Azure Marketplace Deployment

The solution is also available in the Azure Marketplace. To deploy from the marketplace:

1. Go to the Azure Portal and search for "Fabric Capacity Automation"
2. Click "Create" to start the deployment process
3. Fill in the required parameters:
   - Choose to create a new Automation Account or use an existing one
   - Choose to create a new Fabric Capacity or use an existing one (if creating new, select the SKU)
   - Schedule Settings (Start Time, Scale Down Time, Stop Time, Time Zone, Weekdays Only)
   - Webhook Settings (Create Webhooks, Webhook Expiry)
4. Click "Review + Create" to deploy the solution

## Advanced Configuration Options

The deployment supports several optional parameters for advanced configuration:

| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| `Location` | Azure region for the resources | eastus |
| `CreateNewAutomationAccount` | Whether to create a new Automation account | $true |
| `CreateNewFabricCapacity` | Whether to create a new Fabric capacity | $false |
| `FabricCapacitySku` | SKU tier for the Fabric capacity (if creating new) | F2 |
| `StartTime` | Time to start the capacity (HH:MM:SS) | 06:00:00 |
| `ScaleDownTime` | Time to scale down from F64 to F2 (HH:MM:SS) | 06:10:00 |
| `StopTime` | Time to stop the capacity (HH:MM:SS) | 18:00:00 |
| `TimeZone` | Time zone for the schedules | Pacific Standard Time |
| `WeekDaysOnly` | Whether to run only on weekdays | $true |
| `CreateWebhooks` | Whether to create webhooks | $true |
| `WebhookExpiryInDays` | Number of days until webhooks expire | 365 |
| `CertificateExpiryInYears` | Number of years until certificate expires | 2 |
| `RunbookFolder` | Folder containing the runbook .ps1 files | ./azure-runbooks |

### Example with Advanced Options (PowerShell Script)

```powershell
./azure-runbooks/Deploy-FabricAutomation.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "fabric-automation-rg" `
    -AutomationAccountName "fabric-automation" `
    -FabricCapacityName "your-fabric-capacity-name" `
    -Location "westus2" `
    -StartTime "07:00:00" `
    -ScaleDownTime "07:15:00" `
    -StopTime "19:00:00" `
    -TimeZone "Eastern Standard Time" `
    -WeekDaysOnly $true `
    -CreateWebhooks $true `
    -WebhookExpiryInDays 180 `
    -CertificateExpiryInYears 1
```

### Example with Advanced Options (ARM Template)

```powershell
New-AzResourceGroupDeployment `
  -ResourceGroupName "fabric-automation-rg" `
  -TemplateFile "./arm-templates/azuredeploy.json" `
  -automationAccountName "fabric-automation" `
  -createNewAutomationAccount $true `
  -fabricCapacityName "new-fabric-capacity" `
  -createNewFabricCapacity $true `
  -fabricCapacitySku "F4" `
  -location "westus2" `
  -startTime "07:00:00" `
  -scaleDownTime "07:15:00" `
  -stopTime "19:00:00" `
  -timeZone "Eastern Standard Time" `
  -weekDaysOnly $true `
  -createWebhooks $true `
  -webhookExpiryInDays 180
```

## Troubleshooting

### Common Issues

1. **Module Import Failures**
   - Ensure you have the latest Az PowerShell modules installed
   - Try manually importing the modules to the Automation account

2. **Service Principal Creation Issues**
   - Ensure you have sufficient permissions to create service principals
   - If using a CI/CD pipeline, ensure the pipeline service principal has sufficient permissions

3. **RBAC Assignment Failures**
   - Ensure the user running the script has sufficient permissions to assign roles
   - Wait a few minutes after service principal creation before assigning roles (propagation delay)

4. **Webhook Creation Failures**
   - Ensure the runbooks are properly imported and published
   - Check that the automation account has the modules properly imported

5. **ARM Template Validation Failures**
   - Check the error messages returned by the deployment operation
   - Verify that the parameter values are correct
   - Ensure that the referenced resources (e.g., Fabric Capacity) exist if using existing resources

6. **Fabric Capacity Creation Issues**
   - Ensure you have sufficient quota and permissions to create Fabric capacities
   - Verify that the SKU tier selected is available in the chosen region
   - Check that the capacity name is unique within your subscription

## Maintenance

After deployment, set up reminders for:

1. **Certificate renewal**: Before the certificate expires (default: 2 years) - only applicable for PowerShell deployment
2. **Webhook renewal**: Before the webhooks expire (default: 1 year)

You can rerun the deployment script or ARM template to renew these items at any time.

## Next Steps

After deployment:

1. Test the solution by manually executing the runbooks
2. Monitor the automation jobs to ensure they run as expected
3. Adjust the schedule times if needed
4. Set up monitoring alerts for any failures 