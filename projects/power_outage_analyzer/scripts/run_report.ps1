<#
.SYNOPSIS
    Runs Power Outage Pattern Analyzer reports

.DESCRIPTION
    Executes PostgreSQL/PostGIS geospatial analysis reports:
    - Hotspot Detection (K-Means, DBSCAN clustering)
    - Infrastructure Risk Assessment
    - Service Area Analysis

.PARAMETER ReportType
    Type of report: hotspot, risk, service, all

.PARAMETER OutputFormat
    Output format: console, html, csv, json

.PARAMETER Host
    Database host (default: localhost)

.PARAMETER Database
    Database name (default: power_outage_db)

.PARAMETER Username
    Database username (default: postgres)

.EXAMPLE
    .\run_report.ps1 -ReportType hotspot
    
.EXAMPLE
    .\run_report.ps1 -ReportType all -OutputFormat html
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('hotspot', 'risk', 'service', 'all')]
    [string]$ReportType = 'all',
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('console', 'html', 'csv', 'json')]
    [string]$OutputFormat = 'console',
    
    [Parameter(Mandatory=$false)]
    [string]$Host = 'localhost',
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 5432,
    
    [Parameter(Mandatory=$false)]
    [string]$Database = 'power_outage_db',
    
    [Parameter(Mandatory=$false)]
    [string]$Username = 'postgres'
)

# Script root directory
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportsDir = Join-Path $ScriptRoot "reports"
$OutputDir = Join-Path $ScriptRoot ".." "output"

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Report file mapping
$Reports = @{
    'hotspot' = 'hotspot_detection.sql'
    'risk'    = 'infrastructure_risk.sql'
    'service' = 'service_area_analysis.sql'
}

# Timestamp for output files
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

function Invoke-Report {
    param(
        [string]$ReportName,
        [string]$SqlFile
    )
    
    $SqlPath = Join-Path $ReportsDir $SqlFile
    
    if (-not (Test-Path $SqlPath)) {
        Write-Error "Report file not found: $SqlPath"
        return
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Running: $ReportName Report" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $OutputFile = Join-Path $OutputDir "${ReportName}_${Timestamp}"
    
    switch ($OutputFormat) {
        'console' {
            # Direct console output
            $env:PGPASSWORD = $env:PGPASSWORD
            psql -h $Host -p $Port -U $Username -d $Database -f $SqlPath
        }
        'html' {
            # HTML output
            $HtmlFile = "$OutputFile.html"
            $env:PGPASSWORD = $env:PGPASSWORD
            psql -h $Host -p $Port -U $Username -d $Database -f $SqlPath -H -o $HtmlFile
            Write-Host "Output saved to: $HtmlFile" -ForegroundColor Green
        }
        'csv' {
            # CSV output (using \copy or basic output)
            $CsvFile = "$OutputFile.csv"
            $env:PGPASSWORD = $env:PGPASSWORD
            psql -h $Host -p $Port -U $Username -d $Database -f $SqlPath -A -F "," -o $CsvFile
            Write-Host "Output saved to: $CsvFile" -ForegroundColor Green
        }
        'json' {
            # JSON output using row_to_json
            $JsonFile = "$OutputFile.json"
            Write-Host "JSON export requires custom query - outputting to file" -ForegroundColor Yellow
            $env:PGPASSWORD = $env:PGPASSWORD
            psql -h $Host -p $Port -U $Username -d $Database -f $SqlPath -t -o $JsonFile
            Write-Host "Output saved to: $JsonFile" -ForegroundColor Green
        }
    }
}

# Main execution
Write-Host "Power Outage Pattern Analyzer - Report Runner" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow
Write-Host "Database: $Database@$Host:$Port"
Write-Host "Format:   $OutputFormat"
Write-Host "Time:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Check for psql
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    Write-Error "psql not found in PATH. Please install PostgreSQL client tools."
    exit 1
}

# Run selected reports
if ($ReportType -eq 'all') {
    foreach ($report in $Reports.GetEnumerator()) {
        Invoke-Report -ReportName $report.Key -SqlFile $report.Value
    }
} else {
    Invoke-Report -ReportName $ReportType -SqlFile $Reports[$ReportType]
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Report execution complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
