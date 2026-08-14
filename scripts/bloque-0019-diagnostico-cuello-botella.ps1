$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$CssPath = "$ProjectRoot\src\App.css"
$BackupDir = "$ProjectRoot\Downloads\backup-0019"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - BLOQUE 0019" -ForegroundColor Cyan
Write-Host " Diagnostico de cuello de botella" -ForegroundColor Cyan
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

if ($App -notmatch 'type PerformanceAnalysis') {
    throw "No se encontro PerformanceAnalysis."
}

if ($App -notmatch 'const baseline =') {
    throw "No se encontro Baseline."
}

if ($App -notmatch 'processes') {
    throw "No se encontro el modulo de Procesos."
}

# ============================================================
# 1. ACTIVE VIEW
# ============================================================

$ActiveViewPattern = '(?s)(const\s+\[activeView,\s*setActiveView\]\s*=\s*useState<)(.*?)(>\s*\()'
$ActiveViewMatch = [regex]::Match($App, $ActiveViewPattern)

if (-not $ActiveViewMatch.Success) {
    throw "No se pudo localizar activeView."
}

$Union = $ActiveViewMatch.Groups[2].Value

if ($Union -notmatch '"diagnosis"') {
    $NewUnion = $Union.TrimEnd() + ' | "diagnosis"'

    $Replacement =
        $ActiveViewMatch.Groups[1].Value +
        $NewUnion +
        $ActiveViewMatch.Groups[3].Value

    $App =
        $App.Substring(0, $ActiveViewMatch.Index) +
        $Replacement +
        $App.Substring($ActiveViewMatch.Index + $ActiveViewMatch.Length)

    Write-Host "[OK] Vista diagnosis agregada" -ForegroundColor Green
}

# ============================================================
# 2. MOTOR DE DIAGNOSTICO
# ============================================================

