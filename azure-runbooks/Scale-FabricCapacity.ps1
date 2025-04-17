<#
.SYNOPSIS
    Scales a Microsoft Fabric capacity to a different SKU.

.DESCRIPTION
    This runbook scales a Microsoft Fabric capacity to a different SKU using the Microsoft Fabric API.
    It authenticates to Azure using a managed identity.

.PARAMETER CapacityId
    The ID of the Microsoft Fabric capacity to scale.
    This should be in the format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Fabric/capacities/{capacityName}

.PARAMETER TargetSku
    The target SKU to scale to (F2, F4, F8, F16, F32, F64, F128, F256, F512, F1024).

.PARAMETER WaitForCompletion
    Whether to wait for the capacity to be fully scaled before returning. Default: $true

.PARAMETER TimeoutInMinutes
    The maximum time to wait for the capacity to scale, in minutes. Default: 10

.NOTES
    Author: Premier Forge
    Created: 2025-03-07
    Version: 2.0
    Updated: 2025-04-03 - Migrated to managed identity authentication
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$CapacityId,

    [Parameter(Mandatory = $true)]
    [ValidateSet("F2", "F4", "F8", "F16", "F32", "F64", "F128", "F256", "F512", "F1024")]
    [string]$TargetSku,

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

# Function to start the capacity
function Start-Capacity {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$CapacityName
    )
    
    try {
        # Start the capacity (resume endpoint)
        $apiVersion = "2023-11-01"
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Fabric/capacities/$CapacityName/resume`?api-version=$apiVersion"
        
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers @{
            "Authorization" = "Bearer $script:accessToken"
            "Content-Type" = "application/json"
        }
        
        return $response
    }
    catch {
        # Add specific error logging for starting
        Write-Log "Failed to send start (resume) request for capacity: $_" -Level "Error"
        throw
    }
}

# Function to scale the capacity
function Scale-Capacity {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$CapacityName,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetSku,
        
        [Parameter(Mandatory = $true)]
        [object]$CurrentCapacity
    )
    
    try {
        # Create the update payload
        $apiVersion = "2023-11-01"
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Fabric/capacities/$CapacityName`?api-version=$apiVersion"
        
        # Create a copy of the current capacity properties but update the SKU
        $updatePayload = @{
            location = $CurrentCapacity.location
            sku = @{
                name = $TargetSku
            }
            properties = $CurrentCapacity.properties
        }
        
        $jsonPayload = $updatePayload | ConvertTo-Json -Depth 10
        
        # Update the capacity
        $response = Invoke-RestMethod -Uri $uri -Method Put -Headers @{
            "Authorization" = "Bearer $script:accessToken"
            "Content-Type" = "application/json"
        } -Body $jsonPayload
        
        return $response
    }
    catch {
        Write-Log "Failed to scale capacity: $_" -Level "Error"
        throw
    }
}

# Function to wait for the capacity scaling to complete
function Wait-ForCapacityScaling {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$CapacityName,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetSku,
        
        [Parameter(Mandatory = $true)]
        [int]$TimeoutInMinutes
    )
    
    try {
        $timeout = (Get-Date).AddMinutes($TimeoutInMinutes)
        $status = $null
        $isScaled = $false
        $runningStates = @("Running", "Active") # Define target states
        
        Write-Log "Waiting for capacity to scale to $TargetSku..."
        
        while ((Get-Date) -lt $timeout -and -not $isScaled) {
            $capacity = Get-CapacityStatus -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -CapacityName $CapacityName
            $currentSku = $capacity.sku.name
            $state = $capacity.properties.state
            
            # Check if SKU matches AND state is Running or Active
            if ($currentSku -eq $TargetSku -and ($runningStates -contains $state)) {
                $isScaled = $true
                Write-Log "Capacity has been successfully scaled to $TargetSku and is in $state state."
            }
            else {
                Write-Log "Current SKU: $currentSku (Target: $TargetSku), Status: $state. Waiting 30 seconds..."
                Start-Sleep -Seconds 30
            }
        }
        
        if (-not $isScaled) {
            Write-Log "Timeout waiting for capacity to scale. Last SKU: $currentSku, Status: $state" -Level "Warning"
        }
        
        return $isScaled
    }
    catch {
        Write-Log "Error waiting for capacity to scale: $_" -Level "Error"
        throw
    }
}

