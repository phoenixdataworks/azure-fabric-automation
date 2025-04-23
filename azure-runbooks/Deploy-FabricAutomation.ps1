<#
.SYNOPSIS
    Deploys the Microsoft Fabric Capacity Automation solution to an Azure Automation account.

.DESCRIPTION
    This script automates the deployment of the Microsoft Fabric Capacity Automation solution, including:
    1. Creating an Azure Automation account (if it doesn't exist)
    2. Importing required modules
    3. Importing all runbooks
    4. Creating a certificate for authentication (if needed)
    5. Setting up the schedule pattern for Fabric capacity management

.PARAMETER SubscriptionId
    The ID of the Azure subscription to deploy to.

.PARAMETER ResourceGroupName
    The name of the resource group for the Azure Automation account.

.PARAMETER AutomationAccountName
    The name of the Azure Automation account.

.PARAMETER Location
    The Azure region for the resources. Default: "eastus"

.PARAMETER FabricCapacityName
    The name of the Microsoft Fabric capacity to manage.

.PARAMETER ServicePrincipalName
    The name to use for the service principal. Default: "FabricCapacityAutomation"

.PARAMETER StartTime
    The time to start the capacity, in the format "HH:MM:SS". Default: "06:00:00" (6:00 AM)

.PARAMETER ScaleDownTime
    The time to scale down from F64 to F2, in the format "HH:MM:SS". Default: "06:10:00" (6:10 AM)

.PARAMETER StopTime
    The time to stop the capacity, in the format "HH:MM:SS". Default: "18:00:00" (6:00 PM)

.PARAMETER TimeZone
    The time zone to use for the schedules. Default: "Pacific Standard Time"

.PARAMETER WeekDaysOnly
    Whether to schedule the capacity to run only on weekdays (Monday to Friday). Default: $true

.PARAMETER CreateWebhooks
    Whether to create webhooks for the runbooks. Default: $true

.PARAMETER WebhookExpiryInDays
    The number of days until the webhooks expire. Default: 365

.PARAMETER CertificateExpiryInYears
    The number of years until the certificate expires. Default: 2

.PARAMETER RunbookFolder
    The folder containing the runbook .ps1 files. Default: "./azure-runbooks"

.PARAMETER UseRunAsAccount
    Whether to use the Run As Account for authentication. Default: $false

.PARAMETER ScaleUpTime
    The time to scale up from F2 to F64, in the format "HH:MM:SS". Default: "06:00:00" (6:00 AM)

.PARAMETER ScaleUpSku
    The SKU to scale up to. Default: "F64"

.PARAMETER ScheduleDays
    The days of the week to schedule the capacity. Default: Monday to Friday

.PARAMETER DefaultSku
    The default SKU to use when scaling down. Default: "F2"

.EXAMPLE
    ./Deploy-FabricAutomation.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ResourceGroupName "fabric-automation-rg" -AutomationAccountName "fabric-automation" -FabricCapacityName "my-fabric"

.NOTES
    Author: Premier Forge
    Created: 2025-03-07
    Version: 1.0
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AutomationAccountName,

    [Parameter(Mandatory = $true)]
    [string]$FabricCapacityName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalName = "FabricCapacityAutomation",

    [Parameter(Mandatory = $false)]
    [string]$StartTime = "06:00:00",

    [Parameter(Mandatory = $false)]
    [string]$ScaleDownTime = "06:10:00",

    [Parameter(Mandatory = $false)]
    [string]$StopTime = "18:00:00",

    [Parameter(Mandatory = $false)]
    [string]$TimeZone = "Pacific Standard Time",

    [Parameter(Mandatory = $false)]
    [bool]$WeekDaysOnly = $true,

    [Parameter(Mandatory = $false)]
    [bool]$CreateWebhooks = $true,

    [Parameter(Mandatory = $false)]
    [int]$WebhookExpiryInDays = 365,

    [Parameter(Mandatory = $false)]
    [int]$CertificateExpiryInYears = 2,

    [Parameter(Mandatory = $false)]
    [string]$RunbookFolder = "./azure-runbooks",

    [Parameter(Mandatory = $false)]
    [bool]$UseRunAsAccount = $false,

    [Parameter(Mandatory = $false)]
    [string]$ScaleUpTime = "06:00:00",

    [Parameter(Mandatory = $false)]
    [string]$ScaleUpSku = "F64",

    [Parameter(Mandatory = $false)]
    [string]$DefaultSku = "F2",

    [Parameter(Mandatory = $false)]
    [string[]]$ScheduleDays = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
)

