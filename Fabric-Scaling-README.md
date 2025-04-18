# Azure Fabric Capacity Scaling and Scheduling

This extension to the Azure Fabric Capacity Automation solution adds the ability to scale Microsoft Fabric capacities as part of your automation workflows.

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
- `TenantId`: Your Azure AD tenant ID
- `ApplicationId`: The Application ID of your service principal
- `CertificateThumbprint`: The thumbprint of your authentication certificate
- `TargetSku`: The target SKU to scale to (F2, F4, F8, F16, F32, F64, F128, F256, F512, F1024)

Optional parameters:
- `WaitForCompletion`: Whether to wait for the scaling operation to complete (default: true)
- `TimeoutInMinutes`: Maximum time to wait for completion (default: 10)

### Setting Up a Complex Schedule Pattern

To create a complex schedule pattern, run the `Schedule-FabricCapacityPattern.ps1` runbook with the following parameters:

- `ResourceGroupName`: The resource group containing your Azure Automation account
- `AutomationAccountName`: The name of your Azure Automation account
- `CapacityId`: The ID of the Fabric capacity to schedule
- `TenantId`: Your Azure AD tenant ID
- `ApplicationId`: The Application ID of your service principal
- `CertificateThumbprint`: The thumbprint of your authentication certificate

Optional parameters:
- `StartTime`: Time to start the capacity (default: "06:00:00")
- `ScaleDownTime`: Time to scale down from F64 to F2 (default: "06:10:00")
- `StopTime`: Time to stop the capacity (default: "18:00:00")
- `TimeZone`: Time zone for the schedules (default: "Pacific Standard Time")
- `WeekDaysOnly`: Whether to run only on weekdays (default: true)

## Example: Daily Optimization Pattern

The default configuration in `Schedule-FabricCapacityPattern.ps1` implements the following pattern:

1. **6:00 AM Pacific Time**: Start the Fabric capacity
2. **6:00 AM Pacific Time**: Scale the capacity to F64 (for running intensive jobs)
3. **6:10 AM Pacific Time**: Scale the capacity down to F2 (cost-saving mode)
4. **6:00 PM Pacific Time**: Stop (pause) the capacity

This pattern ensures that:
- Your capacity is only running during business hours
- You only pay for the expensive F64 SKU for 10 minutes each day
- You use the more economical F2 SKU for general work throughout the day
- Your capacity is completely paused (no charges) during non-business hours

## Integration with Power BI Dashboard

The scaling operations can be integrated into the Power BI dashboard by:

1. Creating additional webhooks for the Scale-FabricCapacity runbook
2. Adding buttons to the Power BI dashboard to trigger the scaling operations
3. Updating the Power BI dataset to show the current SKU of the capacity

Refer to the [Power BI Dashboard Setup](./PowerBI-Dashboard-Setup.md) document for general guidance on extending the dashboard.

## Security Considerations

The scaling operations use the same security mechanisms as the core solution:

- Service principal with certificate authentication
- Limited permissions through RBAC
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

## Next Steps

After setting up the scaling and scheduling components:

1. Monitor the cost and performance of your Fabric capacity.
2. Adjust the schedule times and SKUs based on your actual usage patterns.
3. Consider creating additional schedule patterns for different scenarios (e.g., month-end processing).