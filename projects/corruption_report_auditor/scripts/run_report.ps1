<#
.SYNOPSIS
    Corruption Report Auditor - Report Runner
.DESCRIPTION
    Runs psql reports with various output options
.PARAMETER Report
    Report to run: daily_aging, weekly_resolution, monthly_trends, quarterly_audit
.PARAMETER Format
    Output format: console, csv, html
.PARAMETER OutputPath
    Path for file output (default: ./output/)
.EXAMPLE
    .\run_report.ps1 -Report daily_aging
    .\run_report.ps1 -Report monthly_trends -Format csv
    .\run_report.ps1 -Report quarterly_audit -Format html -OutputPath "C:\Reports"
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("daily_aging", "weekly_resolution", "monthly_trends", "quarterly_audit", "all")]
    [string]$Report,
    
    [ValidateSet("console", "csv", "html")]
    [string]$Format = "console",
    
    [string]$OutputPath = ".\output",
    
    [string]$Database = "corruption_auditor",
    [string]$Host = "localhost",
    [string]$Port = "5432",
    [string]$User = "postgres"
)

# Load environment variables if .env exists
$envFile = Join-Path $PSScriptRoot "..\..\.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
        }
    }
    
    if ($env:DB_NAME) { $Database = $env:DB_NAME }
    if ($env:DB_HOST) { $Host = $env:DB_HOST }
    if ($env:DB_PORT) { $Port = $env:DB_PORT }
    if ($env:DB_USER) { $User = $env:DB_USER }
}

$ScriptRoot = Join-Path $PSScriptRoot "reports"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Report file mappings
$ReportFiles = @{
    "daily_aging" = "daily_aging_report.sql"
    "weekly_resolution" = "weekly_resolution_summary.sql"
    "monthly_trends" = "monthly_category_trends.sql"
    "quarterly_audit" = "quarterly_audit_report.sql"
}

function Invoke-Report {
    param(
        [string]$ReportName,
        [string]$OutputFormat
    )
    
    $SqlFile = Join-Path $ScriptRoot $ReportFiles[$ReportName]
    
    if (-not (Test-Path $SqlFile)) {
        Write-Error "Report file not found: $SqlFile"
        return
    }
    
    Write-Host "Running $ReportName report..." -ForegroundColor Cyan
    
    switch ($OutputFormat) {
        "console" {
            $env:PGPASSWORD = $env:DB_PASSWORD
            psql -h $Host -p $Port -U $User -d $Database -f $SqlFile
        }
        "csv" {
            if (-not (Test-Path $OutputPath)) {
                New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
            }
            $OutFile = Join-Path $OutputPath "${ReportName}_${Timestamp}.csv"
            
            # Create a modified SQL for CSV output
            $TempSql = [System.IO.Path]::GetTempFileName()
            @"
\pset format csv
\pset tuples_only off
\pset footer off
"@ | Out-File -FilePath $TempSql -Encoding UTF8
            Get-Content $SqlFile | Out-File -FilePath $TempSql -Encoding UTF8 -Append
            
            $env:PGPASSWORD = $env:DB_PASSWORD
            psql -h $Host -p $Port -U $User -d $Database -f $TempSql -o $OutFile
            
            Remove-Item $TempSql
            Write-Host "CSV output saved to: $OutFile" -ForegroundColor Green
        }
        "html" {
            if (-not (Test-Path $OutputPath)) {
                New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
            }
            $OutFile = Join-Path $OutputPath "${ReportName}_${Timestamp}.html"
            
            # Create HTML version
            $TempSql = [System.IO.Path]::GetTempFileName()
            @"
\pset format html
\pset tableattr 'border="1" cellpadding="5" style="border-collapse: collapse; font-family: Arial, sans-serif;"'
"@ | Out-File -FilePath $TempSql -Encoding UTF8
            Get-Content $SqlFile | Out-File -FilePath $TempSql -Encoding UTF8 -Append
            
            # Add HTML header
            $HtmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <title>Corruption Report Auditor - $ReportName</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        table { margin: 20px 0; }
        th { background-color: #4472C4; color: white; padding: 10px; }
        td { padding: 8px; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .timestamp { color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
<h1>Corruption Report Auditor</h1>
<h2>$ReportName Report</h2>
<p class="timestamp">Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
"@
            $HtmlFooter = @"
</body>
</html>
"@
            
            $env:PGPASSWORD = $env:DB_PASSWORD
            $ReportContent = psql -h $Host -p $Port -U $User -d $Database -f $TempSql -H
            
            $HtmlHeader | Out-File -FilePath $OutFile -Encoding UTF8
            $ReportContent | Out-File -FilePath $OutFile -Encoding UTF8 -Append
            $HtmlFooter | Out-File -FilePath $OutFile -Encoding UTF8 -Append
            
            Remove-Item $TempSql
            Write-Host "HTML output saved to: $OutFile" -ForegroundColor Green
        }
    }
}

# Main execution
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "CORRUPTION REPORT AUDITOR" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Database: $Database" -ForegroundColor Gray
Write-Host "Host: ${Host}:${Port}" -ForegroundColor Gray
Write-Host "Format: $Format" -ForegroundColor Gray
Write-Host ""

if ($Report -eq "all") {
    foreach ($ReportName in $ReportFiles.Keys) {
        Invoke-Report -ReportName $ReportName -OutputFormat $Format
        Write-Host ""
    }
} else {
    Invoke-Report -ReportName $Report -OutputFormat $Format
}

Write-Host ""
Write-Host "Report generation complete!" -ForegroundColor Green