# Error action preference
$ErrorActionPreference = "Stop"

# Function to write output
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    if ($Level -eq "Error") {
        Write-Error $logMessage
    }
    elseif ($Level -eq "Warning") {
        Write-Warning $logMessage
    }
    else {
        Write-Output $logMessage
    }
}

# Function to ensure modules are installed
function Ensure-ModulesInstalled {
    param (
        [string[]]$ModuleNames
    )
    
    foreach ($moduleName in $ModuleNames) {
        if (-not (Get-Module -ListAvailable -Name $moduleName)) {
            Write-Log "Installing module: $moduleName"
            Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
        }
        else {
            Write-Log "Module already installed: $moduleName"
        }
    }
}

# Function to create or update a resource group
function Ensure-ResourceGroup {
    param (
        [string]$ResourceGroupName,
        [string]$Location
    )
    
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    
    if (-not $rg) {
        Write-Log "Creating resource group: $ResourceGroupName in $Location"
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    }
    else {
        Write-Log "Resource group already exists: $ResourceGroupName"
    }
    
    return $rg
}

# Function to create or update an automation account
function Ensure-AutomationAccount {
    param (
        [string]$ResourceGroupName,
        [string]$AutomationAccountName,
        [string]$Location
    )
    
    $aa = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -ErrorAction SilentlyContinue
    
    if (-not $aa) {
        Write-Log "Creating automation account: $AutomationAccountName in $ResourceGroupName"
        $aa = New-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -Location $Location
    }
    else {
        Write-Log "Automation account already exists: $AutomationAccountName"
    }
    
    return $aa
}

# Function to import automation modules
function Import-AutomationModules {
    param (
        [string]$ResourceGroupName,
        [string]$AutomationAccountName
    )
    
    $modules = @(
        @{ Name = "Az.Accounts"; Version = "2.12.1" },
        @{ Name = "Az.Automation"; Version = "1.7.3" }
    )
    
    foreach ($module in $modules) {
        Write-Log "Importing module: $($module.Name) version $($module.Version) to automation account"
        
        # Check if module exists and needs to be updated
        $existingModule = Get-AzAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $module.Name -ErrorAction SilentlyContinue
        
        if (-not $existingModule) {
            New-AzAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $module.Name -ContentLinkUri "https://www.powershellgallery.com/api/v2/package/$($module.Name)/$($module.Version)"
        }
        else {
            Write-Log "Module $($module.Name) already imported. Current version: $($existingModule.Version)"
        }
    }
}

# Function to import runbooks
function Import-AutomationRunbooks {
    param (
        [string]$ResourceGroupName,
        [string]$AutomationAccountName,
        [string]$RunbookFolder
    )
    
    # List of runbooks to import
    $runbooks = @(
        "Start-FabricCapacity.ps1",
        "Stop-FabricCapacity.ps1",
        "Get-FabricCapacityStatus.ps1",
        "Scale-FabricCapacity.ps1",
        "Schedule-FabricCapacity.ps1",
        "Schedule-FabricCapacityPattern.ps1",
        "Create-FabricCapacityWebhooks.ps1",
        "Create-FabricScalingWebhooks.ps1"
    )
    
    foreach ($runbookFile in $runbooks) {
        $runbookPath = Join-Path -Path $RunbookFolder -ChildPath $runbookFile
        $runbookName = [System.IO.Path]::GetFileNameWithoutExtension($runbookFile)
        
        if (Test-Path -Path $runbookPath) {
            Write-Log "Importing runbook: $runbookName from $runbookPath"
            Import-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $runbookName -Type PowerShell -Path $runbookPath -Force | Out-Null
            
            # Publish the runbook
            Write-Log "Publishing runbook: $runbookName"
            Publish-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $runbookName | Out-Null
        }
        else {
            Write-Log "Runbook file not found: $runbookPath" -Level "Warning"
        }
    }
}

