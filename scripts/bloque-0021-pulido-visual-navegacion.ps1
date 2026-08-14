$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$CssPath = "$ProjectRoot\src\App.css"
$BackupDir = "$ProjectRoot\Downloads\backup-0021"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - BLOQUE 0021" -ForegroundColor Cyan
Write-Host " Pulido visual y navegacion" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($Path in @($AppPath, $CssPath)) {
    if (-not (Test-Path $Path)) {
        throw "No se encontro: $Path"
    }
}

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

Copy-Item $AppPath "$BackupDir\App.tsx" -Force
Copy-Item $CssPath "$BackupDir\App.css" -Force

Write-Host "[OK] Backup creado" -ForegroundColor Green

$App = Get-Content $AppPath -Raw

# ============================================================
# 1. AGRUPAR VISUALMENTE EL SIDEBAR
# ============================================================

$NavPattern = '(?s)(<nav className="nav">)(.*?)(</nav>)'
$NavMatch = [regex]::Match($App, $NavPattern)

if (-not $NavMatch.Success) {
    throw "No se encontro el sidebar principal."
}

$NavContent = $NavMatch.Groups[2].Value

function Insert-GroupBeforeButton {
    param(
        [string]$Content,
        [string]$ButtonText,
        [string]$GroupLabel,
        [string]$GroupKey
    )

    if ($Content -match ('data-nav-group="' + [regex]::Escape($GroupKey) + '"')) {
        return $Content
    }

    $TextIndex = $Content.IndexOf($ButtonText)

    if ($TextIndex -lt 0) {
        Write-Host "[AVISO] No se encontro '$ButtonText' para el grupo '$GroupLabel'." -ForegroundColor Yellow
        return $Content
    }

    $ButtonStart = $Content.LastIndexOf("<button", $TextIndex)

    if ($ButtonStart -lt 0) {
        Write-Host "[AVISO] No se encontro el inicio del boton '$ButtonText'." -ForegroundColor Yellow
        return $Content
    }

    $Group = @"

          <div
            className="nav-group-label"
            data-nav-group="$GroupKey"
          >
            $GroupLabel
          </div>

"@

    return $Content.Insert($ButtonStart, $Group)
}

$NavContent = Insert-GroupBeforeButton `
    -Content $NavContent `
    -ButtonText "Estado general" `
    -GroupLabel "RESUMEN" `
    -GroupKey "summary"

$NavContent = Insert-GroupBeforeButton `
    -Content $NavContent `
    -ButtonText "Limpieza" `
    -GroupLabel "MANTENIMIENTO" `
    -GroupKey "maintenance"

$NavContent = Insert-GroupBeforeButton `
    -Content $NavContent `
    -ButtonText "Análisis completo" `
    -GroupLabel "DIAGNÓSTICO" `
    -GroupKey "diagnosis"

$NavContent = Insert-GroupBeforeButton `
    -Content $NavContent `
    -ButtonText "Baseline" `
    -GroupLabel "EVOLUCIÓN" `
    -GroupKey "evolution"

$NewNav =
    $NavMatch.Groups[1].Value +
    $NavContent +
    $NavMatch.Groups[3].Value

$App =
    $App.Substring(0, $NavMatch.Index) +
    $NewNav +
    $App.Substring($NavMatch.Index + $NavMatch.Length)

Write-Host "[OK] Sidebar agrupado visualmente" -ForegroundColor Green

# ============================================================
# 2. AÑADIR INDICADOR DE PRODUCTO LOCAL EN FOOTER
# ============================================================

if ($App -notmatch 'className="sidebar-local-badge"') {
    $FooterMarker = @'
          <span>MVP local v0.1</span>
'@

    $FooterReplacement = @'
          <span>MVP local v0.1</span>

          <div className="sidebar-local-badge">
            <span />
            Datos locales
          </div>
'@

    if ($App.Contains($FooterMarker)) {
        $App = $App.Replace(
            $FooterMarker,
            $FooterReplacement
        )

        Write-Host "[OK] Indicador local agregado al footer" -ForegroundColor Green
    }
    else {
        Write-Host "[AVISO] No se encontro el texto MVP local v0.1." -ForegroundColor Yellow
    }
}

Set-Content -Path $AppPath -Value $App -Encoding UTF8

