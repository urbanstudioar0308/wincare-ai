$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$CssPath = "$ProjectRoot\src\App.css"
$BackupDir = "$ProjectRoot\Downloads\backup-0017"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - BLOQUE 0017" -ForegroundColor Cyan
Write-Host " Antes vs ahora" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $AppPath)) {
    throw "No se encontro App.tsx"
}

if (-not (Test-Path $CssPath)) {
    throw "No se encontro App.css"
}

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

Copy-Item $AppPath "$BackupDir\App.tsx" -Force
Copy-Item $CssPath "$BackupDir\App.css" -Force

Write-Host "[OK] Backup creado" -ForegroundColor Green

$App = Get-Content $AppPath -Raw

if ($App -notmatch 'type AnalysisHistoryEntry') {
    throw "No se encontro el historial local. Ejecuta primero el BLOQUE 0015."
}

if ($App -notmatch 'calculateBaseline') {
    throw "No se encontro el motor Baseline. Ejecuta primero el BLOQUE 0016."
}

# ============================================================
# 1. ACTIVE VIEW
# ============================================================

if ($App -notmatch '"compare"') {
    $ActiveViewPattern = '(?s)(const\s+\[activeView,\s*setActiveView\]\s*=\s*useState<)(.*?)(>\s*\()'
    $ActiveViewMatch = [regex]::Match($App, $ActiveViewPattern)

    if (-not $ActiveViewMatch.Success) {
        throw "No se pudo localizar el tipo activeView."
    }

    $Union = $ActiveViewMatch.Groups[2].Value

    if ($Union -notmatch '"compare"') {
        $NewUnion = $Union.TrimEnd() + ' | "compare"'

        $Replacement =
            $ActiveViewMatch.Groups[1].Value +
            $NewUnion +
            $ActiveViewMatch.Groups[3].Value

        $App =
            $App.Substring(0, $ActiveViewMatch.Index) +
            $Replacement +
            $App.Substring($ActiveViewMatch.Index + $ActiveViewMatch.Length)
    }

    Write-Host "[OK] Vista compare agregada a activeView" -ForegroundColor Green
}

# ============================================================
# 2. MOTOR DE COMPARACION
# ============================================================

