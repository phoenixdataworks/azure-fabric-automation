<#
.SYNOPSIS
    Creates a complex schedule pattern for a Microsoft Fabric capacity.

.DESCRIPTION
    This runbook creates a set of Azure Automation schedules to implement a complex pattern:
    1. Start Fabric capacity at specified start time
    2. Scale to selected SKU at scale up time (for job processing)
    3. Scale down to default SKU at scale down time
    4. Pause the capacity at stop time

.PARAMETER ResourceGroupName
    The name of the resource group containing the Azure Automation account.

.PARAMETER AutomationAccountName
    The name of the Azure Automation account.

.PARAMETER CapacityId
    The ID of the Microsoft Fabric capacity to schedule.
    This should be in the format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Fabric/capacities/{capacityName}

.PARAMETER StartTime
    The time to start the capacity, in the format "HH:MM:SS". Default: "06:00:00" (6:00 AM)

.PARAMETER ScaleUpTime
    The time to scale up to the selected SKU, in the format "HH:MM:SS". Default: "06:05:00" (6:05 AM)

.PARAMETER ScaleUpSku
    The SKU to scale up to during peak usage. Default: "F64"

.PARAMETER ScaleDownTime
    The time to scale down to the default SKU, in the format "HH:MM:SS". Default: "17:45:00" (5:45 PM)

.PARAMETER StopTime
    The time to stop the capacity, in the format "HH:MM:SS". Default: "18:00:00" (6:00 PM)

.PARAMETER TimeZone
    The time zone to use for the schedules. Default: "Pacific Standard Time"

.PARAMETER ScheduleDays
    The days of the week to run the schedules. Default: Monday, Tuesday, Wednesday, Thursday, Friday

.PARAMETER DefaultSku
    The default SKU to scale down to outside of peak hours. Default: "F2"

.NOTES
    Author: Premier Forge
    Created: 2025-03-07
    Version: 1.0
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AutomationAccountName,

    [Parameter(Mandatory = $true)]
    [string]$CapacityId,

    [Parameter(Mandatory = $false)]
    [string]$StartTime = "06:00:00",

    [Parameter(Mandatory = $false)]
    [string]$ScaleUpTime = "06:05:00",

    [Parameter(Mandatory = $false)]
    [string]$ScaleUpSku = "F64",

    [Parameter(Mandatory = $false)]
    [string]$ScaleDownTime = "17:45:00",

    [Parameter(Mandatory = $false)]
    [string]$StopTime = "18:00:00",

    [Parameter(Mandatory = $false)]
    [string]$TimeZone = "Pacific Standard Time",

    [Parameter(Mandatory = $false)]
    [string[]]$ScheduleDays = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday"),

    [Parameter(Mandatory = $false)]
    [string]$DefaultSku = "F2"
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

# Function to create a schedule
function New-AutomationSchedule {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$AutomationAccountName,
        
        [Parameter(Mandatory = $true)]
        [string]$ScheduleName,
        
        [Parameter(Mandatory = $true)]
        [string]$StartTime,
        
        [Parameter(Mandatory = $true)]
        [string]$TimeZone,
        
        [Parameter(Mandatory = $false)]
        [string[]]$ScheduleDays = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday"),
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )
    
    try {
        # Parse the start time
        $timeFormat = "HH:mm:ss"
        $startTimeObj = [datetime]::ParseExact($StartTime, $timeFormat, $null)
        
        # Get the current date
        $currentDate = Get-Date
        
        # Create a datetime for today with the specified time
        $scheduleStartTime = New-Object System.DateTime(
            $currentDate.Year,
            $currentDate.Month,
            $currentDate.Day,
            $startTimeObj.Hour,
            $startTimeObj.Minute,
            $startTimeObj.Second
        )
        
        # If the time has already passed today, start tomorrow
        if ($scheduleStartTime -lt $currentDate) {
            $scheduleStartTime = $scheduleStartTime.AddDays(1)
        }
        
        # Create the schedule
        Write-Log "Creating schedule: $ScheduleName"
        
        # Check if the schedule already exists
        $existingSchedule = Get-AzAutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $ScheduleName -ErrorAction SilentlyContinue
        
        if ($existingSchedule) {
            Write-Log "Schedule already exists. Removing it..."
            Remove-AzAutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $ScheduleName -Force
        }
        
        # Create a weekly schedule with the specified days
        $schedule = New-AzAutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $ScheduleName -StartTime $scheduleStartTime -WeekInterval 1 -DaysOfWeek $ScheduleDays -TimeZone $TimeZone -Description $Description
        
        return $schedule
    }
    catch {
        Write-Log "Failed to create schedule: $_" -Level "Error"
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
        
        [Parameter(Mandatory = $false)]
        [int]$ExpiryInDays = 365,
        
        [Parameter(Mandatory = $false)]
        [HashTable]$Parameters = @{}
    )
    
    try {
        # Check if the webhook already exists
        $existingWebhook = Get-AzAutomationWebhook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $WebhookName -ErrorAction SilentlyContinue
        
        if ($existingWebhook) {
            Write-Log "Webhook already exists. Removing it..."
            Remove-AzAutomationWebhook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $WebhookName -Force
        }
        
        # Create a new webhook
        $expiry = (Get-Date).AddDays($ExpiryInDays)
        $webhook = New-AzAutomationWebhook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName $RunbookName -Name $WebhookName -ExpiryTime $expiry -Force -Parameters $Parameters
        
        return $webhook
    }
    catch {
        Write-Log "Failed to create webhook: $_" -Level "Error"
        throw
    }
}

