# Azure Fabric Capacity Automation - Deployment Guide
# Azure Fabric Capacity Automation - Deployment Guide

This guide outlines the steps to automate the deployment of the Azure Fabric Capacity Automation solution.
This guide outlines the steps to automate the deployment of the Azure Fabric Capacity Automation solution.

## Prerequisites

Before deploying the solution, ensure you have:
Before deploying the solution, ensure you have:

1. PowerShell 7.0 or later
2. Azure PowerShell modules installed (`Az` and `Az.Automation`)
3. Sufficient permissions in your Azure subscription to:
   - Create or modify resource groups
   - Modify Azure Automation accounts
   - Assign RBAC roles
4. **REQUIRED EXISTING RESOURCES**: 
   - An existing Microsoft Fabric capacity
   - An existing Azure Automation account

> **IMPORTANT:** If you need to create the Automation account or Fabric capacity, they must be created in the same resource group where you plan to deploy this solution. Resources in different resource groups may cause permission issues and prevent the automation from functioning properly.

## Azure Portal Deployment Sections

When deploying through the Azure Portal, you'll encounter the following sections:

1. **Basics**: Where you select your subscription and resource group (deployment name is now auto-generated)
2. **Instance Details**: Where you configure core deployment settings including:
   - Region for deployment
   - Existing Automation account selection
   - Existing Fabric capacity selection
   - Default Scale Down Size selection
3. **Schedule Settings**: Where you configure the times for start, scale up, scale down, and stop operations
4. **Tags**: Where you can add optional resource tags
5. **Review + Create**: Final validation before deployment

## Deployment Options

You can deploy this solution using several methods:

1. Azure Resource Manager (ARM) template
2. PowerShell script
3. Azure DevOps pipeline
4. GitHub Actions

### Option 1: ARM Template Deployment

The simplest way to deploy the solution is through the ARM template:
You can deploy this solution using several methods:

1. Azure Resource Manager (ARM) template
2. PowerShell script
3. Azure DevOps pipeline
4. GitHub Actions

### Option 1: ARM Template Deployment

The simplest way to deploy the solution is through the ARM template:

```powershell
# Clone the repository if you haven't already
git clone https://github.com/phoenixdataworks/azure-fabric-automation.git
cd azure-fabric-automation

# Connect to your Azure account
Connect-AzAccount

# Set variables
$subscriptionId = "your-subscription-id"
$resourceGroupName = "your-resource-group"
$location = "eastus"  # Change as needed
$automationAccountName = "your-existing-automation-account"
$fabricCapacityResourceId = "/subscriptions/your-subscription-id/resourceGroups/your-resource-group/providers/Microsoft.Fabric/capacities/your-existing-capacity"

# Create resource group if it doesn't exist
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force
# Create resource group if it doesn't exist
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

# Deploy the ARM template
New-AzResourceGroupDeployment `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile ".\arm-templates\azuredeploy.json" `
  -automationAccountName $automationAccountName `
  -location $location `
  -fabricCapacityResourceId $fabricCapacityResourceId `
  -createNewAutomationAccount $false `
  -createNewFabricCapacity $false
```

The deployment adds runbooks, schedules, and job schedules to your existing Automation account to manage your existing Fabric capacity. The `checkRoleAssignment` script will verify and manage the role assignments necessary for the solution to operate.

### Option 2: PowerShell Script Deployment

For more control over the deployment process, use the PowerShell script:
For more control over the deployment process, use the PowerShell script:

```powershell
# Clone the repository if you haven't already
git clone https://github.com/phoenixdataworks/azure-fabric-automation.git
cd azure-fabric-automation

# Connect to your Azure account
Connect-AzAccount

# Run the deployment script
.\Deploy-FabricAutomation.ps1 `
  -SubscriptionId "your-subscription-id" `
  -ResourceGroupName "your-resource-group" `
  -Location "eastus" `  # Change as needed
  -AutomationAccountName "your-existing-automation-account" `
  -FabricCapacityResourceId "/subscriptions/your-subscription-id/resourceGroups/your-resource-group/providers/Microsoft.Fabric/capacities/your-existing-capacity" `
  -CreateScheduledOperation $true
```

### Option 3: Azure DevOps Pipeline

For CI/CD deployments, you can use Azure DevOps:

1. Import the repository into your Azure DevOps project
2. Create a new pipeline using the provided YAML template:
For CI/CD deployments, you can use Azure DevOps:

1. Import the repository into your Azure DevOps project
2. Create a new pipeline using the provided YAML template:

