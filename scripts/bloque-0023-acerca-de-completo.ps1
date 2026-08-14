$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$CssPath = "$ProjectRoot\src\App.css"
$LibRsPath = "$ProjectRoot\src-tauri\src\lib.rs"
$PublicDir = "$ProjectRoot\public"
$LogoSource = "$ProjectRoot\scripts\wincare-ai-logo-oficial.png"
$LogoTarget = "$PublicDir\wincare-ai-logo-oficial.png"
$BackupDir = "$ProjectRoot\Downloads\backup-0023"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - BLOQUE 0023" -ForegroundColor Cyan
Write-Host " Pantalla Acerca de completa" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($Path in @($AppPath, $CssPath, $LibRsPath, $LogoSource)) {
    if (-not (Test-Path $Path)) {
        throw "No se encontro: $Path"
    }
}

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

if (-not (Test-Path $PublicDir)) {
    New-Item -ItemType Directory -Path $PublicDir | Out-Null
}

Copy-Item $AppPath "$BackupDir\App.tsx" -Force
Copy-Item $CssPath "$BackupDir\App.css" -Force
Copy-Item $LibRsPath "$BackupDir\lib.rs" -Force

if (Test-Path $LogoTarget) {
    Copy-Item $LogoTarget "$BackupDir\wincare-ai-logo-oficial.png" -Force
}

Write-Host "[OK] Backup creado" -ForegroundColor Green

# ============================================================
# 1. COPIAR LOGO OFICIAL
# ============================================================

Copy-Item $LogoSource $LogoTarget -Force

if (-not (Test-Path $LogoTarget)) {
    throw "No se pudo copiar el logo oficial."
}

Write-Host "[OK] Logo oficial copiado a public" -ForegroundColor Green

# ============================================================
# 2. RUST - DATOS REALES DEL SISTEMA
# ============================================================

$Lib = Get-Content $LibRsPath -Raw

if ($Lib -notmatch 'struct AboutSystemInfo') {

$RustAbout = @'

#[derive(Serialize, Clone)]
struct AboutSystemInfo {
    os_name: String,
    os_version: String,
    app_version: String,
    build: String,
    architecture: String,
    username: String,
    computer_name: String,
    app_ok: bool,
    app_status: String,
}

#[tauri::command]
fn get_about_system_info() -> AboutSystemInfo {
    let os_name = "Windows".to_string();

    let os_version = std::process::Command::new("cmd")
        .args(["/C", "ver"])
        .output()
        .ok()
        .and_then(|output| {
            String::from_utf8(output.stdout).ok()
        })
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "Windows".to_string());

    let username = std::env::var("USERNAME")
        .unwrap_or_else(|_| "Usuario".to_string());

    let computer_name = std::env::var("COMPUTERNAME")
        .unwrap_or_else(|_| "PC".to_string());

    let architecture = std::env::consts::ARCH.to_string();

    let app_version = env!("CARGO_PKG_VERSION").to_string();

    let build = format!(
        "{}-{}",
        env!("CARGO_PKG_VERSION"),
        std::env::consts::ARCH
    );

    AboutSystemInfo {
        os_name,
        os_version,
        app_version,
        build,
        architecture,
        username,
        computer_name,
        app_ok: true,
        app_status: "Funcionando correctamente".to_string(),
    }
}
'@

    $Marker = '#[cfg_attr(mobile, tauri::mobile_entry_point)]'
    $Index = $Lib.IndexOf($Marker)

    if ($Index -lt 0) {
        throw "No se encontro mobile_entry_point en lib.rs."
    }

    $Lib = $Lib.Insert(
        $Index,
        $RustAbout + "`r`n"
    )

    Write-Host "[OK] Comando get_about_system_info agregado" -ForegroundColor Green
}

# Registrar comando Tauri
$HandlerPattern = '(?s)(tauri::generate_handler!\[)(.*?)(\]\))'
$HandlerMatch = [regex]::Match($Lib, $HandlerPattern)

if (-not $HandlerMatch.Success) {
    throw "No se encontro tauri::generate_handler."
}

$HandlerBody = $HandlerMatch.Groups[2].Value