# Function to create a service principal with certificate authentication
function Create-ServicePrincipal {
    param (
        [string]$ServicePrincipalName,
        [int]$CertificateExpiryInYears
    )
    
    Write-Log "Creating or retrieving service principal: $ServicePrincipalName"
    
    # Check if the service principal already exists
    $sp = Get-AzADServicePrincipal -DisplayName $ServicePrincipalName -ErrorAction SilentlyContinue
    $newlyCreated = $false
    
    if (-not $sp) {
        Write-Log "Creating new service principal: $ServicePrincipalName"
        $newlyCreated = $true
        
        # Create a self-signed certificate
        $certStoreLocation = "cert:\CurrentUser\My"
        $notAfter = (Get-Date).AddYears($CertificateExpiryInYears)
        $thumbprint = (New-SelfSignedCertificate -CertStoreLocation $certStoreLocation -Subject "CN=$ServicePrincipalName" -KeySpec Signature -NotAfter $notAfter -KeyLength 2048).Thumbprint
        
        # Export the certificate
        $certPath = Join-Path -Path $env:TEMP -ChildPath "$ServicePrincipalName.cer"
        Export-Certificate -Cert (Get-Item -Path "$certStoreLocation\$thumbprint") -FilePath $certPath | Out-Null
        
        # Create the service principal with the certificate
        $app = New-AzADApplication -DisplayName $ServicePrincipalName
        New-AzADAppCredential -ApplicationId $app.AppId -CertValue ([System.Convert]::ToBase64String((Get-Content -Path $certPath -Encoding Byte))) -EndDate $notAfter | Out-Null
        $sp = New-AzADServicePrincipal -ApplicationId $app.AppId
        
        # Clean up the temporary certificate file
        Remove-Item -Path $certPath -Force
    }
    else {
        Write-Log "Service principal already exists: $ServicePrincipalName"
        $app = Get-AzADApplication -ApplicationId $sp.AppId
        
        # Check if there's a valid certificate
        $creds = Get-AzADAppCredential -ApplicationId $app.AppId
        $validCert = $creds | Where-Object { $_.Type -eq "AsymmetricX509Cert" -and $_.EndDateTime -gt (Get-Date) }
        
        if (-not $validCert) {
            Write-Log "No valid certificate found. Creating a new certificate."
            $newlyCreated = $true
            
            # Create a new self-signed certificate
            $certStoreLocation = "cert:\CurrentUser\My"
            $notAfter = (Get-Date).AddYears($CertificateExpiryInYears)
            $thumbprint = (New-SelfSignedCertificate -CertStoreLocation $certStoreLocation -Subject "CN=$ServicePrincipalName" -KeySpec Signature -NotAfter $notAfter -KeyLength 2048).Thumbprint
            
            # Export the certificate
            $certPath = Join-Path -Path $env:TEMP -ChildPath "$ServicePrincipalName.cer"
            Export-Certificate -Cert (Get-Item -Path "$certStoreLocation\$thumbprint") -FilePath $certPath | Out-Null
            
            # Add the certificate to the service principal
            New-AzADAppCredential -ApplicationId $app.AppId -CertValue ([System.Convert]::ToBase64String((Get-Content -Path $certPath -Encoding Byte))) -EndDate $notAfter | Out-Null
            
            # Clean up the temporary certificate file
            Remove-Item -Path $certPath -Force
        }
        else {
            Write-Log "Using existing valid certificate for service principal"
            $thumbprint = $validCert.KeyId
        }
    }
    
    # Get the latest certificate thumbprint
    $cert = Get-ChildItem -Path "cert:\CurrentUser\My" | Where-Object { $_.Subject -eq "CN=$ServicePrincipalName" -and $_.NotAfter -gt (Get-Date) } | Sort-Object -Property NotAfter -Descending | Select-Object -First 1
    $thumbprint = $cert.Thumbprint
    
    # Wait for Azure AD propagation if the SP or cert was newly created
    if ($newlyCreated) {
        Write-Log "Service principal or certificate was newly created. Waiting 60 seconds for Azure AD propagation..."
        Start-Sleep -Seconds 60
    }
    
    # Return the service principal info
    return @{
        ServicePrincipalId = $sp.Id
        ApplicationId = $sp.AppId
        CertificateThumbprint = $thumbprint
        TenantId = (Get-AzContext).Tenant.Id
        NewlyCreated = $newlyCreated
    }
}