# ============================================================
# 3. CSS DE PULIDO
# ============================================================

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch 'WINCARE POLISH 0021') {

$PolishCss = @'

/* ==========================================================
   WINCARE POLISH 0021
   ========================================================== */

:root {
  --wincare-panel: #101419;
  --wincare-panel-hover: #141a21;
  --wincare-border: #222933;
  --wincare-border-strong: #303946;
  --wincare-muted: #6d7885;
  --wincare-accent: #647aff;
}

* {
  scrollbar-width: thin;
  scrollbar-color: #37414e #0c1014;
}

*::-webkit-scrollbar {
  width: 9px;
  height: 9px;
}

*::-webkit-scrollbar-track {
  background: #0c1014;
}

*::-webkit-scrollbar-thumb {
  background: #333d49;
  border: 2px solid #0c1014;
  border-radius: 999px;
}

*::-webkit-scrollbar-thumb:hover {
  background: #46515f;
}

/* Sidebar: mejor jerarquia y uso cuando crece la app */
.sidebar {
  position: sticky;
  top: 0;
  height: 100vh;
  overflow: hidden;
}

.nav {
  overflow-y: auto;
  overflow-x: hidden;
  padding-right: 6px;
  scrollbar-gutter: stable;
}

.nav-group-label {
  margin: 18px 10px 7px;
  color: #4f5a67;
  font-size: 8px;
  line-height: 1;
  font-weight: 900;
  letter-spacing: 0.17em;
  user-select: none;
}

.nav-group-label:first-child {
  margin-top: 2px;
}

.nav-item {
  min-height: 44px;
  position: relative;
  transition:
    background 0.16s ease,
    color 0.16s ease,
    transform 0.16s ease;
}

.nav-item:hover {
  background: #141920;
  color: #d9dee5;
}

.nav-item.active {
  background:
    linear-gradient(
      90deg,
      rgba(99, 122, 255, 0.12),
      rgba(99, 122, 255, 0.035)
    ),
    #1a2028;
}

.nav-item.active::after {
  content: "";
  position: absolute;
  right: 9px;
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: #6d82ff;
  box-shadow: 0 0 10px rgba(109, 130, 255, 0.7);
}

.sidebar-local-badge {
  margin-top: 9px;
  width: max-content;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 8px;
  border: 1px solid #24312b;
  border-radius: 999px;
  background: rgba(45, 141, 87, 0.06);
  color: #6e8c7a;
  font-size: 8px;
  font-weight: 700;
}

.sidebar-local-badge > span {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #55d487;
  box-shadow: 0 0 8px rgba(85, 212, 135, 0.6);
}

/* Contenido */
.main {
  scroll-behavior: smooth;
}

.topbar {
  padding-bottom: 12px;
}

.topbar h2 {
  letter-spacing: -0.035em;
}

.eyebrow,
.status-label {
  letter-spacing: 0.14em;
}

/* Todos los botones ganan foco visible para teclado */
button:focus-visible {
  outline: 2px solid #7386ff;
  outline-offset: 2px;
}

/* Sensacion mas consistente entre tarjetas */
.cleanup-summary article,
.performance-metrics article,
.analysis-kpi-grid article,
.history-summary article,
.intelligence-summary-grid article,
.analysis-actions-grid button,
.intelligence-actions button {
  transition:
    transform 0.16s ease,
    border-color 0.16s ease,
    background 0.16s ease;
}

.cleanup-summary article:hover,
.performance-metrics article:hover,
.analysis-kpi-grid article:hover,
.history-summary article:hover,
.intelligence-summary-grid article:hover {
  border-color: #313a46;
  background: #12171d;
  transform: translateY(-1px);
}

.analysis-actions-grid button:hover,
.intelligence-actions button:hover {
  transform: translateY(-1px);
}

/* Botones principales con una respuesta visual mas clara */
.primary-button {
  transition:
    transform 0.15s ease,
    filter 0.15s ease,
    box-shadow 0.15s ease;
}

.primary-button:hover:not(:disabled) {
  transform: translateY(-1px);
  filter: brightness(1.04);
  box-shadow: 0 10px 28px rgba(92, 105, 255, 0.16);
}

.primary-button:active:not(:disabled) {
  transform: translateY(0);
}

.secondary-button {
  transition:
    background 0.15s ease,
    border-color 0.15s ease,
    color 0.15s ease;
}

.secondary-button:hover:not(:disabled) {
  background: #171c22;
  border-color: #3a4350;
  color: #ffffff;
}

/* Evitar cortes poco elegantes en headers largos */
@media (min-width: 900px) {
  .topbar > div:first-child {
    min-width: 0;
  }

  .topbar h2 {
    max-width: 900px;
  }
}

/* Sidebar en pantallas mas bajas */
@media (max-height: 780px) {
  .nav-group-label {
    margin-top: 12px;
  }

  .nav-item {
    min-height: 39px;
  }
}

'@

    Add-Content -Path $CssPath -Value $PolishCss -Encoding UTF8
    Write-Host "[OK] Pulido visual agregado" -ForegroundColor Green
}
else {
    Write-Host "[OK] Pulido visual ya existe" -ForegroundColor Green
}

# ============================================================
# 4. VERIFICACION Y BUILD
# ============================================================

$CheckApp = Get-Content $AppPath -Raw

if ($CheckApp -notmatch 'data-nav-group="summary"') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verificaron los grupos del sidebar. Backup restaurado."
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
Write-Host " BLOQUE 0021 COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Incluye:" -ForegroundColor Cyan
Write-Host " - Sidebar agrupado" -ForegroundColor White
Write-Host " - Scroll interno del menu" -ForegroundColor White
Write-Host " - Estados hover/focus mejorados" -ForegroundColor White
Write-Host " - Indicador de datos locales" -ForegroundColor White
Write-Host " - Pulido de tarjetas y botones" -ForegroundColor White
Write-Host ""
Write-Host "Ejecuta ahora:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
