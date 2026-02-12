# ============================================================================
# Water Point Usage Monitor - Report Runner
# PostgreSQL 14+ with TimescaleDB 2.x
# ============================================================================

param(
    [Parameter(Position=0)]
    [ValidateSet('all', 'risk', 'trends', 'maintenance', 'setup', 'refresh', 'test')]
    [string]$Report = 'all',
    
    [string]$EnvFile = '.env',
    [switch]$Verbose,
    [switch]$OutputFile
)

# Banner
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   WATER POINT USAGE MONITOR - Report Runner    " -ForegroundColor Cyan
Write-Host "   PostgreSQL + TimescaleDB                     " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Load environment variables
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
    Write-Host "[OK] Loaded environment from $EnvFile" -ForegroundColor Green
} else {
    Write-Host "[WARN] No .env file found. Using environment variables." -ForegroundColor Yellow
}

# Database connection
$DB_HOST = $env:DB_HOST ?? 'localhost'
$DB_PORT = $env:DB_PORT ?? '5432'
$DB_NAME = $env:DB_NAME ?? 'water_point_monitor'
$DB_USER = $env:DB_USER ?? 'postgres'
$env:PGPASSWORD = $env:DB_PASSWORD ?? 'postgres'

Write-Host "[INFO] Database: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME" -ForegroundColor Gray
Write-Host ""

# Check psql availability
$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
    Write-Host "[ERROR] psql not found. Install PostgreSQL client tools." -ForegroundColor Red
    exit 1
}

# Paths
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$MigrationsPath = Join-Path $ProjectRoot "database\migrations"
$SeedsPath = Join-Path $ProjectRoot "database\seeds"
$FunctionsPath = Join-Path $ProjectRoot "database\functions"
$ReportsPath = Join-Path $ProjectRoot "scripts\reports"
$TestsPath = Join-Path $ProjectRoot "scripts"