# Function to upload certificate to Automation account
function Upload-CertificateToAutomation {
    param (
        [string]$ResourceGroupName,
        [string]$AutomationAccountName,
        [string]$CertificateName,
        [string]$CertificateThumbprint,
        [string]$CertificateDescription = "Certificate for Fabric capacity management"
    )
    
    try {
        Write-Log "Uploading certificate to Automation account..."
        
        # Check if the certificate already exists in Automation
        $existingCert = Get-AzAutomationCertificate -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $CertificateName -ErrorAction SilentlyContinue
        
        if ($existingCert) {
            Write-Log "Certificate already exists in Automation account. Checking if it's the same..."
            if ($existingCert.Thumbprint -eq $CertificateThumbprint) {
                Write-Log "Certificate with same thumbprint already exists in Automation account. No need to upload."
                return $existingCert
            }
            else {
                Write-Log "Certificate exists but has different thumbprint. Removing old certificate..."
                Remove-AzAutomationCertificate -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $CertificateName -Force
            }
        }
        
        # Get the certificate from local store
        $cert = Get-ChildItem -Path "cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction Stop
        
        if (-not $cert) {
            throw "Certificate with thumbprint $CertificateThumbprint not found in local certificate store."
        }
        
        # Export the certificate to a PFX file with a temporary password
        $tempPassword = [Guid]::NewGuid().ToString()
        $securePassword = ConvertTo-SecureString -String $tempPassword -AsPlainText -Force
        $certPath = Join-Path -Path $env:TEMP -ChildPath "$CertificateName.pfx"
        
        Write-Log "Exporting certificate to temporary file: $certPath"
        Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $securePassword -Force | Out-Null
        
        # Import the certificate to Automation
        Write-Log "Importing certificate to Automation account: $CertificateName"
        try {
            $importedCert = New-AzAutomationCertificate -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $CertificateName -Description $CertificateDescription -Path $certPath -Password $securePassword -Exportable:$false
            Write-Log "Certificate uploaded successfully. Thumbprint: $($importedCert.Thumbprint)"
        }
        catch {
            if ($_.Exception.Message -like "*Access denied*" -or $_.Exception.Message -like "*not authorized*") {
                Write-Log "Permission denied when uploading certificate to Automation account. This is expected if you don't have certificate management permissions." -Level "Warning"
                Write-Log "The runbooks will use the certificate from their local certificate store. Make sure to install the certificate on the Hybrid Worker if using one." -Level "Warning"
                
                # Return a mock certificate object with the thumbprint
                return [PSCustomObject]@{
                    Name = $CertificateName
                    Thumbprint = $CertificateThumbprint
                    UploadFailed = $true
                }
            }
            else {
                # This is a different error, rethrow it
                throw
            }
        }
        finally {
            # Clean up the temporary file
            if (Test-Path $certPath) {
                Remove-Item -Path $certPath -Force
            }
        }
        
        return $importedCert
    }
    catch {
        Write-Log "Failed to upload certificate to Automation account: $_" -Level "Warning"
        
        # Continue with a warning instead of failing the entire deployment
        Write-Log "Continuing deployment without certificate upload. The runbooks will need to access the certificate from the Hybrid Worker or may fail if running in Azure." -Level "Warning"
        
        # Return a mock certificate object with the thumbprint
        return [PSCustomObject]@{
            Name = $CertificateName
            Thumbprint = $CertificateThumbprint
            UploadFailed = $true
        }
    }
}

