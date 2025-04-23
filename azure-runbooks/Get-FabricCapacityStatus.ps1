<#
.SYNOPSIS
    Gets the current status of a Microsoft Fabric capacity.

.DESCRIPTION
    This runbook gets the current status of a Microsoft Fabric capacity using the Microsoft Fabric API.
    It authenticates to Azure using managed identity.

.PARAMETER CapacityId
    The ID of the Microsoft Fabric capacity to get the status of.
    This should be in the format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Fabric/capacities/{capacityName}

.PARAMETER IncludeDetails
    Whether to include additional details about the capacity in the output. Default: $true

.NOTES
    Author: Premier Forge
    Created: 2025-03-03
    Version: 2.0
    Updated: 2025-04-03 - Migrated to managed identity authentication
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$CapacityId,

    [Parameter(Mandatory = $false)]
    [bool]$IncludeDetails = $true
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

# Function to get the capacity
function Get-Capacity {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$CapacityName
    )
    
    try {
        # Get the capacity
        $apiVersion = "2023-11-01"
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Fabric/capacities/$CapacityName`?api-version=$apiVersion"
        
        $capacity = Invoke-RestMethod -Uri $uri -Method Get -Headers @{
            "Authorization" = "Bearer $script:accessToken"
            "Content-Type" = "application/json"
        }
        
        return $capacity
    }
    catch {
        Write-Log "Failed to get capacity: $_" -Level "Error"
        throw
    }
}

# Function to format the capacity status
function Format-CapacityStatus {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Capacity,
        
        [Parameter(Mandatory = $true)]
        [bool]$IncludeDetails
    )
    
    try {
        # Get basic status information
        $name = $Capacity.name
        $state = $Capacity.properties.state
        $sku = $Capacity.sku.name
        
        # Map the SKU to a friendly name
        $pricingTier = switch ($sku) {
            "F2" { "Fabric Capacity (F2)" }
            "F4" { "Fabric Capacity (F4)" }
            "F8" { "Fabric Capacity (F8)" }
            "F16" { "Fabric Capacity (F16)" }
            "F32" { "Fabric Capacity (F32)" }
            "F64" { "Fabric Capacity (F64)" }
            "F128" { "Fabric Capacity (F128)" }
            "F256" { "Fabric Capacity (F256)" }
            "F512" { "Fabric Capacity (F512)" }
            "F1024" { "Fabric Capacity (F1024)" }
            default { "Unknown ($sku)" }
        }
        
        # Create the result object
        $result = @{
            CapacityName = $name
            Status = $state
            SKU = $sku
            PricingTier = $pricingTier
            LastChecked = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        # Include additional details if requested
        if ($IncludeDetails) {
            $result.SubscriptionId = $Capacity.id.Split('/')[2]
            $result.ResourceGroup = $Capacity.id.Split('/')[4]
            $result.Region = $Capacity.location
            $result.ProvisioningState = $Capacity.properties.provisioningState
            $result.AdminEmails = $Capacity.properties.administration.emails -join ';'
        }
        
        return $result
    }
    catch {
        Write-Log "Failed to format capacity status: $_" -Level "Error"
        throw
    }
}

# Main execution
try {
    # Import required modules
    Write-Log "Importing required modules..."
    Import-Module Az.Accounts -ErrorAction Stop
    
    # Parse the capacity ID
    $capacityDetails = Get-CapacityDetails -CapacityId $CapacityId
    $subscriptionId = $capacityDetails.SubscriptionId
    $resourceGroupName = $capacityDetails.ResourceGroupName
    $capacityName = $capacityDetails.CapacityName
    
    Write-Log "Getting status for capacity: $capacityName in resource group: $resourceGroupName"
    
    # Connect to Azure using managed identity
    Write-Log "Connecting to Azure using managed identity..."
    
    # Get an access token
    $azContext = Connect-AzAccount -Identity
    
    # Handle both current string token and future SecureString token formats
    $tokenResponse = Get-AzAccessToken -ResourceUrl "https://management.azure.com/"
    if ($tokenResponse.Token -is [System.Security.SecureString]) {
        # Convert SecureString to plain text (for newer Az module versions)
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenResponse.Token)
        $script:accessToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    } else {
        # Use as-is for current Az module versions
        $script:accessToken = $tokenResponse.Token
    }
    
    # Get the capacity
    $capacity = Get-Capacity -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -CapacityName $capacityName
    
    # Format the status
    $result = Format-CapacityStatus -Capacity $capacity -IncludeDetails $IncludeDetails
    
    # Return the result
    return $result | ConvertTo-Json -Depth 5
}
catch {
    Write-Log "An error occurred: $_" -Level "Error"
    
    # If the capacity doesn't exist or can't be accessed, return a standard error result
    if ($_.Exception.Response.StatusCode -eq 404) {
        $result = @{
            CapacityName = $capacityName
            Status = "NotFound"
            Error = "Capacity not found"
            LastChecked = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        return $result | ConvertTo-Json -Depth 5
    }
    else {
        throw
    }
}
