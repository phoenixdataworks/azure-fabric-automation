# Microsoft Fabric Capacity Automation - Deployment Guide

This guide outlines the steps to automate the deployment of the Microsoft Fabric Capacity Automation solution.

## Prerequisites

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

## Deployment Improvements

The latest version of the ARM template includes several important improvements:

1. **Automatic Role Assignment**: The template now automatically assigns the Contributor role to the Automation account's managed identity at the resource group level, eliminating the need for manual role assignments.

2. **Enhanced Parameter Validation**: Parameters now include proper validation constraints to prevent deployment errors.

3. **Improved Documentation**: Parameter descriptions have been enhanced for better clarity.

## Azure Portal Deployment Sections

When deploying through the Azure Portal, you'll encounter the following sections:

1. **Basics**: Where you select your subscription and resource group (deployment name is now auto-generated)
2. **Instance Details**: Where you configure core deployment settings including:
   - Region for deployment
   - Automation account settings (create new or use existing)
   - Fabric capacity settings (create new or use existing)
   - Fabric capacity administrator (email/UPN)
   - Default capacity SKU
3. **Schedule Settings**: Where you configure the times for start, scale up, scale down, and stop operations:
   - Start Time (HH:MM): When to start the capacity (default: 06:00)
   - Scale Up Time (HH:MM): When to scale up the capacity (default: 06:05)
   - Scale Up Size: SKU to scale up to (default: F64)
   - Scale Down Time (HH:MM): When to scale down the capacity (default: 17:45)
   - Stop Time (HH:MM): When to stop the capacity (default: 18:00)
   - Time Zone: Select the time zone for all schedules (e.g., "United States - Pacific Time")
   - Schedule Days: Select which days of the week to run the schedules
4. **Tags**: Where you can add optional resource tags
5. **Review + Create**: Final validation before deployment

## Schedule Configuration

The deployment creates four daily schedules for the Fabric capacity, which will start the day after deployment:

1. **Start Schedule**: Starts the capacity at the specified Start Time
2. **Scale Up Schedule**: Scales the capacity to the specified SKU at the Scale Up Time
3. **Scale Down Schedule**: Scales the capacity back to the default SKU at the Scale Down Time
4. **Stop Schedule**: Stops the capacity at the specified Stop Time

These schedules run only on the days specified in the Schedule Days parameter and in the time zone selected during deployment.

## Deployment Options

You can deploy this solution using several methods:

1. Azure Resource Manager (ARM) template
2. PowerShell script
3. Azure DevOps pipeline
4. GitHub Actions

> **IMPORTANT: Deployment Mode** 
> 
> This solution should be deployed using **Incremental** deployment mode to prevent accidental deletion of any existing resources in your resource group. The following deployment options all use Incremental mode by default.

### Option 1: ARM Template Deployment Using the Provided Script

The simplest way to deploy the solution is through the provided deployment script:

```powershell
# Clone the repository if you haven't already
git clone https://github.com/phoenixdataworks/azure-fabric-automation.git
cd azure-fabric-automation

# Run the deployment script with Incremental mode (this is the default)
.\arm-templates\azuredeploy.ps1 `
  -SubscriptionId "your-subscription-id" `
  -ResourceGroupName "your-resource-group" `
  -Location "eastus" `
  -TemplateParameters @{
      "automationAccountName" = "your-existing-automation-account"
      "fabricCapacityName" = "your-existing-fabric-capacity"
      "createNewAutomationAccount" = $false
      "createNewFabricCapacity" = $false
      "fabricCapacityAdministrator" = "admin@yourdomain.com"
  }
```

### Option 2: Manual ARM Template Deployment

Alternatively, you can manually deploy the ARM template with the Azure PowerShell module:

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
$fabricCapacityName = "your-existing-fabric-capacity"

# Select the subscription
Set-AzContext -SubscriptionId $subscriptionId

# Create resource group if it doesn't exist
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

