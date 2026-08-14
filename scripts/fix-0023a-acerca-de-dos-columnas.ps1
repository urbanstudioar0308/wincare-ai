$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$CssPath = "$ProjectRoot\src\App.css"
$BackupDir = "$ProjectRoot\Downloads\backup-0023a"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX 0023A" -ForegroundColor Cyan
Write-Host " Acerca de: logo compacto + datos visibles" -ForegroundColor Cyan
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

if ($Css -notmatch 'WINCARE ABOUT LAYOUT 0023A') {

$FixCss = @'

/* ==========================================================
   WINCARE ABOUT LAYOUT 0023A
   Mantiene logo + datos visibles en dos columnas
   ========================================================== */

.about-full-layout {
  grid-template-columns:
    minmax(300px, 0.78fr)
    minmax(430px, 1.35fr) !important;
  gap: 16px !important;
  align-items: start !important;
}

.about-brand-panel {
  min-height: 390px !important;
  padding: 22px !important;
  position: sticky;
  top: 8px;
}

.about-official-logo {
  width: min(100%, 420px) !important;
  max-height: 285px !important;
}

.about-tagline {
  margin-top: 12px !important;
  font-size: 12px !important;
  line-height: 1.5 !important;
}

.about-info-column {
  gap: 14px !important;
}

.about-info-card {
  padding: 17px 18px !important;
}

.about-card-title {
  margin-bottom: 10px !important;
}

.about-card-title h3 {
  font-size: 16px !important;
}

.about-data-list > div {
  min-height: 34px !important;
}

.about-data-list span {
  font-size: 9px !important;
}

.about-data-list strong {
  font-size: 10px !important;
}

/* Mantener dos columnas en ventanas medianas.
   Antes se apilaba demasiado pronto a 1100px. */
@media (max-width: 860px) {
  .about-full-layout {
    grid-template-columns: 1fr !important;
  }

  .about-brand-panel {
    position: static;
    min-height: 300px !important;
  }

  .about-official-logo {
    max-height: 230px !important;
  }
}

'@

    Add-Content `
        -Path $CssPath `
        -Value $FixCss `
        -Encoding UTF8

    Write-Host "[OK] Layout de Acerca de ajustado" -ForegroundColor Green
}
else {
    Write-Host "[OK] FIX 0023A ya estaba aplicado" -ForegroundColor Green
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
Write-Host " FIX 0023A COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Ahora Acerca de debe mostrar:" -ForegroundColor Cyan
Write-Host " - Logo mas compacto a la izquierda" -ForegroundColor White
Write-Host " - Informacion del sistema visible a la derecha" -ForegroundColor White
Write-Host " - Recursos de la app debajo" -ForegroundColor White
Write-Host " - El apilado a una columna solo ocurre en ventanas mas angostas" -ForegroundColor White
Write-Host ""
Write-Host "Ejecuta:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
