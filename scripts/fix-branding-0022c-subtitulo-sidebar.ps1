$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$BackupDir = "$ProjectRoot\Downloads\backup-0022c"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX BRANDING 0022C" -ForegroundColor Cyan
Write-Host " Subtitulo exacto del sidebar" -ForegroundColor Cyan
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

# ============================================================
# 1. LOCALIZAR EL BLOQUE DE MARCA DEL SIDEBAR
# ============================================================

$BrandIndex = $App.IndexOf("WinCare AI")

if ($BrandIndex -lt 0) {
    throw "No se encontro el texto WinCare AI en App.tsx."
}

# Trabajar solo en una ventana cercana al primer WinCare AI,
# para no cambiar textos de otras pantallas.
$WindowStart = [Math]::Max(0, $BrandIndex - 700)
$WindowLength = [Math]::Min(
    1800,
    $App.Length - $WindowStart
)

$BrandWindow = $App.Substring(
    $WindowStart,
    $WindowLength
)

Write-Host "[OK] Bloque de marca localizado" -ForegroundColor Green

# ============================================================
# 2. REEMPLAZOS DIRECTOS CONOCIDOS
# ============================================================

$Candidates = @(
    "PC Health",
    "Diagnóstico inteligente",
    "Diagnostico inteligente",
    "Diagnóstico Inteligente",
    "Diagnostico Inteligente"
)

$Changed = $false

foreach ($Candidate in $Candidates) {
    if ($BrandWindow.Contains($Candidate)) {
        $LocalIndex = $BrandWindow.IndexOf($Candidate)
        $AbsoluteIndex = $WindowStart + $LocalIndex

        $App =
            $App.Substring(0, $AbsoluteIndex) +
            "Diagnóstico Inteligente" +
            $App.Substring(
                $AbsoluteIndex + $Candidate.Length
            )

        $Changed = $true
        Write-Host "[OK] Subtitulo reemplazado desde: $Candidate" -ForegroundColor Green
        break
    }
}

# ============================================================
# 3. PLAN B: REEMPLAZAR EL PRIMER SMALL/SPAN DESPUES DE WinCare AI
# ============================================================

if (-not $Changed) {
    $AfterBrandStart = $BrandIndex + "WinCare AI".Length
    $AfterBrandLength = [Math]::Min(
        700,
        $App.Length - $AfterBrandStart
    )

    $AfterBrand = $App.Substring(
        $AfterBrandStart,
        $AfterBrandLength
    )

    $Patterns = @(
        '(?s)<small[^>]*>\s*([^<]+?)\s*</small>',
        '(?s)<span[^>]*className="[^"]*(?:subtitle|sub|muted|brand)[^"]*"[^>]*>\s*([^<]+?)\s*</span>',
        '(?s)<p[^>]*className="[^"]*(?:subtitle|sub|muted|brand)[^"]*"[^>]*>\s*([^<]+?)\s*</p>'
    )

    foreach ($Pattern in $Patterns) {
        $Match = [regex]::Match(
            $AfterBrand,
            $Pattern
        )

        if ($Match.Success) {
            $Full = $Match.Value
            $Text = $Match.Groups[1].Value

            $NewFull = $Full.Replace(
                $Text,
                "Diagnóstico Inteligente"
            )

            $AbsoluteIndex =
                $AfterBrandStart + $Match.Index

            $App =
                $App.Substring(0, $AbsoluteIndex) +
                $NewFull +
                $App.Substring(
                    $AbsoluteIndex + $Match.Length
                )

            $Changed = $true
            Write-Host "[OK] Subtitulo reemplazado usando el bloque HTML cercano" -ForegroundColor Green
            break
        }
    }
}

if (-not $Changed) {
    throw "No se pudo localizar el subtitulo debajo de WinCare AI."
}

# ============================================================
# 4. GUARDAR
# ============================================================

Set-Content `
    -Path $AppPath `
    -Value $App `
    -Encoding UTF8

# ============================================================
# 5. VERIFICAR SOLO CERCA DE WinCare AI
# ============================================================

$Check = Get-Content $AppPath -Raw
$CheckBrandIndex = $Check.IndexOf("WinCare AI")

$CheckWindowStart = [Math]::Max(
    0,
    $CheckBrandIndex - 300
)

$CheckWindowLength = [Math]::Min(
    1000,
    $Check.Length - $CheckWindowStart
)

$CheckWindow = $Check.Substring(
    $CheckWindowStart,
    $CheckWindowLength
)

if (-not $CheckWindow.Contains("Diagnóstico Inteligente")) {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    throw "El subtitulo no quedo junto a WinCare AI. Backup restaurado."
}

Write-Host "[OK] VERIFICADO: Diagnostico Inteligente esta debajo de WinCare AI" -ForegroundColor Green

# ============================================================
# 6. BUILD
# ============================================================

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
Write-Host " FIX BRANDING 0022C COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Debe verse:" -ForegroundColor Cyan
Write-Host " WinCare AI" -ForegroundColor White
Write-Host " Diagnostico Inteligente" -ForegroundColor White
Write-Host ""
Write-Host "Ejecuta:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
