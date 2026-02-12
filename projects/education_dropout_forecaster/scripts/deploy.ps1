# ============================================================================
# Deployment Script: Education Dropout Forecaster
# PowerShell script for database setup and deployment
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("deploy", "migrate", "seed", "reset", "test", "status")]
    [string]$Action = "status",
    
    [string]$DbHost = "localhost",
    [string]$DbPort = "5432",
    [string]$DbName = "dropout_forecaster",
    [string]$DbUser = "postgres",
    [string]$DbPassword = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$MigrationsDir = Join-Path $ProjectRoot "database\migrations"
$SeedsDir = Join-Path $ProjectRoot "database\seeds"
$FunctionsDir = Join-Path $ProjectRoot "database\functions"
$TestsDir = Join-Path $ProjectRoot "tests"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Get-PsqlCommand {
    # Build psql connection string
    $env:PGPASSWORD = $DbPassword
    return "psql -h $DbHost -p $DbPort -U $DbUser -d $DbName"
}

function Invoke-SqlFile {
    param([string]$FilePath, [string]$Database = $DbName)
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return $false
    }
    
    $env:PGPASSWORD = $DbPassword
    $result = psql -h $DbHost -p $DbPort -U $DbUser -d $Database -f $FilePath 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to execute: $FilePath"
        Write-Host $result -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Test-DatabaseConnection {
    $env:PGPASSWORD = $DbPassword
    $result = psql -h $DbHost -p $DbPort -U $DbUser -d "postgres" -c "SELECT 1" 2>&1
    return $LASTEXITCODE -eq 0
}

function Test-DatabaseExists {
    $env:PGPASSWORD = $DbPassword
    $result = psql -h $DbHost -p $DbPort -U $DbUser -d "postgres" -tAc "SELECT 1 FROM pg_database WHERE datname='$DbName'" 2>&1
    return $result -eq "1"
}

# ============================================================================
# Actions
# ============================================================================

function Invoke-Status {
    Write-Header "Database Status"
    
    if (-not (Test-DatabaseConnection)) {
        Write-Error "Cannot connect to PostgreSQL server"
        return
    }
    Write-Success "PostgreSQL server connection OK"
    
    if (Test-DatabaseExists) {
        Write-Success "Database '$DbName' exists"
        
        $env:PGPASSWORD = $DbPassword
        
        # Get table counts
        $tables = @("states", "districts", "schools", "students", "dropout_events", "annual_school_stats")
        foreach ($table in $tables) {
            $count = psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -tAc "SELECT COUNT(*) FROM $table" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  $table : $count rows"
            }
        }
    } else {
        Write-Host "Database '$DbName' does not exist" -ForegroundColor Yellow
    }
}

function Invoke-Migrate {
    Write-Header "Running Migrations"
    
    # Get migration files in order
    $migrations = Get-ChildItem -Path $MigrationsDir -Filter "V*.sql" | Sort-Object Name
    
    foreach ($migration in $migrations) {
        Write-Step "Applying: $($migration.Name)"
        if (Invoke-SqlFile -FilePath $migration.FullName) {
            Write-Success "Applied: $($migration.Name)"
        } else {
            Write-Error "Failed: $($migration.Name)"
            return
        }
    }
    
    # Apply functions
    Write-Step "Applying analytics functions..."
    $functionFiles = Get-ChildItem -Path $FunctionsDir -Filter "*.sql" -Recurse
    foreach ($funcFile in $functionFiles) {
        Write-Step "  $($funcFile.Name)"
        Invoke-SqlFile -FilePath $funcFile.FullName | Out-Null
    }
    
    Write-Success "All migrations completed"
}

function Invoke-Seed {
    Write-Header "Seeding Database"
    
    # Get seed files in order
    $seeds = Get-ChildItem -Path $SeedsDir -Filter "*.sql" | Sort-Object Name
    
    foreach ($seed in $seeds) {
        Write-Step "Seeding: $($seed.Name)"
        if (Invoke-SqlFile -FilePath $seed.FullName) {
            Write-Success "Seeded: $($seed.Name)"
        } else {
            Write-Error "Failed: $($seed.Name)"
            return
        }
    }
    
    Write-Success "Database seeded successfully"
}

function Invoke-Reset {
    Write-Header "Resetting Database"
    
    Write-Step "Dropping database '$DbName'..."
    $env:PGPASSWORD = $DbPassword
    psql -h $DbHost -p $DbPort -U $DbUser -d "postgres" -c "DROP DATABASE IF EXISTS $DbName" 2>&1 | Out-Null
    
    Write-Step "Creating database '$DbName'..."
    psql -h $DbHost -p $DbPort -U $DbUser -d "postgres" -c "CREATE DATABASE $DbName" 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create database"
        return
    }
    
    Write-Success "Database reset completed"
}

function Invoke-Test {
    Write-Header "Running Tests"
    
    $testFile = Join-Path $TestsDir "test_analytics.sql"
    
    if (-not (Test-Path $testFile)) {
        Write-Error "Test file not found: $testFile"
        return
    }
    
    Write-Step "Running integration tests..."
    $env:PGPASSWORD = $DbPassword
    psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -f $testFile
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "All tests completed"
    } else {
        Write-Error "Some tests may have failed"
    }
}

function Invoke-Deploy {
    Write-Header "Full Deployment"
    
    # Check connection
    if (-not (Test-DatabaseConnection)) {
        Write-Error "Cannot connect to PostgreSQL server at ${DbHost}:${DbPort}"
        return
    }
    
    # Create database if needed
    if (-not (Test-DatabaseExists)) {
        Write-Step "Creating database '$DbName'..."
        $env:PGPASSWORD = $DbPassword
        psql -h $DbHost -p $DbPort -U $DbUser -d "postgres" -c "CREATE DATABASE $DbName" 2>&1 | Out-Null
        Write-Success "Database created"
    }
    
    # Run migrations
    Invoke-Migrate
    
    # Seed data
    Invoke-Seed
    
    # Run tests
    Invoke-Test
    
    Write-Header "Deployment Complete"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. cd dropout_forecaster"
    Write-Host "  2. pip install -r requirements.txt"
    Write-Host "  3. python manage.py runserver"
    Write-Host ""
}

# ============================================================================
# Main
# ============================================================================

Write-Host ""
Write-Host "Education Dropout Forecaster - Deployment" -ForegroundColor Magenta
Write-Host "Action: $Action" -ForegroundColor Magenta
Write-Host ""

switch ($Action) {
    "deploy"  { Invoke-Deploy }
    "migrate" { Invoke-Migrate }
    "seed"    { Invoke-Seed }
    "reset"   { Invoke-Reset }
    "test"    { Invoke-Test }
    "status"  { Invoke-Status }
}