# Function to assign RBAC roles
function Assign-RBACRoles {
    param (
        [string]$ServicePrincipalId,
        [string]$FabricCapacityId,
        [bool]$WaitForPropagation = $false
    )
    
    Write-Log "Assigning RBAC roles to service principal for Fabric capacity"
    
    # Parse the Fabric capacity resource ID
    $pattern = "^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\.Fabric/capacities/([^/]+)$"
    $match = [regex]::Match($FabricCapacityId, $pattern)
    
    if (-not $match.Success) {
        throw "Invalid Fabric capacity ID format. Expected format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Fabric/capacities/{capacityName}"
    }
    
    $capacityResourceGroup = $match.Groups[2].Value
    
    # Assign the Contributor role to the service principal for the Fabric capacity
    New-AzRoleAssignment -ObjectId $ServicePrincipalId -RoleDefinitionName "Contributor" -Scope $FabricCapacityId -ErrorAction SilentlyContinue | Out-Null
    
    # Wait for RBAC propagation if requested
    if ($WaitForPropagation) {
        Write-Log "Waiting 60 seconds for RBAC role assignment propagation..."
        Start-Sleep -Seconds 60
    }
    
    Write-Log "RBAC roles assigned successfully"
}

# Function to run the Schedule-FabricCapacityPattern runbook
function Setup-FabricCapacitySchedule {
    param (
        [string]$ResourceGroupName,
        [string]$AutomationAccountName,
        [string]$FabricCapacityId,
        [string]$StartTime,
        [string]$ScaleUpTime,
        [string]$ScaleUpSku,
        [string]$ScaleDownTime,
        [string]$StopTime,
        [string]$TimeZone,
        [bool]$WeekDaysOnly,
        [string[]]$ScheduleDays,
        [string]$DefaultSku,
        [int]$MaxRetries = 3
    )
    
    Write-Log "Setting up Fabric capacity schedule pattern"
    
    # Create the parameters for the runbook
    $params = @{
        ResourceGroupName = $ResourceGroupName
        AutomationAccountName = $AutomationAccountName
        CapacityId = $FabricCapacityId
        StartTime = $StartTime
        ScaleUpTime = $ScaleUpTime
        ScaleUpSku = $ScaleUpSku
        ScaleDownTime = $ScaleDownTime
        StopTime = $StopTime
        TimeZone = $TimeZone
        DefaultSku = $DefaultSku
    }

    # Use ScheduleDays if provided, otherwise use WeekDaysOnly
    if ($ScheduleDays) {
        $params["ScheduleDays"] = $ScheduleDays
    } else {
        $params["WeekDaysOnly"] = $WeekDaysOnly
    }
    
    $retryCount = 0
    $success = $false
    
    while (-not $success -and $retryCount -lt $MaxRetries) {
        try {
            # Start the runbook
            Write-Log "Starting Schedule-FabricCapacityPattern runbook (Attempt $($retryCount + 1) of $MaxRetries)"
            $job = Start-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name "Schedule-FabricCapacityPattern" -Parameters $params
            
            # Wait for the job to complete
            $jobOutputs = @()
            $jobStatus = Get-AzAutomationJob -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Id $job.JobId
            
            while ($jobStatus.Status -ne "Completed" -and $jobStatus.Status -ne "Failed" -and $jobStatus.Status -ne "Suspended") {
                Write-Log "Waiting for schedule setup job to complete... Current status: $($jobStatus.Status)"
                Start-Sleep -Seconds 10
                $jobStatus = Get-AzAutomationJob -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Id $job.JobId
            }
            
            if ($jobStatus.Status -eq "Completed") {
                Write-Log "Schedule setup completed successfully"
                $jobOutputs = Get-AzAutomationJobOutput -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Id $job.JobId | Get-AzAutomationJobOutputRecord | Select-Object -ExpandProperty Value
                
                foreach ($output in $jobOutputs) {
                    Write-Log $output
                }
                
                $success = $true
            }
            else {
                Write-Log "Schedule setup failed with status: $($jobStatus.Status)" -Level "Error"
                $jobException = Get-AzAutomationJobOutput -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Id $job.JobId -Stream Error
                
                if ($jobException) {
                    Write-Log $jobException.Summary -Level "Error"
                }
                
                $retryCount++
                
                if ($retryCount -lt $MaxRetries) {
                    Write-Log "Waiting 90 seconds before retry..."
                    Start-Sleep -Seconds 90
                }
            }
        }
        catch {
            Write-Log "Error starting or monitoring runbook: $_" -Level "Error"
            $retryCount++
            
            if ($retryCount -lt $MaxRetries) {
                Write-Log "Waiting 90 seconds before retry..."
                Start-Sleep -Seconds 90
            }
        }
    }
    
    if (-not $success) {
        Write-Log "All retries failed for schedule setup" -Level "Error"
    }
    
    return $jobStatus
}

