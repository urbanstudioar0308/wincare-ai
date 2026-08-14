$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$CssPath = "$ProjectRoot\src\App.css"
$BackupDir = "$ProjectRoot\Downloads\backup-0020"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - BLOQUE 0020" -ForegroundColor Cyan
Write-Host " Centro de Diagnostico Inteligente" -ForegroundColor Cyan
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
# VALIDACIONES
# ============================================================

$RequiredMarkers = @(
    'const bottleneckDiagnosis =',
    'const baseline =',
    'const comparison =',
    'const concreteChanges =',
    'type PerformanceAnalysis',
    'runFullAnalysis'
)

foreach ($Marker in $RequiredMarkers) {
    if ($App -notmatch [regex]::Escape($Marker)) {
        throw "Falta una pieza necesaria: $Marker"
    }
}

Write-Host "[OK] Modulos previos verificados" -ForegroundColor Green

# ============================================================
# 1. ACTIVE VIEW
# ============================================================

$ActiveViewPattern = '(?s)(const\s+\[activeView,\s*setActiveView\]\s*=\s*useState<)(.*?)(>\s*\()'
$ActiveViewMatch = [regex]::Match($App, $ActiveViewPattern)

if (-not $ActiveViewMatch.Success) {
    throw "No se pudo localizar activeView."
}

$Union = $ActiveViewMatch.Groups[2].Value

if ($Union -notmatch '"intelligence"') {
    $NewUnion = $Union.TrimEnd() + ' | "intelligence"'

    $Replacement =
        $ActiveViewMatch.Groups[1].Value +
        $NewUnion +
        $ActiveViewMatch.Groups[3].Value

    $App =
        $App.Substring(0, $ActiveViewMatch.Index) +
        $Replacement +
        $App.Substring($ActiveViewMatch.Index + $ActiveViewMatch.Length)

    Write-Host "[OK] Vista intelligence agregada" -ForegroundColor Green
}

# ============================================================
# 2. MOTOR DEL CENTRO INTELIGENTE
# ============================================================

