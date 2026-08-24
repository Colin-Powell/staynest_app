# PowerShell script to migrate local database to Render production
# Use the EXTERNAL hostname (removed the '-a' which is for internal Render network only)
if (-not $env:DATABASE_URL) {
    Write-Host "❌ ERROR: DATABASE_URL environment variable is not set." -ForegroundColor Red
    Write-Host "Please set DATABASE_URL (e.g., set DATABASE_URL=postgresql://user:pass@host/db) before running this script." -ForegroundColor Yellow
    exit 1
}

$PROD_URL = $env:DATABASE_URL

Write-Host "--- Initializing Production Database Schema ---" -ForegroundColor Cyan

# 1. Run the schema file on production
Write-Host "[1/2] Executing schema on Render using Node..." -ForegroundColor Yellow
node backend/scripts/apply-schema.js

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Schema initialization failed." -ForegroundColor Red
    exit 1
}

# 2. Run the seed script for production
Write-Host "[2/2] Running admin seed script against production..." -ForegroundColor Yellow
$env:DATABASE_URL = $PROD_URL
node backend/scripts/seed-admin.js

Write-Host "✅ Migration and Seeding complete!" -ForegroundColor Green