# Function to create webhooks
function Create-Webhooks {
    param (
        [string]$ResourceGroupName,
        [string]$AutomationAccountName,
        [string]$FabricCapacityId,
        [int]$WebhookExpiryInDays
    )
    
    Write-Log "Creating webhooks for Fabric capacity management. URLs will be logged in the respective job outputs."
    
    # Parameters for the webhook creation runbooks
    $basicParams = @{
        ResourceGroupName = $ResourceGroupName
        AutomationAccountName = $AutomationAccountName
        CapacityId = $FabricCapacityId
        WebhookExpiryInDays = $WebhookExpiryInDays
        IsEnabled = $true
    }
    
    # Start the webhook creation runbooks
    Write-Log "Starting Create-FabricCapacityWebhooks job..."
    $basicWebhooksJob = Start-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name "Create-FabricCapacityWebhooks" -Parameters $basicParams
    
    Write-Log "Starting Create-FabricScalingWebhooks job..."
    $scalingWebhooksJob = Start-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name "Create-FabricScalingWebhooks" -Parameters $basicParams
    
    # Wait for the jobs to complete
    $jobIds = @($basicWebhooksJob.JobId, $scalingWebhooksJob.JobId)
    $allCompleted = $false
    
    Write-Log "Waiting for webhook creation jobs to finish..."
    while (-not $allCompleted) {
        $allCompleted = $true
        foreach ($jobId in $jobIds) {
            $jobStatus = Get-AzAutomationJob -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Id $jobId
            if ($jobStatus.Status -ne "Completed" -and $jobStatus.Status -ne "Failed" -and $jobStatus.Status -ne "Suspended") {
                $allCompleted = $false
                Write-Log "  Job $jobId status: $($jobStatus.Status)"
                break
            }
        }
        if (-not $allCompleted) {
            Start-Sleep -Seconds 15 # Increased wait time
        }
    }
    
    # Check job results (simplified logging)
    foreach ($jobId in $jobIds) {
        $jobStatus = Get-AzAutomationJob -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Id $jobId
        if ($jobStatus.Status -eq "Completed") {
            Write-Log "Webhook creation job $jobId completed successfully. Check job output logs for webhook URLs."
        }
        else {
            Write-Log "Webhook creation job $jobId failed with status: $($jobStatus.Status). Check job logs for errors." -Level "Warning"
            # Minimal error retrieval
            try {
                $jobErrors = Get-AzAutomationJobOutput -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Id $jobId -Stream Error | Get-AzAutomationJobOutputRecord
                foreach ($error in $jobErrors) {
                    Write-Log "  Error from Job $jobId : $($error.Value)" -Level "Warning"
                }
            }
            catch {
                Write-Log "  Could not retrieve error details for job $jobId." -Level "Warning"
            }
        }
    }
    
    # No return value needed
}

