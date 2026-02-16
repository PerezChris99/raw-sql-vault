# ============================================================================
# Refugee Aid Allocator - Report Runner
# PostgreSQL 14+
# ============================================================================

param(
    [Parameter(Position = 0)]
    [ValidateSet('all', 'priority', 'camps', 'gaps', 'setup', 'score')]
    [string]$Report = 'priority',
    
    [string]$Camp = $null,
    [string]$EnvFile = '.env'
)

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  REFUGEE AID ALLOCATOR - Report Runner    " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Load environment
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
        }
    }
}

# PowerShell 5.1 compatible null coalescing (works with PS 5.1+)
$DB_HOST = if ($env:DB_HOST) { $env:DB_HOST } else { 'localhost' }
$DB_PORT = if ($env:DB_PORT) { $env:DB_PORT } else { '5432' }
$DB_NAME = if ($env:DB_NAME) { $env:DB_NAME } else { 'refugee_aid' }
$DB_USER = if ($env:DB_USER) { $env:DB_USER } else { 'postgres' }
$env:PGPASSWORD = if ($env:DB_PASSWORD) { $env:DB_PASSWORD } else { 'postgres' }

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Invoke-SQL($File, $Desc) {
    Write-Host "[RUN] $Desc" -ForegroundColor Yellow
    & psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v "NOW='$timestamp'" -f $File
    if ($LASTEXITCODE -eq 0) { Write-Host "[OK] $Desc" -ForegroundColor Green }
}

switch ($Report) {
    'setup' {
        Get-ChildItem "$ProjectRoot\database\migrations" -Filter "V*.sql" | Sort-Object | ForEach-Object {
            Invoke-SQL $_.FullName "Migration: $($_.Name)"
        }
        Get-ChildItem "$ProjectRoot\database\functions" -Filter "*.sql" | ForEach-Object {
            Invoke-SQL $_.FullName "Functions: $($_.Name)"
        }
        Get-ChildItem "$ProjectRoot\database\seeds" -Filter "*.sql" | Sort-Object | ForEach-Object {
            Invoke-SQL $_.FullName "Seed: $($_.Name)"
        }
    }
    'priority' {
        Invoke-SQL "$ProjectRoot\scripts\reports\priority_queue.sql" "Priority Queue Report"
    }
    'score' {
        Write-Host "[RUN] Updating need scores..." -ForegroundColor Yellow
        & psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT * FROM fn_update_all_need_scores();"
    }
    default {
        Invoke-SQL "$ProjectRoot\scripts\reports\priority_queue.sql" "Priority Queue Report"
    }
}

Write-Host ""
Write-Host "Commands: setup | priority | camps | gaps | score" -ForegroundColor Gray