if ($HandlerBody -notmatch 'get_about_system_info') {
    $Trimmed = $HandlerBody.TrimEnd()

    if ($Trimmed.EndsWith(",")) {
        $NewBody = $Trimmed + "`r`n            get_about_system_info`r`n        "
    }
    else {
        $NewBody = $Trimmed + ",`r`n            get_about_system_info`r`n        "
    }

    $NewHandler =
        $HandlerMatch.Groups[1].Value +
        $NewBody +
        $HandlerMatch.Groups[3].Value

    $Lib =
        $Lib.Substring(0, $HandlerMatch.Index) +
        $NewHandler +
        $Lib.Substring($HandlerMatch.Index + $HandlerMatch.Length)
}

Set-Content -Path $LibRsPath -Value $Lib -Encoding UTF8

# ============================================================
# 3. REACT - TIPO + ESTADO
# ============================================================

$App = Get-Content $AppPath -Raw

if ($App -notmatch 'type AboutSystemInfo') {

$AboutType = @'

type AboutSystemInfo = {
  os_name: string;
  os_version: string;
  app_version: string;
  build: string;
  architecture: string;
  username: string;
  computer_name: string;
  app_ok: boolean;
  app_status: string;
};
'@

    $ConstIndex = $App.IndexOf("const emptyStats")

    if ($ConstIndex -lt 0) {
        throw "No se encontro const emptyStats."
    }

    $App = $App.Insert(
        $ConstIndex,
        $AboutType + "`r`n"
    )

    Write-Host "[OK] Tipo AboutSystemInfo agregado" -ForegroundColor Green
}

if ($App -notmatch 'aboutInfoLoading') {

$AboutState = @'

  const [aboutInfo, setAboutInfo] =
    useState<AboutSystemInfo | null>(null);

  const [aboutInfoLoading, setAboutInfoLoading] =
    useState(false);

  const [updateMessage, setUpdateMessage] =
    useState("");

  async function loadAboutInfo() {
    setAboutInfoLoading(true);

    try {
      const info =
        await invoke<AboutSystemInfo>(
          "get_about_system_info",
        );

      setAboutInfo(info);
    } catch (error) {
      console.error(
        "No se pudo leer informacion del sistema:",
        error,
      );

      setAboutInfo({
        os_name: "Windows",
        os_version: "No disponible",
        app_version: "0.1.0",
        build: "No disponible",
        architecture: "No disponible",
        username: "No disponible",
        computer_name: "No disponible",
        app_ok: false,
        app_status:
          "No se pudo leer toda la informacion del sistema",
      });
    } finally {
      setAboutInfoLoading(false);
    }
  }

  function checkLocalUpdates() {
    const version =
      aboutInfo?.app_version ?? "0.1.0";

    setUpdateMessage(
      `Estás usando WinCare AI v${version}. Las actualizaciones automáticas todavía no están habilitadas en este MVP.`,
    );
  }
'@

    $LoadStatsIndex = $App.IndexOf("  async function loadStats()")

    if ($LoadStatsIndex -lt 0) {
        throw "No se encontro loadStats."
    }

    $App = $App.Insert(
        $LoadStatsIndex,
        $AboutState + "`r`n"
    )

    Write-Host "[OK] Estado y carga de Acerca de agregados" -ForegroundColor Green
}

# ============================================================
# 4. HACER QUE EL BOTON ACERCA DE CARGUE LOS DATOS
# ============================================================

$OldAboutClick = 'onClick={() => setActiveView("about")}'

$NewAboutClick = @'
onClick={() => {
              setActiveView("about");

              if (!aboutInfo) {
                loadAboutInfo();
              }
            }}
'@

if ($App.Contains($OldAboutClick)) {
    $App = $App.Replace(
        $OldAboutClick,
        $NewAboutClick
    )
}

# ============================================================
# 5. REEMPLAZAR LA VISTA PLACEHOLDER ACERCA DE
# ============================================================

$AboutViewPattern = '(?s)\{activeView === "about" && \(\s*<>.*?</>\s*\)\}'

$AboutViewMatch = [regex]::Match(
    $App,
    $AboutViewPattern
)

if (-not $AboutViewMatch.Success) {
    throw "No se encontro la vista Acerca de actual."
}

