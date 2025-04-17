# Deployment Options for Azure Fabric Automation

This document outlines different deployment options to handle certificate authentication for the Azure Fabric Capacity Automation solution, especially when you encounter permission issues.

## Understanding Certificate Authentication Options

The automation solution uses certificate-based authentication for secure access to Azure resources. There are several ways to manage these certificates:

### Option 1: Standard Deployment (Administrator Access)

If you have administrator access to the Azure Automation account, the deployment script will automatically:
1. Create a service principal with certificate authentication
2. Upload the certificate to the Azure Automation account
3. Configure all necessary permissions

**Command:**
```powershell
./Deploy-FabricAutomation.ps1 `
  -SubscriptionId "your-subscription-id" `
  -ResourceGroupName "your-resource-group" `
  -AutomationAccountName "your-automation-account" `
  -FabricCapacityName "your-fabric-capacity-name"
```

### Option 2: Run As Account (Recommended for Limited Permissions)

If you encounter the "Access denied" error when uploading certificates, you can use the Azure Automation Run As Account instead:

1. Create an Azure Automation Run As Account in the Azure Portal:
   - Navigate to your Automation Account
   - Under "Account Settings", select "Run as accounts"
   - Click "Create Azure Run As Account"

2. Run the deployment script with the `-UseRunAsAccount` parameter:
```powershell
./Deploy-FabricAutomation.ps1 `
  -SubscriptionId "your-subscription-id" `
  -ResourceGroupName "your-resource-group" `
  -AutomationAccountName "your-automation-account" `
  -FabricCapacityName "your-fabric-capacity-name" `
  -UseRunAsAccount $true
```

### Option 3: Hybrid Worker with Local Certificate

If you're using a Hybrid Worker to run the runbooks:

1. Deploy the solution, ignoring certificate upload errors:
```powershell
./Deploy-FabricAutomation.ps1 `
  -SubscriptionId "your-subscription-id" `
  -ResourceGroupName "your-resource-group" `
  -AutomationAccountName "your-automation-account" `
  -FabricCapacityName "your-fabric-capacity-name"
```

2. Install the certificate on the Hybrid Worker machine:
   - Export the certificate from your local machine
   - Import it to the Personal certificate store on the Hybrid Worker
   - Ensure the Hybrid Worker service account has access to the certificate

3. Configure runbooks to run on the Hybrid Worker:
   - In the Azure Portal, navigate to each runbook
   - Edit the runbook settings
   - Under "Run Settings", select your Hybrid Worker group

## Manual Certificate Upload

If you want to manually upload the certificate to the Automation account:

1. Export the certificate from your local machine:
```powershell
$cert = Get-ChildItem -Path "cert:\CurrentUser\My" | Where-Object { $_.Subject -like "*FabricCapacityAutomation*" }
$certPath = "$env:TEMP\FabricCert.pfx"
$certPassword = ConvertTo-SecureString -String "TempPassword123!" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $certPassword
```

2. In the Azure Portal:
   - Navigate to your Automation Account
   - Under "Shared Resources", select "Certificates"
   - Click "Add a certificate"
   - Upload the certificate file and enter the password
   - Name it "FabricCapacityAutomation-Cert"

## Troubleshooting Authentication Issues

If runbooks fail with authentication errors:

1. Check that the service principal exists and has a valid certificate
2. Verify the certificate is accessible to the runbook (either in Automation account or on Hybrid Worker)
3. Ensure the service principal has proper permissions on the Fabric capacity
4. Check if the tenant ID matches between the service principal and the subscription

You can view detailed logs in the Azure Portal under your Automation Account > Jobs.

## Using Managed Identity Instead

For an alternative approach that doesn't use certificates:

1. Enable System Assigned Managed Identity on your Automation Account
2. Assign "Contributor" role to the Managed Identity for your Fabric capacity
3. Modify the runbooks to use Managed Identity authentication

This requires modifying the runbook scripts but provides a simpler authentication method without certificate management. 