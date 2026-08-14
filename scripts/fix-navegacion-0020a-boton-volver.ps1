$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$CssPath = "$ProjectRoot\src\App.css"
$BackupDir = "$ProjectRoot\Downloads\backup-0020a"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX NAVEGACION 0020A" -ForegroundColor Cyan
Write-Host " Boton volver en todas las pantallas" -ForegroundColor Cyan
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
# 1. AGREGAR useRef AL IMPORT DE REACT
# ============================================================

$App = $App -replace `
    'import \{ useEffect, useMemo, useState \} from "react";', `
    'import { useEffect, useMemo, useRef, useState } from "react";'

if ($App -notmatch 'useRef') {
    throw "No se pudo agregar useRef."
}

Write-Host "[OK] useRef agregado" -ForegroundColor Green

# ============================================================
# 2. HISTORIAL DE NAVEGACION INTERNA
# ============================================================

if ($App -notmatch 'viewHistoryRef') {

$NavigationLogic = @'

  const viewHistoryRef =
    useRef<Array<typeof activeView>>(["dashboard"]);

  const skipNextHistoryRef =
    useRef(false);

  useEffect(() => {
    if (skipNextHistoryRef.current) {
      skipNextHistoryRef.current = false;
      return;
    }

    const history = viewHistoryRef.current;
    const last = history[history.length - 1];

    if (last !== activeView) {
      history.push(activeView);

      if (history.length > 50) {
        history.shift();
      }
    }
  }, [activeView]);

  function goBack() {
    const history = viewHistoryRef.current;

    if (history.length <= 1) {
      setActiveView("dashboard");
      return;
    }

    history.pop();

    const previous =
      history[history.length - 1] ?? "dashboard";

    skipNextHistoryRef.current = true;
    setActiveView(previous);
  }
'@

    $CpuMarker = '  const cpu = Math.round(stats.cpu_usage);'
    $Index = $App.IndexOf($CpuMarker)

    if ($Index -lt 0) {
        throw "No se encontro el bloque principal para insertar navegacion."
    }

    $App = $App.Insert(
        $Index,
        $NavigationLogic + "`r`n"
    )

    Write-Host "[OK] Historial interno de navegacion agregado" -ForegroundColor Green
}
else {
    Write-Host "[OK] Historial interno ya existe" -ForegroundColor Green
}

# ============================================================
# 3. BOTON VOLVER GLOBAL DENTRO DE MAIN
# ============================================================

if ($App -notmatch 'className="back-button"') {

$MainMarker = '<main className="main">'

$BackButton = @'
<main className="main">
        {activeView !== "dashboard" && (
          <div className="back-row">
            <button
              className="back-button"
              onClick={goBack}
              aria-label="Volver a la pantalla anterior"
              title="Volver"
            >
              <span className="back-button-icon">
                ←
              </span>

              <span>Volver</span>
            </button>
          </div>
        )}
'@

    if (-not $App.Contains($MainMarker)) {
        throw "No se encontro <main className=`"main`">."
    }

    $App = $App.Replace(
        $MainMarker,
        $BackButton
    )

    Write-Host "[OK] Boton Volver agregado globalmente" -ForegroundColor Green
}
else {
    Write-Host "[OK] Boton Volver ya existe" -ForegroundColor Green
}

Set-Content -Path $AppPath -Value $App -Encoding UTF8

# ============================================================
# 4. CSS
# ============================================================

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch '\.back-button') {

$BackCss = @'

.back-row {
  display: flex;
  align-items: center;
  margin-bottom: 14px;
}

.back-button {
  border: 1px solid #2a313b;
  background: #101419;
  color: #a8b0bb;
  border-radius: 10px;
  padding: 8px 12px 8px 9px;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-size: 11px;
  font-weight: 700;
  cursor: pointer;
  transition:
    background 0.15s ease,
    border-color 0.15s ease,
    color 0.15s ease,
    transform 0.15s ease;
}

.back-button:hover {
  color: #ffffff;
  background: #151a21;
  border-color: #3a4350;
  transform: translateX(-1px);
}

.back-button:active {
  transform: translateX(-2px);
}

.back-button-icon {
  width: 25px;
  height: 25px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  background: #171c23;
  color: #7c89ff;
  font-size: 16px;
  line-height: 1;
}

@media (max-width: 700px) {
  .back-button {
    padding-right: 9px;
  }

  .back-button > span:last-child {
    display: none;
  }
}

'@

    Add-Content -Path $CssPath -Value $BackCss -Encoding UTF8
    Write-Host "[OK] Estilos del boton Volver agregados" -ForegroundColor Green
}

# ============================================================
# 5. VERIFICAR Y BUILD
# ============================================================

$CheckApp = Get-Content $AppPath -Raw

if ($CheckApp -notmatch 'activeView !== "dashboard"') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico la exclusion del Dashboard. Backup restaurado."
}

if ($CheckApp -notmatch 'function goBack') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico goBack. Backup restaurado."
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
Write-Host " FIX NAVEGACION 0020A COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Dashboard = Estado general" -ForegroundColor Cyan
Write-Host "El boton Volver aparece en todas las demas pantallas." -ForegroundColor White
Write-Host ""
Write-Host "Ejecuta ahora:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