$NewAboutView = @'
{activeView === "about" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  ACERCA DE
                </span>

                <h2>
                  Información de la aplicación
                </h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                v{aboutInfo?.app_version ?? "0.1.0"}
              </div>
            </header>

            <section className="about-full-layout">
              <div className="about-brand-panel">
                <img
                  className="about-official-logo"
                  src="/wincare-ai-logo-oficial.png"
                  alt="WinCare AI - Diagnóstico inteligente para Windows"
                />

                <p className="about-tagline">
                  Mantén tu PC funcionando de forma
                  <strong> rápida, estable y segura.</strong>
                </p>
              </div>

              <div className="about-info-column">
                <article className="about-info-card">
                  <div className="about-card-title">
                    <span className="about-card-icon">
                      ▣
                    </span>

                    <h3>
                      Información del sistema
                    </h3>
                  </div>

                  {aboutInfoLoading && (
                    <div className="about-loading">
                      Leyendo información del equipo...
                    </div>
                  )}

                  {!aboutInfoLoading && (
                    <div className="about-data-list">
                      <div>
                        <span>Sistema operativo</span>
                        <strong>
                          {aboutInfo?.os_name ?? "Windows"}
                        </strong>
                      </div>

                      <div>
                        <span>Versión del sistema</span>
                        <strong>
                          {aboutInfo?.os_version ??
                            "No disponible"}
                        </strong>
                      </div>

                      <div>
                        <span>Versión de WinCare AI</span>
                        <strong>
                          v{aboutInfo?.app_version ?? "0.1.0"}
                        </strong>
                      </div>

                      <div>
                        <span>Build</span>
                        <strong>
                          {aboutInfo?.build ?? "No disponible"}
                        </strong>
                      </div>

                      <div>
                        <span>Arquitectura</span>
                        <strong>
                          {aboutInfo?.architecture ??
                            "No disponible"}
                        </strong>
                      </div>

                      <div>
                        <span>Usuario</span>
                        <strong>
                          {aboutInfo?.username ??
                            "No disponible"}
                        </strong>
                      </div>

                      <div>
                        <span>Nombre del PC</span>
                        <strong>
                          {aboutInfo?.computer_name ??
                            "No disponible"}
                        </strong>
                      </div>
                    </div>
                  )}
                </article>

                <article className="about-info-card">
                  <div className="about-card-title">
                    <span className="about-card-icon">
                      ⚙
                    </span>

                    <h3>
                      Recursos de la app
                    </h3>
                  </div>

                  <div className="about-data-list">
                    <div>
                      <span>Motor</span>
                      <strong>
                        WinCare AI Core
                      </strong>
                    </div>

                    <div>
                      <span>Diagnóstico</span>
                      <strong>
                        Reglas inteligentes + análisis local
                      </strong>
                    </div>

                    <div>
                      <span>Base de análisis</span>
                      <strong>
                        Baseline + historial + snapshots
                      </strong>
                    </div>

                    <div>
                      <span>Actualizaciones</span>
                      <strong>
                        Manuales
                      </strong>
                    </div>

                    <div>
                      <span>Privacidad</span>
                      <strong>
                        Procesamiento local
                      </strong>
                    </div>
                  </div>
                </article>
              </div>
            </section>

            <section
              className={`about-app-status ${
                aboutInfo?.app_ok === false
                  ? "warning"
                  : "good"
              }`}
            >
              <div className="about-status-shield">
                {aboutInfo?.app_ok === false
                  ? "!"
                  : "✓"}
              </div>

              <div>
                <span className="status-label">
                  ESTADO DE LA APLICACIÓN
                </span>

                <h3>
                  {aboutInfo?.app_status ??
                    "Funcionando correctamente"}
                </h3>

                <p>
                  {aboutInfo?.app_ok === false
                    ? "Uno o más datos del sistema no pudieron leerse correctamente."
                    : "Los módulos locales de WinCare AI están disponibles y la aplicación está respondiendo correctamente."}
                </p>
              </div>
            </section>

            <section className="about-actions">
              <button
                disabled
                title="Disponible cuando exista el sitio oficial"
              >
                <span>▣</span>
                <strong>Sitio oficial</strong>
                <small>Próximamente</small>
              </button>

              <button
                disabled
                title="Disponible cuando se defina el canal de soporte"
              >
                <span>◉</span>
                <strong>Soporte</strong>
                <small>Próximamente</small>
              </button>

              <button
                onClick={checkLocalUpdates}
              >
                <span>⇧</span>
                <strong>
                  Buscar actualizaciones
                </strong>
                <small>
                  Comprobación local
                </small>
              </button>
            </section>

            {updateMessage && (
              <section className="about-update-message">
                <span>i</span>
                <p>{updateMessage}</p>
              </section>
            )}

            <footer className="about-product-footer">
              <strong>
                WinCare AI © 2026
              </strong>

              <span>•</span>

              <span>
                v{aboutInfo?.app_version ?? "0.1.0"} — MVP
              </span>

              <span>•</span>

              <span>
                Diagnóstico inteligente para Windows
              </span>
            </footer>
          </>
        )}