if ($App -notmatch 'const comparison =') {

$ComparisonLogic = @'

  const comparison = (() => {
    if (history.length < 2) {
      return null;
    }

    const current = history[0];
    const previous = history[1];

    const metrics = [
      {
        key: "score",
        label: "Health Score",
        current: current.score,
        previous: previous.score,
        suffix: "",
        higherIsBetter: true,
        warning: 7,
        critical: 15,
      },
      {
        key: "ram",
        label: "Memoria RAM",
        current: current.ram_usage,
        previous: previous.ram_usage,
        suffix: "%",
        higherIsBetter: false,
        warning: 10,
        critical: 20,
      },
      {
        key: "cpu",
        label: "CPU",
        current: current.cpu_usage,
        previous: previous.cpu_usage,
        suffix: "%",
        higherIsBetter: false,
        warning: 15,
        critical: 30,
      },
      {
        key: "disk",
        label: "Disco C:",
        current: current.disk_usage,
        previous: previous.disk_usage,
        suffix: "%",
        higherIsBetter: false,
        warning: 5,
        critical: 10,
      },
      {
        key: "heavy",
        label: "Procesos pesados",
        current: current.heavy_processes,
        previous: previous.heavy_processes,
        suffix: "",
        higherIsBetter: false,
        warning: 2,
        critical: 5,
      },
      {
        key: "startup",
        label: "Apps de inicio",
        current: current.startup_active,
        previous: previous.startup_active,
        suffix: "",
        higherIsBetter: false,
        warning: 2,
        critical: 5,
      },
      {
        key: "cleanup",
        label: "Temporales",
        current: current.cleanup_bytes,
        previous: previous.cleanup_bytes,
        suffix: "bytes",
        higherIsBetter: false,
        warning: 300 * 1024 * 1024,
        critical: 1024 * 1024 * 1024,
      },
      {
        key: "large",
        label: "Archivos grandes",
        current: current.large_files_bytes,
        previous: previous.large_files_bytes,
        suffix: "bytes",
        higherIsBetter: false,
        warning: 5 * 1024 * 1024 * 1024,
        critical: 15 * 1024 * 1024 * 1024,
      },
    ];

    const evaluated = metrics.map((metric) => {
      const difference = metric.current - metric.previous;
      const magnitude = Math.abs(difference);

      let direction:
        | "better"
        | "worse"
        | "same" = "same";

      if (difference !== 0) {
        if (metric.higherIsBetter) {
          direction =
            difference > 0 ? "better" : "worse";
        } else {
          direction =
            difference < 0 ? "better" : "worse";
        }
      }

      let severity:
        | "normal"
        | "warning"
        | "critical" = "normal";

      if (direction === "worse") {
        if (magnitude >= metric.critical) {
          severity = "critical";
        } else if (magnitude >= metric.warning) {
          severity = "warning";
        }
      }

      return {
        ...metric,
        difference,
        direction,
        severity,
      };
    });

    const worst = [...evaluated]
      .filter((metric) => metric.direction === "worse")
      .sort((a, b) => {
        const severityWeight = (
          value: "normal" | "warning" | "critical",
        ) =>
          value === "critical"
            ? 3
            : value === "warning"
              ? 2
              : 1;

        const severityDiff =
          severityWeight(b.severity) -
          severityWeight(a.severity);

        if (severityDiff !== 0) {
          return severityDiff;
        }

        const aRatio =
          a.warning > 0
            ? Math.abs(a.difference) / a.warning
            : 0;

        const bRatio =
          b.warning > 0
            ? Math.abs(b.difference) / b.warning
            : 0;

        return bRatio - aRatio;
      })[0];

    const scoreDifference =
      current.score - previous.score;

    let headline =
      "El equipo se mantiene estable";

    let summary =
      "No encontramos un cambio negativo importante entre los dos últimos análisis.";

    if (worst) {
      headline = `El mayor cambio está en ${worst.label}`;

      if (worst.suffix === "bytes") {
        summary =
          `${worst.label} cambió ${formatBytes(
            Math.abs(worst.difference),
          )} respecto del análisis anterior.`;
      } else {
        summary =
          `${worst.label} cambió ${Math.abs(
            worst.difference,
          ).toFixed(
            worst.suffix === "%" ? 0 : 1,
          )}${worst.suffix} respecto del análisis anterior.`;
      }
    }

    return {
      current,
      previous,
      metrics: evaluated,
      worst,
      scoreDifference,
      headline,
      summary,
    };
  })();
'@

    $BaselineAnchor = '  const baseline ='
    $BaselineIndex = $App.IndexOf($BaselineAnchor)

    if ($BaselineIndex -lt 0) {
        throw "No se encontro const baseline."
    }

    # Insertar despues del bloque const baseline = calculateBaseline();
    $BaselineEndMarker = 'calculateBaseline();'
    $BaselineEnd = $App.IndexOf($BaselineEndMarker, $BaselineIndex)

    if ($BaselineEnd -lt 0) {
        throw "No se encontro el final del calculo Baseline."
    }

    $InsertAt = $BaselineEnd + $BaselineEndMarker.Length

    $App = $App.Insert(
        $InsertAt,
        "`r`n" + $ComparisonLogic
    )

    Write-Host "[OK] Motor Antes vs ahora agregado" -ForegroundColor Green
}

# ============================================================
# 3. SIDEBAR
# ============================================================

$NavPattern = '(?s)(<nav className="nav">)(.*?)(</nav>)'
$NavMatch = [regex]::Match($App, $NavPattern)

if (-not $NavMatch.Success) {
    throw "No se encontro el menu lateral."
}

$NavContent = $NavMatch.Groups[2].Value

if ($NavContent -notmatch '(?s)>\s*Antes vs ahora\s*</button>') {

$CompareButton = @'

          <button
            className={`nav-item ${
              activeView === "compare"
                ? "active"
                : ""
            }`}
            onClick={() => {
              setActiveView("compare");

              if (history.length < 2) {
                loadHistory();
              }
            }}
          >
            Antes vs ahora
          </button>

'@

    $HistoryPosition = $NavContent.IndexOf("Historial")

    if ($HistoryPosition -lt 0) {
        throw "No se encontro Historial en el sidebar."
    }

    $HistoryButtonStart = $NavContent.LastIndexOf(
        "<button",
        $HistoryPosition
    )

    if ($HistoryButtonStart -lt 0) {
        throw "No se pudo localizar el boton Historial."
    }

    $NewNavContent = $NavContent.Insert(
        $HistoryButtonStart,
        $CompareButton
    )

    $NewNav =
        $NavMatch.Groups[1].Value +
        $NewNavContent +
        $NavMatch.Groups[3].Value

    $App =
        $App.Substring(0, $NavMatch.Index) +
        $NewNav +
        $App.Substring($NavMatch.Index + $NavMatch.Length)

    Write-Host "[OK] Antes vs ahora agregado al sidebar" -ForegroundColor Green
}