if ($App -notmatch 'const bottleneckDiagnosis =') {

$DiagnosisLogic = @'

  const bottleneckDiagnosis = (() => {
    if (!performance) {
      return null;
    }

    const topProcesses =
      (processes?.processes ?? [])
        .slice()
        .sort(
          (a, b) =>
            b.memory_bytes - a.memory_bytes,
        )
        .slice(0, 5);

    const cpuPressure =
      performance.cpu_usage >= 85
        ? 100
        : performance.cpu_usage >= 70
          ? 80
          : performance.cpu_usage >= 50
            ? 55
            : performance.cpu_usage >= 30
              ? 30
              : 10;

    const ramPressure =
      performance.ram_usage_percent >= 90
        ? 100
        : performance.ram_usage_percent >= 80
          ? 85
          : performance.ram_usage_percent >= 70
            ? 65
            : performance.ram_usage_percent >= 60
              ? 40
              : 15;

    const diskPressure =
      performance.disk_usage_percent >= 95
        ? 100
        : performance.disk_usage_percent >= 90
          ? 85
          : performance.disk_usage_percent >= 80
            ? 65
            : performance.disk_usage_percent >= 70
              ? 40
              : 15;

    const startupPressure =
      performance.active_startup_items >= 15
        ? 95
        : performance.active_startup_items >= 10
          ? 75
          : performance.active_startup_items >= 6
            ? 50
            : 20;

    const processPressure =
      performance.heavy_processes >= 10
        ? 95
        : performance.heavy_processes >= 6
          ? 75
          : performance.heavy_processes >= 3
            ? 55
            : performance.heavy_processes >= 1
              ? 30
              : 10;

    const baselineRamBoost =
      baseline?.ram.status === "critical"
        ? 20
        : baseline?.ram.status === "warning"
          ? 10
          : 0;

    const baselineCpuBoost =
      baseline?.cpu.status === "critical"
        ? 20
        : baseline?.cpu.status === "warning"
          ? 10
          : 0;

    const baselineDiskBoost =
      baseline?.disk.status === "critical"
        ? 20
        : baseline?.disk.status === "warning"
          ? 10
          : 0;

    const baselineStartupBoost =
      baseline?.startup.status === "critical"
        ? 20
        : baseline?.startup.status === "warning"
          ? 10
          : 0;

    const candidates = [
      {
        id: "ram",
        label: "Memoria RAM",
        score: ramPressure + baselineRamBoost,
        current: `${Math.round(
          performance.ram_usage_percent,
        )}%`,
        explanation:
          "La presión de memoria puede hacer que Windows use más memoria virtual y responda con mayor lentitud.",
        action: "processes",
      },
      {
        id: "cpu",
        label: "CPU",
        score: cpuPressure + baselineCpuBoost,
        current: `${Math.round(
          performance.cpu_usage,
        )}%`,
        explanation:
          "Una CPU sostenidamente ocupada puede retrasar aplicaciones, animaciones y tareas en segundo plano.",
        action: "processes",
      },
      {
        id: "disk",
        label: "Almacenamiento",
        score: diskPressure + baselineDiskBoost,
        current: `${Math.round(
          performance.disk_usage_percent,
        )}% ocupado`,
        explanation:
          "Una unidad muy llena reduce el margen de trabajo de Windows y puede afectar actualizaciones, temporales y memoria virtual.",
        action: "storage",
      },
      {
        id: "startup",
        label: "Inicio de Windows",
        score:
          startupPressure +
          baselineStartupBoost,
        current: `${
          performance.active_startup_items
        } apps`,
        explanation:
          "Muchos programas iniciándose con Windows aumentan la carga inicial y pueden mantener procesos residentes.",
        action: "startup",
      },
      {
        id: "processes",
        label: "Procesos pesados",
        score: processPressure,
        current: `${
          performance.heavy_processes
        } detectados`,
        explanation:
          "Los procesos de alto consumo pueden concentrar RAM o CPU aunque el resto del sistema esté en buen estado.",
        action: "processes",
      },
    ]
      .map((item) => ({
        ...item,
        score: Math.min(item.score, 100),
      }))
      .sort((a, b) => b.score - a.score);

    const primary = candidates[0];
    const secondary = candidates[1];

    const confidence =
      baseline?.level === "established"
        ? "Alta"
        : baseline?.level === "preliminary"
          ? "Media"
          : "Inicial";

    let state:
      | "good"
      | "attention"
      | "critical" = "good";

    if (primary.score >= 85) {
      state = "critical";
    } else if (primary.score >= 55) {
      state = "attention";
    }

    const headline =
      state === "good"
        ? "No hay un cuello de botella dominante"
        : `El principal cuello de botella parece ser ${primary.label}`;

    const summary =
      state === "good"
        ? "Los recursos principales están relativamente equilibrados en este momento."
        : `${primary.label} presenta la mayor presión relativa del sistema. ${primary.explanation}`;

    return {
      primary,
      secondary,
      candidates,
      confidence,
      state,
      headline,
      summary,
      topProcesses,
    };
  })();
'@

    $LoadStatsIndex = $App.IndexOf("  async function loadStats()")

    if ($LoadStatsIndex -lt 0) {
        throw "No se encontro loadStats."
    }

    $App = $App.Insert(
        $LoadStatsIndex,
        $DiagnosisLogic + "`r`n"
    )

    Write-Host "[OK] Motor de diagnostico agregado" -ForegroundColor Green
}

# ============================================================
# 3. SIDEBAR
# ============================================================

$NavPattern = '(?s)(<nav className="nav">)(.*?)(</nav>)'
$NavMatch = [regex]::Match($App, $NavPattern)

if (-not $NavMatch.Success) {
    throw "No se encontro el sidebar."
}

$NavContent = $NavMatch.Groups[2].Value