'@

$App =
    $App.Substring(0, $AboutViewMatch.Index) +
    $NewAboutView +
    $App.Substring(
        $AboutViewMatch.Index +
        $AboutViewMatch.Length
    )

Set-Content -Path $AppPath -Value $App -Encoding UTF8

Write-Host "[OK] Pantalla Acerca de completa integrada" -ForegroundColor Green

# ============================================================
# 6. CSS
# ============================================================

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch 'WINCARE ABOUT FULL 0023') {

$AboutCss = @'

/* ==========================================================
   WINCARE ABOUT FULL 0023
   ========================================================== */

.about-full-layout {
  display: grid;
  grid-template-columns:
    minmax(340px, 0.9fr)
    minmax(520px, 1.35fr);
  gap: 18px;
  align-items: stretch;
}

.about-brand-panel {
  min-height: 470px;
  border: 1px solid #223347;
  border-radius: 22px;
  background:
    radial-gradient(
      circle at 50% 38%,
      rgba(0, 159, 255, 0.15),
      transparent 44%
    ),
    linear-gradient(
      145deg,
      #0e151e,
      #0b1016
    );
  padding: 28px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  overflow: hidden;
}

.about-official-logo {
  width: min(100%, 520px);
  max-height: 360px;
  display: block;
  object-fit: contain;
  filter:
    drop-shadow(
      0 0 20px rgba(0, 160, 255, 0.18)
    );
}

.about-tagline {
  max-width: 430px;
  margin: 18px auto 0;
  text-align: center;
  color: #aeb7c2;
  font-size: 14px;
  line-height: 1.6;
}

.about-tagline strong {
  color: #48d0ff;
}

.about-info-column {
  display: grid;
  grid-template-rows: 1fr 1fr;
  gap: 18px;
}

.about-info-card {
  border: 1px solid #223347;
  border-radius: 20px;
  background:
    linear-gradient(
      145deg,
      #101720,
      #0d1218
    );
  padding: 21px;
}

.about-card-title {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 15px;
}

.about-card-title h3 {
  margin: 0;
  font-size: 18px;
}

.about-card-icon {
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  color: #43c8ff;
  border: 1px solid #285b76;
  background: rgba(0, 174, 255, 0.07);
}

.about-data-list {
  display: flex;
  flex-direction: column;
}

.about-data-list > div {
  min-height: 39px;
  border-top: 1px solid #1f2a35;
  display: grid;
  grid-template-columns:
    minmax(150px, 0.8fr)
    minmax(190px, 1.2fr);
  gap: 15px;
  align-items: center;
}

.about-data-list > div:first-child {
  border-top: 0;
}

.about-data-list span {
  color: #7c8793;
  font-size: 10px;
}

.about-data-list strong {
  color: #e7ebef;
  font-size: 11px;
  font-weight: 700;
  text-align: right;
  overflow-wrap: anywhere;
}

.about-loading {
  min-height: 160px;
  display: grid;
  place-items: center;
  color: #6d7885;
  font-size: 11px;
}

.about-app-status {
  margin-top: 18px;
  border-radius: 18px;
  padding: 20px 22px;
  display: flex;
  align-items: center;
  gap: 15px;
}

.about-app-status.good {
  border: 1px solid #26543a;
  background:
    rgba(42, 165, 95, 0.055);
}

.about-app-status.warning {
  border: 1px solid #5c4927;
  background:
    rgba(225, 170, 79, 0.055);
}

.about-status-shield {
  width: 46px;
  height: 46px;
  flex: 0 0 46px;
  border-radius: 14px;
  display: grid;
  place-items: center;
  color: #55d18b;
  background:
    rgba(62, 201, 125, 0.09);
  border: 1px solid #2b6143;
  font-size: 19px;
  font-weight: 900;
}

.about-app-status.warning .about-status-shield {
  color: #e5b05a;
  background:
    rgba(225, 170, 79, 0.09);
  border-color: #624c27;
}

.about-app-status h3 {
  margin: 5px 0;
  font-size: 18px;
}

.about-app-status p {
  margin: 0;
  color: #6f7b87;
  font-size: 10px;
}

.about-actions {
  display: grid;
  grid-template-columns:
    repeat(3, minmax(0, 1fr));
  gap: 12px;
  margin-top: 18px;
}

.about-actions button {
  min-height: 84px;
  border: 1px solid #273543;
  border-radius: 16px;
  background: #10161d;
  color: white;
  display: grid;
  grid-template-columns:
    34px 1fr;
  grid-template-rows:
    auto auto;
  column-gap: 10px;
  align-items: center;
  padding: 14px;
  text-align: left;
  cursor: pointer;
}

.about-actions button:hover:not(:disabled) {
  border-color: #34759a;
  background: #121b24;
}

.about-actions button:disabled {
  opacity: 0.48;
  cursor: not-allowed;
}

.about-actions button > span {
  grid-row: 1 / span 2;
  width: 34px;
  height: 34px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  color: #46caff;
  background:
    rgba(0, 174, 255, 0.07);
}

.about-actions strong {
  font-size: 11px;
}

.about-actions small {
  color: #65717d;
  font-size: 9px;
}

.about-update-message {
  margin-top: 12px;
  border: 1px solid #283649;
  border-radius: 13px;
  background: #0f151d;
  padding: 12px 15px;
  display: flex;
  gap: 10px;
  align-items: center;
}

.about-update-message > span {
  width: 26px;
  height: 26px;
  flex: 0 0 26px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  color: #5bcaff;
  background: rgba(0, 174, 255, 0.08);
  font-weight: 900;
}

.about-update-message p {
  margin: 0;
  color: #85909c;
  font-size: 10px;
}

.about-product-footer {
  min-height: 52px;
  margin-top: 18px;
  border-top: 1px solid #202833;
  color: #697581;
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  align-items: center;
  gap: 9px;
  font-size: 9px;
}

.about-product-footer strong {
  color: #cbd2d9;
}

@media (max-width: 1100px) {
  .about-full-layout {
    grid-template-columns: 1fr;
  }

  .about-brand-panel {
    min-height: 360px;
  }
}

@media (max-width: 700px) {
  .about-actions {
    grid-template-columns: 1fr;
  }

  .about-data-list > div {
    grid-template-columns: 1fr;
    gap: 3px;
    padding: 9px 0;
  }

  .about-data-list strong {
    text-align: left;
  }
}

'@

    Add-Content -Path $CssPath -Value $AboutCss -Encoding UTF8
    Write-Host "[OK] Estilos de Acerca de agregados" -ForegroundColor Green
}

