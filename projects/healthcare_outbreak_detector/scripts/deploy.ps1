# ============================================================================
# Healthcare Outbreak Detector - Deployment Script
# Purpose: Automated database deployment with migration support
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$DatabaseHost = "localhost",
    
    [Parameter(Mandatory=$false)]
    [int]$DatabasePort = 5432,
    
    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "outbreak_surveillance",
    
    [Parameter(Mandatory=$false)]
    [string]$DatabaseUser = "postgres",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("deploy", "migrate", "seed", "rollback", "status")]
    [string]$Action = "deploy",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSeed,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot

# Configuration
$MigrationsPath = Join-Path $ProjectRoot "database\migrations"
$SeedsPath = Join-Path $ProjectRoot "database\seeds"
$FunctionsPath = Join-Path $ProjectRoot "database\functions"
$ViewsPath = Join-Path $ProjectRoot "database\views"

# Logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
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
        $env:PGPASSWORD = $env:DB_PASSWORD
        $result = & psql -h $DatabaseHost -p $DatabasePort -U $DatabaseUser -d $DatabaseName -f $FilePath -v ON_ERROR_STOP=1 2>&1
        
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

# Get migration status
function Get-MigrationStatus {
    Write-Log "Checking migration status..."
    
    $checkTable = @"
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'surveillance' 
        AND table_name = 'schema_migrations'
    );
"@
    
    $env:PGPASSWORD = $env:DB_PASSWORD
    $exists = & psql -h $DatabaseHost -p $DatabasePort -U $DatabaseUser -d $DatabaseName -t -c $checkTable 2>&1
    
    if ($exists -match "t") {
        $migrations = & psql -h $DatabaseHost -p $DatabasePort -U $DatabaseUser -d $DatabaseName -t -c "SELECT version, applied_at FROM surveillance.schema_migrations ORDER BY version;" 2>&1
        Write-Log "Applied migrations:"
        Write-Host $migrations
    }
    else {
        Write-Log "No migrations applied yet" "WARN"
    }
}

# Deploy migrations
function Invoke-Migrations {
    Write-Log "Running migrations..."
    
    $migrations = Get-ChildItem -Path $MigrationsPath -Filter "V*.sql" | Sort-Object Name
    
    foreach ($migration in $migrations) {
        $version = $migration.Name -replace "V(\d+)__.*\.sql", '$1'
        
        # Check if already applied
        $checkSql = "SELECT 1 FROM surveillance.schema_migrations WHERE version = '$version';"
        $applied = & psql -h $DatabaseHost -p $DatabasePort -U $DatabaseUser -d $DatabaseName -t -c $checkSql 2>&1
        
        if ($applied -match "1" -and -not $Force) {
            Write-Log "Skipping (already applied): $($migration.Name)"
            continue
        }
        
        $success = Invoke-SqlFile -FilePath $migration.FullName
        
        if ($success) {
            # Record migration
            $recordSql = "INSERT INTO surveillance.schema_migrations (version, filename) VALUES ('$version', '$($migration.Name)') ON CONFLICT (version) DO NOTHING;"
            & psql -h $DatabaseHost -p $DatabasePort -U $DatabaseUser -d $DatabaseName -c $recordSql 2>&1 | Out-Null
        }
        else {
            throw "Migration failed: $($migration.Name)"
        }
    }
}

# Deploy functions
function Invoke-Functions {
    Write-Log "Deploying functions..."
    
    $folders = @("analytics", "api", "procedures")
    
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

# Deploy views
function Invoke-Views {
    Write-Log "Deploying views..."
    
    $folders = @("standard", "materialized")
    
    foreach ($folder in $folders) {
        $path = Join-Path $ViewsPath $folder
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

# Main execution
Write-Log "Healthcare Outbreak Detector - Database Deployment"
Write-Log "Target: $DatabaseHost`:$DatabasePort/$DatabaseName"
Write-Log "Action: $Action"
Write-Host ""

switch ($Action) {
    "status" {
        Get-MigrationStatus
    }
    
    "migrate" {
        Invoke-Migrations
    }
    
    "seed" {
        Invoke-Seeds
    }
    
    "deploy" {
        Write-Log "Starting full deployment..."
        
        # Create database if needed
        $createDb = "SELECT 1 FROM pg_database WHERE datname = '$DatabaseName';"
        $dbExists = & psql -h $DatabaseHost -p $DatabasePort -U $DatabaseUser -d postgres -t -c $createDb 2>&1
        
        if (-not ($dbExists -match "1")) {
            Write-Log "Creating database: $DatabaseName"
            & psql -h $DatabaseHost -p $DatabasePort -U $DatabaseUser -d postgres -c "CREATE DATABASE $DatabaseName;" 2>&1 | Out-Null
        }
        
        # Run migrations
        Invoke-Migrations
        
        # Deploy functions
        Invoke-Functions
        
        # Deploy views
        Invoke-Views
        
        # Load seed data
        if (-not $SkipSeed) {
            Invoke-Seeds
        }
        
        Write-Log "Deployment completed successfully!" "SUCCESS"
    }
    
    "rollback" {
        Write-Log "Rollback not implemented - use manual recovery" "WARN"
    }
}

Write-Host ""
Write-Log "Done."
