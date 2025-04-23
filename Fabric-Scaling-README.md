# Microsoft Fabric Capacity Scaling and Scheduling

This extension to the Microsoft Fabric Capacity Automation solution adds the ability to scale Microsoft Fabric capacities as part of your automation workflows.

## Overview

Microsoft Fabric capacities can be expensive to run at high SKU tiers (like F64). With this extension, you can:

- Scale a capacity up before running resource-intensive jobs
- Scale a capacity down during periods of lower usage
- Create complex schedule patterns that include scaling operations
- Automate the entire daily lifecycle of a capacity with precise control

## New Components

This extension adds the following components to the core solution:

1. **Scale-FabricCapacity.ps1**: A runbook to scale a Microsoft Fabric capacity to a different SKU
2. **Schedule-FabricCapacityPattern.ps1**: A runbook to create complex schedule patterns that include scaling operations

## Integration with Role-Based Access Control

The solution now automatically creates a role assignment for the Automation account's managed identity, granting it Contributor access to the resource group. This ensures the runbooks can properly interact with the Fabric capacity without manual permission configuration.

See the architectural diagram in the main [README.md](./README.md) for a visual representation of how the components interact, including the role assignment.

## Usage Scenarios

### Scaling for Batch Jobs

If you have batch jobs that run at specific times and need more resources, you can:

1. Start with a smaller capacity (e.g., F2)
2. Scale up to a larger capacity (e.g., F64) before the batch job runs
3. Scale back down to the smaller capacity after the job completes
4. Stop the capacity when it's no longer needed

### Cost Optimization

By using a larger capacity only when needed, you can significantly reduce costs while still meeting performance requirements for your workloads.

## How to Use

### Scaling a Capacity

To scale a Fabric capacity manually, run the `Scale-FabricCapacity.ps1` runbook with the following parameters:

- `CapacityId`: The ID of the Fabric capacity to scale
- `TargetSku`: The target SKU to scale to (F2, F4, F8, F16, F32, F64, F128, F256, F512, F1024)

Optional parameters:
- `WaitForCompletion`: Whether to wait for the scaling operation to complete (default: true)
- `TimeoutInMinutes`: Maximum time to wait for completion (default: 10)

### Quota Requirements for Scaling

**Important**: Before scaling to larger SKUs, ensure your Azure subscription has sufficient Fabric Capacity Units (CU) quota:

- Each SKU requires its corresponding number of CUs (F2 = 2 CUs, F64 = 64 CUs, etc.)
- If you attempt to scale beyond your available quota, the operation will fail
- Quota is checked at the time of scaling, not when creating the schedule

To check and request quota increases:
1. In the Azure Portal, go to **Quotas** > **Microsoft Fabric**
2. View your current usage and quota limits
3. Request increases through the portal or support ticket if needed

For detailed information on managing Fabric quotas, refer to [Microsoft Fabric capacity quotas](https://learn.microsoft.com/en-us/fabric/enterprise/fabric-quotas).

### Setting Up a Complex Schedule Pattern

To create a complex schedule pattern, run the `Schedule-FabricCapacityPattern.ps1` runbook with the following parameters:

- `ResourceGroupName`: The resource group containing your Azure Automation account
- `AutomationAccountName`: The name of your Azure Automation account
- `CapacityId`: The ID of the Fabric capacity to schedule

Optional parameters:
- `StartTime`: Time to start the capacity (default: "06:00:00")
- `ScaleDownTime`: Time to scale down from F64 to F2 (default: "06:10:00")
- `StopTime`: Time to stop the capacity (default: "18:00:00")
- `TimeZone`: Time zone for the schedules (default: "Pacific Standard Time")
- `WeekDaysOnly`: Whether to run only on weekdays (default: true)

## Example: Daily Optimization Pattern

The default configuration in the deployment template implements the following pattern:

1. **6:00 AM**: Start the Fabric capacity
2. **6:05 AM**: Scale the capacity to F64 (for running intensive jobs)
3. **5:45 PM**: Scale the capacity down to F2 (cost-saving mode)
4. **6:00 PM**: Stop (pause) the capacity

This pattern ensures that:
- Your capacity is only running during business hours
- You have high performance capacity during the workday
- Your capacity is completely paused (no charges) during non-business hours

All times are based on the time zone you select during deployment (default: "United States - Pacific Time").

## Time Zone Support

The solution supports various time zones, including:
- United States - Pacific Time
- United States - Mountain Time
- United States - Central Time
- United States - Eastern Time
- Coordinated Universal Time

Schedules are created to run in your selected time zone, ensuring operations occur at locally appropriate times.

## Integration with Power BI Dashboard

The scaling operations can be integrated into the Power BI dashboard by:

1. Creating additional webhooks for the Scale-FabricCapacity runbook
2. Adding buttons to the Power BI dashboard to trigger the scaling operations
3. Updating the Power BI dataset to show the current SKU of the capacity

Refer to the [Power BI Dashboard Setup](./PowerBI-Dashboard-Setup.md) document for general guidance on extending the dashboard.

## Security Considerations

The scaling operations use the same security mechanisms as the core solution:

- Automated role assignment at the resource group level
- Managed identity authentication (no credentials needed)
- Secure webhooks for external access

## Troubleshooting

### Common Issues

1. **Scaling fails with "Capacity is not in a running state"**
   - The capacity must be in a running state to scale. Start the capacity first.

2. **Scaling takes longer than expected**
   - Scaling operations can take several minutes, especially for larger SKUs.
   - Increase the `TimeoutInMinutes` parameter if needed.

3. **Schedule doesn't execute at the expected time**
   - Verify the time zone setting is correct.
   - Check that the Azure Automation account has the necessary permissions.

4. **Permission errors when running scaling operations**
   - Verify the role assignment was created successfully.
   - Wait 5-10 minutes for RBAC permissions to propagate.
   - If needed, manually add the Contributor role for the managed identity.

## Next Steps

After setting up the scaling and scheduling components:

1. Monitor the cost and performance of your Fabric capacity.
2. Adjust the schedule times and SKUs based on your actual usage patterns.
3. Consider creating additional schedule patterns for different scenarios (e.g., month-end processing).