```yaml
# azure-pipeline.yml
# azure-pipeline.yml
trigger:
  - main
  - main

pool:
  vmImage: 'windows-latest'

steps:
- task: AzurePowerShell@5
- task: AzurePowerShell@5
  inputs:
    azureSubscription: 'your-service-connection'
    ScriptType: 'FilePath'
    ScriptPath: '$(System.DefaultWorkingDirectory)/Deploy-FabricAutomation.ps1'
    ScriptArguments: >
      -SubscriptionId "your-subscription-id"
      -ResourceGroupName "your-resource-group"
      -Location "eastus"
      -AutomationAccountName "your-existing-automation-account"
      -FabricCapacityResourceId "/subscriptions/your-subscription-id/resourceGroups/your-resource-group/providers/Microsoft.Fabric/capacities/your-existing-capacity"
      -CreateScheduledOperation $true
      -CreateNewAutomationAccount $false
      -CreateNewFabricCapacity $false
    azurePowerShellVersion: 'LatestVersion'
    pwsh: true
```
```

### Option 4: GitHub Actions

You can also deploy using GitHub Actions:
You can also deploy using GitHub Actions:

1. Fork the repository
2. Set up the required GitHub secrets:
   - `AZURE_CREDENTIALS`: JSON output from `az ad sp create-for-rbac`
   - `SUBSCRIPTION_ID`: Your Azure subscription ID
   - `RESOURCE_GROUP`: Target resource group name
   - `FABRIC_CAPACITY_ID`: Resource ID of your existing Fabric capacity
   - `AUTOMATION_ACCOUNT_NAME`: Name of your existing Automation account
3. The provided workflow file will handle the deployment:

```yaml
# .github/workflows/deploy.yml
# .github/workflows/deploy.yml
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
        ./Deploy-FabricAutomation.ps1 `
          -SubscriptionId "${{ secrets.SUBSCRIPTION_ID }}" `
          -ResourceGroupName "${{ secrets.RESOURCE_GROUP }}" `
          -Location "eastus" `
          -AutomationAccountName "${{ secrets.AUTOMATION_ACCOUNT_NAME }}" `
          -FabricCapacityResourceId "${{ secrets.FABRIC_CAPACITY_ID }}" `
          -CreateScheduledOperation $true `
          -CreateNewAutomationAccount $false `
          -CreateNewFabricCapacity $false
```

## Post-Deployment Steps

After deploying the solution:

1. Wait 5-10 minutes for RBAC permissions to propagate
2. Manually create webhooks for the runbooks:
   - Go to your Azure Automation account
   - Select the runbook you want to add a webhook for
   - Click "Webhooks" and "Add webhook"
   - Configure and save the webhook URL securely
   - Note: The automatic webhook creation functionality has been removed to enhance security

## Role Assignment

The solution includes a `checkRoleAssignment` script that will:

1. Verify if the necessary role assignments exist for the managed identity
2. Add any missing role assignments required for the automation to function
3. Ensure proper sequencing of role assignments in the deployment process
4. Report on the role assignment status to help with troubleshooting

This improvement ensures that the deployment automatically handles the permissions required for the solution to operate correctly.

The `checkRoleAssignment` script is a deployment script resource in the ARM template that runs during deployment to:
- Connect to Azure using the managed identity
- Check if the specified managed identity exists in the resource group
- Retrieve the principal ID of the managed identity
- Verify if the identity already has the Contributor role assignment
- Output the status of the role assignment check
- Store the result as an output variable used by the template to control subsequent deployment steps

This validation step ensures that role assignments are properly configured before the rest of the deployment proceeds, preventing permission-related failures during automated operations.

## Advanced Configuration

### Customizing Schedules

You can modify the schedules created by the deployment:

```powershell
# Example: Change the start and stop times
.\Schedule-FabricCapacity.ps1 `
  -SubscriptionId "your-subscription-id" `
  -ResourceGroupName "your-resource-group" `
  -AutomationAccountName "your-existing-automation-account" `
  -FabricCapacityResourceId "/subscriptions/your-subscription-id/resourceGroups/your-resource-group/providers/Microsoft.Fabric/capacities/your-existing-capacity" `
  -StartTime "08:00" `  # 8:00 AM
  -StopTime "20:00"     # 8:00 PM
```

### Customizing Scaling Pattern

You can set up a custom scaling pattern:

```powershell
# Example: Scale up for a longer period
.\Schedule-FabricCapacityPattern.ps1 `
  -SubscriptionId "your-subscription-id" `
  -ResourceGroupName "your-resource-group" `
  -AutomationAccountName "your-existing-automation-account" `
  -FabricCapacityResourceId "/subscriptions/your-subscription-id/resourceGroups/your-resource-group/providers/Microsoft.Fabric/capacities/your-existing-capacity" `
  -StartTime "06:00" `                # 6:00 AM
  -HighScaleSkuName "F64" `           # Scale to F64
  -HighScaleDurationMinutes 60 `      # Keep at F64 for 60 minutes
  -LowScaleSkuName "F4" `             # Then scale to F4
  -StopTime "18:00" `                 # 6:00 PM
  -RunDaysOfWeek "Monday,Tuesday,Wednesday,Thursday,Friday"  # Weekdays only
```

## Azure Marketplace Deployment

This solution is also available through the Azure Marketplace for simplified deployment:

1. Search for "Fabric Capacity Automation" in the Azure Marketplace
2. Click "Create" or "Get It Now"
3. Follow the guided deployment experience
4. Select your existing Automation account and Fabric capacity
5. Configure the schedule parameters
6. Review and create the deployment

## Troubleshooting

If you encounter issues during deployment:

1. Check the output of the deployment for specific error messages
2. Verify that the managed identity has appropriate permissions
3. Check the Activity Log in the Azure Portal for any deployment failures
4. Allow sufficient time for RBAC permissions to propagate (5-10 minutes)
5. Verify that the Fabric capacity resource ID is correct
6. Review the output from the `checkRoleAssignment` script to verify role assignment status
7. Ensure that both the Automation account and Fabric capacity exist before deployment

For additional assistance, please open an issue in the GitHub repository. 