if ($NavContent -notmatch '(?s)>\s*Diagnóstico\s*</button>') {

$DiagnosisButton = @'

          <button
            className={`nav-item ${
              activeView === "diagnosis"
                ? "active"
                : ""
            }`}
            onClick={() => {
              setActiveView("diagnosis");
              loadPerformance();
              loadProcesses();

              if (history.length === 0) {
                loadHistory();
              }
            }}
          >
            Diagnóstico
          </button>

'@

    $BaselinePosition = $NavContent.IndexOf("Baseline")

    if ($BaselinePosition -lt 0) {
        throw "No se encontro Baseline en el sidebar."
    }

    $BaselineButtonStart = $NavContent.LastIndexOf(
        "<button",
        $BaselinePosition
    )

    if ($BaselineButtonStart -lt 0) {
        throw "No se encontro el boton Baseline."
    }

    $NewNavContent = $NavContent.Insert(
        $BaselineButtonStart,
        $DiagnosisButton
    )

    $NewNav =
        $NavMatch.Groups[1].Value +
        $NewNavContent +
        $NavMatch.Groups[3].Value

    $App =
        $App.Substring(0, $NavMatch.Index) +
        $NewNav +
        $App.Substring($NavMatch.Index + $NavMatch.Length)

    Write-Host "[OK] Diagnostico agregado al sidebar" -ForegroundColor Green
}

# ============================================================
# 4. VISTA
# ============================================================

