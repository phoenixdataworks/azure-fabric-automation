<#
.SYNOPSIS
    Creates schedules to automatically start and stop a Microsoft Fabric capacity.

.DESCRIPTION
    This runbook creates Azure Automation schedules to automatically start and stop a Microsoft Fabric capacity at specified times.
    It creates two schedules: one for starting the capacity and one for stopping it.

.PARAMETER ResourceGroupName
    The name of the resource group containing the Azure Automation account.

.PARAMETER AutomationAccountName
    The name of the Azure Automation account.

.PARAMETER CapacityId
    The ID of the Microsoft Fabric capacity to schedule.
    This should be in the format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Fabric/capacities/{capacityName}

.PARAMETER StartTime
    The time to start the capacity, in the format "HH:MM:SS". Default: "08:00:00" (8:00 AM)

.PARAMETER StopTime
    The time to stop the capacity, in the format "HH:MM:SS". Default: "18:00:00" (6:00 PM)

.PARAMETER TimeZone
    The time zone to use for the schedules. Default: "UTC"

.PARAMETER WeekDaysOnly
    Whether to schedule the capacity to run only on weekdays (Monday to Friday). Default: $true

.NOTES
    Author: Premier Forge
    Created: 2025-03-03
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
    [string]$StartTime = "08:00:00",

    [Parameter(Mandatory = $false)]
    [string]$StopTime = "18:00:00",

    [Parameter(Mandatory = $false)]
    [string]$TimeZone = "UTC",

    [Parameter(Mandatory = $false)]
    [bool]$WeekDaysOnly = $true
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
        [bool]$WeekDaysOnly = $true,
        
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
        
        # Create the schedule
        if ($WeekDaysOnly) {
            # Create a weekly schedule that runs Monday to Friday
            $schedule = New-AzAutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $ScheduleName -StartTime $scheduleStartTime -WeekInterval 1 -DaysOfWeek "Monday", "Tuesday", "Wednesday", "Thursday", "Friday" -TimeZone $TimeZone -Description $Description
        }
        else {
            # Create a daily schedule
            $schedule = New-AzAutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $ScheduleName -StartTime $scheduleStartTime -DayInterval 1 -TimeZone $TimeZone -Description $Description
        }
        
        return $schedule
    }
    catch {
        Write-Log "Failed to create schedule: $_" -Level "Error"
        throw
    }
}

# Function to register a schedule with a runbook
function Register-ScheduleWithRunbook {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$AutomationAccountName,
        
        [Parameter(Mandatory = $true)]
        [string]$RunbookName,
        
        [Parameter(Mandatory = $true)]
        [string]$ScheduleName,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters
    )
    
    try {
        Write-Log "Registering schedule $ScheduleName with runbook $RunbookName"
        
        # Register the schedule with the runbook
        $job = Register-AzAutomationScheduledRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName $RunbookName -ScheduleName $ScheduleName -Parameters $Parameters
        
        return $job
    }
    catch {
        Write-Log "Failed to register schedule with runbook: $_" -Level "Error"
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
    
    Write-Log "Creating schedules for capacity: $capacityName"
    
    # Connect to Azure using managed identity
    Write-Log "Connecting to Azure using managed identity..."
    Connect-AzAccount -Identity
    
    # Test connection by getting current subscription
    try {
        $context = Get-AzContext
        Write-Log "Successfully connected to Azure using managed identity. Current subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
    }
    catch {
        Write-Log "Failed to get Azure context after connecting: $_" -Level "Error"
        throw "Failed to authenticate with managed identity. Please verify the Automation account has a system-assigned managed identity enabled."
    }
    
    # Create the start schedule
    $startScheduleName = "Start-$capacityName"
    $startScheduleDescription = "Schedule to start the $capacityName Fabric capacity"
    $startSchedule = New-AutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ScheduleName $startScheduleName -StartTime $StartTime -TimeZone $TimeZone -WeekDaysOnly $WeekDaysOnly -Description $startScheduleDescription
    
    # Create the stop schedule
    $stopScheduleName = "Stop-$capacityName"
    $stopScheduleDescription = "Schedule to stop the $capacityName Fabric capacity"
    $stopSchedule = New-AutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ScheduleName $stopScheduleName -StartTime $StopTime -TimeZone $TimeZone -WeekDaysOnly $WeekDaysOnly -Description $stopScheduleDescription
    
    # Create the parameters for the runbooks
    $runbookParameters = @{
        CapacityId = $CapacityId
    }
    
    # Register the schedules with the runbooks
    $startJob = Register-ScheduleWithRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName "Start-FabricCapacity" -ScheduleName $startScheduleName -Parameters $runbookParameters
    $stopJob = Register-ScheduleWithRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName "Stop-FabricCapacity" -ScheduleName $stopScheduleName -Parameters $runbookParameters
    
    # Return the schedule details
    $result = @{
        CapacityName = $capacityName
        StartSchedule = @{
            Name = $startScheduleName
            Time = $StartTime
            TimeZone = $TimeZone
            WeekDaysOnly = $WeekDaysOnly
            NextRun = $startSchedule.NextRun
        }
        StopSchedule = @{
            Name = $stopScheduleName
            Time = $StopTime
            TimeZone = $TimeZone
            WeekDaysOnly = $WeekDaysOnly
            NextRun = $stopSchedule.NextRun
        }
        CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    return $result | ConvertTo-Json -Depth 5
}
catch {
    Write-Log "An error occurred: $_" -Level "Error"
    throw
}