# Main script execution
try {
    # Connect to Azure
    $null = Connect-AzAccount -Identity
    
    # Get capacity details
    $capacityDetails = Get-CapacityDetails -CapacityId $CapacityId
    $subscriptionId = $capacityDetails.SubscriptionId
    $capacityName = $capacityDetails.CapacityName
    
    # Set the correct subscription context
    $null = Set-AzContext -SubscriptionId $subscriptionId
    
    # Create schedules for the capacity
    Write-Log "Creating schedules for Fabric capacity: $capacityName"
    
    # Create start schedule
    $startScheduleDescription = "Schedule to start the $capacityName Fabric capacity"
    $startSchedule = New-AutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ScheduleName "Start-$capacityName" -StartTime $StartTime -TimeZone $TimeZone -ScheduleDays $ScheduleDays -Description $startScheduleDescription
    
    # Create scale up schedule
    $scaleUpScheduleDescription = "Schedule to scale the $capacityName Fabric capacity to $ScaleUpSku"
    $scaleUpSchedule = New-AutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ScheduleName "ScaleUp-$capacityName-$ScaleUpSku" -StartTime $ScaleUpTime -TimeZone $TimeZone -ScheduleDays $ScheduleDays -Description $scaleUpScheduleDescription
    
    # Create scale down schedule
    $scaleDownScheduleDescription = "Schedule to scale the $capacityName Fabric capacity to $DefaultSku"
    $scaleDownSchedule = New-AutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ScheduleName "ScaleDown-$capacityName-$DefaultSku" -StartTime $ScaleDownTime -TimeZone $TimeZone -ScheduleDays $ScheduleDays -Description $scaleDownScheduleDescription
    
    # Create stop schedule
    $stopScheduleDescription = "Schedule to stop the $capacityName Fabric capacity"
    $stopSchedule = New-AutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ScheduleName "Stop-$capacityName" -StartTime $StopTime -TimeZone $TimeZone -ScheduleDays $ScheduleDays -Description $stopScheduleDescription
    
    # Register the schedules with the runbooks
    Write-Log "Registering schedules with runbooks"
    
    # Register Start schedule with Start-FabricCapacity runbook
    $startRunbookParams = @{
        CapacityId = $CapacityId
    }
    $null = Register-AzAutomationScheduledRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName "Start-FabricCapacity" -ScheduleName $startSchedule.Name -Parameters $startRunbookParams
    
    # Register Scale Up schedule with Scale-FabricCapacity runbook
    $scaleUpRunbookParams = @{
        CapacityId = $CapacityId
        TargetSku = $ScaleUpSku
    }
    $null = Register-AzAutomationScheduledRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName "Scale-FabricCapacity" -ScheduleName $scaleUpSchedule.Name -Parameters $scaleUpRunbookParams
    
    # Register Scale Down schedule with Scale-FabricCapacity runbook
    $scaleDownRunbookParams = @{
        CapacityId = $CapacityId
        TargetSku = $DefaultSku
    }
    $null = Register-AzAutomationScheduledRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName "Scale-FabricCapacity" -ScheduleName $scaleDownSchedule.Name -Parameters $scaleDownRunbookParams
    
    # Register Stop schedule with Stop-FabricCapacity runbook
    $stopRunbookParams = @{
        CapacityId = $CapacityId
    }
    $null = Register-AzAutomationScheduledRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName "Stop-FabricCapacity" -ScheduleName $stopSchedule.Name -Parameters $stopRunbookParams
    
    # Output the schedule details
    Write-Log "Schedules created successfully for Fabric capacity: $capacityName"
    
    $result = @{
        CapacityName = $capacityName
        Schedules = @{
            Start = $startSchedule.Name
            ScaleUp = $scaleUpSchedule.Name
            ScaleDown = $scaleDownSchedule.Name
            Stop = $stopSchedule.Name
        }
        StartTime = $StartTime
        ScaleUpTime = $ScaleUpTime
        ScaleUpSku = $ScaleUpSku
        ScaleDownTime = $ScaleDownTime
        DefaultSku = $DefaultSku
        StopTime = $StopTime
        TimeZone = $TimeZone
        ScheduleDays = $ScheduleDays
    }
    
    Write-Output $result
}
catch {
    Write-Log "Failed to create schedule pattern: $_" -Level "Error"
    throw
} 