if ($App -notmatch 'activeView === "diagnosis" &&') {

$DiagnosisView = @'

        {activeView === "diagnosis" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  DIAGNÓSTICO
                </span>

                <h2>
                  ¿Qué está limitando tu PC?
                </h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                Diagnóstico local
              </div>
            </header>

            {!bottleneckDiagnosis && (
              <section className="diagnosis-empty">
                <div className="diagnosis-empty-icon">
                  ?
                </div>

                <span className="status-label">
                  SIN DIAGNÓSTICO
                </span>

                <h3>
                  Necesitamos analizar el estado actual
                </h3>

                <p>
                  WinCare AI combinará CPU, RAM, almacenamiento,
                  procesos, programas de inicio y Baseline para
                  buscar el recurso que más limita al equipo.
                </p>

                <button
                  className="primary-button"
                  onClick={() => {
                    loadPerformance();
                    loadProcesses();
                  }}
                >
                  Diagnosticar ahora
                </button>
              </section>
            )}

            {bottleneckDiagnosis && (
              <>
                <section
                  className={`diagnosis-hero ${bottleneckDiagnosis.state}`}
                >
                  <div className="diagnosis-primary">
                    <div
                      className={`diagnosis-gauge ${bottleneckDiagnosis.state}`}
                    >
                      <strong>
                        {Math.round(
                          bottleneckDiagnosis.primary.score,
                        )}
                      </strong>

                      <span>/100</span>
                    </div>

                    <div>
                      <span className="status-label">
                        CUELLO DE BOTELLA PRINCIPAL
                      </span>

                      <h3>
                        {bottleneckDiagnosis.headline}
                      </h3>

                      <p>
                        {bottleneckDiagnosis.summary}
                      </p>

                      <div className="diagnosis-confidence">
                        <span>
                          Confianza del diagnóstico
                        </span>

                        <strong>
                          {bottleneckDiagnosis.confidence}
                        </strong>
                      </div>
                    </div>
                  </div>

                  <button
                    className="primary-button"
                    onClick={() => {
                      loadPerformance();
                      loadProcesses();
                      loadHistory();
                    }}
                  >
                    Actualizar diagnóstico
                  </button>
                </section>

                <section className="diagnosis-ranking">
                  <div className="diagnosis-ranking-header">
                    <div>
                      <span className="eyebrow">
                        PRESIÓN POR RECURSO
                      </span>

                      <h3>
                        Dónde está la carga
                      </h3>
                    </div>

                    <span>
                      0 = sin presión · 100 = muy alta
                    </span>
                  </div>

                  {bottleneckDiagnosis.candidates.map(
                    (candidate, index) => (
                      <article
                        className="diagnosis-resource-row"
                        key={candidate.id}
                      >
                        <div className="diagnosis-rank">
                          {index + 1}
                        </div>

                        <div className="diagnosis-resource-main">
                          <strong>
                            {candidate.label}
                          </strong>

                          <span>
                            {candidate.current}
                          </span>
                        </div>

                        <div className="diagnosis-pressure">
                          <div className="diagnosis-pressure-track">
                            <div
                              style={{
                                width: `${candidate.score}%`,
                              }}
                            />
                          </div>

                          <strong>
                            {Math.round(
                              candidate.score,
                            )}
                          </strong>
                        </div>

                        <button
                          className="secondary-button"
                          onClick={() => {
                            if (
                              candidate.action ===
                              "processes"
                            ) {
                              setActiveView("processes");
                              loadProcesses();
                            }

                            if (
                              candidate.action ===
                              "startup"
                            ) {
                              setActiveView("startup");
                              loadStartupItems();
                            }

                            if (
                              candidate.action ===
                              "storage"
                            ) {
                              setActiveView("storage");
                              scanStorage();
                            }
                          }}
                        >
                          Revisar
                        </button>
                      </article>
                    ),
                  )}
                </section>

                <section className="diagnosis-two-column">
                  <article className="diagnosis-detail-card">
                    <span className="eyebrow">
                      EXPLICACIÓN
                    </span>

                    <h3>
                      Por qué elegimos{" "}
                      {bottleneckDiagnosis.primary.label}
                    </h3>

                    <p>
                      {
                        bottleneckDiagnosis.primary
                          .explanation
                      }
                    </p>

                    {bottleneckDiagnosis.secondary && (
                      <p>
                        El segundo factor con mayor presión es{" "}
                        <strong>
                          {
                            bottleneckDiagnosis.secondary
                              .label
                          }
                        </strong>
                        , con una presión estimada de{" "}
                        <strong>
                          {Math.round(
                            bottleneckDiagnosis.secondary
                              .score,
                          )}
                          /100
                        </strong>
                        .
                      </p>
                    )}

                    {baseline && (
                      <div className="diagnosis-baseline-note">
                        <strong>
                          Baseline:{" "}
                          {baseline.level ===
                          "established"
                            ? "establecido"
                            : baseline.level ===
                                "preliminary"
                              ? "preliminar"
                              : "aprendiendo"}
                        </strong>

                        <span>
                          El diagnóstico también considera
                          si estos valores se apartan de lo
                          habitual para esta PC.
                        </span>
                      </div>
                    )}
                  </article>

                  <article className="diagnosis-detail-card">
                    <span className="eyebrow">
                      PROCESOS CON MÁS RAM
                    </span>

                    <h3>
                      Principales consumidores
                    </h3>

                    {bottleneckDiagnosis.topProcesses.length >
                    0 ? (
                      <div className="diagnosis-process-list">
                        {bottleneckDiagnosis.topProcesses.map(
                          (process) => (
                            <div
                              key={`${process.pid}-${process.name}`}
                            >
                              <div>
                                <strong>
                                  {process.name}
                                </strong>

                                <span>
                                  PID {process.pid}
                                </span>
                              </div>

                              <strong>
                                {formatBytes(
                                  process.memory_bytes,
                                )}
                              </strong>
                            </div>
                          ),
                        )}
                      </div>
                    ) : (
                      <div className="change-none">
                        Sin datos de procesos
                      </div>
                    )}

                    <button
                      className="secondary-button diagnosis-process-button"
                      onClick={() => {
                        setActiveView("processes");
                        loadProcesses();
                      }}
                    >
                      Ver todos los procesos
                    </button>
                  </article>
                </section>

                <section className="diagnosis-warning">
                  <div>
                    i
                  </div>

                  <div>
                    <strong>
                      Diagnóstico, no una sentencia
                    </strong>

                    <p>
                      Un recurso puede subir temporalmente por una
                      actualización, una aplicación abierta o una
                      tarea de Windows. Por eso WinCare AI combina
                      el estado actual con el Baseline y el historial
                      antes de señalar un posible cuello de botella.
                    </p>
                  </div>
                </section>

                <section className="local-panel">
                  <div className="shield">
                    ✓
                  </div>

                  <div>
                    <strong>
                      Diagnóstico explicable
                    </strong>

                    <p>
                      No aplicamos una optimización automática.
                      Primero mostramos qué recurso parece limitar
                      al equipo y por qué.
                    </p>
                  </div>
                </section>
              </>
            )}
          </>
        )}
