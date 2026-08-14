$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$CssPath = "$ProjectRoot\src\App.css"
$BackupDir = "$ProjectRoot\Downloads\backup-0021b"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX SIDEBAR 0021B" -ForegroundColor Cyan
Write-Host " Secciones colapsables - corregido" -ForegroundColor Cyan
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
# 1. ESTADO PARA SECCION ABIERTA
# ============================================================

if ($App -notmatch 'openNavGroup') {

$NavState = @'

  const [openNavGroup, setOpenNavGroup] =
    useState<"maintenance" | "diagnosis" | "evolution" | null>(
      null,
    );

  useEffect(() => {
    if (
      activeView === "cleanup" ||
      activeView === "storage" ||
      activeView === "performance" ||
      activeView === "startup" ||
      activeView === "processes"
    ) {
      setOpenNavGroup("maintenance");
      return;
    }

    if (
      activeView === "analysis" ||
      activeView === "intelligence" ||
      activeView === "diagnosis"
    ) {
      setOpenNavGroup("diagnosis");
      return;
    }

    if (
      activeView === "baseline" ||
      activeView === "compare" ||
      activeView === "changes" ||
      activeView === "history"
    ) {
      setOpenNavGroup("evolution");
      return;
    }

    if (activeView === "dashboard") {
      setOpenNavGroup(null);
    }
  }, [activeView]);

  function toggleNavGroup(
    group: "maintenance" | "diagnosis" | "evolution",
  ) {
    setOpenNavGroup((current) =>
      current === group ? null : group,
    );
  }
'@

    $CpuMarker = '  const cpu = Math.round(stats.cpu_usage);'
    $Index = $App.IndexOf($CpuMarker)

    if ($Index -lt 0) {
        throw "No se encontro un punto seguro para insertar el estado del menu."
    }

    $App = $App.Insert(
        $Index,
        $NavState + "`r`n"
    )

    Write-Host "[OK] Estado de secciones colapsables agregado" -ForegroundColor Green
}
else {
    Write-Host "[OK] Estado colapsable ya existe" -ForegroundColor Green
}

# ============================================================
# 2. EXTRAER BOTONES EXISTENTES DEL NAV
# ============================================================

$NavPattern = '(?s)(<nav className="nav">)(.*?)(</nav>)'
$NavMatch = [regex]::Match($App, $NavPattern)