# ============================================================
# 4. VISTA
# ============================================================

if ($App -notmatch 'activeView === "compare" &&') {

$CompareView = @'

        {activeView === "compare" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  ANTES VS AHORA
                </span>

                <h2>
                  Qué cambió desde el análisis anterior
                </h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                Comparación local
              </div>
            </header>

            {!comparison && (
              <section className="compare-empty">
                <div className="compare-empty-icon">
                  ↔
                </div>

                <span className="status-label">
                  NECESITAMOS DOS ANÁLISIS
                </span>

                <h3>
                  Todavía no podemos comparar
                </h3>

                <p>
                  Ejecutá al menos dos análisis completos.
                  WinCare AI comparará automáticamente el
                  resultado más reciente contra el anterior.
                </p>

                <button
                  className="primary-button"
                  onClick={runFullAnalysis}
                >
                  Analizar PC
                </button>
              </section>
            )}

            {comparison && (
              <>
                <section
                  className={`compare-hero ${
                    comparison.scoreDifference < -7
                      ? "warning"
                      : comparison.scoreDifference > 7
                        ? "better"
                        : "stable"
                  }`}
                >
                  <div className="compare-score-pair">
                    <div className="compare-score-box">
                      <span>Anterior</span>

                      <strong>
                        {comparison.previous.score}
                      </strong>

                      <small>
                        {new Date(
                          comparison.previous.timestamp *
                            1000,
                        ).toLocaleString("es-AR")}
                      </small>
                    </div>

                    <div className="compare-arrow">
                      →
                    </div>

                    <div className="compare-score-box current">
                      <span>Ahora</span>

                      <strong>
                        {comparison.current.score}
                      </strong>

                      <small>
                        {new Date(
                          comparison.current.timestamp *
                            1000,
                        ).toLocaleString("es-AR")}
                      </small>
                    </div>

                    <div
                      className={`compare-score-change ${
                        comparison.scoreDifference > 0
                          ? "better"
                          : comparison.scoreDifference < 0
                            ? "worse"
                            : "same"
                      }`}
                    >
                      <strong>
                        {comparison.scoreDifference > 0
                          ? "+"
                          : ""}
                        {comparison.scoreDifference}
                      </strong>

                      <span>puntos</span>
                    </div>
                  </div>
                </section>

                <section className="compare-diagnosis">
                  <div
                    className={`compare-diagnosis-icon ${
                      comparison.worst
                        ? comparison.worst.severity
                        : "good"
                    }`}
                  >
                    {comparison.worst ? "!" : "✓"}
                  </div>

                  <div>
                    <span className="status-label">
                      CAMBIO PRINCIPAL
                    </span>

                    <h3>
                      {comparison.headline}
                    </h3>

                    <p>
                      {comparison.summary}
                    </p>
                  </div>
                </section>

                <section className="compare-panel">
                  <div className="compare-header">
                    <span>Indicador</span>
                    <span>Anterior</span>
                    <span>Ahora</span>
                    <span>Cambio</span>
                    <span>Lectura</span>
                  </div>

                  {comparison.metrics.map(
                    (metric) => {
                      const renderValue = (
                        value: number,
                      ) => {
                        if (
                          metric.suffix === "bytes"
                        ) {
                          return formatBytes(value);
                        }

                        return `${value.toFixed(
                          metric.suffix === "%"
                            ? 0
                            : 1,
                        )}${metric.suffix}`;
                      };

                      const renderDifference = () => {
                        const prefix =
                          metric.difference > 0
                            ? "+"
                            : "";

                        if (
                          metric.suffix === "bytes"
                        ) {
                          if (
                            metric.difference === 0
                          ) {
                            return "0 MB";
                          }

                          return `${
                            metric.difference > 0
                              ? "+"
                              : "-"
                          }${formatBytes(
                            Math.abs(
                              metric.difference,
                            ),
                          )}`;
                        }

                        return `${prefix}${metric.difference.toFixed(
                          metric.suffix === "%"
                            ? 0
                            : 1,
                        )}${metric.suffix}`;
                      };

                      return (
                        <article
                          className="compare-row"
                          key={metric.key}
                        >
                          <strong>
                            {metric.label}
                          </strong>

                          <span>
                            {renderValue(
                              metric.previous,
                            )}
                          </span>

                          <span>
                            {renderValue(
                              metric.current,
                            )}
                          </span>

                          <span
                            className={`compare-delta ${metric.direction}`}
                          >
                            {renderDifference()}
                          </span>

                          <span
                            className={`compare-reading ${metric.severity} ${metric.direction}`}
                          >
                            {metric.direction === "better"
                              ? "Mejor"
                              : metric.direction === "worse"
                                ? metric.severity ===
                                  "critical"
                                  ? "Anomalía"
                                  : metric.severity ===
                                      "warning"
                                    ? "Atención"
                                    : "Cambió"
                                : "Estable"}
                          </span>
                        </article>
                      );
                    },
                  )}
                </section>

                <section className="compare-note">
                  <span className="eyebrow">
                    INTERPRETACIÓN
                  </span>

                  <h3>
                    Una variación no siempre significa un problema
                  </h3>

                  <p>
                    WinCare AI compara los dos análisis más recientes.
                    Una aplicación abierta, una descarga o una tarea de
                    Windows pueden cambiar temporalmente CPU o RAM.
                    El Baseline usa varios análisis y sirve para decidir
                    si ese cambio es realmente anormal para esta PC.
                  </p>

                  <button
                    className="secondary-button"
                    onClick={() =>
                      setActiveView("baseline")
                    }
                  >
                    Ver Baseline
                  </button>
                </section>

                <section className="local-panel">
                  <div className="shield">
                    ✓
                  </div>

                  <div>
                    <strong>
                      Comparación privada
                    </strong>

                    <p>
                      Los datos comparados provienen únicamente
                      del historial local de esta computadora.
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
        $CompareView + "`r`n      "
    )

    Write-Host "[OK] Vista Antes vs ahora creada" -ForegroundColor Green
}

Set-Content -Path $AppPath -Value $App -Encoding UTF8

# ============================================================
# 5. CSS
# ============================================================

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch '\.compare-hero') {

$CompareCss = @'

.compare-hero {
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
}

.compare-score-pair {
  display: flex;
  align-items: center;
  gap: 18px;
}

.compare-score-box {
  min-width: 170px;
  border: 1px solid #292f38;
  border-radius: 16px;
  padding: 18px;
  background: #0f1318;
}

.compare-score-box.current {
  border-color: #45569d;
}

.compare-score-box span {
  display: block;
  color: #67727e;
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.compare-score-box strong {
  display: block;
  margin: 7px 0 4px;
  font-size: 38px;
}

.compare-score-box small {
  color: #56616d;
  font-size: 9px;
}

.compare-arrow {
  color: #606b78;
  font-size: 28px;
}

.compare-score-change {
  min-width: 100px;
  border-radius: 14px;
  padding: 15px;
  text-align: center;
}

.compare-score-change strong {
  display: block;
  font-size: 25px;
}

.compare-score-change span {
  font-size: 9px;
  text-transform: uppercase;
}

.compare-score-change.better {
  color: #62d491;
  background: rgba(68, 202, 124, 0.08);
}

.compare-score-change.worse {
  color: #e87983;
  background: rgba(224, 107, 117, 0.08);
}

.compare-score-change.same {
  color: #8b96a2;
  background: rgba(120, 130, 143, 0.07);
}

.compare-diagnosis {
  border: 1px solid #252b35;
  border-radius: 18px;
  padding: 22px;
  margin-bottom: 18px;
  background: #101419;
  display: flex;
  gap: 16px;
  align-items: flex-start;
}

.compare-diagnosis-icon {
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  font-weight: 900;
}

.compare-diagnosis-icon.good {
  color: #64d493;
  background: rgba(62, 201, 125, 0.1);
}

.compare-diagnosis-icon.warning {
  color: #e5b05a;
  background: rgba(225, 170, 79, 0.1);
}

.compare-diagnosis-icon.critical {
  color: #ed7b84;
  background: rgba(224, 107, 117, 0.1);
}

.compare-diagnosis h3 {
  margin: 6px 0;
  font-size: 21px;
}

.compare-diagnosis p {
  margin: 0;
  color: #737e8b;
  font-size: 12px;
  line-height: 1.6;
}

.compare-panel {
  border: 1px solid #22272f;
  border-radius: 18px;
  overflow: hidden;
  background: #0f1318;
}

.compare-header,
.compare-row {
  display: grid;
  grid-template-columns:
    minmax(180px, 1fr)
    130px
    130px
    130px
    120px;
  gap: 14px;
  align-items: center;
}

.compare-header {
  padding: 13px 20px;
  border-bottom: 1px solid #22272f;
  color: #626d7a;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.compare-row {
  padding: 16px 20px;
  border-bottom: 1px solid #20252b;
}

.compare-row:last-child {
  border-bottom: 0;
}

.compare-row:hover {
  background: #12171d;
}

.compare-row > strong {
  font-size: 12px;
}

.compare-row > span {
  color: #98a1ac;
  font-size: 11px;
}

.compare-delta.better {
  color: #61d18f;
}

.compare-delta.worse {
  color: #e57982;
}

.compare-delta.same {
  color: #7e8995;
}

.compare-reading {
  display: inline-flex;
  width: max-content;
  padding: 6px 9px;
  border-radius: 999px;
  font-size: 9px !important;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.compare-reading.better {
  color: #61d18f;
  background: rgba(62, 201, 125, 0.08);
}

.compare-reading.worse.warning {
  color: #e5b05a;
  background: rgba(225, 170, 79, 0.08);
}

.compare-reading.worse.critical {
  color: #ed7b84;
  background: rgba(224, 107, 117, 0.08);
}

.compare-reading.worse.normal,
.compare-reading.same {
  color: #818c98;
  background: rgba(120, 130, 143, 0.07);
}

.compare-note {
  margin-top: 18px;
  border: 1px solid #22272f;
  border-radius: 18px;
  padding: 24px;
  background: #101419;
}

.compare-note h3 {
  margin: 6px 0 8px;
}

.compare-note p {
  max-width: 850px;
  color: #6e7986;
  font-size: 12px;
  line-height: 1.7;
}

.compare-note button {
  margin-top: 12px;
}

.compare-empty {
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
  justify-content: center;
  align-items: center;
  text-align: center;
  padding: 40px;
}

.compare-empty-icon {
  width: 70px;
  height: 70px;
  border: 1px solid #303846;
  border-radius: 22px;
  display: grid;
  place-items: center;
  margin-bottom: 18px;
  color: #7584ff;
  font-size: 30px;
}

.compare-empty h3 {
  margin: 8px 0;
  font-size: 27px;
}

.compare-empty p {
  max-width: 560px;
  color: #727d89;
  line-height: 1.65;
}

.compare-empty button {
  margin-top: 13px;
}

@media (max-width: 950px) {
  .compare-score-pair {
    flex-wrap: wrap;
  }

  .compare-panel {
    overflow-x: auto;
  }

  .compare-header,
  .compare-row {
    min-width: 800px;
  }
}

@media (max-width: 650px) {
  .compare-score-pair {
    flex-direction: column;
    align-items: stretch;
  }

  .compare-arrow {
    transform: rotate(90deg);
    align-self: center;
  }
}
'@

    Add-Content -Path $CssPath -Value $CompareCss -Encoding UTF8
    Write-Host "[OK] Estilos Antes vs ahora agregados" -ForegroundColor Green
}

# ============================================================
# 6. VERIFICACIONES
# ============================================================

$CheckApp = Get-Content $AppPath -Raw
$CheckNav = [regex]::Match($CheckApp, $NavPattern).Groups[2].Value

if ($CheckNav -notmatch '(?s)>\s*Antes vs ahora\s*</button>') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se pudo verificar el boton Antes vs ahora. Se restauro el backup."
}

if ($CheckApp -notmatch 'activeView === "compare" &&') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se pudo verificar la vista compare. Se restauro el backup."
}

Write-Host "[OK] Navegacion verificada" -ForegroundColor Green
Write-Host "[OK] Vista verificada" -ForegroundColor Green

# ============================================================
# 7. BUILD
# ============================================================

Write-Host ""
Write-Host "Ejecutando build..." -ForegroundColor Yellow

Set-Location $ProjectRoot
npm run build

if ($LASTEXITCODE -ne 0) {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "Build fallido. Se restauro el backup."
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " BLOQUE 0017 COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Ejecuta ahora:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