'@

    $MainClose = $App.LastIndexOf("</main>")

    if ($MainClose -lt 0) {
        throw "No se encontro </main>."
    }

    $App = $App.Insert(
        $MainClose,
        $DiagnosisView + "`r`n      "
    )

    Write-Host "[OK] Vista Diagnostico creada" -ForegroundColor Green
}

Set-Content -Path $AppPath -Value $App -Encoding UTF8

# ============================================================
# 5. CSS
# ============================================================

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch '\.diagnosis-hero') {

$DiagnosisCss = @'

.diagnosis-hero {
  border: 1px solid #252b35;
  border-radius: 20px;
  padding: 30px;
  margin-bottom: 18px;
  background:
    radial-gradient(
      circle at 82% 20%,
      rgba(91, 111, 255, 0.12),
      transparent 38%
    ),
    linear-gradient(145deg, #12161b, #0e1115);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 30px;
}

.diagnosis-primary {
  display: flex;
  align-items: center;
  gap: 25px;
}

.diagnosis-gauge {
  width: 120px;
  height: 120px;
  flex: 0 0 120px;
  border-radius: 50%;
  border: 8px solid #29313b;
  background: #101419;
  display: flex;
  align-items: baseline;
  justify-content: center;
  padding-top: 32px;
}

.diagnosis-gauge.good {
  border-color: #2f7b51;
}

.diagnosis-gauge.attention {
  border-color: #9a763a;
}

.diagnosis-gauge.critical {
  border-color: #88454c;
}

.diagnosis-gauge strong {
  font-size: 34px;
}

.diagnosis-gauge span {
  margin-left: 2px;
  color: #697481;
  font-size: 10px;
}

.diagnosis-primary h3 {
  margin: 7px 0;
  font-size: 27px;
}

.diagnosis-primary p {
  margin: 0;
  max-width: 650px;
  color: #75808d;
  line-height: 1.65;
  font-size: 12px;
}

.diagnosis-confidence {
  display: inline-flex;
  align-items: center;
  gap: 9px;
  margin-top: 13px;
  padding: 7px 10px;
  border: 1px solid #2b323c;
  border-radius: 999px;
  background: #11161b;
}

.diagnosis-confidence span {
  color: #687380;
  font-size: 9px;
}

.diagnosis-confidence strong {
  font-size: 10px;
}

.diagnosis-ranking {
  border: 1px solid #22272f;
  border-radius: 18px;
  overflow: hidden;
  background: #0f1318;
}

.diagnosis-ranking-header {
  padding: 20px;
  border-bottom: 1px solid #22272f;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.diagnosis-ranking-header h3 {
  margin: 5px 0 0;
}

.diagnosis-ranking-header > span {
  color: #59636f;
  font-size: 9px;
}

.diagnosis-resource-row {
  display: grid;
  grid-template-columns:
    42px
    minmax(180px, 1fr)
    minmax(220px, 1.3fr)
    100px;
  gap: 15px;
  align-items: center;
  padding: 15px 20px;
  border-bottom: 1px solid #20252b;
}

.diagnosis-resource-row:last-child {
  border-bottom: 0;
}

.diagnosis-resource-row:hover {
  background: #12171d;
}

.diagnosis-rank {
  width: 30px;
  height: 30px;
  border: 1px solid #2b323b;
  border-radius: 9px;
  display: grid;
  place-items: center;
  color: #697481;
  font-size: 10px;
}

.diagnosis-resource-main {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.diagnosis-resource-main strong {
  font-size: 12px;
}

.diagnosis-resource-main span {
  color: #66717e;
  font-size: 10px;
}

.diagnosis-pressure {
  display: grid;
  grid-template-columns: 1fr 38px;
  align-items: center;
  gap: 10px;
}

.diagnosis-pressure-track {
  height: 7px;
  background: #20262d;
  border-radius: 999px;
  overflow: hidden;
}

.diagnosis-pressure-track > div {
  height: 100%;
  border-radius: inherit;
  background:
    linear-gradient(
      90deg,
      #526fff,
      #7660f5
    );
}

.diagnosis-pressure strong {
  font-size: 11px;
  text-align: right;
}

.diagnosis-two-column {
  display: grid;
  grid-template-columns:
    repeat(2, minmax(0, 1fr));
  gap: 14px;
  margin-top: 18px;
}

.diagnosis-detail-card {
  border: 1px solid #22272f;
  border-radius: 18px;
  background: #101419;
  padding: 22px;
}

.diagnosis-detail-card h3 {
  margin: 6px 0 9px;
}

.diagnosis-detail-card p {
  color: #707b87;
  line-height: 1.65;
  font-size: 11px;
}

.diagnosis-baseline-note {
  margin-top: 15px;
  border: 1px solid #28313b;
  border-radius: 12px;
  background: #0e1217;
  padding: 13px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.diagnosis-baseline-note strong {
  font-size: 10px;
}

.diagnosis-baseline-note span {
  color: #66727e;
  font-size: 9px;
}

.diagnosis-process-list {
  display: flex;
  flex-direction: column;
  border-top: 1px solid #22272f;
}

.diagnosis-process-list > div {
  padding: 11px 0;
  border-bottom: 1px solid #20252b;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 15px;
}

.diagnosis-process-list > div > div {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.diagnosis-process-list > div > div strong {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 11px;
}

.diagnosis-process-list span {
  color: #596470;
  font-size: 9px;
}

.diagnosis-process-list > div > strong {
  font-size: 10px;
  white-space: nowrap;
}

.diagnosis-process-button {
  margin-top: 14px;
}

.diagnosis-warning {
  margin-top: 18px;
  border: 1px solid #2c3540;
  border-radius: 18px;
  background: #101419;
  padding: 20px;
  display: flex;
  gap: 14px;
  align-items: flex-start;
}

.diagnosis-warning > div:first-child {
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: rgba(91, 111, 255, 0.1);
  color: #7b88ff;
  font-weight: 900;
}

.diagnosis-warning strong {
  font-size: 11px;
}

.diagnosis-warning p {
  margin: 5px 0 0;
  color: #66717e;
  font-size: 10px;
  line-height: 1.6;
}

.diagnosis-empty {
  min-height: 410px;
  border: 1px solid #252b35;
  border-radius: 22px;
  background:
    radial-gradient(
      circle at 50% 20%,
      rgba(91, 111, 255, 0.12),
      transparent 32%
    ),
    #101419;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 40px;
}

.diagnosis-empty-icon {
  width: 70px;
  height: 70px;
  border: 1px solid #303846;
  border-radius: 22px;
  display: grid;
  place-items: center;
  margin-bottom: 18px;
  color: #7584ff;
  font-size: 28px;
  font-weight: 900;
}

.diagnosis-empty h3 {
  margin: 8px 0;
  font-size: 26px;
}

.diagnosis-empty p {
  max-width: 580px;
  color: #727d89;
  line-height: 1.65;
}

.diagnosis-empty button {
  margin-top: 13px;
}

@media (max-width: 950px) {
  .diagnosis-hero,
  .diagnosis-primary {
    flex-direction: column;
    align-items: flex-start;
  }

  .diagnosis-resource-row {
    grid-template-columns:
      36px 1fr;
  }

  .diagnosis-pressure,
  .diagnosis-resource-row button {
    grid-column: 2;
  }

  .diagnosis-two-column {
    grid-template-columns: 1fr;
  }
}
'@

    Add-Content -Path $CssPath -Value $DiagnosisCss -Encoding UTF8
    Write-Host "[OK] Estilos Diagnostico agregados" -ForegroundColor Green
}

# ============================================================
# 6. VERIFICAR + BUILD
# ============================================================

$CheckApp = Get-Content $AppPath -Raw
$CheckNav = [regex]::Match($CheckApp, $NavPattern).Groups[2].Value

if ($CheckNav -notmatch '(?s)>\s*Diagnóstico\s*</button>') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico Diagnostico en sidebar. Backup restaurado."
}

if ($CheckApp -notmatch 'activeView === "diagnosis" &&') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico la vista Diagnostico. Backup restaurado."
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
Write-Host " BLOQUE 0019 COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Ejecuta ahora:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