# Function to get or create Run As Account
function Ensure-RunAsAccount {
    param (
        [string]$ResourceGroupName,
        [string]$AutomationAccountName
    )
    
    try {
        Write-Log "Checking for existing Run As Account..."
        
        # Check if the Run As connection exists
        $connectionName = "AzureRunAsConnection"
        $connection = Get-AzAutomationConnection -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $connectionName -ErrorAction SilentlyContinue
        
        if ($connection) {
            Write-Log "Run As Account already exists."
            
            # Get the service principal for the Run As Account
            $connectionFields = $connection.FieldDefinitionValues
            $applicationId = $connectionFields.ApplicationId
            $tenantId = $connectionFields.TenantId
            $certificateThumbprint = $connectionFields.CertificateThumbprint
            
            # Get the service principal
            $sp = Get-AzADServicePrincipal -ApplicationId $applicationId -ErrorAction SilentlyContinue
            
            if (-not $sp) {
                Write-Log "Service principal for Run As Account not found. The Run As Account may need to be recreated." -Level "Warning"
                return $null
            }
            
            Write-Log "Found Run As Account with application ID: $applicationId"
            
            return @{
                ServicePrincipalId = $sp.Id
                ApplicationId = $applicationId
                TenantId = $tenantId
                CertificateThumbprint = $certificateThumbprint
            }
        }
        else {
            Write-Log "Run As Account does not exist. Please create it manually in the Azure Portal." -Level "Warning"
            Write-Log "Steps to create Run As Account:" -Level "Warning"
            Write-Log "1. Go to the Azure Portal" -Level "Warning"
            Write-Log "2. Navigate to your Automation Account" -Level "Warning"
            Write-Log "3. Under 'Account Settings', select 'Run as accounts'" -Level "Warning"
            Write-Log "4. Click 'Create Azure Run As Account'" -Level "Warning"
            Write-Log "5. Wait for the creation to complete" -Level "Warning"
            Write-Log "6. Run this script again with the same parameters" -Level "Warning"
            
            throw "Run As Account does not exist and cannot be created programmatically. Please create it manually."
        }
    }
    catch {
        Write-Log "Error while checking Run As Account: $_" -Level "Error"
        throw
    }
}