# Deploy the ARM template with INCREMENTAL mode
New-AzResourceGroupDeployment `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile ".\arm-templates\mainTemplate.json" `
  -Mode Incremental `
  -automationAccountName $automationAccountName `
  -fabricCapacityName $fabricCapacityName `
  -fabricCapacityAdministrator "admin@yourdomain.com" `
  -location $location `
  -createNewAutomationAccount $false `
  -createNewFabricCapacity $false
```

### Option 3: PowerShell Script Deployment

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
  -FabricCapacityAdministrator "admin@yourdomain.com" `
  -CreateScheduledOperation $true
```

### Option 4: Azure DevOps Pipeline

For CI/CD deployments, you can use Azure DevOps:

1. Import the repository into your Azure DevOps project
2. Create a new pipeline using the provided YAML template:

```yaml
# azure-pipeline.yml
trigger:
  - main

pool:
  vmImage: 'windows-latest'

steps:
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
      -FabricCapacityAdministrator "admin@yourdomain.com"
      -CreateScheduledOperation $true
      -CreateNewAutomationAccount $false
      -CreateNewFabricCapacity $false
    azurePowerShellVersion: 'LatestVersion'
    pwsh: true
```

### Option 5: GitHub Actions

You can also deploy using GitHub Actions:

1. Fork the repository
2. Set up the required GitHub secrets:
   - `AZURE_CREDENTIALS`: JSON output from `az ad sp create-for-rbac`
   - `SUBSCRIPTION_ID`: Your Azure subscription ID
   - `RESOURCE_GROUP`: Target resource group name
   - `FABRIC_CAPACITY_ID`: Resource ID of your existing Fabric capacity
   - `AUTOMATION_ACCOUNT_NAME`: Name of your existing Automation account
   - `FABRIC_CAPACITY_ADMIN`: Email of the Fabric capacity admin
3. The provided workflow file will handle the deployment:

```yaml
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
          -FabricCapacityAdministrator "${{ secrets.FABRIC_CAPACITY_ADMIN }}" `
          -CreateScheduledOperation $true `
          -CreateNewAutomationAccount $false `
          -CreateNewFabricCapacity $false
```

## Post-Deployment Steps

After deploying the solution:

1. Wait 5-10 minutes for RBAC permissions to propagate
2. Verify the role assignment was created successfully by checking the Azure portal (Access control (IAM) section of your resource group)
3. Manually create webhooks for the runbooks:
   - Go to your Azure Automation account
   - Select the runbook you want to add a webhook for
   - Click "Webhooks" and "Add webhook"
   - Configure and save the webhook URL securely

## Troubleshooting Role Assignment Issues

If you encounter permission errors after deployment:

1. Verify that the role assignment was created correctly in the Azure portal
2. Check that the managed identity of the automation account has the Contributor role at the resource group level
3. If the role assignment is missing, you can manually add it:
   - Navigate to your resource group in the Azure portal
   - Click on "Access control (IAM)"
   - Click "Add" > "Add role assignment"
   - Select the "Contributor" role
   - In the "Assign access to" dropdown, select "Managed Identity"
   - Select your automation account's managed identity
   - Click "Review + assign"

Remember that RBAC changes can take up to 10 minutes to propagate through the Azure system.

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

### Quota-Related Issues

If scaling operations fail with error messages about insufficient resources or capacity OR the capacity pauses during a scaling operation:

1. **Check your Fabric capacity quota**: Your Azure subscription has limits on the number of Fabric Capacity Units (CUs) available
   - In the Azure Portal, go to **Quotas** > **Microsoft Fabric**
   - Compare your current usage against your limit
   - Remember that F2 requires 2 CUs, F4 requires 4 CUs, F8 requires 8 CUs, etc.

2. **Request a quota increase if needed**:
   - Through the Azure Portal Quotas page
   - By creating a support request for "Service and subscription limits (quotas)"
   - Select "Microsoft Fabric" as the quota type

3. **Consider temporary workarounds**: 
   - Scale to a smaller SKU that fits within your current quota
   - Split workloads across multiple smaller capacities

For more information, see [Microsoft Fabric capacity quotas](https://learn.microsoft.com/en-us/fabric/enterprise/fabric-quotas).

For additional assistance, please open an issue in the GitHub repository. 