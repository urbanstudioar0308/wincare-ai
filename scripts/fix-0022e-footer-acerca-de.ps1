$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$CssPath = "$ProjectRoot\src\App.css"
$BackupDir = "$ProjectRoot\Downloads\backup-0022e"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX 0022E" -ForegroundColor Cyan
Write-Host " Footer lateral -> Acerca de" -ForegroundColor Cyan
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
# 1. AGREGAR "about" A activeView
# ============================================================

$ActiveViewPattern = '(?s)(const\s+\[activeView,\s*setActiveView\]\s*=\s*useState<)(.*?)(>\s*\()'
$ActiveViewMatch = [regex]::Match($App, $ActiveViewPattern)

if (-not $ActiveViewMatch.Success) {
    throw "No se pudo localizar activeView."
}

$Union = $ActiveViewMatch.Groups[2].Value

if ($Union -notmatch '"about"') {
    $NewUnion = $Union.TrimEnd() + ' | "about"'

    $Replacement =
        $ActiveViewMatch.Groups[1].Value +
        $NewUnion +
        $ActiveViewMatch.Groups[3].Value

    $App =
        $App.Substring(0, $ActiveViewMatch.Index) +
        $Replacement +
        $App.Substring($ActiveViewMatch.Index + $ActiveViewMatch.Length)

    Write-Host "[OK] Vista about agregada a activeView" -ForegroundColor Green
}

# ============================================================
# 2. REEMPLAZAR FOOTER DEL SIDEBAR
# ============================================================

$FooterPattern = '(?s)<div className="sidebar-footer">.*?</div>\s*</aside>'

$FooterMatch = [regex]::Match($App, $FooterPattern)

if (-not $FooterMatch.Success) {
    throw "No se encontro sidebar-footer."
}

$NewFooter = @'
<div className="sidebar-footer">
          <button
            className={`about-sidebar-button ${
              activeView === "about" ? "active" : ""
            }`}
            onClick={() => setActiveView("about")}
          >
            <span className="about-sidebar-icon">i</span>

            <span className="about-sidebar-text">
              <strong>Acerca de</strong>
              <small>WinCare AI</small>
            </span>
          </button>
        </div>
      </aside>
'@

$App =
    $App.Substring(0, $FooterMatch.Index) +
    $NewFooter +
    $App.Substring($FooterMatch.Index + $FooterMatch.Length)

Write-Host "[OK] Footer reemplazado por acceso Acerca de" -ForegroundColor Green

# ============================================================
# 3. VISTA MINIMA ACERCA DE
# ============================================================

if ($App -notmatch 'activeView === "about" &&') {

$AboutView = @'

        {activeView === "about" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  ACERCA DE
                </span>

                <h2>
                  WinCare AI
                </h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                v0.1.0
              </div>
            </header>

            <section className="about-placeholder">
              <div className="about-placeholder-icon">
                i
              </div>

              <div>
                <span className="status-label">
                  INFORMACIÓN DE LA APLICACIÓN
                </span>

                <h3>
                  Diagnóstico Inteligente
                </h3>

                <p>
                  Esta pantalla queda preparada para integrar
                  el diseño final de Acerca de WinCare AI,
                  con logo, versión, privacidad, información
                  del sistema, licencias y enlaces.
                </p>
              </div>
            </section>
          </>
        )}
'@

    $MainClose = $App.LastIndexOf("</main>")

    if ($MainClose -lt 0) {
        throw "No se encontro </main>."
    }

    $App = $App.Insert(
        $MainClose,
        $AboutView + "`r`n      "
    )

    Write-Host "[OK] Vista Acerca de preparada" -ForegroundColor Green
}

Set-Content -Path $AppPath -Value $App -Encoding UTF8

# ============================================================
# 4. CSS
# ============================================================

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch 'WINCARE ABOUT FOOTER 0022E') {

$AboutCss = @'

/* ==========================================================
   WINCARE ABOUT FOOTER 0022E
   ========================================================== */

.sidebar-footer {
  padding: 14px 14px 16px;
  border-top: 1px solid #20262e;
}

.about-sidebar-button {
  width: 100%;
  border: 1px solid transparent;
  border-radius: 12px;
  background: transparent;
  color: #8893a0;
  padding: 10px;
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
  text-align: left;
  transition:
    background 0.15s ease,
    border-color 0.15s ease,
    color 0.15s ease;
}

.about-sidebar-button:hover {
  background: #141a21;
  border-color: #29313b;
  color: #ffffff;
}

.about-sidebar-button.active {
  background:
    linear-gradient(
      90deg,
      rgba(99, 122, 255, 0.12),
      rgba(99, 122, 255, 0.03)
    ),
    #181e26;
  border-color: #33425b;
  color: #ffffff;
}

.about-sidebar-icon {
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  border: 1px solid #33415a;
  background: #111720;
  color: #65bfff;
  font-weight: 900;
  font-size: 16px;
}

.about-sidebar-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.about-sidebar-text strong {
  font-size: 12px;
}

.about-sidebar-text small {
  color: #5f6a77;
  font-size: 9px;
}

.about-placeholder {
  min-height: 280px;
  border: 1px solid #232a33;
  border-radius: 20px;
  background:
    radial-gradient(
      circle at 85% 10%,
      rgba(0, 170, 255, 0.10),
      transparent 34%
    ),
    #101419;
  padding: 32px;
  display: flex;
  gap: 18px;
  align-items: flex-start;
}

.about-placeholder-icon {
  width: 50px;
  height: 50px;
  flex: 0 0 50px;
  border-radius: 15px;
  display: grid;
  place-items: center;
  color: #55c8ff;
  background: rgba(0, 174, 255, 0.08);
  border: 1px solid #2c6684;
  font-size: 22px;
  font-weight: 900;
}

.about-placeholder h3 {
  margin: 7px 0 9px;
  font-size: 27px;
}

.about-placeholder p {
  max-width: 720px;
  margin: 0;
  color: #727d89;
  line-height: 1.7;
  font-size: 12px;
}

'@

    Add-Content -Path $CssPath -Value $AboutCss -Encoding UTF8
    Write-Host "[OK] Estilos Acerca de agregados" -ForegroundColor Green
}

# ============================================================
# 5. VERIFICAR + BUILD
# ============================================================

$CheckApp = Get-Content $AppPath -Raw

if ($CheckApp -notmatch 'about-sidebar-button') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico el acceso Acerca de. Backup restaurado."
}

if ($CheckApp -notmatch 'activeView === "about" &&') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico la vista Acerca de. Backup restaurado."
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
Write-Host " FIX 0022E COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Footer inferior:" -ForegroundColor Cyan
Write-Host " - Acerca de" -ForegroundColor White
Write-Host " - WinCare AI" -ForegroundColor White
Write-Host ""
Write-Host "Ejecuta:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
