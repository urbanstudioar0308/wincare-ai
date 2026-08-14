$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$BackupDir = "$ProjectRoot\Downloads\backup-0016c"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX 0016C" -ForegroundColor Cyan
Write-Host " Baseline en sidebar" -ForegroundColor Cyan
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

if ($App -notmatch 'activeView\s*===\s*"baseline"') {
    throw "La vista Baseline no existe. No se modificara App.tsx."
}

if ($App -notmatch 'calculateBaseline') {
    throw "El motor calculateBaseline no existe."
}

Write-Host "[OK] Vista Baseline encontrada" -ForegroundColor Green
Write-Host "[OK] Motor Baseline encontrado" -ForegroundColor Green

$NavPattern = '(?s)(<nav className="nav">)(.*?)(</nav>)'

$NavMatch = [regex]::Match($App, $NavPattern)

if (-not $NavMatch.Success) {
    throw "No se encontro el NAV principal."
}

$NavContent = $NavMatch.Groups[2].Value

if ($NavContent -match '(?s)>\s*Baseline\s*</button>') {
    Write-Host "[OK] Baseline ya estaba dentro del sidebar" -ForegroundColor Green
}
else {
    $BaselineButton = @'

          <button
            className={`nav-item ${
              activeView === "baseline"
                ? "active"
                : ""
            }`}
            onClick={() => {
              setActiveView("baseline");

              if (history.length === 0) {
                loadHistory();
              }
            }}
          >
            Baseline
          </button>

'@

    $HistoryTextPosition = $NavContent.IndexOf("Historial")

    if ($HistoryTextPosition -lt 0) {
        throw "No se encontro el boton Historial dentro del sidebar."
    }

    $HistoryButtonStart = $NavContent.LastIndexOf(
        "<button",
        $HistoryTextPosition
    )

    if ($HistoryButtonStart -lt 0) {
        throw "No se encontro el inicio del boton Historial."
    }

    $NewNavContent = $NavContent.Insert(
        $HistoryButtonStart,
        $BaselineButton
    )

    $NewNav = $NavMatch.Groups[1].Value +
              $NewNavContent +
              $NavMatch.Groups[3].Value

    $App = $App.Substring(0, $NavMatch.Index) +
           $NewNav +
           $App.Substring(
               $NavMatch.Index + $NavMatch.Length
           )

    Set-Content `
        -Path $AppPath `
        -Value $App `
        -Encoding UTF8

    Write-Host "[OK] Baseline insertado antes de Historial" -ForegroundColor Green
}

$Check = Get-Content $AppPath -Raw

$CheckNav = [regex]::Match(
    $Check,
    $NavPattern
).Groups[2].Value

if ($CheckNav -notmatch '(?s)>\s*Baseline\s*</button>') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    throw "La verificacion fallo. Se restauro el backup."
}

Write-Host ""
Write-Host "[OK] VERIFICADO: Baseline esta en el sidebar" -ForegroundColor Green
Write-Host ""

Write-Host "Menu detectado:" -ForegroundColor Cyan

$Buttons = [regex]::Matches(
    $CheckNav,
    '(?s)<button.*?>\s*([^<>{}]+?)\s*</button>'
)

foreach ($Button in $Buttons) {
    $Label = $Button.Groups[1].Value.Trim()

    if ($Label) {
        Write-Host " - $Label" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "Ejecutando build..." -ForegroundColor Yellow

Set-Location $ProjectRoot

npm run build

if ($LASTEXITCODE -ne 0) {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    throw "Build fallido. Se restauro App.tsx."
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " FIX 0016C COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
