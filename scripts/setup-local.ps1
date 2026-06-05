<#
PowerShell local setup script for StayNet backend + PostgreSQL
Run from workspace root in an elevated PowerShell if needed:
  .\scripts\setup-local.ps1
#>

param(
  [string]$PgUser = 'postgres',
  [string]$PgPassword = 'postgres',
  [string]$PgHost = 'localhost',
  [int]$PgPort = 5432,
  [string]$Database = 'staynest',
  [string]$JwtSecret = 'dev-secret-change-me',
  [string]$CorsOrigin = 'http://localhost:8080',
  [string]$StoragePath = 'uploads',
  [int]$Port = 8080,
  [switch]$StartBackend
)

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-ErrorMsg($m) { Write-Host "[ERROR] $m" -ForegroundColor Red }

# Check for required commands
function Check-Command($cmd) {
  $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

if (-not (Check-Command 'psql')) {
  Write-ErrorMsg "psql not found in PATH. Please install PostgreSQL or add psql to PATH."
  Write-Host "Download: https://www.postgresql.org/download/"
  exit 1
}
if (-not (Check-Command 'node')) {
  Write-ErrorMsg "node not found in PATH. Install Node.js (v18+)."
  exit 1
}
if (-not (Check-Command 'npm')) {
  Write-ErrorMsg "npm not found in PATH. Install Node.js which includes npm."
  exit 1
}

Write-Info "Using PostgreSQL: $PgUser@$PgHost:$PgPort, database: $Database"

# Helper to run psql with password
$env:PGPASSWORD = $PgPassword

# Create DB if missing
try {
  Write-Info "Creating database if it doesn't exist..."
  & psql -U $PgUser -h $PgHost -p $PgPort -tc "SELECT 1 FROM pg_database WHERE datname='$Database'" | Out-Null
  $exists = & psql -U $PgUser -h $PgHost -p $PgPort -tAc "SELECT 1 FROM pg_database WHERE datname='$Database'" | ForEach-Object { $_.Trim() }
  if ($exists -ne '1') {
    Write-Info "Database '$Database' not found — creating..."
    & psql -U $PgUser -h $PgHost -p $PgPort -c "CREATE DATABASE \"$Database\";"
    Write-Info "Created database $Database"
  } else {
    Write-Info "Database $Database already exists"
  }
} catch {
  Write-ErrorMsg "Failed to check/create database: $_"
  exit 1
}

# Apply schema
$schemaPath = Join-Path $PSScriptRoot '..' 'backend' 'scripts' 'init-db.sql'
if (-not (Test-Path $schemaPath)) {
  Write-ErrorMsg "Schema file not found: $schemaPath"
  exit 1
}

try {
  Write-Info "Applying schema from $schemaPath"
  & psql -U $PgUser -h $PgHost -p $PgPort -d $Database -f $schemaPath
  Write-Info "Schema applied"
} catch {
  Write-ErrorMsg "Failed to apply schema: $_"
  exit 1
}

# Create backend .env file
$envFile = Join-Path $PSScriptRoot '..' 'backend' '.env'
$databaseUrl = "postgresql://$PgUser:$PgPassword@$PgHost:$PgPort/$Database"
$envContent = @"
DATABASE_URL=$databaseUrl
JWT_SECRET=$JwtSecret
CORS_ORIGIN=$CorsOrigin
STORAGE_PATH=$StoragePath
PORT=$Port
"@

try {
  Write-Info "Writing backend .env to $envFile"
  $envContent | Out-File -FilePath $envFile -Encoding utf8
} catch {
  Write-ErrorMsg "Failed writing .env: $_"
}

# Install backend deps
Write-Info "Installing backend dependencies (npm install)"
Push-Location (Join-Path $PSScriptRoot '..' 'backend')
& npm install
if ($LASTEXITCODE -ne 0) {
  Write-ErrorMsg "npm install failed"
  Pop-Location
  exit 1
}

# Seed admin
Write-Info "Running seed script to create admin user"
& npm run seed
if ($LASTEXITCODE -ne 0) {
  Write-ErrorMsg "Seeding admin failed"
  Pop-Location
  exit 1
}

Pop-Location

Write-Info "Setup complete. Backend .env created and admin seeded."

if ($StartBackend) {
  Write-Info "Starting backend in dev mode"
  Push-Location (Join-Path $PSScriptRoot '..' 'backend')
  & npm run dev
  Pop-Location
}

Write-Host "\nNext steps:" -ForegroundColor Green
Write-Host "- Start the backend (if not auto-started): cd backend; npm run dev"
Write-Host "- Start the Flutter app: cd flutter_frontend; flutter pub get; flutter run"
Write-Host "- Remember to use the correct API base in flutter_frontend/lib/session/app_session.dart depending on emulator/device."