# ============================================================
# 7. CHECK RUST + BUILD FRONTEND
# ============================================================

Write-Host ""
Write-Host "Validando Rust..." -ForegroundColor Yellow

Set-Location "$ProjectRoot\src-tauri"
cargo check

if ($LASTEXITCODE -ne 0) {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    Copy-Item "$BackupDir\lib.rs" $LibRsPath -Force
    throw "cargo check fallo. Backup restaurado."
}

Write-Host ""
Write-Host "Validando frontend..." -ForegroundColor Yellow

Set-Location $ProjectRoot
npm run build

if ($LASTEXITCODE -ne 0) {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    Copy-Item "$BackupDir\lib.rs" $LibRsPath -Force
    throw "npm run build fallo. Backup restaurado."
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " BLOQUE 0023 COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Incluye:" -ForegroundColor Cyan
Write-Host " - Logo oficial grande" -ForegroundColor White
Write-Host " - Datos reales del sistema" -ForegroundColor White
Write-Host " - Recursos reales de la app" -ForegroundColor White
Write-Host " - Estado de la aplicacion" -ForegroundColor White
Write-Host " - Botones Sitio / Soporte / Actualizaciones" -ForegroundColor White
Write-Host " - Footer WinCare AI 2026" -ForegroundColor White
Write-Host ""
Write-Host "Ejecuta:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
