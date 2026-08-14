$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$CssPath = "$ProjectRoot\src\App.css"
$BackupDir = "$ProjectRoot\Downloads\backup-0021a"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX SIDEBAR 0021A" -ForegroundColor Cyan
Write-Host " Secciones colapsables" -ForegroundColor Cyan
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
# 2. RECONSTRUIR SOLO EL CONTENIDO DEL NAV
# ============================================================

$NavPattern = '(?s)(<nav className="nav">)(.*?)(</nav>)'
$NavMatch = [regex]::Match($App, $NavPattern)

if (-not $NavMatch.Success) {
    throw "No se encontro <nav className=`"nav`">."
}

$CurrentNav = $NavMatch.Groups[2].Value

# Extraer botones existentes por su texto visible, para conservar
# exactamente los onClick que ya funcionan.
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

$DashboardButton = Get-ButtonByLabel $CurrentNav "Estado general"
$CleanupButton = Get-ButtonByLabel $CurrentNav "Limpieza"
$StorageButton = Get-ButtonByLabel $CurrentNav "Almacenamiento"
$PerformanceButton = Get-ButtonByLabel $CurrentNav "Rendimiento"
$StartupButton = Get-ButtonByLabel $CurrentNav "Inicio de Windows"
$ProcessesButton = Get-ButtonByLabel $CurrentNav "Procesos"

$AnalysisButton = Get-ButtonByLabel $CurrentNav "Análisis completo"
$IntelligenceButton = Get-ButtonByLabel $CurrentNav "Centro inteligente"
$DiagnosisButton = Get-ButtonByLabel $CurrentNav "Diagnóstico"

$BaselineButton = Get-ButtonByLabel $CurrentNav "Baseline"
$CompareButton = Get-ButtonByLabel $CurrentNav "Antes vs ahora"
$ChangesButton = Get-ButtonByLabel $CurrentNav "Qué cambió"
$HistoryButton = Get-ButtonByLabel $CurrentNav "Historial"

$RequiredButtons = @{
    "Estado general" = $DashboardButton
    "Limpieza" = $CleanupButton
    "Almacenamiento" = $StorageButton
    "Rendimiento" = $PerformanceButton
    "Inicio de Windows" = $StartupButton
    "Procesos" = $ProcessesButton
    "Análisis completo" = $AnalysisButton
    "Centro inteligente" = $IntelligenceButton
    "Diagnóstico" = $DiagnosisButton
    "Baseline" = $BaselineButton
    "Antes vs ahora" = $CompareButton
    "Qué cambió" = $ChangesButton
    "Historial" = $HistoryButton
}

foreach ($Key in $RequiredButtons.Keys) {
    if (-not $RequiredButtons[$Key]) {
        throw "No se pudo localizar el boton: $Key"
    }
}

function Indent-Block {
    param(
        [string]$Text,
        [string]$Indent = "            "
    )

    $Lines = $Text -split "`r?`n"
    return ($Lines | ForEach-Object {
        if ($_ -eq "") {
            ""
        }
        else {
            $Indent + $_.TrimStart()
        }
    }) -join "`r`n"
}

$DashboardButton = Indent-Block $DashboardButton "          "
$CleanupButton = Indent-Block $CleanupButton "            "
$StorageButton = Indent-Block $StorageButton "            "
$PerformanceButton = Indent-Block $PerformanceButton "            "
$StartupButton = Indent-Block $StartupButton "            "
$ProcessesButton = Indent-Block $ProcessesButton "            "

$AnalysisButton = Indent-Block $AnalysisButton "            "
$IntelligenceButton = Indent-Block $IntelligenceButton "            "
$DiagnosisButton = Indent-Block $DiagnosisButton "            "

$BaselineButton = Indent-Block $BaselineButton "            "
$CompareButton = Indent-Block $CompareButton "            "
$ChangesButton = Indent-Block $ChangesButton "            "
$HistoryButton = Indent-Block $HistoryButton "            "

$NewNavContent = @"

          <div className="nav-group-label nav-group-static">
            RESUMEN
          </div>

$DashboardButton

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
$CleanupButton
$StorageButton
$PerformanceButton
$StartupButton
$ProcessesButton
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
$AnalysisButton
$IntelligenceButton
$DiagnosisButton
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
$BaselineButton
$CompareButton
$ChangesButton
$HistoryButton
            </div>
          )}

"@

$NewNav =
    $NavMatch.Groups[1].Value +
    $NewNavContent +
    $NavMatch.Groups[3].Value

$App =
    $App.Substring(0, $NavMatch.Index) +
    $NewNav +
    $App.Substring($NavMatch.Index + $NavMatch.Length)

Write-Host "[OK] Sidebar reconstruido con acordeones" -ForegroundColor Green

Set-Content -Path $AppPath -Value $App -Encoding UTF8

# ============================================================
# 3. CSS
# ============================================================

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch 'WINCARE COLLAPSIBLE NAV 0021A') {

$NavCss = @'

/* ==========================================================
   WINCARE COLLAPSIBLE NAV 0021A
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
  color: #8390a0;
}

.nav-group-chevron {
  width: 22px;
  height: 22px;
  border-radius: 7px;
  display: grid;
  place-items: center;
  background: #11161c;
  color: #657aff;
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 0;
  transition:
    transform 0.15s ease,
    background 0.15s ease;
}

.nav-group-toggle.open .nav-group-chevron {
  background: rgba(99, 122, 255, 0.08);
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
# 4. VERIFICAR + BUILD
# ============================================================

$CheckApp = Get-Content $AppPath -Raw

if ($CheckApp -notmatch 'toggleNavGroup\("maintenance"\)') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico Mantenimiento colapsable. Backup restaurado."
}

if ($CheckApp -notmatch 'openNavGroup === "diagnosis"') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico Diagnostico colapsable. Backup restaurado."
}

if ($CheckApp -notmatch 'openNavGroup === "evolution"') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico Evolucion colapsable. Backup restaurado."
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
Write-Host " FIX SIDEBAR 0021A COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Comportamiento:" -ForegroundColor Cyan
Write-Host " - Resumen queda visible" -ForegroundColor White
Write-Host " - Solo un grupo se abre a la vez" -ForegroundColor White
Write-Host " - Mantenimiento incluye Procesos" -ForegroundColor White
Write-Host " - El grupo de la pantalla activa se abre automaticamente" -ForegroundColor White
Write-Host ""
Write-Host "Ejecuta ahora:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
