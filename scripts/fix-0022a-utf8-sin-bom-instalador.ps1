$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$PackagePath = "$ProjectRoot\package.json"
$TauriConfigPath = "$ProjectRoot\src-tauri\tauri.conf.json"
$BackupDir = "$ProjectRoot\Downloads\backup-0022a"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX 0022A" -ForegroundColor Cyan
Write-Host " UTF-8 sin BOM + build instalador" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($Path in @($PackagePath, $TauriConfigPath)) {
    if (-not (Test-Path $Path)) {
        throw "No se encontro: $Path"
    }
}

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

Copy-Item $PackagePath "$BackupDir\package.json" -Force
Copy-Item $TauriConfigPath "$BackupDir\tauri.conf.json" -Force

Write-Host "[OK] Backup creado" -ForegroundColor Green

# ============================================================
# FUNCION UTF-8 SIN BOM
# Compatible con Windows PowerShell 5.1
# ============================================================

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        $Utf8NoBom
    )
}

# ============================================================
# 1. NORMALIZAR package.json
# ============================================================

Write-Host ""
Write-Host "Normalizando package.json..." -ForegroundColor Yellow

$PackageRaw = [System.IO.File]::ReadAllText($PackagePath)

# Quitar BOM Unicode si existe en el contenido.
$PackageRaw = $PackageRaw.TrimStart([char]0xFEFF)

try {
    $Package = $PackageRaw | ConvertFrom-Json
}
catch {
    throw "package.json no es JSON valido: $($_.Exception.Message)"
}

$Package.name = "wincare-ai"
$Package.version = "0.1.0"

$PackageJson = $Package | ConvertTo-Json -Depth 100

Write-Utf8NoBom `
    -Path $PackagePath `
    -Content $PackageJson

Write-Host "[OK] package.json guardado en UTF-8 sin BOM" -ForegroundColor Green

# ============================================================
# 2. NORMALIZAR tauri.conf.json
# ============================================================

Write-Host ""
Write-Host "Normalizando tauri.conf.json..." -ForegroundColor Yellow

$TauriRaw = [System.IO.File]::ReadAllText($TauriConfigPath)
$TauriRaw = $TauriRaw.TrimStart([char]0xFEFF)

try {
    $Tauri = $TauriRaw | ConvertFrom-Json
}
catch {
    throw "tauri.conf.json no es JSON valido: $($_.Exception.Message)"
}

$Tauri.productName = "WinCare AI"
$Tauri.version = "0.1.0"

if (-not $Tauri.bundle) {
    $Tauri | Add-Member `
        -NotePropertyName bundle `
        -NotePropertyValue ([pscustomobject]@{}) `
        -Force
}

$Tauri.bundle.active = $true

$TauriJson = $Tauri | ConvertTo-Json -Depth 100

Write-Utf8NoBom `
    -Path $TauriConfigPath `
    -Content $TauriJson

Write-Host "[OK] tauri.conf.json guardado en UTF-8 sin BOM" -ForegroundColor Green

# ============================================================
# 3. VERIFICAR PRIMER BYTE
# ============================================================

function Test-Utf8Bom {
    param([string]$Path)

    $Bytes = [System.IO.File]::ReadAllBytes($Path)

    if ($Bytes.Length -ge 3) {
        return (
            $Bytes[0] -eq 0xEF -and
            $Bytes[1] -eq 0xBB -and
            $Bytes[2] -eq 0xBF
        )
    }

    return $false
}

if (Test-Utf8Bom $PackagePath) {
    throw "package.json todavia contiene BOM."
}

if (Test-Utf8Bom $TauriConfigPath) {
    throw "tauri.conf.json todavia contiene BOM."
}

Write-Host "[OK] Verificado: JSON sin BOM" -ForegroundColor Green

# ============================================================
# 4. FRONTEND BUILD
# ============================================================

Write-Host ""
Write-Host "Validando frontend..." -ForegroundColor Yellow

Set-Location $ProjectRoot
npm run build

if ($LASTEXITCODE -ne 0) {
    throw "npm run build fallo."
}

Write-Host "[OK] Frontend build" -ForegroundColor Green

# ============================================================
# 5. RUST CHECK
# ============================================================

Write-Host ""
Write-Host "Validando Rust..." -ForegroundColor Yellow

Set-Location "$ProjectRoot\src-tauri"
cargo check

if ($LASTEXITCODE -ne 0) {
    throw "cargo check fallo."
}

Write-Host "[OK] cargo check" -ForegroundColor Green

# ============================================================
# 6. TAURI BUILD
# ============================================================

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " CREANDO WINCARE AI v0.1.0" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Este paso puede tardar varios minutos..." -ForegroundColor Yellow
Write-Host ""

Set-Location $ProjectRoot
npm run tauri build

if ($LASTEXITCODE -ne 0) {
    throw "tauri build fallo. El codigo fuente permanece intacto."
}

# ============================================================
# 7. MOSTRAR RESULTADOS
# ============================================================

$ReleaseRoot = "$ProjectRoot\src-tauri\target\release"
$BundleRoot = "$ReleaseRoot\bundle"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " FIX 0022A COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

$MainExe = Get-ChildItem `
    -Path $ReleaseRoot `
    -File `
    -Filter "*.exe" `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -notmatch "build-script"
    } |
    Select-Object -First 5

if ($MainExe) {
    Write-Host "Ejecutable(s) release:" -ForegroundColor Cyan

    foreach ($File in $MainExe) {
        Write-Host " - $($File.FullName)" -ForegroundColor White
    }

    Write-Host ""
}

if (Test-Path $BundleRoot) {
    $Installers = Get-ChildItem `
        -Path $BundleRoot `
        -Recurse `
        -File `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in @(".exe", ".msi")
        }

    if ($Installers) {
        Write-Host "Instaladores encontrados:" -ForegroundColor Cyan

        foreach ($Installer in $Installers) {
            Write-Host " - $($Installer.FullName)" -ForegroundColor White
        }
    }
    else {
        Write-Host "[AVISO] No se encontraron instaladores .exe/.msi dentro de bundle." -ForegroundColor Yellow
        Write-Host "Revisa:" -ForegroundColor White
        Write-Host " $BundleRoot" -ForegroundColor White
    }
}
else {
    Write-Host "[AVISO] No se encontro la carpeta bundle." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "IMPORTANTE:" -ForegroundColor Yellow
Write-Host "El problema era un BOM UTF-8 agregado por Windows PowerShell 5.1" -ForegroundColor White
Write-Host "al escribir archivos JSON con Set-Content -Encoding UTF8." -ForegroundColor White
Write-Host "Este fix guarda los JSON en UTF-8 SIN BOM." -ForegroundColor White
Write-Host ""