# Function to wait for the capacity to start (copied from Start-FabricCapacity.ps1)
function Wait-ForCapacityStart {
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
        $isStarted = $false
        $validTransitionStates = @("Starting", "Resuming", "PreparingForRunning")
        $runningStates = @("Running", "Active")
        
        Write-Log "Waiting for capacity to start..."
        
        while ((Get-Date) -lt $timeout -and -not $isStarted) {
            # Use the same Get-CapacityStatus function defined earlier in this script
            $capacity = Get-CapacityStatus -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -CapacityName $CapacityName 
            $status = $capacity.properties.state
            
            if ($runningStates -contains $status) {
                $isStarted = $true
                Write-Log "Capacity is now $status. Proceeding with scaling."
            }
            elseif ($status -eq "Paused") {
                Write-Log "Capacity still shows as Paused. Waiting for state transition to begin..."
                Start-Sleep -Seconds 60
            }
            elseif ($validTransitionStates -contains $status) {
                Write-Log "Capacity is in transitional state: $status. Continuing to wait..."
                Start-Sleep -Seconds 30
            }
            else {
                Write-Log "Current status while waiting to start: $status. Waiting 30 seconds..."
                Start-Sleep -Seconds 30
            }
        }
        
        if (-not $isStarted) {
            # Warning instead of throwing an error immediately
            Write-Log "Timeout waiting for capacity to start before scaling attempt. Last status: $status" -Level "Warning"
        }
        
        return $isStarted
    }
    catch {
        Write-Log "Error waiting for capacity to start: $_" -Level "Error"
        # Don't re-throw here, let the main logic decide based on the return value
        return $false 
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
    
    Write-Log "Scaling capacity: $capacityName in resource group: $resourceGroupName to SKU: $TargetSku"
    
    # Connect to Azure using managed identity
    Write-Log "Connecting to Azure using managed identity..."
    $azContext = Connect-AzAccount -Identity
    
    # Get an access token using managed identity
    $script:accessToken = (Get-AzAccessToken -ResourceUrl "https://management.azure.com/").Token
    
    # Get the current status
    $capacity = Get-CapacityStatus -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -CapacityName $capacityName
    $currentStatus = $capacity.properties.state
    $currentSku = $capacity.sku.name
    
    Write-Log "Current capacity status: $currentStatus, SKU: $currentSku"
    
    # Check if the capacity is already at the target SKU
    if ($currentSku -eq $TargetSku) {
        Write-Log "Capacity is already at the target SKU ($TargetSku). No action needed."
        
        # Return the capacity details
        $result = @{
            CapacityName = $capacityName
            Status = $currentStatus
            SubscriptionId = $subscriptionId
            ResourceGroup = $resourceGroupName
            Region = $capacity.location
            SKU = $currentSku
            LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Message = "No scaling needed - already at target SKU"
        }
        
        return $result | ConvertTo-Json -Depth 5
    }
    
    # Check if the capacity is running (needs to be running or active to scale)
    $runningStates = @("Running", "Active")
    if (-not ($runningStates -contains $currentStatus)) {
        Write-Log "Capacity is not in a running/active state ($currentStatus). Starting the capacity first..."
        
        # Use the Start-Capacity function
        $startResponse = Start-Capacity -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -CapacityName $capacityName
        
        # Add initial delay (consistent with Start-FabricCapacity.ps1)
        Write-Log "Waiting 30 seconds for capacity state transition to begin..."
        Start-Sleep -Seconds 30
        
        # Wait for the capacity to start before scaling
        if ($WaitForCompletion) {
            # Use the Wait-ForCapacityStart function (adjust timeout maybe? Using half for now)
            $isStarted = Wait-ForCapacityStart -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -CapacityName $capacityName -TimeoutInMinutes ($TimeoutInMinutes / 2)
            
            if (-not $isStarted) {
                # Handle failure to start - maybe exit or throw a more specific error
                throw "Capacity did not reach a running/active state within the allocated time after starting. Cannot proceed with scaling."
            }
            # Refresh capacity status after successful start
            $capacity = Get-CapacityStatus -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -CapacityName $capacityName
            $currentStatus = $capacity.properties.state
            $currentSku = $capacity.sku.name
            Write-Log "Capacity successfully started. Current status: $currentStatus, SKU: $currentSku"
        }
        else {
            # If not waiting, we cannot guarantee it started, so we should probably exit.
            throw "Capacity was not running/active and WaitForCompletion for starting was set to false. Cannot proceed with scaling."
        }
    }
    
    # Scale the capacity
    Write-Log "Scaling capacity from $currentSku to $TargetSku..."
    $scaleResponse = Scale-Capacity -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -CapacityName $capacityName -TargetSku $TargetSku -CurrentCapacity $capacity
    
    # Wait for the scaling to complete if requested
    $finalStatus = $currentStatus
    $finalSku = $currentSku
    if ($WaitForCompletion) {
        $isScaled = Wait-ForCapacityScaling -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -CapacityName $capacityName -TargetSku $TargetSku -TimeoutInMinutes $TimeoutInMinutes
        
        if ($isScaled) {
            $finalStatus = "Running"
            $finalSku = $TargetSku
        }
        else {
            $finalStatus = "Scaling"
            $finalSku = "Scaling to $TargetSku"
        }
    }
    else {
        $finalStatus = "Scaling"
        $finalSku = "Scaling to $TargetSku"
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
        PreviousSKU = $currentSku
        CurrentSKU = $capacity.sku.name
        TargetSKU = $TargetSku
        LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    return $result | ConvertTo-Json -Depth 5
}
catch {
    Write-Log "An error occurred: $_" -Level "Error"
    throw
} 