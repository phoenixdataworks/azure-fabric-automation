# Managed Identity Migration Guide

This guide explains how the Azure Fabric Capacity Automation solution has been migrated from using certificate-based service principal authentication to using managed identity authentication.

## Why Migrate to Managed Identity?

Microsoft has retired Run As accounts for Azure Automation as of September 30, 2023. According to [Microsoft documentation](https://learn.microsoft.com/en-us/azure/automation/migrate-run-as-accounts-managed-identity?tabs=run-as-account), Run As accounts are now replaced with Managed Identities.

Benefits of using managed identity include:

1. **No certificate management**: No need to generate, upload, or renew certificates
2. **Enhanced security**: No credentials to manage or potentially leak
3. **Simplified authentication**: No need to track application IDs, tenant IDs, or certificate thumbprints
4. **Reduced maintenance**: No monthly/yearly renewal of certificates required

## What Has Changed?

The following changes have been made to the scripts in this solution:

### 1. Authentication Method

All scripts now use the managed identity authentication method:

```powershell
# Old authentication method (service principal with certificate)
Connect-AzAccount -ServicePrincipal -Tenant $TenantId -ApplicationId $ApplicationId -CertificateThumbprint $CertificateThumbprint

# New authentication method (managed identity)
Connect-AzAccount -Identity
```

### 2. Parameter Simplification

The following parameters have been removed from all runbook scripts:
- `TenantId`
- `ApplicationId`
- `CertificateThumbprint`

### 3. Deployment Changes

The deployment script now:
- Enables system-assigned managed identity on the Automation account
- Assigns the appropriate RBAC roles to the managed identity
- No longer creates or manages service principals or certificates

### 4. Webhook Changes

Webhooks now use the simplified parameter set (only passing the `CapacityId` parameter) since the authentication details are not needed.

### 5. Additional Improvements (April 2025)

Several additional improvements have been implemented:

#### Improved State Handling
- Both Start-FabricCapacity.ps1 and Stop-FabricCapacity.ps1 now properly recognize and handle "Active" state as a valid running state
- Appropriate polling delays have been added to wait for state transitions
- Enhanced polling logic with better recognition of transitional states

#### Error Handling
- Improved error handling for webhook creation
- Better handling of asynchronous operations with appropriate delay times
- More detailed logging for troubleshooting

#### User Experience
- Webhook URLs are now properly displayed and saved in the deployment output
- Clear warnings when webhooks are created that they must be saved immediately

## How to Migrate Existing Automation Accounts

If you have existing automation accounts using Run As accounts or certificate-based authentication, follow these steps to migrate:

1. **Enable managed identity on the Automation account**:
   ```powershell
   Set-AzAutomationAccount -ResourceGroupName "YourResourceGroup" -Name "YourAutomationAccount" -AssignSystemIdentity
   ```

2. **Assign appropriate permissions to the managed identity**:
   ```powershell
   $automationAccount = Get-AzAutomationAccount -ResourceGroupName "YourResourceGroup" -Name "YourAutomationAccount"
   $managedIdentityObjectId = $automationAccount.Identity.PrincipalId
   
   # Assign contributor role to the Fabric capacity
   New-AzRoleAssignment -ObjectId $managedIdentityObjectId -RoleDefinitionName "Contributor" -Scope "/subscriptions/YourSubscriptionId/resourceGroups/YourResourceGroup/providers/Microsoft.Fabric/capacities/YourCapacityName"
   
   # Assign contributor role to the Automation account itself for creating schedules
   $automationAccountResourceId = "/subscriptions/YourSubscriptionId/resourceGroups/YourResourceGroup/providers/Microsoft.Automation/automationAccounts/YourAutomationAccount"
   New-AzRoleAssignment -ObjectId $managedIdentityObjectId -RoleDefinitionName "Contributor" -Scope $automationAccountResourceId
   ```

3. **Import the updated runbooks** from this repository

4. **Re-create any webhooks** using the new scripts

5. **Re-create any schedules** using the new Schedule-FabricCapacityPattern script

## Verifying the Migration

To verify that your migration was successful:

1. **Check that managed identity is enabled**:
   ```powershell
   Get-AzAutomationAccount -ResourceGroupName "YourResourceGroup" -Name "YourAutomationAccount" | Select-Object -ExpandProperty Identity
   ```

2. **Run a test job manually** to verify that authentication works

3. **Check the job output** for any authentication errors

## Troubleshooting

If you encounter issues during or after migration:

1. **Permission errors**: Ensure the managed identity has been assigned the appropriate RBAC roles
   ```powershell
   Get-AzRoleAssignment -ObjectId $managedIdentityObjectId
   ```

2. **Authentication errors in runbooks**: Check that the runbooks are using the `-Identity` parameter with Connect-AzAccount

3. **Delays in permission propagation**: Wait 5-10 minutes after assigning roles before running runbooks to allow for Azure RBAC propagation

4. **Webhook creation errors**: If you see "A command that prompts the user failed" errors, make sure your webhook creation scripts have the latest updates with confirmation suppression

5. **State transition issues**: If capacity state doesn't change properly, the improved polling logic should help, but you may need to manually verify the state in the Azure portal

## Additional Resources

- [Microsoft documentation on migrating from Run As accounts to managed identities](https://learn.microsoft.com/en-us/azure/automation/migrate-run-as-accounts-managed-identity?tabs=run-as-account)
- [Azure Automation managed identity authentication overview](https://learn.microsoft.com/en-us/azure/automation/automation-security-overview#managed-identities-preview) 
- [Azure PowerShell breaking changes](https://learn.microsoft.com/en-us/powershell/scripting/install/powershell-support-lifecycle) - Be aware of upcoming breaking changes in the Get-AzAccessToken cmdlet 