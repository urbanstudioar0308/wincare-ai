$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$BackupDir = "$ProjectRoot\Downloads\backup-0022d"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX BRANDING 0022D" -ForegroundColor Cyan
Write-Host " Reemplazo directo de PC Health" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $AppPath)) {
    throw "No se encontro App.tsx"
}

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

Copy-Item $AppPath "$BackupDir\App.tsx" -Force
Write-Host "[OK] Backup creado" -ForegroundColor Green

$App = Get-Content $AppPath -Raw

$CountBefore = ([regex]::Matches(
    $App,
    [regex]::Escape("PC Health")
)).Count

Write-Host "[INFO] Apariciones de PC Health: $CountBefore" -ForegroundColor Yellow

if ($CountBefore -eq 0) {
    throw "No existe el texto literal 'PC Health' en App.tsx. No se modifico nada."
}

$App = $App.Replace(
    "PC Health",
    "Diagnóstico Inteligente"
)

Set-Content `
    -Path $AppPath `
    -Value $App `
    -Encoding UTF8

$Check = Get-Content $AppPath -Raw

if ($Check.Contains("PC Health")) {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    throw "Todavia existe PC Health. Backup restaurado."
}

if (-not $Check.Contains("Diagnóstico Inteligente")) {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    throw "No se encontro el nuevo subtitulo. Backup restaurado."
}

Write-Host "[OK] PC Health reemplazado por Diagnostico Inteligente" -ForegroundColor Green

Write-Host ""
Write-Host "Ejecutando build..." -ForegroundColor Yellow

Set-Location $ProjectRoot
npm run build

if ($LASTEXITCODE -ne 0) {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    throw "Build fallido. App.tsx restaurado."
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " FIX BRANDING 0022D COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Debe verse:" -ForegroundColor Cyan
Write-Host " WinCare AI" -ForegroundColor White
Write-Host " Diagnostico Inteligente" -ForegroundColor White
Write-Host ""
Write-Host "Ejecuta:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