# Output directory
$OutputDir = Join-Path $ProjectRoot "output"
if ($OutputFile -and -not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Helper function to run SQL
function Invoke-SQL {
    param(
        [string]$File,
        [string]$Description,
        [switch]$ShowOutput
    )
    
    Write-Host "[RUN] $Description" -ForegroundColor Yellow
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $args = @(
        "-h", $DB_HOST,
        "-p", $DB_PORT,
        "-U", $DB_USER,
        "-d", $DB_NAME,
        "-v", "NOW='$timestamp'",
        "-f", $File
    )
    
    if ($ShowOutput) {
        $args += "--echo-errors"
    }
    
    if ($OutputFile) {
        $outputPath = Join-Path $OutputDir ((Split-Path -Leaf $File) -replace '\.sql$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt")
        & psql @args 2>&1 | Tee-Object -FilePath $outputPath
        Write-Host "[OK] Output saved to: $outputPath" -ForegroundColor Green
    } else {
        & psql @args
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed: $Description" -ForegroundColor Red
        return $false
    }
    
    Write-Host "[OK] $Description completed" -ForegroundColor Green
    Write-Host ""
    return $true
}

# Database setup (migrations + seeds + functions)
function Invoke-Setup {
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "  DATABASE SETUP" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
    
    # Check TimescaleDB extension
    Write-Host "[CHECK] Verifying TimescaleDB extension..." -ForegroundColor Yellow
    $checkExt = @"
SELECT 
    CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb')
    THEN 'TimescaleDB is installed'
    ELSE 'TimescaleDB is NOT installed - run CREATE EXTENSION timescaledb;'
    END;
"@
    & psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c $checkExt
    Write-Host ""
    
    # Run migrations in order
    Get-ChildItem $MigrationsPath -Filter "V*.sql" | Sort-Object Name | ForEach-Object {
        Invoke-SQL -File $_.FullName -Description "Migration: $($_.Name)"
    }
    
    # Run function files
    Get-ChildItem $FunctionsPath -Filter "*.sql" | Sort-Object Name | ForEach-Object {
        Invoke-SQL -File $_.FullName -Description "Functions: $($_.Name)"
    }
    
    # Run seeds in order
    Get-ChildItem $SeedsPath -Filter "*.sql" | Sort-Object Name | ForEach-Object {
        Invoke-SQL -File $_.FullName -Description "Seed: $($_.Name)"
    }
    
    Write-Host "[DONE] Database setup complete!" -ForegroundColor Green
}

# Refresh continuous aggregates
function Invoke-Refresh {
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "  REFRESH CONTINUOUS AGGREGATES" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
    
    $refreshSQL = @"
-- Refresh all continuous aggregates
SELECT 'Refreshing usage_hourly_agg...' as status;
CALL refresh_continuous_aggregate('usage_hourly_agg', NULL, NULL);

SELECT 'Refreshing usage_daily_agg...' as status;
CALL refresh_continuous_aggregate('usage_daily_agg', NULL, NULL);

SELECT 'Refreshing usage_weekly_agg...' as status;
CALL refresh_continuous_aggregate('usage_weekly_agg', NULL, NULL);

SELECT 'All continuous aggregates refreshed' as status;
"@
    
    Write-Host "[RUN] Refreshing TimescaleDB continuous aggregates..." -ForegroundColor Yellow
    & psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c $refreshSQL
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Continuous aggregates refreshed" -ForegroundColor Green
    }
}

# Run reports
switch ($Report) {
    'setup' {
        Invoke-Setup
    }
    'refresh' {
        Invoke-Refresh
    }
    'risk' {
        Invoke-SQL -File (Join-Path $ReportsPath "breakdown_risk.sql") -Description "Breakdown Risk Report" -ShowOutput
    }
    'trends' {
        Invoke-SQL -File (Join-Path $ReportsPath "usage_trends.sql") -Description "Usage Trends Report" -ShowOutput
    }
    'maintenance' {
        Invoke-SQL -File (Join-Path $ReportsPath "maintenance_schedule.sql") -Description "Maintenance Schedule Report" -ShowOutput
    }
    'test' {
        $testFile = Join-Path $TestsPath "test_timeseries.sql"
        if (Test-Path $testFile) {
            Invoke-SQL -File $testFile -Description "TimescaleDB Tests" -ShowOutput
        } else {
            Write-Host "[ERROR] Test file not found: $testFile" -ForegroundColor Red
        }
    }
    'all' {
        Write-Host "Running ALL reports..." -ForegroundColor Cyan
        Write-Host ""
        
        Invoke-SQL -File (Join-Path $ReportsPath "breakdown_risk.sql") -Description "Breakdown Risk Report" -ShowOutput
        Invoke-SQL -File (Join-Path $ReportsPath "usage_trends.sql") -Description "Usage Trends Report" -ShowOutput
        Invoke-SQL -File (Join-Path $ReportsPath "maintenance_schedule.sql") -Description "Maintenance Schedule Report" -ShowOutput
    }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Report execution complete!" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Show available commands
Write-Host "Available commands:" -ForegroundColor Gray
Write-Host "  .\run_report.ps1 setup       - Run migrations, functions, and seeds" -ForegroundColor Gray
Write-Host "  .\run_report.ps1 refresh     - Refresh continuous aggregates" -ForegroundColor Gray
Write-Host "  .\run_report.ps1 risk        - Breakdown risk report" -ForegroundColor Gray
Write-Host "  .\run_report.ps1 trends      - Usage trends report" -ForegroundColor Gray
Write-Host "  .\run_report.ps1 maintenance - Maintenance schedule report" -ForegroundColor Gray
Write-Host "  .\run_report.ps1 test        - Run TimescaleDB tests" -ForegroundColor Gray
Write-Host "  .\run_report.ps1 all         - Run all reports" -ForegroundColor Gray
Write-Host ""
Write-Host "Options:" -ForegroundColor Gray
Write-Host "  -OutputFile                  - Save output to files" -ForegroundColor Gray
Write-Host "  -EnvFile custom.env          - Use custom environment file" -ForegroundColor Gray
