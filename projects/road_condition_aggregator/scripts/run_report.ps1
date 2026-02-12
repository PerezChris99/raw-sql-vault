<#
.SYNOPSIS
    Road Condition Aggregator - Report Runner
    
.DESCRIPTION
    Executes SQL reports for the Road Condition Aggregator project.
    Supports multiple report types with PostgreSQL connection.
    
.PARAMETER Report
    The report to run: priority, cluster, district, or all
    
.PARAMETER Output
    Output format: console (default), file, or both
    
.PARAMETER Database
    Database name (default: road_condition_db)
    
.EXAMPLE
    .\run_report.ps1 -Report priority
    .\run_report.ps1 -Report all -Output file
    .\run_report.ps1 -Report cluster -Database my_custom_db
#>

param(
    [Parameter(Position=0)]
    [ValidateSet("priority", "cluster", "district", "all")]
    [string]$Report = "priority",
    
    [ValidateSet("console", "file", "both")]
    [string]$Output = "console",
    
    [string]$Database = "road_condition_db"
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportsDir = Join-Path $ScriptDir "reports"
$OutputDir = Join-Path $ScriptDir ".." "output"

# Load environment variables if .env exists
$EnvFile = Join-Path $ScriptDir ".." ".env"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match "^([^=]+)=(.*)$") {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }
}

# Database connection settings
$DbHost = if ($env:PGHOST) { $env:PGHOST } else { "localhost" }
$DbPort = if ($env:PGPORT) { $env:PGPORT } else { "5432" }
$DbUser = if ($env:PGUSER) { $env:PGUSER } else { "postgres" }
$DbName = if ($env:PGDATABASE) { $env:PGDATABASE } else { $Database }

# Report file mapping
$Reports = @{
    "priority" = "priority_queue.sql"
    "cluster"  = "cluster_analysis.sql"
    "district" = "district_summary.sql"
}

function Write-Header {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
}

function Run-Report {
    param(
        [string]$ReportName,
        [string]$SqlFile
    )
    
    $SqlPath = Join-Path $ReportsDir $SqlFile
    
    if (-not (Test-Path $SqlPath)) {
        Write-Host "ERROR: Report file not found: $SqlPath" -ForegroundColor Red
        return
    }
    
    Write-Header "Running: $ReportName"
    Write-Host "  Database: $DbName@$DbHost`:$DbPort" -ForegroundColor Gray
    Write-Host "  SQL File: $SqlFile" -ForegroundColor Gray
    Write-Host ""
    
    # Build psql command
    $PsqlArgs = @(
        "-h", $DbHost,
        "-p", $DbPort,
        "-U", $DbUser,
        "-d", $DbName,
        "-v", "NOW='$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')'",
        "-f", $SqlPath
    )
    
    if ($Output -eq "file" -or $Output -eq "both") {
        # Ensure output directory exists
        if (-not (Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
        
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $OutputFile = Join-Path $OutputDir "${ReportName}_${Timestamp}.txt"
        
        Write-Host "  Output: $OutputFile" -ForegroundColor Gray
        Write-Host ""
        
        if ($Output -eq "both") {
            psql @PsqlArgs 2>&1 | Tee-Object -FilePath $OutputFile
        } else {
            psql @PsqlArgs 2>&1 > $OutputFile
            Write-Host "Report saved to: $OutputFile" -ForegroundColor Green
        }
    } else {
        # Console only
        psql @PsqlArgs 2>&1
    }
}

function Test-PostgresConnection {
    Write-Host "Testing PostgreSQL connection..." -ForegroundColor Gray
    
    $TestResult = psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -c "SELECT 1" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Cannot connect to PostgreSQL" -ForegroundColor Red
        Write-Host $TestResult -ForegroundColor Red
        Write-Host ""
        Write-Host "Please check:" -ForegroundColor Yellow
        Write-Host "  1. PostgreSQL is running"
        Write-Host "  2. Database '$DbName' exists"
        Write-Host "  3. Connection settings are correct"
        Write-Host ""
        Write-Host "Connection settings:" -ForegroundColor Gray
        Write-Host "  Host: $DbHost"
        Write-Host "  Port: $DbPort"
        Write-Host "  User: $DbUser"
        Write-Host "  Database: $DbName"
        return $false
    }
    
    Write-Host "Connection successful!" -ForegroundColor Green
    return $true
}

function Test-PostGISExtension {
    Write-Host "Checking PostGIS extension..." -ForegroundColor Gray
    
    $PostGISResult = psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -t -c "SELECT PostGIS_Version()" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: PostGIS may not be installed" -ForegroundColor Yellow
        Write-Host "Run: CREATE EXTENSION postgis;" -ForegroundColor Gray
        return $false
    }
    
    Write-Host "PostGIS version: $($PostGISResult.Trim())" -ForegroundColor Green
    return $true
}

# Main execution
Write-Host "`n"
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       ROAD CONDITION AGGREGATOR - REPORT RUNNER          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Test connection
if (-not (Test-PostgresConnection)) {
    exit 1
}

# Test PostGIS
Test-PostGISExtension | Out-Null

# Run reports
if ($Report -eq "all") {
    foreach ($ReportKey in $Reports.Keys) {
        Run-Report -ReportName $ReportKey -SqlFile $Reports[$ReportKey]
    }
} else {
    Run-Report -ReportName $Report -SqlFile $Reports[$Report]
}

Write-Host "`n"
Write-Host "Report execution completed." -ForegroundColor Green
Write-Host ""
