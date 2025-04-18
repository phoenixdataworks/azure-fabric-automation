# Azure Fabric Capacity Automation

Automate the management of Microsoft Fabric capacities in Azure, allowing you to start, stop, and scale capacities on a schedule or through manual triggers.

This script has been shared by the [Phoenix Dataworks](https://phoenixdaa.works). Contact us with any issues or if you need help with this or similar solutions.

## Overview

This solution deploys Azure Automation runbooks that can control Microsoft Fabric capacities in your Azure subscription. It requires existing resources and adds automation capabilities to them.

## Quick Start

1. Ensure you have an existing Azure Automation account and Fabric capacity
2. Deploy the solution using the [ARM template](arm-templates/azuredeploy.json)
3. Configure schedules for automatic start/stop of capacities
4. Create manual webhooks for on-demand control
5. Monitor automation job status in the Azure portal

For detailed instructions, see the [Automated Deployment Guide](Automated-Deployment-Guide.md).

## Key Components

- **Azure Automation Account**: Hosts the runbooks and schedules
- **System-assigned Managed Identity**: Used for secure, passwordless authentication
- **PowerShell Runbooks**:
  - `Start-FabricCapacity.ps1`: Starts a stopped capacity
  - `Stop-FabricCapacity.ps1`: Stops a running capacity
  - `Scale-FabricCapacity.ps1`: Scales a capacity to a specified SKU
  - `Schedule-FabricCapacity.ps1`: Creates schedules for start/stop operations
  - `Schedule-FabricCapacityPattern.ps1`: Creates complex scaling patterns
  - `Deploy-FabricAutomation.ps1`: Used during deployment

## Prerequisites

- An Azure subscription
- Contributor access to the Azure subscription or resource group
- PowerShell 7.0 or later (for local deployment)
- **Existing Microsoft Fabric capacity resource**
- **Existing Azure Automation account**

> **IMPORTANT:** If the Automation account or Fabric capacity do not already exist, they must be created in the same resource group where you plan to deploy this solution. Resources in different resource groups may cause permission issues and prevent the automation from functioning properly.

## Security and Permissions

The solution uses a system-assigned managed identity with:
- **Contributor** role on the Fabric capacity resources
- **Automation Job Operator** role on the Automation account

Role assignments are automatically verified and managed by the role assignment verification process during deployment.

## Common Usage Scenarios

### Daily Office Hours

1. Start capacity at 8:00 AM Monday-Friday
2. Scale to appropriate size during peak hours
3. Stop capacity at 6:00 PM Monday-Friday

### Batch Processing

1. Start capacity at 11:00 PM
2. Scale to high-performance SKU
3. Run intensive workloads
4. Stop capacity when processing completes

### Development Environment

1. Run on-demand during development hours
2. Stop automatically after hours
3. Remain stopped on weekends

## Creating Manual Webhooks

To manually create webhooks for on-demand operations:

1. Navigate to your Azure Automation account
2. Select "Runbooks" and choose the desired runbook
3. Click "Webhooks" and "Add webhook"
4. Provide a name and expiration date
5. Copy and securely store the URL (it won't be shown again)
6. Configure the webhook parameters

## Advanced Configuration

The solution is highly configurable:

- **Multiple capacities**: Control multiple Fabric capacities
- **Complex schedules**: Create day/time-based patterns
- **Scaling patterns**: Define custom scaling scenarios

## Troubleshooting

Common issues and their solutions:
Common issues and their solutions:

- **Permission errors**: Check that the managed identity has proper roles assigned and allow time for RBAC propagation
- **Module import failures**: Verify the required modules are available in your Automation account
- **Webhook failures**: Ensure the URL is valid and parameters are correctly formatted
- **Resource errors**: Verify both the Automation account and Fabric capacity exist before deployment

## Contributing

Contributions are welcome! Please open issues and pull requests on GitHub.
Contributions are welcome! Please open issues and pull requests on GitHub.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Microsoft Azure Documentation
- Microsoft Fabric Documentation
- Power BI Community
- Power Automate Community
