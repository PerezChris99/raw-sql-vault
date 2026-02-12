# ============================================================================
# Job Matching Engine - Deployment Script
# Purpose: Automated database deployment with migration support
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$DatabaseHost = "localhost",
    
    [Parameter(Mandatory = $false)]
    [int]$DatabasePort = 3306,
    
    [Parameter(Mandatory = $false)]
    [string]$DatabaseName = "job_matching",
    
    [Parameter(Mandatory = $false)]
    [string]$DatabaseUser = "root",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("deploy", "migrate", "seed", "reset", "status")]
    [string]$Action = "deploy",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipSeed,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot

# Configuration
$MigrationsPath = Join-Path $ProjectRoot "database\migrations"
$SeedsPath = Join-Path $ProjectRoot "database\seeds"
$FunctionsPath = Join-Path $ProjectRoot "database\functions"

# Logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Execute SQL file
function Invoke-SqlFile {
    param(
        [string]$FilePath,
        [string]$Description = ""
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "File not found: $FilePath" "ERROR"
        return $false
    }
    
    $fileName = Split-Path -Leaf $FilePath
    Write-Log "Executing: $fileName $Description"
    
    try {
        $result = & mysql -h $DatabaseHost -P $DatabasePort -u $DatabaseUser -p"$env:MYSQL_PASSWORD" $DatabaseName -e "source $FilePath" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed: $result" "ERROR"
            return $false
        }
        
        Write-Log "Completed: $fileName" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Exception: $_" "ERROR"
        return $false
    }
}

# Create database
function Initialize-Database {
    Write-Log "Creating database: $DatabaseName"
    
    $sql = @"
CREATE DATABASE IF NOT EXISTS $DatabaseName 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;
"@
    
    & mysql -h $DatabaseHost -P $DatabasePort -u $DatabaseUser -p"$env:MYSQL_PASSWORD" -e $sql 2>&1 | Out-Null
}

# Deploy migrations
function Invoke-Migrations {
    Write-Log "Running migrations..."
    
    $migrations = Get-ChildItem -Path $MigrationsPath -Filter "V*.sql" | Sort-Object Name
    
    foreach ($migration in $migrations) {
        $success = Invoke-SqlFile -FilePath $migration.FullName
        if (-not $success -and -not $Force) {
            throw "Migration failed: $($migration.Name)"
        }
    }
}

# Deploy functions
function Invoke-Functions {
    Write-Log "Deploying functions and stored procedures..."
    
    $folders = @("matching", "api")
    
    foreach ($folder in $folders) {
        $path = Join-Path $FunctionsPath $folder
        if (Test-Path $path) {
            $files = Get-ChildItem -Path $path -Filter "*.sql" | Sort-Object Name
            foreach ($file in $files) {
                Invoke-SqlFile -FilePath $file.FullName | Out-Null
            }
        }
    }
}

# Run seed data
function Invoke-Seeds {
    Write-Log "Loading seed data..."
    
    $seeds = Get-ChildItem -Path $SeedsPath -Filter "*.sql" | Sort-Object Name
    
    foreach ($seed in $seeds) {
        Invoke-SqlFile -FilePath $seed.FullName | Out-Null
    }
}

# Reset database
function Reset-Database {
    Write-Log "Resetting database..." "WARN"
    
    $sql = "DROP DATABASE IF EXISTS $DatabaseName;"
    & mysql -h $DatabaseHost -P $DatabasePort -u $DatabaseUser -p"$env:MYSQL_PASSWORD" -e $sql 2>&1 | Out-Null
}

# Main execution
Write-Log "Job Matching Engine - Database Deployment"
Write-Log "Target: $DatabaseHost`:$DatabasePort/$DatabaseName"
Write-Log "Action: $Action"
Write-Host ""

switch ($Action) {
    "status" {
        $sql = "SELECT COUNT(*) as tables FROM information_schema.tables WHERE table_schema = '$DatabaseName';"
        & mysql -h $DatabaseHost -P $DatabasePort -u $DatabaseUser -p"$env:MYSQL_PASSWORD" -e $sql 2>&1
    }
    
    "migrate" {
        Invoke-Migrations
    }
    
    "seed" {
        Invoke-Seeds
    }
    
    "reset" {
        Reset-Database
        Initialize-Database
        Invoke-Migrations
        Invoke-Functions
        if (-not $SkipSeed) {
            Invoke-Seeds
        }
        Write-Log "Database reset completed!" "SUCCESS"
    }
    
    "deploy" {
        Write-Log "Starting full deployment..."
        
        Initialize-Database
        Invoke-Migrations
        Invoke-Functions
        
        if (-not $SkipSeed) {
            Invoke-Seeds
        }
        
        Write-Log "Deployment completed successfully!" "SUCCESS"
    }
}

Write-Host ""
Write-Log "Done."
