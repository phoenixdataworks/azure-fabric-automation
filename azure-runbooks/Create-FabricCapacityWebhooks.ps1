<#
.SYNOPSIS
    Creates webhooks for the Fabric capacity management runbooks.

.DESCRIPTION
    This runbook creates webhooks for the Start-FabricCapacity, Stop-FabricCapacity, and Get-FabricCapacityStatus runbooks in Azure Automation.
    These webhooks can be used to trigger the runbooks from external systems like Power BI.
    It uses managed identity for authentication.

.PARAMETER ResourceGroupName
    The name of the resource group containing the Azure Automation account.

.PARAMETER AutomationAccountName
    The name of the Azure Automation account.

.PARAMETER CapacityId
    The ID of the Microsoft Fabric capacity to manage.
    This should be in the format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Fabric/capacities/{capacityName}

.PARAMETER WebhookExpiryInDays
    The number of days until the webhooks expire. Default: 365

.PARAMETER IsEnabled
    Indicates whether the webhook is enabled. Default: $true

.NOTES
    Author: Premier Forge
    Created: 2025-03-03
    Version: 2.0
    Updated: 2025-04-03 - Migrated to managed identity authentication
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AutomationAccountName,

    [Parameter(Mandatory = $true)]
    [string]$CapacityId,

    [Parameter(Mandatory = $false)]
    [int]$WebhookExpiryInDays = 365,
    
    [Parameter(Mandatory = $false)]
    [bool]$IsEnabled = $true
)

# Error action preference
$ErrorActionPreference = "Stop"
$ConfirmPreference = "None"
$ProgressPreference = "SilentlyContinue"

# Suppress confirmation prompts globally
$PSDefaultParameterValues = @{
    "*-Az*:Confirm" = $false
    "New-AzAutomationWebhook:Confirm" = $false
}

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

# Function to parse the capacity ID
function Get-CapacityDetails {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CapacityId
    )
    
    try {
        # Parse the capacity ID
        $pattern = "^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\.Fabric/capacities/([^/]+)$"
        $match = [regex]::Match($CapacityId, $pattern)
        
        if (-not $match.Success) {
            throw "Invalid capacity ID format. Expected format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Fabric/capacities/{capacityName}"
        }
        
        $subscriptionId = $match.Groups[1].Value
        $resourceGroupName = $match.Groups[2].Value
        $capacityName = $match.Groups[3].Value
        
        return @{
            SubscriptionId = $subscriptionId
            ResourceGroupName = $resourceGroupName
            CapacityName = $capacityName
        }
    }
    catch {
        Write-Log "Failed to parse capacity ID: $_" -Level "Error"
        throw
    }
}

# Function to create a webhook
function New-AutomationWebhook {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$AutomationAccountName,
        
        [Parameter(Mandatory = $true)]
        [string]$RunbookName,
        
        [Parameter(Mandatory = $true)]
        [string]$WebhookName,
        
        [Parameter(Mandatory = $true)]
        [int]$ExpiryInDays,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsEnabled = $true
    )
    
    try {
        Write-Log "Creating webhook: $WebhookName for runbook: $RunbookName"
        
        # Check if the webhook already exists
        $existingWebhook = Get-AzAutomationWebhook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $WebhookName -ErrorAction SilentlyContinue
        
        if ($existingWebhook) {
            Write-Log "Webhook already exists. Removing it..."
            Remove-AzAutomationWebhook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $WebhookName
        }
        
        # Create the webhook
        $expiryTime = (Get-Date).AddDays($ExpiryInDays)
        $webhook = New-AzAutomationWebhook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName $RunbookName -Name $WebhookName -ExpiryTime $expiryTime -Parameters $Parameters -IsEnabled $IsEnabled -Force
        
        return $webhook
    }
    catch {
        Write-Log "Failed to create webhook: $_" -Level "Error"
        throw
    }
}

# Main execution
try {
    # Import required modules
    Write-Log "Importing required modules..."
    Import-Module Az.Accounts -ErrorAction Stop
    Import-Module Az.Automation -ErrorAction Stop
    
    # Parse the capacity ID
    $capacityDetails = Get-CapacityDetails -CapacityId $CapacityId
    $capacityName = $capacityDetails.CapacityName
    
    Write-Log "Creating webhooks for capacity: $capacityName"
    
    # Connect to Azure using managed identity
    Write-Log "Connecting to Azure using managed identity..."
    Connect-AzAccount -Identity
    
    # Create the parameters that will be used for all webhooks
    $parameters = @{
        CapacityId = $CapacityId
    }
    
    # Create the webhooks for each runbook
    # $webhooks = @{} # No longer collecting for return
    
    # Start Capacity webhook
    $startWebhookName = "Start-$capacityName"
    $startWebhook = New-AutomationWebhook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName "Start-FabricCapacity" -WebhookName $startWebhookName -ExpiryInDays $WebhookExpiryInDays -Parameters $parameters -IsEnabled $IsEnabled
    Write-Log "---> Start Webhook URI: $($startWebhook.WebhookUri)" # Log URL directly
    # $webhooks["Start"] = @{ ... } # Remove collection
    
    # Stop Capacity webhook
    $stopWebhookName = "Stop-$capacityName"
    $stopWebhook = New-AutomationWebhook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName "Stop-FabricCapacity" -WebhookName $stopWebhookName -ExpiryInDays $WebhookExpiryInDays -Parameters $parameters -IsEnabled $IsEnabled
    Write-Log "---> Stop Webhook URI: $($stopWebhook.WebhookUri)" # Log URL directly
    # $webhooks["Stop"] = @{ ... } # Remove collection
    
    # Get Status webhook
    $statusWebhookName = "Status-$capacityName"
    $statusWebhook = New-AutomationWebhook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName "Get-FabricCapacityStatus" -WebhookName $statusWebhookName -ExpiryInDays $WebhookExpiryInDays -Parameters $parameters -IsEnabled $IsEnabled
    Write-Log "---> Status Webhook URI: $($statusWebhook.WebhookUri)" # Log URL directly
    # $webhooks["Status"] = @{ ... } # Remove collection
    
    Write-Log "Webhook creation process completed."
    # Remove final return statement
    # $result = @{ ... }
    # return $result | ConvertTo-Json -Depth 5
}
catch {
    Write-Log "An error occurred: $_" -Level "Error"
    throw
}
