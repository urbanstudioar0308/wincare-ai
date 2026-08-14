$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$TauriConfigPath = "$ProjectRoot\src-tauri\tauri.conf.json"
$PackagePath = "$ProjectRoot\package.json"
$BackupDir = "$ProjectRoot\Downloads\backup-0022"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - BLOQUE 0022" -ForegroundColor Cyan
Write-Host " Branding + instalador Windows v0.1" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($Path in @($AppPath, $TauriConfigPath, $PackagePath)) {
    if (-not (Test-Path $Path)) {
        throw "No se encontro: $Path"
    }
}

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

Copy-Item $AppPath "$BackupDir\App.tsx" -Force
Copy-Item $TauriConfigPath "$BackupDir\tauri.conf.json" -Force
Copy-Item $PackagePath "$BackupDir\package.json" -Force

Write-Host "[OK] Backup creado" -ForegroundColor Green

# ============================================================
# 1. BRANDING EN LA INTERFAZ
# ============================================================

$App = Get-Content $AppPath -Raw

if ($App -match 'PC Health') {
    $App = $App.Replace(
        'PC Health',
        'Diagnóstico inteligente'
    )

    Set-Content `
        -Path $AppPath `
        -Value $App `
        -Encoding UTF8

    Write-Host "[OK] Subtitulo actualizado a Diagnostico inteligente" -ForegroundColor Green
}
else {
    Write-Host "[OK] El subtitulo PC Health ya no existe" -ForegroundColor Green
}

# ============================================================
# 2. CONFIGURACION TAURI
# ============================================================

Write-Host ""
Write-Host "Configurando nombre de producto..." -ForegroundColor Yellow

$Config = Get-Content $TauriConfigPath -Raw | ConvertFrom-Json

$Config.productName = "WinCare AI"
$Config.version = "0.1.0"

# Tauri 2 suele tener bundle dentro de config.
if (-not $Config.bundle) {
    $Config | Add-Member `
        -NotePropertyName bundle `
        -NotePropertyValue ([pscustomobject]@{}) `
        -Force
}

$Config.bundle.active = $true

# No forzamos targets particulares: Tauri generara los disponibles
# segun las herramientas instaladas.
$ConfigJson = $Config | ConvertTo-Json -Depth 100

Set-Content `
    -Path $TauriConfigPath `
    -Value $ConfigJson `
    -Encoding UTF8

Write-Host "[OK] productName = WinCare AI" -ForegroundColor Green
Write-Host "[OK] version = 0.1.0" -ForegroundColor Green
Write-Host "[OK] bundle activo" -ForegroundColor Green

# ============================================================
# 3. PACKAGE.JSON
# ============================================================

$Package = Get-Content $PackagePath -Raw | ConvertFrom-Json

$Package.name = "wincare-ai"
$Package.version = "0.1.0"

$PackageJson = $Package | ConvertTo-Json -Depth 100

Set-Content `
    -Path $PackagePath `
    -Value $PackageJson `
    -Encoding UTF8

Write-Host "[OK] package.json alineado con v0.1.0" -ForegroundColor Green

# ============================================================
# 4. VALIDACIONES PREVIAS
# ============================================================

Write-Host ""
Write-Host "Validando frontend..." -ForegroundColor Yellow

Set-Location $ProjectRoot
npm run build

if ($LASTEXITCODE -ne 0) {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\tauri.conf.json" $TauriConfigPath -Force
    Copy-Item "$BackupDir\package.json" $PackagePath -Force

    throw "Frontend build fallido. Se restauro el backup."
}

Write-Host ""
Write-Host "Validando Rust..." -ForegroundColor Yellow

Set-Location "$ProjectRoot\src-tauri"
cargo check

if ($LASTEXITCODE -ne 0) {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\tauri.conf.json" $TauriConfigPath -Force
    Copy-Item "$BackupDir\package.json" $PackagePath -Force

    throw "cargo check fallo. Se restauro el backup."
}

# ============================================================
# 5. BUILD DE DISTRIBUCION
# ============================================================

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " CREANDO INSTALADOR WINDOWS" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Este paso puede tardar varios minutos..." -ForegroundColor Yellow
Write-Host ""

Set-Location $ProjectRoot
npm run tauri build

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] No se pudo crear el instalador." -ForegroundColor Red
    Write-Host "El codigo fuente NO se restaura porque los builds previos fueron correctos." -ForegroundColor Yellow
    Write-Host "Revisaremos solamente la etapa de empaquetado." -ForegroundColor Yellow
    throw "tauri build fallo."
}

# ============================================================
# 6. LOCALIZAR RESULTADOS
# ============================================================

$BundleRoot = "$ProjectRoot\src-tauri\target\release\bundle"
$ExePath = "$ProjectRoot\src-tauri\target\release\wincare-ai.exe"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " BLOQUE 0022 COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

if (Test-Path $ExePath) {
    Write-Host "[OK] Ejecutable release:" -ForegroundColor Green
    Write-Host "     $ExePath" -ForegroundColor White
    Write-Host ""
}

if (Test-Path $BundleRoot) {
    $Installers = Get-ChildItem `
        -Path $BundleRoot `
        -Recurse `
        -File `
        -Include *.exe,*.msi `
        -ErrorAction SilentlyContinue

    if ($Installers.Count -gt 0) {
        Write-Host "Instaladores encontrados:" -ForegroundColor Cyan

        foreach ($Installer in $Installers) {
            Write-Host " - $($Installer.FullName)" -ForegroundColor White
        }
    }
    else {
        Write-Host "[AVISO] El bundle existe pero no encontre .exe/.msi." -ForegroundColor Yellow
        Write-Host "Ruta para revisar:" -ForegroundColor Yellow
        Write-Host " $BundleRoot" -ForegroundColor White
    }
}
else {
    Write-Host "[AVISO] No se encontro la carpeta bundle." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Branding aplicado:" -ForegroundColor Cyan
Write-Host " WinCare AI" -ForegroundColor White
Write-Host " Diagnostico inteligente" -ForegroundColor White
Write-Host " Version 0.1.0" -ForegroundColor White
Write-Host ""
Write-Host "NOTA:" -ForegroundColor Yellow
Write-Host "El icono final personalizado lo integraremos en un bloque separado," -ForegroundColor White
Write-Host "porque conviene usar una version simplificada del simbolo y no el logo completo con texto." -ForegroundColor White
Write-Host ""