if (-not $NavMatch.Success) {
    throw "No se encontro <nav className=`"nav`">."
}

$CurrentNav = $NavMatch.Groups[2].Value

function Get-ButtonByLabel {
    param(
        [string]$Nav,
        [string]$Label
    )

    $LabelIndex = $Nav.IndexOf($Label)

    if ($LabelIndex -lt 0) {
        return $null
    }

    $ButtonStart = $Nav.LastIndexOf("<button", $LabelIndex)

    if ($ButtonStart -lt 0) {
        return $null
    }

    $ButtonEnd = $Nav.IndexOf("</button>", $LabelIndex)

    if ($ButtonEnd -lt 0) {
        return $null
    }

    $ButtonEnd += "</button>".Length

    return $Nav.Substring(
        $ButtonStart,
        $ButtonEnd - $ButtonStart
    )
}

$Buttons = [ordered]@{
    DASHBOARD    = Get-ButtonByLabel $CurrentNav "Estado general"
    CLEANUP      = Get-ButtonByLabel $CurrentNav "Limpieza"
    STORAGE      = Get-ButtonByLabel $CurrentNav "Almacenamiento"
    PERFORMANCE  = Get-ButtonByLabel $CurrentNav "Rendimiento"
    STARTUP      = Get-ButtonByLabel $CurrentNav "Inicio de Windows"
    PROCESSES    = Get-ButtonByLabel $CurrentNav "Procesos"
    ANALYSIS     = Get-ButtonByLabel $CurrentNav "Análisis completo"
    INTELLIGENCE = Get-ButtonByLabel $CurrentNav "Centro inteligente"
    DIAGNOSIS    = Get-ButtonByLabel $CurrentNav "Diagnóstico"
    BASELINE     = Get-ButtonByLabel $CurrentNav "Baseline"
    COMPARE      = Get-ButtonByLabel $CurrentNav "Antes vs ahora"
    CHANGES      = Get-ButtonByLabel $CurrentNav "Qué cambió"
    HISTORY      = Get-ButtonByLabel $CurrentNav "Historial"
}

foreach ($Key in $Buttons.Keys) {
    if (-not $Buttons[$Key]) {
        throw "No se pudo localizar el boton: $Key"
    }
}

Write-Host "[OK] Todos los botones actuales fueron localizados" -ForegroundColor Green

# ============================================================
# 3. RECONSTRUIR NAV CON PLANTILLA LITERAL SEGURA
# ============================================================

# IMPORTANTE:
# Esta plantilla usa here-string de comilla SIMPLE (@' ... '@).
# Así PowerShell NO interpreta los backticks de JSX.
$NavTemplate = @'

          <div className="nav-group-label nav-group-static">
            RESUMEN
          </div>

__DASHBOARD__

          <button
            className={`nav-group-toggle ${
              openNavGroup === "maintenance" ? "open" : ""
            }`}
            onClick={() => toggleNavGroup("maintenance")}
            aria-expanded={openNavGroup === "maintenance"}
          >
            <span>MANTENIMIENTO</span>
            <span className="nav-group-chevron">
              {openNavGroup === "maintenance" ? "⌄" : "›"}
            </span>
          </button>

          {openNavGroup === "maintenance" && (
            <div className="nav-group-content">
__CLEANUP__
__STORAGE__
__PERFORMANCE__
__STARTUP__
__PROCESSES__
            </div>
          )}

          <button
            className={`nav-group-toggle ${
              openNavGroup === "diagnosis" ? "open" : ""
            }`}
            onClick={() => toggleNavGroup("diagnosis")}
            aria-expanded={openNavGroup === "diagnosis"}
          >
            <span>DIAGNÓSTICO</span>
            <span className="nav-group-chevron">
              {openNavGroup === "diagnosis" ? "⌄" : "›"}
            </span>
          </button>

          {openNavGroup === "diagnosis" && (
            <div className="nav-group-content">
__ANALYSIS__
__INTELLIGENCE__
__DIAGNOSIS__
            </div>
          )}

          <button
            className={`nav-group-toggle ${
              openNavGroup === "evolution" ? "open" : ""
            }`}
            onClick={() => toggleNavGroup("evolution")}
            aria-expanded={openNavGroup === "evolution"}
          >
            <span>EVOLUCIÓN</span>
            <span className="nav-group-chevron">
              {openNavGroup === "evolution" ? "⌄" : "›"}
            </span>
          </button>

          {openNavGroup === "evolution" && (
            <div className="nav-group-content">
__BASELINE__
__COMPARE__
__CHANGES__
__HISTORY__
            </div>
          )}

'@

function Normalize-ButtonIndent {
    param(
        [string]$Text,
        [string]$Indent
    )

    $Lines = $Text -split "`r?`n"

    return (($Lines | ForEach-Object {
        if ($_.Trim().Length -eq 0) {
            ""
        }
        else {
            $Indent + $_.TrimStart()
        }
    }) -join "`r`n")
}

$ReplacementMap = @{
    "__DASHBOARD__"    = Normalize-ButtonIndent $Buttons.DASHBOARD "          "
    "__CLEANUP__"      = Normalize-ButtonIndent $Buttons.CLEANUP "              "
    "__STORAGE__"      = Normalize-ButtonIndent $Buttons.STORAGE "              "
    "__PERFORMANCE__"  = Normalize-ButtonIndent $Buttons.PERFORMANCE "              "
    "__STARTUP__"      = Normalize-ButtonIndent $Buttons.STARTUP "              "
    "__PROCESSES__"    = Normalize-ButtonIndent $Buttons.PROCESSES "              "
    "__ANALYSIS__"     = Normalize-ButtonIndent $Buttons.ANALYSIS "              "
    "__INTELLIGENCE__" = Normalize-ButtonIndent $Buttons.INTELLIGENCE "              "
    "__DIAGNOSIS__"    = Normalize-ButtonIndent $Buttons.DIAGNOSIS "              "
    "__BASELINE__"     = Normalize-ButtonIndent $Buttons.BASELINE "              "
    "__COMPARE__"      = Normalize-ButtonIndent $Buttons.COMPARE "              "
    "__CHANGES__"      = Normalize-ButtonIndent $Buttons.CHANGES "              "
    "__HISTORY__"      = Normalize-ButtonIndent $Buttons.HISTORY "              "
}

$NewNavContent = $NavTemplate

foreach ($Token in $ReplacementMap.Keys) {
    $NewNavContent = $NewNavContent.Replace(
        $Token,
        $ReplacementMap[$Token]
    )
}

$NewNav =
    $NavMatch.Groups[1].Value +
    $NewNavContent +
    $NavMatch.Groups[3].Value

$App =
    $App.Substring(0, $NavMatch.Index) +
    $NewNav +
    $App.Substring($NavMatch.Index + $NavMatch.Length)

Write-Host "[OK] Sidebar reconstruido sin interpretar backticks JSX" -ForegroundColor Green

Set-Content -Path $AppPath -Value $App -Encoding UTF8

# ============================================================
# 4. CSS
# ============================================================

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch 'WINCARE COLLAPSIBLE NAV 0021B') {

$NavCss = @'

/* ==========================================================
   WINCARE COLLAPSIBLE NAV 0021B
   ========================================================== */

.nav-group-static {
  margin-top: 2px;
}

.nav-group-toggle {
  width: 100%;
  min-height: 42px;
  margin-top: 8px;
  padding: 0 10px;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: #65717e;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  cursor: pointer;
  font-size: 8px;
  line-height: 1;
  font-weight: 900;
  letter-spacing: 0.16em;
  text-align: left;
  transition:
    background 0.15s ease,
    color 0.15s ease;
}

.nav-group-toggle:hover {
  background: #11161c;
  color: #9ba5b0;
}

.nav-group-toggle.open {
  color: #8996a5;
}

.nav-group-chevron {
  width: 22px;
  height: 22px;
  flex: 0 0 22px;
  border-radius: 7px;
  display: grid;
  place-items: center;
  background: #11161c;
  color: #657aff;
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 0;
}

.nav-group-toggle.open .nav-group-chevron {
  background: rgba(99, 122, 255, 0.09);
}

.nav-group-content {
  position: relative;
  margin: 2px 0 6px 9px;
  padding: 2px 0 3px 10px;
  border-left: 1px solid #202833;
  animation: navGroupReveal 0.14s ease-out;
}

.nav-group-content .nav-item {
  min-height: 39px;
  margin: 2px 0;
  padding-left: 10px;
  border-radius: 9px;
  font-size: 13px;
}

.nav-group-content .nav-item.active {
  background:
    linear-gradient(
      90deg,
      rgba(99, 122, 255, 0.11),
      rgba(99, 122, 255, 0.025)
    ),
    #171d25;
}

.nav-group-content .nav-item.active::after {
  right: 8px;
}

@keyframes navGroupReveal {
  from {
    opacity: 0;
    transform: translateY(-3px);
  }

  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@media (max-height: 780px) {
  .nav-group-toggle {
    min-height: 37px;
    margin-top: 4px;
  }

  .nav-group-content .nav-item {
    min-height: 35px;
  }
}

'@

    Add-Content -Path $CssPath -Value $NavCss -Encoding UTF8
    Write-Host "[OK] Estilos de acordeon agregados" -ForegroundColor Green
}

# ============================================================
# 5. VERIFICACION PRE-BUILD
# ============================================================

$CheckApp = Get-Content $AppPath -Raw

$BrokenPatterns = @(
    'av-group-toggle',
    'className=\{\s*$',
    'className=\{\s*\d'
)

foreach ($Pattern in $BrokenPatterns) {
    if ($CheckApp -match $Pattern) {
        Copy-Item "$BackupDir\App.tsx" $AppPath -Force
        Copy-Item "$BackupDir\App.css" $CssPath -Force
        throw "Se detecto JSX potencialmente corrupto antes del build. Backup restaurado."
    }
}

if ($CheckApp -notmatch 'className=\{`nav-group-toggle \$\{') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico el template literal correcto del acordeon. Backup restaurado."
}

if ($CheckApp -notmatch 'toggleNavGroup\("maintenance"\)') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico Mantenimiento colapsable. Backup restaurado."
}

Write-Host "[OK] JSX verificado antes del build" -ForegroundColor Green

# ============================================================
# 6. BUILD
# ============================================================

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
Write-Host " FIX SIDEBAR 0021B COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Comportamiento:" -ForegroundColor Cyan
Write-Host " - Estado general siempre visible" -ForegroundColor White
Write-Host " - Mantenimiento / Diagnostico / Evolucion colapsables" -ForegroundColor White
Write-Host " - Solo un grupo abierto a la vez" -ForegroundColor White
Write-Host " - Procesos dentro de Mantenimiento" -ForegroundColor White
Write-Host " - La seccion activa se abre automaticamente" -ForegroundColor White
Write-Host ""
Write-Host "Ejecuta ahora:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
