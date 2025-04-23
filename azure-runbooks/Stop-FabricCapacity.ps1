<#
.SYNOPSIS
    Stops (pauses) a running Microsoft Fabric capacity.

.DESCRIPTION
    This runbook stops (pauses) a running Microsoft Fabric capacity using the Microsoft Fabric API.
    It authenticates to Azure using managed identity.

.PARAMETER CapacityId
    The ID of the Microsoft Fabric capacity to stop.
    This should be in the format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Fabric/capacities/{capacityName}

.PARAMETER WaitForCompletion
    Whether to wait for the capacity to be fully stopped before returning. Default: $true

.PARAMETER TimeoutInMinutes
    The maximum time to wait for the capacity to stop, in minutes. Default: 10

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
    [bool]$WaitForCompletion = $true,

    [Parameter(Mandatory = $false)]
    [int]$TimeoutInMinutes = 10
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

# Function to get the capacity status
function Get-CapacityStatus {
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
        
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers @{
            "Authorization" = "Bearer $script:accessToken"
            "Content-Type" = "application/json"
        }
        
        return $response
    }
    catch {
        Write-Log "Failed to get capacity status: $_" -Level "Error"
        throw
    }
}

# Function to stop the capacity
function Stop-Capacity {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$CapacityName
    )
    
    try {
        # Stop the capacity
        $apiVersion = "2023-11-01"
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Fabric/capacities/$CapacityName/suspend`?api-version=$apiVersion"
        
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers @{
            "Authorization" = "Bearer $script:accessToken"
            "Content-Type" = "application/json"
        }
        
        return $response
    }
    catch {
        Write-Log "Failed to stop capacity: $_" -Level "Error"
        throw
    }
}

# Function to wait for the capacity to stop
function Wait-ForCapacityStop {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$CapacityName,
        
        [Parameter(Mandatory = $true)]
        [int]$TimeoutInMinutes
    )
    
    try {
        $timeout = (Get-Date).AddMinutes($TimeoutInMinutes)
        $status = $null
        $isStopped = $false
        $validTransitionStates = @("Stopping", "Suspending", "PreparingForPause")
        $runningStates = @("Running", "Active")
        
        Write-Log "Waiting for capacity to stop..."
        
        while ((Get-Date) -lt $timeout -and -not $isStopped) {
            $capacity = Get-CapacityStatus -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -CapacityName $CapacityName
            $status = $capacity.properties.state
            
            if ($status -eq "Paused") {
                $isStopped = $true
                Write-Log "Capacity is now paused."
            }
            elseif ($runningStates -contains $status) {
                Write-Log "Capacity still shows as $status. Waiting for state transition to begin..."
                Start-Sleep -Seconds 60  # Longer delay if still showing a running state
            }
            elseif ($validTransitionStates -contains $status) {
                Write-Log "Capacity is in transitional state: $status. Continuing to wait..."
                Start-Sleep -Seconds 30
            }
            else {
                Write-Log "Current status: $status. Waiting 30 seconds..."
                Start-Sleep -Seconds 30
            }
        }
        
        if (-not $isStopped) {
            Write-Log "Timeout waiting for capacity to stop. Last status: $status" -Level "Warning"
        }
        
        return $isStopped
    }
    catch {
        Write-Log "Error waiting for capacity to stop: $_" -Level "Error"
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
    
    Write-Log "Stopping capacity: $capacityName in resource group: $resourceGroupName"
    
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
    
    # Get the current status
    $capacity = Get-CapacityStatus -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -CapacityName $capacityName
    $currentStatus = $capacity.properties.state
    
    Write-Log "Current capacity status: $currentStatus"
    
    # Check if the capacity is already paused
    if ($currentStatus -eq "Paused") {
        Write-Log "Capacity is already paused. No action needed."
        
        # Return the capacity details
        $result = @{
            CapacityName = $capacityName
            Status = $currentStatus
            SubscriptionId = $subscriptionId
            ResourceGroup = $resourceGroupName
            Region = $capacity.location
            SKU = $capacity.sku.name
            LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        return $result | ConvertTo-Json -Depth 5
    }
    
    # Stop the capacity if it's in Running or Active state
    if ($currentStatus -eq "Running" -or $currentStatus -eq "Active") {
        Write-Log "Stopping capacity from state: $currentStatus..."
        $stopResponse = Stop-Capacity -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -CapacityName $capacityName
        
        # Add initial delay to allow the capacity to begin transitioning states
        Write-Log "Waiting 30 seconds for capacity state transition to begin..."
        Start-Sleep -Seconds 30
    }
    else {
        Write-Log "Capacity is in state $currentStatus, which is not a running state. No stop action needed."
        
        # Return the capacity details
        $result = @{
            CapacityName = $capacityName
            Status = $currentStatus
            SubscriptionId = $subscriptionId
            ResourceGroup = $resourceGroupName
            Region = $capacity.location
            SKU = $capacity.sku.name
            LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        return $result | ConvertTo-Json -Depth 5
    }
    
    # Wait for the capacity to stop if requested
    $finalStatus = $currentStatus
    if ($WaitForCompletion) {
        $isStopped = Wait-ForCapacityStop -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -CapacityName $capacityName -TimeoutInMinutes $TimeoutInMinutes
        
        if ($isStopped) {
            $finalStatus = "Paused"
        }
        else {
            $finalStatus = "Stopping"
        }
    }
    else {
        $finalStatus = "Stopping"
    }
    
    # Get the updated capacity details
    $capacity = Get-CapacityStatus -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -CapacityName $capacityName
    
    # Return the capacity details
    $result = @{
        CapacityName = $capacityName
        Status = $finalStatus
        SubscriptionId = $subscriptionId
        ResourceGroup = $resourceGroupName
        Region = $capacity.location
        SKU = $capacity.sku.name
        LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    return $result | ConvertTo-Json -Depth 5
}
catch {
    Write-Log "An error occurred: $_" -Level "Error"
    throw
}