if ($App -notmatch 'const intelligentCenter =') {

$IntelligenceLogic = @'

  const intelligentCenter = (() => {
    if (!bottleneckDiagnosis || !performance) {
      return null;
    }

    const findings: {
      level: "good" | "info" | "warning" | "critical";
      title: string;
      description: string;
      target:
        | "processes"
        | "startup"
        | "storage"
        | "cleanup"
        | "baseline"
        | "changes"
        | "compare"
        | "analysis";
    }[] = [];

    const main = bottleneckDiagnosis.primary;

    if (bottleneckDiagnosis.state === "critical") {
      findings.push({
        level: "critical",
        title: `Alta presión en ${main.label}`,
        description:
          `${main.label} tiene una presión estimada de ${Math.round(
            main.score,
          )}/100. ${main.explanation}`,
        target:
          main.action === "processes"
            ? "processes"
            : main.action === "startup"
              ? "startup"
              : "storage",
      });
    } else if (bottleneckDiagnosis.state === "attention") {
      findings.push({
        level: "warning",
        title: `${main.label} merece atención`,
        description:
          `${main.label} es actualmente el recurso con mayor presión relativa (${Math.round(
            main.score,
          )}/100).`,
        target:
          main.action === "processes"
            ? "processes"
            : main.action === "startup"
              ? "startup"
              : "storage",
      });
    } else {
      findings.push({
        level: "good",
        title: "No hay un cuello de botella dominante",
        description:
          "CPU, RAM, almacenamiento y procesos se encuentran relativamente equilibrados en este momento.",
        target: "analysis",
      });
    }

    if (
      baseline &&
      baseline.level !== "insufficient"
    ) {
      const anomalousMetrics = [
        {
          label: "RAM",
          status: baseline.ram.status,
          difference: baseline.ram.difference,
          suffix: "%",
        },
        {
          label: "CPU",
          status: baseline.cpu.status,
          difference: baseline.cpu.difference,
          suffix: "%",
        },
        {
          label: "Disco",
          status: baseline.disk.status,
          difference: baseline.disk.difference,
          suffix: "%",
        },
        {
          label: "Procesos pesados",
          status: baseline.heavyProcesses.status,
          difference:
            baseline.heavyProcesses.difference,
          suffix: "",
        },
        {
          label: "Apps de inicio",
          status: baseline.startup.status,
          difference: baseline.startup.difference,
          suffix: "",
        },
      ].filter(
        (metric) =>
          metric.status === "warning" ||
          metric.status === "critical",
      );

      if (anomalousMetrics.length > 0) {
        const first = anomalousMetrics[0];

        findings.push({
          level:
            first.status === "critical"
              ? "critical"
              : "warning",
          title: `${first.label} está fuera de lo habitual`,
          description:
            `${first.label} se aparta ${Math.abs(
              first.difference,
            ).toFixed(
              first.suffix === "%" ? 0 : 1,
            )}${first.suffix} del comportamiento habitual de esta PC.`,
          target: "baseline",
        });
      } else {
        findings.push({
          level: "good",
          title: "El comportamiento coincide con tu Baseline",
          description:
            "No detectamos desviaciones relevantes respecto del patrón habitual de esta PC.",
          target: "baseline",
        });
      }
    } else {
      findings.push({
        level: "info",
        title: "El Baseline todavía está aprendiendo",
        description:
          "Cuantos más análisis completos guardemos, mayor será la confianza para distinguir una anomalía real de una variación normal.",
        target: "baseline",
      });
    }

    if (comparison) {
      if (comparison.scoreDifference >= 3) {
        findings.push({
          level: "good",
          title: `El Health Score mejoró ${comparison.scoreDifference} puntos`,
          description:
            "El último análisis muestra una mejora respecto del análisis inmediatamente anterior.",
          target: "compare",
        });
      } else if (comparison.scoreDifference <= -3) {
        findings.push({
          level: "warning",
          title: `El Health Score cayó ${Math.abs(
            comparison.scoreDifference,
          )} puntos`,
          description:
            "Conviene revisar qué indicador cambió entre los dos últimos análisis.",
          target: "compare",
        });
      }
    }

    if (concreteChanges) {
      if (concreteChanges.totalChanges > 0) {
        findings.push({
          level: "info",
          title: `${concreteChanges.totalChanges} cambios concretos detectados`,
          description:
            "WinCare AI encontró diferencias reales entre los últimos snapshots de inicio, procesos, almacenamiento o temporales.",
          target: "changes",
        });
      } else {
        findings.push({
          level: "good",
          title: "La configuración observada se mantiene estable",
          description:
            "No aparecieron ni desaparecieron elementos relevantes entre los dos últimos snapshots.",
          target: "changes",
        });
      }
    }

    if (performance.ram_usage_percent >= 80) {
      findings.push({
        level:
          performance.ram_usage_percent >= 90
            ? "critical"
            : "warning",
        title: "La memoria RAM está bajo presión",
        description:
          `La RAM está utilizando aproximadamente ${Math.round(
            performance.ram_usage_percent,
          )}% de su capacidad.`,
        target: "processes",
      });
    }

    if (performance.active_startup_items >= 8) {
      findings.push({
        level: "info",
        title: "Hay varios programas iniciándose con Windows",
        description:
          `${performance.active_startup_items} aplicaciones están configuradas para iniciar automáticamente.`,
        target: "startup",
      });
    }

    const severityWeight = (
      level: "good" | "info" | "warning" | "critical",
    ) =>
      level === "critical"
        ? 4
        : level === "warning"
          ? 3
          : level === "info"
            ? 2
            : 1;

    const sortedFindings = findings
      .slice()
      .sort(
        (a, b) =>
          severityWeight(b.level) -
          severityWeight(a.level),
      );

    const criticalCount =
      sortedFindings.filter(
        (item) => item.level === "critical",
      ).length;

    const warningCount =
      sortedFindings.filter(
        (item) => item.level === "warning",
      ).length;

    let overallState:
      | "good"
      | "attention"
      | "critical" = "good";

    if (criticalCount > 0) {
      overallState = "critical";
    } else if (warningCount > 0) {
      overallState = "attention";
    }

    let answer =
      "No detectamos un problema dominante en este momento.";

    if (overallState === "critical") {
      answer =
        `El principal problema actual parece estar en ${main.label}.`;
    } else if (overallState === "attention") {
      answer =
        `${main.label} es el área que más conviene revisar ahora.`;
    } else if (
      baseline &&
      baseline.level !== "insufficient"
    ) {
      answer =
        "La PC está funcionando cerca de su comportamiento habitual.";
    }

    return {
      answer,
      overallState,
      findings: sortedFindings.slice(0, 8),
      criticalCount,
      warningCount,
      confidence: bottleneckDiagnosis.confidence,
      mainResource: main.label,
      mainPressure: Math.round(main.score),
      healthScore: performance.score,
      healthStatus: performance.status,
    };
  })();
'@

    $LoadStatsIndex = $App.IndexOf("  async function loadStats()")

    if ($LoadStatsIndex -lt 0) {
        throw "No se encontro loadStats."
    }

    $App = $App.Insert(
        $LoadStatsIndex,
        $IntelligenceLogic + "`r`n"
    )

    Write-Host "[OK] Motor del Centro Inteligente agregado" -ForegroundColor Green
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

if ($NavContent -notmatch '(?s)>\s*Centro inteligente\s*</button>') {

$IntelligenceButton = @'

          <button
            className={`nav-item ${
              activeView === "intelligence"
                ? "active"
                : ""
            }`}
            onClick={() => {
              setActiveView("intelligence");
              loadPerformance();
              loadProcesses();
              loadHistory();
              loadChangeSnapshots();
            }}
          >
            Centro inteligente
          </button>

'@

    $DiagnosisPosition = $NavContent.IndexOf("Diagnóstico")

    if ($DiagnosisPosition -lt 0) {
        throw "No se encontro Diagnostico en el sidebar."
    }

    $DiagnosisButtonStart = $NavContent.LastIndexOf(
        "<button",
        $DiagnosisPosition
    )

    if ($DiagnosisButtonStart -lt 0) {
        throw "No se encontro el boton Diagnostico."
    }

    $NewNavContent = $NavContent.Insert(
        $DiagnosisButtonStart,
        $IntelligenceButton
    )

    $NewNav =
        $NavMatch.Groups[1].Value +
        $NewNavContent +
        $NavMatch.Groups[3].Value

    $App =
        $App.Substring(0, $NavMatch.Index) +
        $NewNav +
        $App.Substring($NavMatch.Index + $NavMatch.Length)

    Write-Host "[OK] Centro inteligente agregado al sidebar" -ForegroundColor Green
}

# ============================================================
# 4. VISTA
# ============================================================

if ($App -notmatch 'activeView === "intelligence" &&') {

$IntelligenceView = @'

        {activeView === "intelligence" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  CENTRO INTELIGENTE
                </span>

                <h2>
                  ¿Qué le pasa a mi PC?
                </h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                Diagnóstico explicable
              </div>
            </header>

            {!intelligentCenter && (
              <section className="intelligence-empty">
                <div className="intelligence-empty-icon">
                  W
                </div>

                <span className="status-label">
                  NECESITAMOS DATOS ACTUALES
                </span>

                <h3>
                  Preparando el diagnóstico inteligente
                </h3>

                <p>
                  WinCare AI necesita combinar el estado actual,
                  el Baseline, los dos últimos análisis y los
                  snapshots de cambios.
                </p>

                <button
                  className="primary-button"
                  onClick={() => {
                    loadPerformance();
                    loadProcesses();
                    loadHistory();
                    loadChangeSnapshots();
                  }}
                >
                  Analizar situación
                </button>
              </section>
            )}

            {intelligentCenter && (
              <>
                <section
                  className={`intelligence-hero ${intelligentCenter.overallState}`}
                >
                  <div className="intelligence-answer">
                    <span className="status-label">
                      RESPUESTA DE WINCARE AI
                    </span>

                    <h3>
                      {intelligentCenter.answer}
                    </h3>

                    <p>
                      Esta conclusión combina rendimiento actual,
                      comportamiento histórico y cambios recientes.
                    </p>

                    <div className="intelligence-confidence">
                      <span>
                        Confianza
                      </span>

                      <strong>
                        {intelligentCenter.confidence}
                      </strong>
                    </div>
                  </div>

                  <div className="intelligence-score-box">
                    <span>
                      Health Score
                    </span>

                    <strong>
                      {intelligentCenter.healthScore}
                    </strong>

                    <small>
                      {intelligentCenter.healthStatus}
                    </small>
                  </div>
                </section>

                <section className="intelligence-summary-grid">
                  <article>
                    <span>
                      Recurso principal
                    </span>

                    <strong>
                      {intelligentCenter.mainResource}
                    </strong>

                    <small>
                      mayor presión relativa
                    </small>
                  </article>

                  <article>
                    <span>
                      Presión estimada
                    </span>

                    <strong>
                      {intelligentCenter.mainPressure}
                    </strong>

                    <small>
                      /100
                    </small>
                  </article>

                  <article>
                    <span>
                      Alertas
                    </span>

                    <strong>
                      {intelligentCenter.warningCount}
                    </strong>

                    <small>
                      requieren atención
                    </small>
                  </article>

                  <article>
                    <span>
                      Críticas
                    </span>

                    <strong>
                      {intelligentCenter.criticalCount}
                    </strong>

                    <small>
                      alta prioridad
                    </small>
                  </article>
                </section>

                <section className="intelligence-findings">
                  <div className="intelligence-findings-header">
                    <div>
                      <span className="eyebrow">
                        CONCLUSIONES
                      </span>

                      <h3>
                        Por qué llegamos a esta respuesta
                      </h3>
                    </div>

                    <span>
                      Reglas locales + historial
                    </span>
                  </div>

                  {intelligentCenter.findings.map(
                    (finding, index) => (
                      <article
                        className={`intelligence-finding ${finding.level}`}
                        key={`${finding.title}-${index}`}
                      >
                        <div
                          className={`intelligence-finding-icon ${finding.level}`}
                        >
                          {finding.level === "critical"
                            ? "!"
                            : finding.level === "warning"
                              ? "!"
                              : finding.level === "good"
                                ? "✓"
                                : "i"}
                        </div>

                        <div className="intelligence-finding-main">
                          <strong>
                            {finding.title}
                          </strong>

                          <span>
                            {finding.description}
                          </span>
                        </div>

                        <button
                          className="secondary-button"
                          onClick={() => {
                            if (finding.target === "processes") {
                              setActiveView("processes");
                              loadProcesses();
                            }

                            if (finding.target === "startup") {
                              setActiveView("startup");
                              loadStartupItems();
                            }

                            if (finding.target === "storage") {
                              setActiveView("storage");
                              scanStorage();
                            }

                            if (finding.target === "cleanup") {
                              setActiveView("cleanup");

                              if (!cleanup) {
                                scanCleanup();
                              }
                            }

                            if (finding.target === "baseline") {
                              setActiveView("baseline");
                            }

                            if (finding.target === "changes") {
                              setActiveView("changes");
                              loadChangeSnapshots();
                            }

                            if (finding.target === "compare") {
                              setActiveView("compare");
                            }

                            if (finding.target === "analysis") {
                              setActiveView("analysis");
                            }
                          }}
                        >
                          Revisar
                        </button>
                      </article>
                    ),
                  )}
                </section>

                <section className="intelligence-actions">
                  <button
                    onClick={() => {
                      setActiveView("processes");
                      loadProcesses();
                    }}
                  >
                    <span>01</span>
                    <strong>
                      Ver procesos
                    </strong>
                    <small>
                      CPU y RAM por proceso
                    </small>
                  </button>

                  <button
                    onClick={() => {
                      setActiveView("startup");
                      loadStartupItems();
                    }}
                  >
                    <span>02</span>
                    <strong>
                      Revisar inicio
                    </strong>
                    <small>
                      programas automáticos
                    </small>
                  </button>

                  <button
                    onClick={() => {
                      setActiveView("changes");
                      loadChangeSnapshots();
                    }}
                  >
                    <span>03</span>
                    <strong>
                      Ver qué cambió
                    </strong>
                    <small>
                      snapshots recientes
                    </small>
                  </button>

                  <button
                    onClick={() =>
                      setActiveView("baseline")
                    }
                  >
                    <span>04</span>
                    <strong>
                      Ver Baseline
                    </strong>
                    <small>
                      comportamiento habitual
                    </small>
                  </button>
                </section>

                <section className="intelligence-question">
                  <div className="intelligence-question-icon">
                    ?
                  </div>

                  <div>
                    <span className="eyebrow">
                      OBJETIVO DEL SISTEMA
                    </span>

                    <h3>
                      De números sueltos a una explicación
                    </h3>

                    <p>
                      WinCare AI ya no se limita a mostrar “RAM 85%”.
                      Intenta determinar si ese valor es alto para esta
                      PC, si cambió recientemente, si existe un cuello
                      de botella relacionado y qué módulo conviene
                      revisar primero.
                    </p>
                  </div>
                </section>

                <section className="local-panel">
                  <div className="shield">
                    ✓
                  </div>

                  <div>
                    <strong>
                      Inteligencia local y explicable
                    </strong>

                    <p>
                      Esta etapa todavía no utiliza un modelo de IA.
                      Las conclusiones provienen de reglas transparentes,
                      historial, Baseline y snapshots locales.
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
        $IntelligenceView + "`r`n      "
    )

    Write-Host "[OK] Vista Centro inteligente creada" -ForegroundColor Green
}

Set-Content -Path $AppPath -Value $App -Encoding UTF8

# ============================================================
# 5. CSS
# ============================================================

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch '\.intelligence-hero') {

$IntelligenceCss = @'

.intelligence-hero {
  border: 1px solid #252b35;
  border-radius: 22px;
  padding: 30px;
  margin-bottom: 18px;
  background:
    radial-gradient(
      circle at 82% 20%,
      rgba(91, 111, 255, 0.13),
      transparent 38%
    ),
    linear-gradient(145deg, #12161b, #0e1115);
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 30px;
}

.intelligence-hero.attention {
  border-color: #55462c;
}

.intelligence-hero.critical {
  border-color: #653c44;
}

.intelligence-answer {
  max-width: 720px;
}

.intelligence-answer h3 {
  margin: 7px 0 9px;
  font-size: 29px;
  line-height: 1.2;
}

.intelligence-answer p {
  margin: 0;
  color: #76818e;
  font-size: 12px;
  line-height: 1.65;
}

.intelligence-confidence {
  margin-top: 14px;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  border: 1px solid #2a323c;
  border-radius: 999px;
  padding: 7px 10px;
  background: #101419;
}

.intelligence-confidence span {
  color: #65707d;
  font-size: 9px;
}

.intelligence-confidence strong {
  font-size: 10px;
}

.intelligence-score-box {
  min-width: 155px;
  padding: 20px;
  border: 1px solid #2a323c;
  border-radius: 18px;
  background: #0f1318;
  text-align: center;
}

.intelligence-score-box span {
  color: #65707d;
  font-size: 10px;
}

.intelligence-score-box strong {
  display: block;
  margin: 5px 0;
  font-size: 42px;
}

.intelligence-score-box small {
  color: #8e99a5;
  font-size: 10px;
}

.intelligence-summary-grid {
  display: grid;
  grid-template-columns:
    repeat(4, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 18px;
}

.intelligence-summary-grid article {
  border: 1px solid #22272f;
  border-radius: 16px;
  background: #101419;
  padding: 18px;
}

.intelligence-summary-grid span {
  color: #697482;
  font-size: 10px;
}

.intelligence-summary-grid strong {
  display: block;
  margin: 7px 0 4px;
  font-size: 21px;
}

.intelligence-summary-grid small {
  color: #59636f;
  font-size: 9px;
}

.intelligence-findings {
  border: 1px solid #22272f;
  border-radius: 18px;
  overflow: hidden;
  background: #0f1318;
}

.intelligence-findings-header {
  padding: 20px;
  border-bottom: 1px solid #22272f;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.intelligence-findings-header h3 {
  margin: 5px 0 0;
}

.intelligence-findings-header > span {
  color: #59636f;
  font-size: 9px;
}

.intelligence-finding {
  display: grid;
  grid-template-columns:
    42px 1fr auto;
  gap: 14px;
  align-items: center;
  padding: 16px 20px;
  border-bottom: 1px solid #20252b;
}

.intelligence-finding:last-child {
  border-bottom: 0;
}

.intelligence-finding:hover {
  background: #12171d;
}

.intelligence-finding-icon {
  width: 34px;
  height: 34px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  font-size: 11px;
  font-weight: 900;
}

.intelligence-finding-icon.good {
  color: #61d18f;
  background: rgba(62, 201, 125, 0.1);
}

.intelligence-finding-icon.info {
  color: #7e8cff;
  background: rgba(91, 111, 255, 0.1);
}

.intelligence-finding-icon.warning {
  color: #e5b05a;
  background: rgba(225, 170, 79, 0.1);
}

.intelligence-finding-icon.critical {
  color: #ed7b84;
  background: rgba(224, 107, 117, 0.1);
}

.intelligence-finding-main {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.intelligence-finding-main strong {
  font-size: 12px;
}

.intelligence-finding-main span {
  color: #697482;
  font-size: 10px;
  line-height: 1.5;
}

.intelligence-actions {
  display: grid;
  grid-template-columns:
    repeat(4, minmax(0, 1fr));
  gap: 12px;
  margin-top: 18px;
}

.intelligence-actions button {
  border: 1px solid #22272f;
  border-radius: 16px;
  background: #101419;
  color: white;
  padding: 18px;
  text-align: left;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  gap: 5px;
}

.intelligence-actions button:hover {
  background: #151a21;
  border-color: #343d4b;
}

.intelligence-actions button > span {
  color: #637dff;
  font-size: 9px;
  font-weight: 900;
}

.intelligence-actions button > strong {
  font-size: 12px;
}

.intelligence-actions button > small {
  color: #626d79;
  font-size: 9px;
}

.intelligence-question {
  margin-top: 18px;
  border: 1px solid #22272f;
  border-radius: 18px;
  padding: 22px;
  background: #101419;
  display: flex;
  gap: 16px;
  align-items: flex-start;
}

.intelligence-question-icon {
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: #7d89ff;
  background: rgba(91, 111, 255, 0.1);
  font-weight: 900;
}

.intelligence-question h3 {
  margin: 5px 0 7px;
}

.intelligence-question p {
  margin: 0;
  max-width: 900px;
  color: #697482;
  font-size: 11px;
  line-height: 1.65;
}

.intelligence-empty {
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

.intelligence-empty-icon {
  width: 70px;
  height: 70px;
  border-radius: 22px;
  display: grid;
  place-items: center;
  margin-bottom: 18px;
  color: white;
  background:
    linear-gradient(
      135deg,
      #4e6cff,
      #7858ef
    );
  font-size: 24px;
  font-weight: 900;
}

.intelligence-empty h3 {
  margin: 8px 0;
  font-size: 26px;
}

.intelligence-empty p {
  max-width: 600px;
  color: #727d89;
  line-height: 1.65;
}

.intelligence-empty button {
  margin-top: 13px;
}

@media (max-width: 1000px) {
  .intelligence-summary-grid,
  .intelligence-actions {
    grid-template-columns:
      repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 750px) {
  .intelligence-hero {
    flex-direction: column;
    align-items: flex-start;
  }

  .intelligence-summary-grid,
  .intelligence-actions {
    grid-template-columns: 1fr;
  }

  .intelligence-finding {
    grid-template-columns: 42px 1fr;
  }

  .intelligence-finding button {
    grid-column: 2;
    justify-self: start;
  }
}
'@

    Add-Content -Path $CssPath -Value $IntelligenceCss -Encoding UTF8
    Write-Host "[OK] Estilos Centro inteligente agregados" -ForegroundColor Green
}

# ============================================================
# 6. VERIFICAR + BUILD
# ============================================================

$CheckApp = Get-Content $AppPath -Raw
$CheckNav = [regex]::Match($CheckApp, $NavPattern).Groups[2].Value

if ($CheckNav -notmatch '(?s)>\s*Centro inteligente\s*</button>') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico Centro inteligente en sidebar. Backup restaurado."
}

if ($CheckApp -notmatch 'activeView === "intelligence" &&') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico la vista Centro inteligente. Backup restaurado."
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
Write-Host " BLOQUE 0020 COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Ejecuta ahora:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
