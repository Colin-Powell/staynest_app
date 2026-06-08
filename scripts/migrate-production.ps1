# PowerShell script to migrate local database to Render production
# Use the EXTERNAL hostname (removed the '-a' which is for internal Render network only)
$PROD_URL = "postgresql://staynest:Ih9VC5wZqnZZgnQz8So4X4UDCgpaxQVe@dpg-d8ip5h4vikkc73c3dlmg.singapore-postgres.render.com/staynest_rv6g?sslmode=require"

Write-Host "--- Initializing Production Database Schema ---" -ForegroundColor Cyan

# 1. Run the schema file on production
Write-Host "[1/2] Executing schema on Render using Node..." -ForegroundColor Yellow
$env:DATABASE_URL = $PROD_URL
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