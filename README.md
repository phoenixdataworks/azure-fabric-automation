# Azure Fabric Capacity Automation

This project provides a solution for automating the management of Microsoft Fabric capacities through Azure Automation, with optional integration to a Power BI dashboard.

## Overview

Microsoft Fabric is a unified analytics platform that brings together various data and analytics services. Fabric capacities are the compute resources that power these services. However, Fabric capacities can be expensive to run continuously, especially in non-production environments.

This solution enables users to:

- Start (resume) a paused Fabric capacity
- Stop (pause) a running Fabric capacity
- Scale a Fabric capacity between different SKU sizes (F2, F4, F8, F16, F32, F64)
- Check the current status of a Fabric capacity
- Schedule automatic start, scale, and stop operations
- Control capacities through webhooks (which can be integrated with Power BI, Power Automate, or other systems)

By automating the start and stop of Fabric capacities, organizations can:

- Reduce costs by running capacities only when needed
- Scale capacities up only during intensive processing windows
- Empower users to control capacities without requiring Azure portal access
- Ensure capacities are available during business hours
- Automatically shut down capacities during non-business hours

## Latest Updates (April 2025)

- **Managed Identity Authentication**: Migrated from certificate-based authentication to managed identity
- **Improved State Handling**: Better handling of Fabric capacity states including "Active" state
- **Enhanced Polling Logic**: Added appropriate delays for state transitions
- **Webhook Improvements**: Fixed issues with webhook creation and improved error handling
- **Better Documentation**: Updated deployment guides and troubleshooting information

For more details on the migration to managed identity, see the [Managed Identity Migration Guide](./Managed-Identity-Migration-Guide.md).

## Solution Components

The solution consists of the following components:

1. **PowerShell Runbooks**: Scripts that interact with the Microsoft Fabric API
2. **Azure Automation**: Hosts and executes the runbooks
3. **Webhooks**: Allow external systems to trigger the runbooks
4. **Schedules**: Automate capacity management on a regular schedule

## Getting Started

### Prerequisites

Before you begin, ensure you have:

- An Azure subscription with permissions to create resources
- A Microsoft Fabric capacity to manage
- PowerShell 7.0 or later
- Azure PowerShell modules installed

### Setup Instructions

1. Clone this repository to your local machine
2. Open PowerShell and navigate to the repository directory
3. Sign in to Azure using `Connect-AzAccount`
4. Run the deployment script:

```powershell
./Deploy-FabricAutomation.ps1 `
  -SubscriptionId "your-subscription-id" `
  -ResourceGroupName "your-resource-group" `
  -AutomationAccountName "your-automation-account" `
  -FabricCapacityName "your-fabric-capacity" `
  -RunbookFolder (Get-Location).Path
```

For detailed deployment options, see the [Deployment Guide](./Deployment-Guide.md).

## Files in this Repository

### PowerShell Runbooks

- **Start-FabricCapacity.ps1**: Starts (resumes) a paused Fabric capacity
- **Stop-FabricCapacity.ps1**: Stops (pauses) a running Fabric capacity
- **Scale-FabricCapacity.ps1**: Scales a Fabric capacity to a specified SKU size
- **Get-FabricCapacityStatus.ps1**: Retrieves the current status of a Fabric capacity
- **Schedule-FabricCapacity.ps1**: Creates simple start/stop schedules
- **Schedule-FabricCapacityPattern.ps1**: Creates a complex schedule pattern with scaling
- **Create-FabricCapacityWebhooks.ps1**: Creates webhooks for basic operations
- **Create-FabricScalingWebhooks.ps1**: Creates webhooks for scaling operations

### Deployment and Configuration

- **Deploy-FabricAutomation.ps1**: Main deployment script that sets up the entire solution
- **README.md**: This file
- **Managed-Identity-Migration-Guide.md**: Guide for migrating from certificate to managed identity authentication

## Usage

### Using Webhooks

After deployment, the `Create-FabricCapacityWebhooks` and `Create-FabricScalingWebhooks` runbooks will create webhooks to trigger various operations.

**How to find the Webhook URLs:**

1. Go to your Azure Automation account in the Azure portal.
2. Navigate to **Jobs** under Process Automation.
3. Find the completed jobs named `Create-FabricCapacityWebhooks` and `Create-FabricScalingWebhooks` that were run by the deployment script.
4. Click on each job and view its **Output** stream.
5. The webhook URLs will be logged in the output, prefixed with `--->`.

**Example Output Log Line:**
```
---> Start Webhook URI: https://<...>.webhook.<region>.azure-automation.net/webhooks?token=<...>
```

These webhooks can be called from any system that can make HTTP POST requests:

```http
POST <Webhook-URL-From-Job-Logs>
```

**IMPORTANT**: Copy and save the webhook URLs securely as soon as you retrieve them from the job logs. They cannot be retrieved again later due to Azure security measures.

### Using Scheduled Operations

The solution creates a schedule with the following pattern:

1. Start the capacity at specified start time (default: 6:00 AM)
2. Scale to F64 (immediately after starting)
3. Scale down to F2 after a specified time (default: 10 minutes later)
4. Stop the capacity at specified stop time (default: 6:00 PM)

This pattern runs on weekdays only by default, but can be configured to run every day.

## Troubleshooting

If you encounter issues with the solution:

1. Check the Azure Automation job logs for detailed error messages
2. Verify that the managed identity has appropriate permissions on both the Fabric capacity and the Automation account
3. Allow sufficient time (5-10 minutes) after deployment for RBAC role assignments to propagate
4. Refer to the [Managed Identity Migration Guide](./Managed-Identity-Migration-Guide.md) for common issues

## Security Considerations

This solution uses managed identity authentication, which is more secure than certificate-based authentication:

- No credentials are stored or managed
- Permissions are limited to only what's needed
- Webhooks use random tokens that can be regenerated if needed
- Scheduled operations use Azure Automation's built-in security

## Contributing

Contributions to this project are welcome. Please submit a pull request or open an issue to discuss proposed changes.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Microsoft Azure Documentation
- Microsoft Fabric Documentation
- Power BI Community
- Power Automate Community
