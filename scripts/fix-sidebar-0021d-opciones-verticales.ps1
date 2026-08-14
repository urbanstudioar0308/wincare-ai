$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$CssPath = "$ProjectRoot\src\App.css"
$BackupDir = "$ProjectRoot\Downloads\backup-0021d"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX SIDEBAR 0021D" -ForegroundColor Cyan
Write-Host " Opciones apiladas verticalmente" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $CssPath)) {
    throw "No se encontro App.css"
}

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

Copy-Item $CssPath "$BackupDir\App.css" -Force

Write-Host "[OK] Backup creado" -ForegroundColor Green

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch 'WINCARE COLLAPSIBLE NAV 0021D') {

$FixCss = @'

/* ==========================================================
   WINCARE COLLAPSIBLE NAV 0021D
   Fuerza todas las opciones desplegadas a una columna
   ========================================================== */

.nav-group-content {
  display: flex !important;
  flex-direction: column !important;
  align-items: stretch !important;
  width: auto;
}

.nav-group-content .nav-item {
  display: flex !important;
  width: 100% !important;
  flex: 0 0 auto !important;
  box-sizing: border-box;
  justify-content: flex-start;
}

.nav-group-content .nav-item + .nav-item {
  margin-top: 2px;
}

'@

    Add-Content `
        -Path $CssPath `
        -Value $FixCss `
        -Encoding UTF8

    Write-Host "[OK] Layout vertical forzado" -ForegroundColor Green
}
else {
    Write-Host "[OK] Fix 0021D ya existe" -ForegroundColor Green
}

Write-Host ""
Write-Host "Ejecutando build..." -ForegroundColor Yellow

Set-Location $ProjectRoot
npm run build

if ($LASTEXITCODE -ne 0) {
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "Build fallido. App.css restaurado."
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " FIX SIDEBAR 0021D COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Ahora las opciones deben quedar:" -ForegroundColor Cyan
Write-Host " Baseline" -ForegroundColor White
Write-Host " Antes vs ahora" -ForegroundColor White
Write-Host " Que cambio" -ForegroundColor White
Write-Host " Historial" -ForegroundColor White
Write-Host ""
Write-Host "Ejecuta:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
