# Azure Fabric Capacity Automation

This solution provides automation for Microsoft Fabric capacities in Azure, allowing you to automatically start, stop, and scale capacities based on schedules or through manual triggers.

## Features

- **Automatic start and stop**: Schedule capacities to automatically turn on and off at specific times
- **Scaling**: Scale your capacity up and down based on usage patterns
- **Managed Identity Authentication**: Uses Azure Managed Identities for secure, passwordless authentication
- **Manual control**: Trigger operations on-demand through manually created webhooks
- **Role verification**: Automatically verifies and manages required role assignments

## Architecture

The solution uses Azure Automation to host and execute PowerShell runbooks that control Fabric capacities:

```
                                       +-------------------+
                                       |                   |
                                       |  Azure Scheduler  |
                                       |                   |
                                       +--------+----------+
                                                |
                                                |
                                       +--------v----------+
+----------------+                     |                   |
|                |                     |                   |
| Manual Webhook +-------------------->+  Azure Automation |
|    Triggers    |                     |                   |
|                |                     |                   |
+----------------+                     +--------+----------+
                                                |
                                                |
                                       +--------v----------+
                                       |                   |
                                       | Microsoft Fabric  |
                                       |    Capacity       |
                                       |                   |
                                       +-------------------+
```

## Components

1. **Azure Automation Account**: Hosts the runbooks and schedules that control Fabric capacities
2. **Managed Identity**: Used for secure authentication to Azure resources
3. **PowerShell Runbooks**:
   - `Start-FabricCapacity`: Starts a stopped capacity
   - `Stop-FabricCapacity`: Stops a running capacity  
   - `Scale-FabricCapacity`: Scales a capacity to a specified SKU
   - `Schedule-FabricCapacity`: Sets up schedules for start/stop operations
   - `Schedule-FabricCapacityPattern`: Sets up complex scaling patterns
   - `Deploy-FabricAutomation`: Deploys the full solution
   - `checkRoleAssignment`: Verifies and manages the required RBAC role assignments

## Integration Options

### 1. Schedule-Based Automation

The solution can be configured to automatically:
- Start your capacity each morning
- Scale it up for processing intensive workloads
- Scale it down to save costs during lower usage periods  
- Stop the capacity during non-business hours

### 2. Webhook Integration

You can create webhooks in the Azure Portal to trigger operations from:
- Custom applications
- Flow/Logic Apps
- Azure DevOps pipelines
- Other automation systems

## Setup

See the [Automated Deployment Guide](Automated-Deployment-Guide.md) for detailed deployment instructions.

## Creating Manual Webhooks

To create a webhook for a runbook:

1. Navigate to your Azure Automation account in the Azure Portal
2. Select "Runbooks" from the left menu
3. Click on the runbook you want to create a webhook for (e.g., Start-FabricCapacity)
4. Select "Webhooks" from the resources menu
5. Click "Add webhook"
6. Provide a name and expiration date
7. Copy and securely store the webhook URL (it will not be shown again)
8. Configure the parameters for the webhook:
   - `FabricCapacityResourceId`: The resource ID of your Fabric capacity 
   - `SkuName` (for Scale-FabricCapacity only): The SKU to scale to (e.g., F2, F4, F8, etc.)

## Security Considerations

- The solution uses Managed Identity authentication rather than service principals
- Manually created webhooks are secured using a unique token in the URL
- The webhook URLs should be treated as secrets and stored securely
- The automation account only has the minimum required permissions on your Fabric capacity

## Common Scenarios

### Daily Workday Automation

1. **6:00 AM**: Start capacity
2. **6:05 AM**: Scale to F64 for morning processing
3. **7:00 AM**: Scale down to F4 for normal daytime usage
4. **6:00 PM**: Stop capacity

### Batch Processing

1. **11:00 PM**: Start capacity
2. **11:05 PM**: Scale to F64 for overnight processing
3. **4:00 AM**: Stop capacity

### Development Environment

1. **8:00 AM**: Start capacity at F4
2. **5:00 PM**: Stop capacity
3. **Weekends**: Remain stopped

## Monitoring

Monitor the execution of your automation jobs in the Azure Automation account:

1. Navigate to your Automation account
2. Select "Jobs" from the left menu
3. Review the status and output of recent jobs
4. Configure alerts for job failures

## Troubleshooting

### Common Issues

1. **Role Assignment Problems**:
   - The managed identity must have the "Contributor" role on the Fabric capacity
   - The role verification script will check and attempt to repair this automatically
   - Allow 5-10 minutes for RBAC permissions to propagate after assignment

2. **Webhook Failures**:
   - Verify the webhook URL is correct and has not expired
   - Check that the parameters passed to the webhook are correct
   - Review the job outputs in the Automation account for specific error messages

3. **Scheduling Issues**:
   - Ensure the time zone is set correctly for your schedules
   - Verify that the Azure Automation service is running in your region
   - Check that the schedules are enabled in the Automation account

## Contributing

Contributions are welcome! Please open an issue or pull request in the GitHub repository. 