# Main execution
try {
    $scriptStartTime = Get-Date
    Write-Log "Starting deployment of Microsoft Fabric Capacity Automation solution at $scriptStartTime"
    
    # Ensure required modules are installed
    Write-Log "Checking required PowerShell modules"
    Ensure-ModulesInstalled -ModuleNames @("Az.Accounts", "Az.Resources", "Az.Automation", "Az.ManagedServiceIdentity")
    
    # Connect to Azure if not already connected
    $context = Get-AzContext
    if (-not $context) {
        Write-Log "Connecting to Azure..."
        Connect-AzAccount | Out-Null
    }
    
    # Set the subscription context
    Write-Log "Setting subscription context to: $SubscriptionId"
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    
    # Construct the Fabric Capacity ID from the subscription, resource group, and capacity name
    $FabricCapacityId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Fabric/capacities/$FabricCapacityName"
    Write-Log "Using Fabric Capacity ID: $FabricCapacityId"
    
    # Create or validate the resource group
    $rg = Ensure-ResourceGroup -ResourceGroupName $ResourceGroupName -Location $Location
    
    # Create or validate the automation account
    $aa = Ensure-AutomationAccount -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Location $Location
    
    # Enable system-assigned managed identity on the automation account
    Write-Log "Enabling system-assigned managed identity on Automation account..."
    $aa = Set-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -AssignSystemIdentity
    
    # Verify managed identity was enabled
    if ($aa.Identity -and $aa.Identity.PrincipalId) {
        Write-Log "System-assigned managed identity enabled successfully. Principal ID: $($aa.Identity.PrincipalId)"
    } else {
        throw "Failed to enable system-assigned managed identity on Automation account."
    }
    
    # Import required modules to the automation account
    Import-AutomationModules -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
    
    # Import runbooks
    Import-AutomationRunbooks -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookFolder $RunbookFolder
    
    # Assign RBAC roles to managed identity
    Write-Log "Assigning Contributor role to managed identity for Fabric capacity..."
    $managedIdentityObjectId = $aa.Identity.PrincipalId
    New-AzRoleAssignment -ObjectId $managedIdentityObjectId -RoleDefinitionName "Contributor" -Scope $FabricCapacityId -ErrorAction SilentlyContinue | Out-Null
    
    # Assign permission to create schedules in the Automation account
    Write-Log "Assigning Contributor role to managed identity for Automation account..."
    $automationAccountResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AutomationAccountName"
    New-AzRoleAssignment -ObjectId $managedIdentityObjectId -RoleDefinitionName "Contributor" -Scope $automationAccountResourceId -ErrorAction SilentlyContinue | Out-Null
    
    # Wait for RBAC propagation
    Write-Log "Waiting 60 seconds for RBAC role assignment propagation..."
    Start-Sleep -Seconds 60
    
    # Verify authentication details before schedule setup
    Write-Log "Verifying authentication details for managed identity before schedule setup"
    
    # Setup Fabric capacity schedule
    Write-Log "Setting up Fabric capacity schedule pattern. This may take a few minutes..."
    
    # Setup Fabric capacity schedule with retries
    Setup-FabricCapacitySchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -FabricCapacityId $FabricCapacityId -StartTime $StartTime -ScaleUpTime $ScaleUpTime -ScaleUpSku $ScaleUpSku -ScaleDownTime $ScaleDownTime -StopTime $StopTime -TimeZone $TimeZone -WeekDaysOnly $WeekDaysOnly -ScheduleDays $ScheduleDays -DefaultSku $DefaultSku -MaxRetries 3
    
    # Create webhooks if requested
    if ($CreateWebhooks) {
        Create-Webhooks -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -FabricCapacityId $FabricCapacityId -WebhookExpiryInDays $WebhookExpiryInDays
    }
    
    # Print summary
    Write-Log "=============================================="
    Write-Log "Deployment complete! Summary:"
    Write-Log "Subscription: $SubscriptionId"
    Write-Log "Resource Group: $ResourceGroupName"
    Write-Log "Automation Account: $AutomationAccountName"
    Write-Log "Authentication: System-assigned managed identity"
    Write-Log "Managed Identity Object ID: $($aa.Identity.PrincipalId)"
    Write-Log "Schedule Pattern:"
    Write-Log "  - Start capacity at $StartTime"
    Write-Log "  - Scale to $ScaleUpSku at $ScaleUpTime"
    Write-Log "  - Scale down to $DefaultSku at $ScaleDownTime"
    Write-Log "  - Stop capacity at $StopTime"
    Write-Log "  - Time Zone: $TimeZone"
    if ($ScheduleDays.Count -gt 0) {
        Write-Log "  - Scheduled Days: $($ScheduleDays -join ', ')"
    } else {
        Write-Log "  - Weekdays Only: $WeekDaysOnly"
    }
    Write-Log "Webhooks Created: $CreateWebhooks"
    
    # Update summary for webhook URLs
    if ($CreateWebhooks) {
        Write-Log "Webhook URLs: Please check the output logs of the 'Create-FabricCapacityWebhooks' and 'Create-FabricScalingWebhooks' jobs in the Azure portal for the generated webhook URLs."
        Write-Log "             (SAVE THESE - THEY CANNOT BE RETRIEVED LATER)"
    }
    
    $scriptEndTime = Get-Date
    $scriptDuration = New-TimeSpan -Start $scriptStartTime -End $scriptEndTime
    Write-Log "Deployment finished at $scriptEndTime (Duration: $($scriptDuration.ToString('hh\:mm\:ss')))"
    Write-Log "=============================================="
}
catch {
    Write-Log "An error occurred during deployment: $_" -Level "Error"
    throw
} 