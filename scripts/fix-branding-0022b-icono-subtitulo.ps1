$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$CssPath = "$ProjectRoot\src\App.css"
$PublicDir = "$ProjectRoot\public"
$IconTarget = "$PublicDir\wincare-ai-icon.png"
$IconSource = "$ProjectRoot\scripts\wincare-ai-icon-oficial.png"
$BackupDir = "$ProjectRoot\Downloads\backup-0022b"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX BRANDING 0022B" -ForegroundColor Cyan
Write-Host " Icono oficial + subtitulo" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($Path in @($AppPath, $CssPath)) {
    if (-not (Test-Path $Path)) {
        throw "No se encontro: $Path"
    }
}

if (-not (Test-Path $IconSource)) {
    throw "Falta el icono oficial en: $IconSource"
}

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

if (-not (Test-Path $PublicDir)) {
    New-Item -ItemType Directory -Path $PublicDir | Out-Null
}

Copy-Item $AppPath "$BackupDir\App.tsx" -Force
Copy-Item $CssPath "$BackupDir\App.css" -Force

if (Test-Path $IconTarget) {
    Copy-Item $IconTarget "$BackupDir\wincare-ai-icon.png" -Force
}

Write-Host "[OK] Backup creado" -ForegroundColor Green

# ============================================================
# 1. COPIAR ICONO OFICIAL A PUBLIC
# ============================================================

Copy-Item $IconSource $IconTarget -Force

if (-not (Test-Path $IconTarget)) {
    throw "No se pudo copiar el icono oficial a public."
}

Write-Host "[OK] Icono oficial copiado a public" -ForegroundColor Green

# ============================================================
# 2. APP.TSX - REEMPLAZAR W POR IMAGEN Y SUBTITULO
# ============================================================

$App = Get-Content $AppPath -Raw

# Reemplazar bloque visual del logo si existe como avatar con W.
$AvatarPattern = '(?s)<div className="brand-icon">\s*W\s*</div>'

if ($App -match $AvatarPattern) {
    $AvatarReplacement = @'
<div className="brand-icon brand-icon-image">
            <img
              src="/wincare-ai-icon.png"
              alt="WinCare AI"
            />
          </div>
'@

    $App = [regex]::Replace(
        $App,
        $AvatarPattern,
        $AvatarReplacement,
        1
    )

    Write-Host "[OK] W reemplazada por icono oficial" -ForegroundColor Green
}
elseif ($App -match 'wincare-ai-icon\.png') {
    Write-Host "[OK] Icono oficial ya estaba aplicado" -ForegroundColor Green
}
else {
    # Plan B: localizar un div que contenga solamente W cerca del branding.
    $FallbackPattern = '(?s)<div[^>]*className="[^"]*(?:logo|brand)[^"]*"[^>]*>\s*W\s*</div>'

    if ($App -match $FallbackPattern) {
        $FallbackReplacement = @'
<div className="brand-icon brand-icon-image">
            <img
              src="/wincare-ai-icon.png"
              alt="WinCare AI"
            />
          </div>
'@

        $App = [regex]::Replace(
            $App,
            $FallbackPattern,
            $FallbackReplacement,
            1
        )

        Write-Host "[OK] W reemplazada usando metodo alternativo" -ForegroundColor Green
    }
    else {
        throw "No se pudo localizar el avatar W del sidebar."
    }
}

# Subtitulo exacto pedido.
if ($App -match 'Diagnóstico inteligente') {
    $App = $App -replace 'Diagnóstico inteligente(?: para Windows)?', 'Diagnóstico Inteligente'
}
elseif ($App -match 'PC Health') {
    $App = $App.Replace(
        'PC Health',
        'Diagnóstico Inteligente'
    )
}
else {
    Write-Host "[AVISO] No se encontro subtitulo previo; revisa visualmente." -ForegroundColor Yellow
}

Set-Content -Path $AppPath -Value $App -Encoding UTF8

Write-Host "[OK] Subtitulo actualizado a Diagnostico Inteligente" -ForegroundColor Green

# ============================================================
# 3. CSS - ESTILO DEL ICONO
# ============================================================

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch 'WINCARE BRAND ICON 0022B') {

$IconCss = @'

/* ==========================================================
   WINCARE BRAND ICON 0022B
   ========================================================== */

.brand-icon-image {
  padding: 0 !important;
  overflow: hidden;
  background: transparent !important;
  box-shadow: none !important;
  border: 0 !important;
}

.brand-icon-image img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: contain;
  filter:
    drop-shadow(0 0 6px rgba(45, 176, 255, 0.22));
}

'@

    Add-Content -Path $CssPath -Value $IconCss -Encoding UTF8
    Write-Host "[OK] Estilos del icono agregados" -ForegroundColor Green
}

# ============================================================
# 4. VERIFICAR + BUILD
# ============================================================

$CheckApp = Get-Content $AppPath -Raw

if ($CheckApp -notmatch 'src="/wincare-ai-icon\.png"') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico el icono en App.tsx. Backup restaurado."
}

if ($CheckApp -notmatch 'Diagnóstico Inteligente') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico el subtitulo. Backup restaurado."
}

Write-Host ""
Write-Host "Ejecutando build..." -ForegroundColor Yellow

Set-Location $ProjectRoot
npm run build

if ($LASTEXITCODE -ne 0) {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "Build fallido. Backup restaurado."
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " FIX BRANDING 0022B COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Cambios aplicados:" -ForegroundColor Cyan
Write-Host " - Icono oficial reemplaza la W" -ForegroundColor White
Write-Host " - Subtitulo: Diagnostico Inteligente" -ForegroundColor White
Write-Host ""
Write-Host "Ejecuta:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
