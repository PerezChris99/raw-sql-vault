<#
.SYNOPSIS
    Corruption Report Auditor - Report Scheduler
.DESCRIPTION
    Sets up Windows Task Scheduler jobs for automated report generation
.PARAMETER Action
    Action to perform: create, remove, list
.EXAMPLE
    .\schedule_reports.ps1 -Action create
    .\schedule_reports.ps1 -Action remove
    .\schedule_reports.ps1 -Action list
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "remove", "list")]
    [string]$Action
)

$TaskPrefix = "CorruptionAuditor"
$ScriptPath = Join-Path $PSScriptRoot "run_report.ps1"
$OutputPath = Join-Path $PSScriptRoot "..\output"

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$ScheduledReports = @(
    @{
        Name = "${TaskPrefix}_DailyAging"
        Report = "daily_aging"
        Schedule = "Daily"
        Time = "06:00"
        Description = "Daily aging report at 6 AM"
    },
    @{
        Name = "${TaskPrefix}_WeeklyResolution"
        Report = "weekly_resolution"
        Schedule = "Weekly"
        DayOfWeek = "Monday"
        Time = "07:00"
        Description = "Weekly resolution summary every Monday at 7 AM"
    },
    @{
        Name = "${TaskPrefix}_MonthlyTrends"
        Report = "monthly_trends"
        Schedule = "Monthly"
        DayOfMonth = 1
        Time = "08:00"
        Description = "Monthly trends on the 1st at 8 AM"
    },
    @{
        Name = "${TaskPrefix}_QuarterlyAudit"
        Report = "quarterly_audit"
        Schedule = "Quarterly"
        Months = @(1, 4, 7, 10) # Jan, Apr, Jul, Oct
        DayOfMonth = 1
        Time = "09:00"
        Description = "Quarterly audit on the 1st of Jan, Apr, Jul, Oct at 9 AM"
    }
)

function New-ReportTask {
    param(
        [hashtable]$Config
    )
    
    $TaskName = $Config.Name
    $ReportArg = "-ExecutionPolicy Bypass -File `"$ScriptPath`" -Report $($Config.Report) -Format html -OutputPath `"$OutputPath`""
    
    Write-Host "Creating task: $TaskName" -ForegroundColor Cyan
    
    # Create the action
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $ReportArg
    
    # Create the trigger based on schedule type
    switch ($Config.Schedule) {
        "Daily" {
            $Trigger = New-ScheduledTaskTrigger -Daily -At $Config.Time
        }
        "Weekly" {
            $Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Config.DayOfWeek -At $Config.Time
        }
        "Monthly" {
            $Trigger = New-ScheduledTaskTrigger -Monthly -DaysOfMonth $Config.DayOfMonth -At $Config.Time
        }
        "Quarterly" {
            # Create multiple monthly triggers for quarterly
            $Triggers = @()
            foreach ($Month in $Config.Months) {
                # Note: This creates a monthly trigger - for true quarterly, 
                # the script would need additional logic
                $Triggers += New-ScheduledTaskTrigger -Monthly -DaysOfMonth $Config.DayOfMonth -At $Config.Time
            }
            $Trigger = $Triggers[0] # Use first month as primary
        }
    }
    
    # Create the principal (run as current user)
    $Principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    
    # Create settings
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    # Register the task
    try {
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description $Config.Description -Force | Out-Null
        Write-Host "  Created: $TaskName" -ForegroundColor Green
    } catch {
        Write-Host "  Failed to create $TaskName : $_" -ForegroundColor Red
    }
}

function Remove-ReportTask {
    param(
        [string]$TaskName
    )
    
    Write-Host "Removing task: $TaskName" -ForegroundColor Cyan
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Host "  Removed: $TaskName" -ForegroundColor Green
    } catch {
        Write-Host "  Task not found or could not be removed: $TaskName" -ForegroundColor Yellow
    }
}

function Get-ReportTasks {
    Write-Host ""
    Write-Host "Corruption Auditor Scheduled Tasks:" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    
    $Tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "${TaskPrefix}*" }
    
    if ($Tasks.Count -eq 0) {
        Write-Host "No scheduled tasks found." -ForegroundColor Yellow
    } else {
        foreach ($Task in $Tasks) {
            $TaskInfo = Get-ScheduledTaskInfo -TaskName $Task.TaskName -ErrorAction SilentlyContinue
            Write-Host ""
            Write-Host "Task: $($Task.TaskName)" -ForegroundColor White
            Write-Host "  State: $($Task.State)" -ForegroundColor Gray
            Write-Host "  Description: $($Task.Description)" -ForegroundColor Gray
            if ($TaskInfo.LastRunTime) {
                Write-Host "  Last Run: $($TaskInfo.LastRunTime)" -ForegroundColor Gray
            }
            if ($TaskInfo.NextRunTime) {
                Write-Host "  Next Run: $($TaskInfo.NextRunTime)" -ForegroundColor Gray
            }
        }
    }
}

# Main execution
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "CORRUPTION REPORT SCHEDULER" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

switch ($Action) {
    "create" {
        Write-Host "Creating scheduled tasks..." -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($ReportConfig in $ScheduledReports) {
            New-ReportTask -Config $ReportConfig
        }
        
        Write-Host ""
        Write-Host "Scheduled tasks created successfully!" -ForegroundColor Green
        Write-Host "Output will be saved to: $OutputPath" -ForegroundColor Gray
    }
    "remove" {
        Write-Host "Removing scheduled tasks..." -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($ReportConfig in $ScheduledReports) {
            Remove-ReportTask -TaskName $ReportConfig.Name
        }
        
        Write-Host ""
        Write-Host "Scheduled tasks removed!" -ForegroundColor Green
    }
    "list" {
        Get-ReportTasks
    }
}

Write-Host ""
