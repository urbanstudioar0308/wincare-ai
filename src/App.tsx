import { useEffect, useMemo, useRef, useState } from "react";
import "./App.css";
import * as api from "./services/wincareApi";
import type { CpuAdvancedDiagnosis, RamAdvancedDiagnosis, StorageAdvancedDiagnosis, StartupAdvancedDiagnosis, NetworkAdvancedDiagnosis, WindowsAdvancedDiagnosis } from "./services/wincareApi";
import type {
  SystemStats,
  CleanupCategory,
  CleanupScan,
  CleanupResult,
  StorageScan,
  ProcessSnapshot,
  StartupItem,
  StartupSnapshot,
  PerformanceAnalysis,
  FullAnalysisResult,
  AnalysisHistoryEntry,
  BaselineMetric,
  BaselineResult,
  ChangeSnapshot,
  AboutSystemInfo,
  AdvancedSystemSnapshot,
} from "./types";
import { formatBytes } from "./utils/format";

const emptyStats: SystemStats = {
  cpu_usage: 0,
  ram_used_gb: 0,
  ram_total_gb: 0,
  ram_usage_percent: 0,
  disk_used_gb: 0,
  disk_total_gb: 0,
  disk_free_gb: 0,
  disk_usage_percent: 0,
};

function App() {
  const [stats, setStats] = useState<SystemStats>(emptyStats);

  const [activeView, setActiveView] = useState<
    "dashboard" | "cleanup" | "storage" | "processes" | "startup" | "performance" | "analysis" | "history" | "baseline" | "compare" | "changes" | "diagnosis" | "intelligence" | "evidence" | "cpuAdvanced" | "ramAdvanced" | "storageAdvanced" | "startupAdvanced" | "networkAdvanced" | "windowsAdvanced" | "about">("dashboard");

  const [cleanup, setCleanup] =
    useState<CleanupScan | null>(null);

  const [cleanupLoading, setCleanupLoading] =
    useState(false);

  const [cleaning, setCleaning] = useState(false);

  const [selectedCategories, setSelectedCategories] =
    useState<string[]>([]);

  const [showReview, setShowReview] = useState(false);

  const [confirmed, setConfirmed] = useState(false);

  const [result, setResult] =
    useState<CleanupResult | null>(null);


  const [storage, setStorage] =
    useState<StorageScan | null>(null);

  const [storageLoading, setStorageLoading] =
    useState(false);

  const [storageThreshold, setStorageThreshold] =
    useState(500);

  async function scanStorage(
    threshold = storageThreshold,
  ) {
    setStorageLoading(true);

    try {
      const data =
        await api.scanLargeFiles(threshold);

      setStorage(data);
    } catch (error) {
      console.error(
        "Error analizando almacenamiento:",
        error,
      );
    } finally {
      setStorageLoading(false);
    }
  }

  const [processes, setProcesses] =
    useState<ProcessSnapshot | null>(null);

  const [processesLoading, setProcessesLoading] =
    useState(false);

  const [processFilter, setProcessFilter] =
    useState<"all" | "heavy">("all");

  async function loadProcesses() {
    setProcessesLoading(true);

    try {
      const data =
        await api.getProcesses();

      setProcesses(data);
    } catch (error) {
      console.error(
        "Error leyendo procesos:",
        error,
      );
    } finally {
      setProcessesLoading(false);
    }
  }

  const [startupItems, setStartupItems] =
    useState<StartupSnapshot | null>(null);

  const [startupLoading, setStartupLoading] =
    useState(false);


  const [startupChanging, setStartupChanging] =
    useState<string | null>(null);

  const [startupConfirm, setStartupConfirm] =
    useState<StartupItem | null>(null);

  const [startupError, setStartupError] =
    useState<string>("");

  const [startupChanges, setStartupChanges] =
    useState(0);

  async function changeStartupItem(
    item: StartupItem,
  ) {
    if (!item.editable) {
      return;
    }

    setStartupChanging(item.id);
    setStartupError("");

    try {
      await api.setStartupEnabled(item.name, !item.enabled);

      setStartupChanges((value) => value + 1);

      await loadStartupItems();

      setStartupConfirm(null);
    } catch (error) {
      setStartupError(String(error));
    } finally {
      setStartupChanging(null);
    }
  }
  async function loadStartupItems() {
    setStartupLoading(true);

    try {
      const data =
        await api.getStartupItems();

      setStartupItems(data);
    } catch (error) {
      console.error(
        "Error leyendo inicio de Windows:",
        error,
      );
    } finally {
      setStartupLoading(false);
    }
  }

  const [performance, setPerformance] =
    useState<PerformanceAnalysis | null>(null);

  const [performanceLoading, setPerformanceLoading] =
    useState(false);

  async function loadPerformance() {
    setPerformanceLoading(true);

    try {
      const data =
        await api.getPerformanceAnalysis();

      setPerformance(data);
    } catch (error) {
      console.error(
        "Error analizando rendimiento:",
        error,
      );
    } finally {
      setPerformanceLoading(false);
    }
  }

  const [fullAnalysis, setFullAnalysis] =
    useState<FullAnalysisResult | null>(null);

  const [fullAnalysisLoading, setFullAnalysisLoading] =
    useState(false);

  const [fullAnalysisStep, setFullAnalysisStep] =
    useState("");

  const [fullAnalysisProgress, setFullAnalysisProgress] =
    useState(0);

  const [fullAnalysisError, setFullAnalysisError] =
    useState("");

  async function runFullAnalysis() {
    if (fullAnalysisLoading) {
      return;
    }

    setFullAnalysisLoading(true);
    setFullAnalysisError("");
    setFullAnalysisProgress(0);
    setFullAnalysisStep("Preparando análisis...");

    try {
      setActiveView("analysis");

      // ------------------------------------------------------
      // 1. Sistema
      // ------------------------------------------------------

      setFullAnalysisStep(
        "Leyendo CPU, memoria y almacenamiento...",
      );

      setFullAnalysisProgress(10);

      const systemData =
        await api.getSystemStats();

      setStats(systemData);

      // ------------------------------------------------------
      // 2. Limpieza
      // ------------------------------------------------------

      setFullAnalysisStep(
        "Buscando archivos temporales...",
      );

      setFullAnalysisProgress(25);

      const cleanupData =
        await api.scanCleanup();

      setCleanup(cleanupData);

      // ------------------------------------------------------
      // 3. Archivos grandes
      // ------------------------------------------------------

      setFullAnalysisStep(
        "Analizando archivos grandes...",
      );

      setFullAnalysisProgress(42);

      const storageData =
        await api.scanLargeFiles(500);

      setStorage(storageData);

      // ------------------------------------------------------
      // 4. Procesos
      // ------------------------------------------------------

      setFullAnalysisStep(
        "Revisando procesos activos...",
      );

      setFullAnalysisProgress(60);

      const processData =
        await api.getProcesses();

      setProcesses(processData);

      // ------------------------------------------------------
      // 5. Inicio de Windows
      // ------------------------------------------------------

      setFullAnalysisStep(
        "Revisando programas de inicio...",
      );

      setFullAnalysisProgress(75);

      const startupData =
        await api.getStartupItems();

      setStartupItems(startupData);

      // ------------------------------------------------------
      // 6. Rendimiento / Health Score
      // ------------------------------------------------------

      setFullAnalysisStep(
        "Calculando Health Score...",
      );

      setFullAnalysisProgress(88);

      const performanceData =
        await api.getPerformanceAnalysis();

      setPerformance(performanceData);

      // ------------------------------------------------------
      // RESULTADO
      // ------------------------------------------------------

      const activeStartup =
        startupData.items.filter(
          (item) => item.enabled,
        ).length;


      try {
        await api.saveAnalysisHistory({
          score: performanceData.score,
          status: performanceData.status,
          cpuUsage: systemData.cpu_usage,
          ramUsage: systemData.ram_usage_percent,
          diskUsage: systemData.disk_usage_percent,
          cleanupBytes: cleanupData.total_bytes,
          largeFilesBytes:
            storageData.total_large_bytes,
          heavyProcesses:
            performanceData.heavy_processes,
          startupActive: activeStartup,
        });

        await loadHistory();
      } catch (historyError) {
        console.error(
          "No se pudo guardar historial:",
          historyError,
        );
      }

      try {
        const activeStartupNames = Array.from(
          new Set(
            startupData.items
              .filter((item) => item.enabled)
              .map((item) => item.name),
          ),
        ).sort();

        const cpuCountGuess = Math.max(
          1,
          navigator.hardwareConcurrency || 1,
        );

        const heavyNames = Array.from(
          new Set(
            processData.processes
              .filter((process) => {
                const normalizedCpu =
                  process.cpu_usage / cpuCountGuess;

                return (
                  process.memory_bytes >=
                    300 * 1024 * 1024 ||
                  normalizedCpu >= 5
                );
              })
              .map((process) => process.name),
          ),
        )
          .sort()
          .slice(0, 30);

        const snapshotLargeFiles =
          storageData.files
            .slice(0, 50)
            .map((file) => ({
              name: file.name,
              path: file.path,
              size_bytes: file.size_bytes,
            }));

        const snapshotCleanup =
          cleanupData.categories.map(
            (category) => ({
              id: category.id,
              name: category.name,
              size_bytes: category.size_bytes,
              file_count: category.file_count,
            }),
          );

        await api.saveChangeSnapshot({
          startupActive: activeStartupNames,
          heavyProcesses: heavyNames,
          largeFiles: snapshotLargeFiles,
          cleanupCategories: snapshotCleanup,
        });

        await loadChangeSnapshots();
      } catch (snapshotError) {
        console.error(
          "No se pudo guardar snapshot de cambios:",
          snapshotError,
        );
      }
      setFullAnalysis({
        healthScore: performanceData.score,
        healthStatus: performanceData.status,

        cpuUsage: systemData.cpu_usage,
        ramUsage: systemData.ram_usage_percent,
        diskUsage: systemData.disk_usage_percent,

        cleanupBytes: cleanupData.total_bytes,
        cleanupFiles: cleanupData.total_files,

        largeFilesBytes:
          storageData.total_large_bytes,

        largeFilesCount:
          storageData.total_large_files,

        heavyProcesses:
          performanceData.heavy_processes,

        startupActive: activeStartup,

        recommendations:
          performanceData.recommendations,

        completedAt:
          new Date().toLocaleString("es-AR"),
      });

      setFullAnalysisProgress(100);
      setFullAnalysisStep("Análisis completado");
    } catch (error) {
      console.error(
        "Error durante análisis completo:",
        error,
      );

      setFullAnalysisError(
        String(error),
      );

      setFullAnalysisStep(
        "No se pudo completar el análisis",
      );
    } finally {
      setFullAnalysisLoading(false);
    }
  }

  const [history, setHistory] =
    useState<AnalysisHistoryEntry[]>([]);

  const [historyLoading, setHistoryLoading] =
    useState(false);

  async function loadHistory() {
    setHistoryLoading(true);

    try {
      const data =
        await api.getAnalysisHistory();

      setHistory(data);
    } catch (error) {
      console.error(
        "Error leyendo historial:",
        error,
      );
    } finally {
      setHistoryLoading(false);
    }
  }

  async function clearHistory() {
    const confirmed = window.confirm(
      "¿Querés borrar todo el historial local de análisis?",
    );

    if (!confirmed) {
      return;
    }

    try {
      await api.clearAnalysisHistory();
      setHistory([]);
    } catch (error) {
      console.error(
        "Error borrando historial:",
        error,
      );
    }
  }

  function calculateBaseline():
    BaselineResult | null {

    if (history.length === 0) {
      return null;
    }

    const latest = history[0];

    const previousSamples =
      history.slice(1, 21);

    if (previousSamples.length === 0) {
      return {
        sampleCount: 1,
        level: "insufficient",

        score: {
          average: latest.score,
          current: latest.score,
          difference: 0,
          status: "normal",
        },

        cpu: {
          average: latest.cpu_usage,
          current: latest.cpu_usage,
          difference: 0,
          status: "normal",
        },

        ram: {
          average: latest.ram_usage,
          current: latest.ram_usage,
          difference: 0,
          status: "normal",
        },

        disk: {
          average: latest.disk_usage,
          current: latest.disk_usage,
          difference: 0,
          status: "normal",
        },

        heavyProcesses: {
          average: latest.heavy_processes,
          current: latest.heavy_processes,
          difference: 0,
          status: "normal",
        },

        startup: {
          average: latest.startup_active,
          current: latest.startup_active,
          difference: 0,
          status: "normal",
        },

        primaryFinding:
          "Todavía no hay suficientes análisis.",

        summary:
          "WinCare AI necesita más análisis para aprender cómo funciona normalmente esta PC.",
      };
    }

    function average(
      values: number[],
    ) {
      if (values.length === 0) {
        return 0;
      }

      return (
        values.reduce(
          (sum, value) => sum + value,
          0,
        ) / values.length
      );
    }

    function createMetric(
      avg: number,
      current: number,
      thresholds: {
        warning: number;
        critical: number;
        lowerIsBetter?: boolean;
      },
    ): BaselineMetric {

      const difference = current - avg;

      let status:
        | "normal"
        | "warning"
        | "critical"
        | "better" = "normal";

      if (thresholds.lowerIsBetter) {
        if (
          difference >= thresholds.critical
        ) {
          status = "critical";
        } else if (
          difference >= thresholds.warning
        ) {
          status = "warning";
        } else if (
          difference <=
          -thresholds.warning
        ) {
          status = "better";
        }
      } else {
        if (
          difference <=
          -thresholds.critical
        ) {
          status = "critical";
        } else if (
          difference <=
          -thresholds.warning
        ) {
          status = "warning";
        } else if (
          difference >=
          thresholds.warning
        ) {
          status = "better";
        }
      }

      return {
        average: avg,
        current,
        difference,
        status,
      };
    }

    const avgScore = average(
      previousSamples.map(
        (item) => item.score,
      ),
    );

    const avgCpu = average(
      previousSamples.map(
        (item) => item.cpu_usage,
      ),
    );

    const avgRam = average(
      previousSamples.map(
        (item) => item.ram_usage,
      ),
    );

    const avgDisk = average(
      previousSamples.map(
        (item) => item.disk_usage,
      ),
    );

    const avgHeavy = average(
      previousSamples.map(
        (item) => item.heavy_processes,
      ),
    );

    const avgStartup = average(
      previousSamples.map(
        (item) => item.startup_active,
      ),
    );

    const scoreMetric = createMetric(
      avgScore,
      latest.score,
      {
        warning: 7,
        critical: 15,
        lowerIsBetter: false,
      },
    );

    const cpuMetric = createMetric(
      avgCpu,
      latest.cpu_usage,
      {
        warning: 15,
        critical: 30,
        lowerIsBetter: true,
      },
    );

    const ramMetric = createMetric(
      avgRam,
      latest.ram_usage,
      {
        warning: 10,
        critical: 20,
        lowerIsBetter: true,
      },
    );

    const diskMetric = createMetric(
      avgDisk,
      latest.disk_usage,
      {
        warning: 5,
        critical: 10,
        lowerIsBetter: true,
      },
    );

    const heavyMetric = createMetric(
      avgHeavy,
      latest.heavy_processes,
      {
        warning: 2,
        critical: 5,
        lowerIsBetter: true,
      },
    );

    const startupMetric = createMetric(
      avgStartup,
      latest.startup_active,
      {
        warning: 2,
        critical: 5,
        lowerIsBetter: true,
      },
    );

    const anomalyCandidates = [
      {
        name: "RAM",
        severity:
          ramMetric.status === "critical"
            ? 3
            : ramMetric.status === "warning"
              ? 2
              : 0,
        text:
          `La RAM está ${Math.abs(
            ramMetric.difference,
          ).toFixed(0)} puntos por encima de lo habitual.`,
      },

      {
        name: "CPU",
        severity:
          cpuMetric.status === "critical"
            ? 3
            : cpuMetric.status === "warning"
              ? 2
              : 0,
        text:
          `La CPU está ${Math.abs(
            cpuMetric.difference,
          ).toFixed(0)} puntos por encima de lo habitual.`,
      },

      {
        name: "Procesos",
        severity:
          heavyMetric.status === "critical"
            ? 3
            : heavyMetric.status === "warning"
              ? 2
              : 0,
        text:
          `Hay ${Math.abs(
            heavyMetric.difference,
          ).toFixed(0)} procesos pesados más de lo habitual.`,
      },

      {
        name: "Inicio",
        severity:
          startupMetric.status === "critical"
            ? 3
            : startupMetric.status === "warning"
              ? 2
              : 0,
        text:
          `Hay ${Math.abs(
            startupMetric.difference,
          ).toFixed(0)} programas de inicio más de lo habitual.`,
      },

      {
        name: "Disco",
        severity:
          diskMetric.status === "critical"
            ? 3
            : diskMetric.status === "warning"
              ? 2
              : 0,
        text:
          `El disco está ${Math.abs(
            diskMetric.difference,
          ).toFixed(0)} puntos más ocupado de lo habitual.`,
      },
    ];

    const primary =
      anomalyCandidates
        .sort(
          (a, b) =>
            b.severity - a.severity,
        )
        .find(
          (item) =>
            item.severity > 0,
        );

    const sampleCount =
      previousSamples.length + 1;

    const level =
      sampleCount >= 5
        ? "established"
        : sampleCount >= 3
          ? "preliminary"
          : "insufficient";

    let primaryFinding =
      "El equipo está dentro de su comportamiento habitual.";

    let summary =
      "No encontramos desviaciones importantes respecto de los análisis anteriores.";

    if (primary) {
      primaryFinding =
        `Principal anomalía: ${primary.name}`;

      summary = primary.text;
    }

    if (level === "insufficient") {
      summary =
        "Ya podemos hacer una comparación inicial, pero todavía necesitamos más análisis para establecer un patrón confiable.";
    }

    if (level === "preliminary") {
      summary =
        primary
          ? `${primary.text} El baseline todavía es preliminar.`
          : "El comportamiento actual es similar al patrón preliminar de esta PC.";
    }

    return {
      sampleCount,
      level,

      score: scoreMetric,
      cpu: cpuMetric,
      ram: ramMetric,
      disk: diskMetric,
      heavyProcesses: heavyMetric,
      startup: startupMetric,

      primaryFinding,
      summary,
    };
  }

  const baseline =
    calculateBaseline();

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

      const noiseFloor =
        metric.key === "score"
          ? 1
          : metric.key === "ram"
            ? 2
            : metric.key === "cpu"
              ? 3
              : metric.key === "disk"
                ? 1
                : metric.key === "heavy"
                  ? 1
                  : metric.key === "startup"
                    ? 1
                    : metric.key === "cleanup"
                      ? 50 * 1024 * 1024
                      : metric.key === "large"
                        ? 500 * 1024 * 1024
                        : 0;

      if (
        magnitude >= noiseFloor &&
        magnitude > 0
      ) {
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
      .filter(
        (metric) =>
          metric.direction === "worse" &&
          metric.severity !== "normal",
      )
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
    } else if (scoreDifference >= 3) {
      headline =
        "El estado general mejoró";

      summary =
        `El Health Score subió ${scoreDifference} puntos y no detectamos ningún empeoramiento significativo.`;
    } else if (scoreDifference <= -3) {
      headline =
        "El Health Score bajó";

      summary =
        `El Health Score cayó ${Math.abs(scoreDifference)} puntos, aunque ningún indicador individual superó todavía el umbral de anomalía.`;
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

  const [changeSnapshots, setChangeSnapshots] =
    useState<ChangeSnapshot[]>([]);

  const [changeSnapshotsLoading, setChangeSnapshotsLoading] =
    useState(false);

  async function loadChangeSnapshots() {
    setChangeSnapshotsLoading(true);

    try {
      const data =
        await api.getChangeSnapshots();

      setChangeSnapshots(data);
    } catch (error) {
      console.error(
        "Error leyendo snapshots de cambios:",
        error,
      );
    } finally {
      setChangeSnapshotsLoading(false);
    }
  }

  const concreteChanges = (() => {
    if (changeSnapshots.length < 2) {
      return null;
    }

    const current = changeSnapshots[0];
    const previous = changeSnapshots[1];

    const previousStartup =
      new Set(previous.startup_active);

    const currentStartup =
      new Set(current.startup_active);

    const startupAdded =
      current.startup_active.filter(
        (name) => !previousStartup.has(name),
      );

    const startupRemoved =
      previous.startup_active.filter(
        (name) => !currentStartup.has(name),
      );

    const previousHeavy =
      new Set(previous.heavy_processes);

    const currentHeavy =
      new Set(current.heavy_processes);

    const heavyAdded =
      current.heavy_processes.filter(
        (name) => !previousHeavy.has(name),
      );

    const heavyRemoved =
      previous.heavy_processes.filter(
        (name) => !currentHeavy.has(name),
      );

    const previousFiles =
      new Map(
        previous.large_files.map((file) => [
          file.path,
          file,
        ]),
      );

    const currentFiles =
      new Map(
        current.large_files.map((file) => [
          file.path,
          file,
        ]),
      );

    const largeFilesAdded =
      current.large_files.filter(
        (file) => !previousFiles.has(file.path),
      );

    const largeFilesRemoved =
      previous.large_files.filter(
        (file) => !currentFiles.has(file.path),
      );

    const cleanupChanges =
      current.cleanup_categories
        .map((category) => {
          const previousCategory =
            previous.cleanup_categories.find(
              (item) => item.id === category.id,
            );

          if (!previousCategory) {
            return null;
          }

          const bytesDifference =
            category.size_bytes -
            previousCategory.size_bytes;

          const filesDifference =
            category.file_count -
            previousCategory.file_count;

          const significant =
            Math.abs(bytesDifference) >=
              50 * 1024 * 1024 ||
            Math.abs(filesDifference) >= 500;

          if (!significant) {
            return null;
          }

          return {
            id: category.id,
            name: category.name,
            bytesDifference,
            filesDifference,
          };
        })
        .filter(
          (
            item,
          ): item is {
            id: string;
            name: string;
            bytesDifference: number;
            filesDifference: number;
          } => item !== null,
        );

    const totalChanges =
      startupAdded.length +
      startupRemoved.length +
      heavyAdded.length +
      heavyRemoved.length +
      largeFilesAdded.length +
      largeFilesRemoved.length +
      cleanupChanges.length;

    return {
      current,
      previous,
      startupAdded,
      startupRemoved,
      heavyAdded,
      heavyRemoved,
      largeFilesAdded,
      largeFilesRemoved,
      cleanupChanges,
      totalChanges,
    };
  })();

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
        await api.getAboutSystemInfo();

      setAboutInfo(info);
    } catch (error) {
      console.error(
        "No se pudo leer información del sistema:",
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
          "No se pudo leer toda la información del sistema",
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

  const [advancedSnapshots, setAdvancedSnapshots] =
    useState<AdvancedSystemSnapshot[]>([]);
  const [advancedSnapshotLoading, setAdvancedSnapshotLoading] =
    useState(false);
  const [advancedSnapshotError, setAdvancedSnapshotError] =
    useState("");
  const [expandedEvidence, setExpandedEvidence] =
    useState<string | null>(null);

  async function loadAdvancedSnapshots() {
    setAdvancedSnapshotLoading(true);
    setAdvancedSnapshotError("");

    try {
      const data = await api.getAdvancedSystemSnapshots();
      setAdvancedSnapshots(data);
    } catch (error) {
      console.error("Error leyendo snapshots avanzados:", error);
      setAdvancedSnapshotError(String(error));
    } finally {
      setAdvancedSnapshotLoading(false);
    }
  }

  async function captureAdvancedSnapshot() {
    if (advancedSnapshotLoading) return;

    setAdvancedSnapshotLoading(true);
    setAdvancedSnapshotError("");

    try {
      const snapshot = await api.captureAdvancedSystemSnapshot();

      setAdvancedSnapshots((current) =>
        [
          snapshot,
          ...current.filter((item) => item.id !== snapshot.id),
        ].slice(0, 100),
      );
    } catch (error) {
      console.error("Error capturando snapshot avanzado:", error);
      setAdvancedSnapshotError(String(error));
    } finally {
      setAdvancedSnapshotLoading(false);
    }
  }

  async function clearAdvancedSnapshots() {
    if (advancedSnapshots.length === 0) return;

    if (
      !window.confirm(
        "¿Querés borrar el historial local de evidencias avanzadas?",
      )
    ) {
      return;
    }

    try {
      await api.clearAdvancedSystemSnapshots();
      setAdvancedSnapshots([]);
      setExpandedEvidence(null);
    } catch (error) {
      console.error("Error borrando snapshots avanzados:", error);
      setAdvancedSnapshotError(String(error));
    }
  }

  function evidenceSeverityLabel(severity: string) {
    if (severity === "high") return "Alta";
    if (severity === "medium") return "Media";
    if (severity === "low") return "Baja";
    return severity;
  }

  const latestAdvancedSnapshot = advancedSnapshots[0] ?? null;


  const [cpuAdvanced, setCpuAdvanced] =
    useState<CpuAdvancedDiagnosis | null>(null);
  const [cpuAdvancedLoading, setCpuAdvancedLoading] =
    useState(false);
  const [cpuAdvancedError, setCpuAdvancedError] =
    useState("");

  async function runCpuAdvancedDiagnosis() {
    if (cpuAdvancedLoading) return;

    setCpuAdvancedLoading(true);
    setCpuAdvancedError("");

    try {
      const data = await api.getCpuAdvancedDiagnosis();
      setCpuAdvanced(data);
    } catch (error) {
      console.error("Error en diagnóstico avanzado de CPU:", error);
      setCpuAdvancedError(String(error));
    } finally {
      setCpuAdvancedLoading(false);
    }
  }


  const [ramAdvanced, setRamAdvanced] =
    useState<RamAdvancedDiagnosis | null>(null);
  const [ramAdvancedLoading, setRamAdvancedLoading] =
    useState(false);
  const [ramAdvancedError, setRamAdvancedError] =
    useState("");

  async function runRamAdvancedDiagnosis() {
    if (ramAdvancedLoading) return;

    setRamAdvancedLoading(true);
    setRamAdvancedError("");

    try {
      const data = await api.getRamAdvancedDiagnosis();
      setRamAdvanced(data);
    } catch (error) {
      console.error("Error en diagnóstico avanzado de RAM:", error);
      setRamAdvancedError(String(error));
    } finally {
      setRamAdvancedLoading(false);
    }
  }


  const [storageAdvanced,setStorageAdvanced]=useState<StorageAdvancedDiagnosis|null>(null);
  const [storageAdvancedLoading,setStorageAdvancedLoading]=useState(false);
  const [storageAdvancedError,setStorageAdvancedError]=useState("");
  async function runStorageAdvancedDiagnosis(){
    if(storageAdvancedLoading)return;
    setStorageAdvancedLoading(true);setStorageAdvancedError("");
    try{setStorageAdvanced(await api.getStorageAdvancedDiagnosis())}
    catch(error){console.error("Error en diagnóstico avanzado de almacenamiento:",error);setStorageAdvancedError(String(error))}
    finally{setStorageAdvancedLoading(false)}
  }

  const [startupAdvanced, setStartupAdvanced] =
    useState<StartupAdvancedDiagnosis | null>(null);
  const [startupAdvancedLoading, setStartupAdvancedLoading] = useState(false);
  const [startupAdvancedError, setStartupAdvancedError] = useState("");

  async function runStartupAdvancedDiagnosis() {
    if (startupAdvancedLoading) return;

    setStartupAdvancedLoading(true);
    setStartupAdvancedError("");

    try {
      const data = await api.getStartupAdvancedDiagnosis();
      setStartupAdvanced(data);
      await refreshStartupActionState();
    } catch (error) {
      console.error("Error en diagnóstico avanzado de inicio:", error);
      setStartupAdvancedError(String(error));
    } finally {
      setStartupAdvancedLoading(false);
    }
  }


  const [networkAdvanced, setNetworkAdvanced] =
    useState<NetworkAdvancedDiagnosis | null>(null);
  const [networkAdvancedLoading, setNetworkAdvancedLoading] = useState(false);
  const [networkAdvancedError, setNetworkAdvancedError] = useState("");

  async function runNetworkAdvancedDiagnosis() {
    if (networkAdvancedLoading) return;
    setNetworkAdvancedLoading(true);
    setNetworkAdvancedError("");
    try {
      const data = await api.getNetworkAdvancedDiagnosis();
      setNetworkAdvanced(data);
    } catch (error) {
      console.error("Error en diagnóstico avanzado de red:", error);
      setNetworkAdvancedError(String(error));
    } finally {
      setNetworkAdvancedLoading(false);
    }
  }


  const [windowsAdvanced,setWindowsAdvanced]=useState<WindowsAdvancedDiagnosis|null>(null);
  const [windowsAdvancedLoading,setWindowsAdvancedLoading]=useState(false);
  const [windowsAdvancedError,setWindowsAdvancedError]=useState("");
  async function runWindowsAdvancedDiagnosis(){
    if(windowsAdvancedLoading)return;
    setWindowsAdvancedLoading(true);setWindowsAdvancedError("");
    try{setWindowsAdvanced(await api.getWindowsAdvancedDiagnosis())}
    catch(error){console.error("Error en diagnóstico avanzado de Windows:",error);setWindowsAdvancedError(String(error))}
    finally{setWindowsAdvancedLoading(false)}
  }


  const [startupActionBusy, setStartupActionBusy] = useState("");
  const [startupActionMessage, setStartupActionMessage] = useState("");
  const [startupActionError, setStartupActionError] = useState("");
  const [startupConfirmAction, setStartupConfirmAction] = useState<{
    mode: "disable" | "restore";
    item:
      | { name: string; command: string; location: string }
      | api.StartupDisabledItem;
  } | null>(null);

  function startupAdvancedIsActionable(location: string) {
    const value = location.toLowerCase();
    const hkcuRun =
      value.includes("hkcu") &&
      value.includes("software") &&
      value.includes("microsoft") &&
      value.includes("windows") &&
      value.includes("currentversion") &&
      value.includes("run");
    const startupFolder = value.includes("startup");
    return hkcuRun || startupFolder;
  }

  async function runStartupAdvancedAction(
    item: { name: string; command: string; location: string },
    enabled: boolean,
  ) {
    const actionKey = `${item.name}|${item.location}`;
    const verb = enabled ? "reactivar" : "desactivar";

    setStartupActionBusy(actionKey);
    setStartupActionMessage("");
    setStartupActionError("");

    try {
      const isStartupFolder = item.location.toLowerCase().includes("startup");

      const result = isStartupFolder
        ? await api.setStartupFolderEnabled(
            item.name,
            item.command,
            item.location,
            enabled,
          )
        : await api.setStartupAdvancedEnabled(
            item.name,
            item.command,
            item.location,
            enabled,
          );

      setStartupActionMessage(result.message);

      const refreshed = await api.getStartupAdvancedDiagnosis();
      setStartupAdvanced(refreshed);

      await refreshStartupActionState();
    } catch (error) {
      console.error(`Error al ${verb} elemento de inicio:`, error);
      setStartupActionError(String(error));
    } finally {
      setStartupActionBusy("");
    }
  }


  const [startupDisabledItems,setStartupDisabledItems]=useState<api.StartupDisabledItem[]>([]);
  const [startupActionHistory,setStartupActionHistory]=useState<api.StartupActionHistoryItem[]>([]);

  async function refreshStartupActionState(){
    const [disabled,history]=await Promise.all([
      api.getStartupDisabledItems(),
      api.getStartupActionHistory(),
    ]);
    setStartupDisabledItems(disabled);
    setStartupActionHistory(history);
  }

  async function restoreStartupItem(item:api.StartupDisabledItem){
    const key=`restore|${item.id}`;

    setStartupActionBusy(key);
    setStartupActionMessage("");
    setStartupActionError("");

    try{
      const result=await api.restoreStartupDisabledItem(item);
      setStartupActionMessage(result.message);

      const refreshed=await api.getStartupAdvancedDiagnosis();
      setStartupAdvanced(refreshed);

      await refreshStartupActionState();
    }catch(error){
      setStartupActionError(String(error));
    }finally{
      setStartupActionBusy("");
    }
  }

  async function loadStats() {
    try {
      const data =
        await api.getSystemStats();

      setStats(data);
    } catch (error) {
      console.error(error);
    }
  }

  async function scanCleanup() {
    setCleanupLoading(true);
    setShowReview(false);
    setConfirmed(false);
    setResult(null);

    try {
      const data =
        await api.scanCleanup();

      setCleanup(data);

      setSelectedCategories(
        data.categories
          .filter(
            (category) =>
              category.accessible &&
              category.file_count > 0 &&
              category.size_bytes > 0,
          )
          .map((category) => category.id),
      );
    } finally {
      setCleanupLoading(false);
    }
  }

  async function executeCleanup() {
    if (!confirmed || selectedCategories.length === 0) {
      return;
    }

    setCleaning(true);
    setResult(null);

    try {
      const cleanupResult =
        await api.runCleanup(selectedCategories);

      setResult(cleanupResult);

      const freshScan =
        await api.scanCleanup();

      setCleanup(freshScan);

      setSelectedCategories([]);
      setConfirmed(false);
      setShowReview(false);

      await loadStats();
    } catch (error) {
      console.error("Error durante limpieza:", error);
    } finally {
      setCleaning(false);
    }
  }

  useEffect(() => {
    loadStats();
    loadPerformance();

    const timer =
      window.setInterval(loadStats, 3000);

    return () => window.clearInterval(timer);
  }, []);


  const visibleProcesses = useMemo(() => {
    const list = processes?.processes ?? [];

    if (processFilter === "all") {
      return list;
    }

    return list.filter(
      (process) =>
        process.memory_bytes >=
          300 * 1024 * 1024 ||
        process.cpu_usage >= 5,
    );
  }, [processes, processFilter]);

  const visibleProcessesRam = useMemo(
    () =>
      visibleProcesses.reduce(
        (total, process) =>
          total + process.memory_bytes,
        0,
      ),
    [visibleProcesses],
  );

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
      activeView === "cpuAdvanced" ||
      activeView === "ramAdvanced" ||
      activeView === "storageAdvanced" ||
      activeView === "startupAdvanced" ||
      activeView === "networkAdvanced" ||
      activeView === "windowsAdvanced" ||
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
  const cpu = Math.round(stats.cpu_usage);
  const ram = Math.round(stats.ram_usage_percent);
  const disk = Math.round(stats.disk_usage_percent);

  const selectedData = useMemo(() => {
    if (!cleanup) {
      return {
        bytes: 0,
        files: 0,
        categories: [] as CleanupCategory[],
      };
    }

    const categories =
      cleanup.categories.filter((category) =>
        selectedCategories.includes(category.id),
      );

    return {
      categories,
      bytes: categories.reduce(
        (sum, category) =>
          sum + category.size_bytes,
        0,
      ),
      files: categories.reduce(
        (sum, category) =>
          sum + category.file_count,
        0,
      ),
    };
  }, [cleanup, selectedCategories]);

  function toggleCategory(id: string) {
    setConfirmed(false);
    setShowReview(false);

    setSelectedCategories((current) =>
      current.includes(id)
        ? current.filter((item) => item !== id)
        : [...current, id],
    );
  }

  function selectAll() {
    if (!cleanup) return;

    setSelectedCategories(
      cleanup.categories
        .filter(
          (category) =>
            category.accessible &&
            category.file_count > 0 &&
            category.size_bytes > 0,
        )
        .map((category) => category.id),
    );

    setConfirmed(false);
    setShowReview(false);
  }

  function clearSelection() {
    setSelectedCategories([]);
    setConfirmed(false);
    setShowReview(false);
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-icon brand-icon-image">
            <img
              src="/wincare-ai-icon.png"
              alt="WinCare AI"
            />
          </div>

          <div>
            <h1>WinCare AI</h1>
            <span>Diagnóstico Inteligente</span>
          </div>
        </div>

        <nav className="nav">
          <div className="nav-group-label nav-group-static">
            RESUMEN
          </div>

          <button
          className={`nav-item ${
          activeView === "dashboard" ? "active" : ""
          }`}
          onClick={() => setActiveView("dashboard")}
          >
          Estado general
          </button>

          <button
            className={`nav-group-toggle ${
              openNavGroup === "maintenance" ? "open" : ""
            }`}
            onClick={() => toggleNavGroup("maintenance")}
            aria-expanded={openNavGroup === "maintenance"}
          >
            <span>Mantenimiento</span>
            <span className="nav-group-chevron">
              {openNavGroup === "maintenance" ? "⌄" : "›"}
            </span>
          </button>

          {openNavGroup === "maintenance" && (
            <div className="nav-group-content">
              <button
              className={`nav-item ${
              activeView === "cleanup" ? "active" : ""
              }`}
              onClick={() => {
              setActiveView("cleanup");

              if (!cleanup) {
              scanCleanup();
              }
              }}
              >
              Limpieza
              </button>
              <button
              className={`nav-item ${
              activeView === "storage" ? "active" : ""
              }`}
              onClick={() => {
              setActiveView("storage");

              if (!storage) {
              scanStorage();
              }
              }}
              >
              Almacenamiento
              </button>
              <button
              className={`nav-item ${
              activeView === "performance"
              ? "active"
              : ""
              }`}
              onClick={() => {
              setActiveView("performance");
              loadPerformance();
              }}
              >
              Rendimiento
              </button>
              <button
              className={`nav-item ${
              activeView === "startup" ? "active" : ""
              }`}
              onClick={() => {
              setActiveView("startup");

              if (!startupItems) {
              loadStartupItems();
              }
              }}
              >
              Inicio de Windows
              </button>
              <button
              className={`nav-item ${
              activeView === "processes" ? "active" : ""
              }`}
              onClick={() => {
              setActiveView("processes");

              if (!processes) {
              loadProcesses();
              }
              }}
              >
              Procesos
              </button>
            </div>
          )}<button
            className={`nav-group-toggle ${
              openNavGroup === "diagnosis" ? "open" : ""
            }`}
            onClick={() => toggleNavGroup("diagnosis")}
            aria-expanded={openNavGroup === "diagnosis"}
          >
            <span>Diagnóstico</span>
            <span className="nav-group-chevron">
              {openNavGroup === "diagnosis" ? "⌄" : "›"}
            </span>
          </button>

          {openNavGroup === "diagnosis" && (
            <div className="nav-group-content">
              <button
              className={`nav-item ${
              activeView === "analysis" ? "active" : ""
              }`}
              onClick={() => {
              setActiveView("analysis");

              if (!fullAnalysis) {
              runFullAnalysis();
              }
              }}
              >
              Análisis completo
              </button>
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
            
              <button
                className={`nav-item ${
                  activeView === "cpuAdvanced" ? "active" : ""
                }`}
                onClick={() => {
                  setActiveView("cpuAdvanced");
                }}
              >
                Diagnóstico de CPU
              </button>
              <button
                className={`nav-item ${
                  activeView === "ramAdvanced" ? "active" : ""
                }`}
                onClick={() => {
                  setActiveView("ramAdvanced");
                }}
              >
                Diagnóstico de RAM
              </button>
              <button className={`nav-item ${activeView === "storageAdvanced" ? "active" : ""}`} onClick={()=>setActiveView("storageAdvanced")}>
                Diagnóstico de almacenamiento
              </button>
              <button
                className={`nav-item ${
                  activeView === "startupAdvanced" ? "active" : ""
                }`}
                onClick={() => setActiveView("startupAdvanced")}
              >
                Diagnóstico de inicio
              </button>
              <button
                className={`nav-item ${
                  activeView === "networkAdvanced" ? "active" : ""
                }`}
                onClick={() => setActiveView("networkAdvanced")}
              >
                Diagnóstico de red
              </button>
              <button className={`nav-item ${activeView === "windowsAdvanced" ? "active" : ""}`} onClick={()=>setActiveView("windowsAdvanced")}>
                Diagnóstico de Windows
              </button>
</div>
          )}

          <button
            className={`nav-group-toggle ${
              openNavGroup === "evolution" ? "open" : ""
            }`}
            onClick={() => toggleNavGroup("evolution")}
            aria-expanded={openNavGroup === "evolution"}
          >
            <span>Evolución</span>
            <span className="nav-group-chevron">
              {openNavGroup === "evolution" ? "⌄" : "›"}
            </span>
          </button>

          {openNavGroup === "evolution" && (
            <div className="nav-group-content">
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
              <button
              className={`nav-item ${
              activeView === "changes"
              ? "active"
              : ""
              }`}
              onClick={() => {
              setActiveView("changes");
              loadChangeSnapshots();
              }}
              >
              Qué cambió
              </button>
              <button
              className={`nav-item ${
              activeView === "history" ? "active" : ""
              }`}
              onClick={() => {
              setActiveView("history");
              loadHistory();
              }}
              >
              Historial
              </button>
            </div>
          )}
</nav>

                    <button
              className={`nav-item ${
                activeView === "evidence" ? "active" : ""
              }`}
              onClick={() => {
                setActiveView("evidence");
                loadAdvancedSnapshots();
              }}
            >
              Evidencias avanzadas
            </button>
<div className="sidebar-footer">
          <button
            className={`about-sidebar-button ${
              activeView === "about" ? "active" : ""
            }`}
            onClick={() => {
              setActiveView("about");

              if (!aboutInfo) {
                loadAboutInfo();
              }
            }}
          >
            <span className="about-sidebar-icon">i</span>

            <span className="about-sidebar-text">
              <strong>Acerca de</strong>
              <small>WinCare AI</small>
            </span>
          </button>
        </div>
      </aside>

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
        {activeView === "dashboard" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  ESTADO DEL EQUIPO
                </span>

                <h2>Información real de tu PC</h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                100% local
              </div>
            </header>

            <section className="hero-grid">
              <div className="health-card">
                <div
                  className="score-ring"
                  style={{
                    background: performance
                      ? `conic-gradient(#627cff 0 ${performance.score}%, #20252d ${performance.score}% 100%)`
                      : undefined,
                  }}
                >
                  <div className="score-inner">
                    <strong>
                      {performance?.score ?? "--"}
                    </strong>

                    {performance && <span>/100</span>}
                  </div>
                </div>

                <div className="health-copy">
                  <span className="status-label">
                    ESTADO GENERAL
                  </span>

                  <h3>
                    {performance?.status ??
                      "Analizando sistema..."}
                  </h3>

                  <p>
                    WinCare AI está leyendo información
                    directamente desde Windows.
                  </p>

                  <button
                    className="primary-button"
                    onClick={runFullAnalysis}
                    disabled={fullAnalysisLoading}
                  >
                    {fullAnalysisLoading
                      ? "Analizando..."
                      : "Analizar PC"}
                  </button>
                </div>
              </div>

              <div className="system-card">
                <div className="metric">
                  <div className="metric-header">
                    <span>CPU</span>
                    <strong>{cpu}%</strong>
                  </div>

                  <div className="progress">
                    <div
                      className="progress-value"
                      style={{
                        width: `${Math.min(cpu, 100)}%`,
                      }}
                    />
                  </div>

                  <small>Uso actual</small>
                </div>

                <div className="metric">
                  <div className="metric-header">
                    <span>Memoria RAM</span>
                    <strong>{ram}%</strong>
                  </div>

                  <div className="progress">
                    <div
                      className="progress-value"
                      style={{
                        width: `${Math.min(ram, 100)}%`,
                      }}
                    />
                  </div>

                  <small>
                    {stats.ram_used_gb.toFixed(1)} GB de{" "}
                    {stats.ram_total_gb.toFixed(1)} GB
                  </small>
                </div>

                <div className="metric">
                  <div className="metric-header">
                    <span>Disco C:</span>
                    <strong>{disk}%</strong>
                  </div>

                  <div className="progress">
                    <div
                      className="progress-value"
                      style={{
                        width: `${Math.min(disk, 100)}%`,
                      }}
                    />
                  </div>

                  <small>
                    {stats.disk_free_gb.toFixed(1)} GB libres
                  </small>
                </div>
              </div>
            </section>

            <section className="section-header">
              <div>
                <span className="eyebrow">
                  MONITOREO LOCAL
                </span>
                <h3>Datos del equipo</h3>
              </div>
            </section>

            <section className="cards-grid">
              <article className="action-card">
                <div className="card-icon">⚙</div>
                <span className="card-type">CPU</span>
                <strong>{cpu}%</strong>
                <h4>Procesador</h4>
                <p>Uso actual del procesador.</p>
              </article>

              <article className="action-card">
                <div className="card-icon">▦</div>
                <span className="card-type">
                  MEMORIA
                </span>

                <strong>
                  {stats.ram_used_gb.toFixed(1)} GB
                </strong>

                <h4>RAM utilizada</h4>
              </article>

              <article className="action-card">
                <div className="card-icon">▣</div>
                <span className="card-type">
                  DISCO C:
                </span>

                <strong>
                  {stats.disk_free_gb.toFixed(1)} GB
                </strong>

                <h4>Espacio disponible</h4>
              </article>

              <article className="action-card">
                <div className="card-icon">✓</div>
                <span className="card-type">
                  PRIVACIDAD
                </span>

                <strong>Local</strong>
                <h4>Sin servidores</h4>
              </article>
            </section>
          </>
        )}

        {activeView === "cleanup" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  LIMPIEZA
                </span>

                <h2>Archivos temporales</h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                Protección activa
              </div>
            </header>

            <section className="cleanup-hero">
              <div>
                <span className="status-label">
                  ESPACIO DETECTADO
                </span>

                <strong className="cleanup-total">
                  {cleanupLoading
                    ? "Analizando..."
                    : formatBytes(
                        cleanup?.total_bytes ?? 0,
                      )}
                </strong>

                <p>
                  Solo se eliminarán archivos con más de
                  24 horas y dentro de ubicaciones
                  autorizadas.
                </p>
              </div>

              <button
                className="primary-button"
                onClick={scanCleanup}
                disabled={cleanupLoading || cleaning}
              >
                Analizar nuevamente
              </button>
            </section>

            <section className="cleanup-summary">
              <article>
                <span>Archivos encontrados</span>

                <strong>
                  {(
                    cleanup?.total_files ?? 0
                  ).toLocaleString("es-AR")}
                </strong>
              </article>

              <article>
                <span>Espacio detectado</span>

                <strong>
                  {formatBytes(
                    cleanup?.total_bytes ?? 0,
                  )}
                </strong>
              </article>

              <article>
                <span>Seleccionado</span>

                <strong>
                  {formatBytes(selectedData.bytes)}
                </strong>
              </article>
            </section>

            <section className="selection-toolbar">
              <div>
                <strong>
                  {selectedCategories.length} categorías
                  seleccionadas
                </strong>

                <span>
                  {selectedData.files.toLocaleString(
                    "es-AR",
                  )}{" "}
                  archivos detectados
                </span>
              </div>

              <div className="selection-actions">
                <button
                  className="secondary-button"
                  onClick={selectAll}
                >
                  Seleccionar todo
                </button>

                <button
                  className="secondary-button"
                  onClick={clearSelection}
                >
                  Quitar selección
                </button>
              </div>
            </section>

            <section className="cleanup-list">
              {(cleanup?.categories ?? []).map(
                (category) => {
                  const selected =
                    selectedCategories.includes(
                      category.id,
                    );

                  const disabled =
                    !category.accessible ||
                    category.file_count === 0 ||
                    category.size_bytes === 0;

                  return (
                    <article
                      key={category.id}
                      className={`cleanup-row selectable ${
                        selected ? "selected" : ""
                      } ${
                        disabled ? "disabled" : ""
                      }`}
                      onClick={() => {
                        if (!disabled && !cleaning) {
                          toggleCategory(category.id);
                        }
                      }}
                    >
                      <div
                        className={`category-checkbox ${
                          selected ? "checked" : ""
                        }`}
                      >
                        {selected ? "✓" : ""}
                      </div>

                      <div className="cleanup-row-main">
                        <strong>
                          {category.name}
                        </strong>

                        <span>{category.path}</span>
                      </div>

                      <div className="cleanup-row-files">
                        <strong>
                          {category.file_count.toLocaleString(
                            "es-AR",
                          )}
                        </strong>

                        <span>archivos</span>
                      </div>

                      <div className="cleanup-row-size">
                        <strong>
                          {formatBytes(
                            category.size_bytes,
                          )}
                        </strong>

                        <span>
                          {selected
                            ? "seleccionado"
                            : "sin seleccionar"}
                        </span>
                      </div>
                    </article>
                  );
                },
              )}
            </section>

            <section className="prepare-cleanup-panel">
              <div>
                <span className="status-label">
                  LIMPIEZA SELECCIONADA
                </span>

                <strong>
                  {formatBytes(selectedData.bytes)}
                </strong>

                <p>
                  La cantidad realmente liberada puede
                  ser menor porque se protegen archivos
                  recientes o en uso.
                </p>
              </div>

              <button
                className="primary-button"
                disabled={
                  selectedCategories.length === 0 ||
                  cleaning
                }
                onClick={() => {
                  setShowReview(true);
                  setConfirmed(false);
                }}
              >
                Preparar limpieza
              </button>
            </section>

            {showReview && (
              <section className="review-panel">
                <div className="review-icon">!</div>

                <div className="review-content">
                  <span className="status-label">
                    CONFIRMACIÓN
                  </span>

                  <h3>Revisá antes de continuar</h3>

                  <p>
                    WinCare AI solo intentará eliminar
                    archivos antiguos en las categorías
                    seleccionadas.
                  </p>

                  <label className="confirm-check">
                    <input
                      type="checkbox"
                      checked={confirmed}
                      onChange={(event) =>
                        setConfirmed(
                          event.target.checked,
                        )
                      }
                    />

                    <span>
                      Confirmo que quiero limpiar las
                      categorías seleccionadas.
                    </span>
                  </label>

                  <button
                    className="danger-safe-button"
                    disabled={!confirmed || cleaning}
                    onClick={executeCleanup}
                  >
                    {cleaning
                      ? "Limpiando..."
                      : "Limpiar archivos seguros"}
                  </button>
                </div>
              </section>
            )}

            {result && (
              <section className="cleanup-result">
                <div className="result-success">
                  ✓
                </div>

                <div>
                  <span className="status-label">
                    LIMPIEZA FINALIZADA
                  </span>

                  <h3>
                    {formatBytes(
                      result.deleted_bytes,
                    )}{" "}
                    liberados
                  </h3>

                  <p>
                    {result.deleted_files.toLocaleString(
                      "es-AR",
                    )}{" "}
                    archivos eliminados ·{" "}
                    {result.skipped_files.toLocaleString(
                      "es-AR",
                    )}{" "}
                    protegidos u omitidos ·{" "}
                    {result.failed_files.toLocaleString(
                      "es-AR",
                    )}{" "}
                    no pudieron eliminarse.
                  </p>
                </div>
              </section>
            )}

            <section className="local-panel">
              <div className="shield">✓</div>

              <div>
                <strong>
                  Protección de limpieza activa
                </strong>

                <p>
                  Lista blanca de ubicaciones, archivos
                  recientes protegidos y archivos en uso
                  omitidos automáticamente.
                </p>
              </div>
            </section>
          </>
        )}
        {activeView === "storage" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  ALMACENAMIENTO
                </span>

                <h2>Archivos grandes</h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                Solo análisis
              </div>
            </header>

            <section className="storage-hero">
              <div>
                <span className="status-label">
                  ARCHIVOS GRANDES DETECTADOS
                </span>

                <strong className="cleanup-total">
                  {storageLoading
                    ? "Analizando..."
                    : formatBytes(
                        storage?.total_large_bytes ?? 0,
                      )}
                </strong>

                <p>
                  WinCare AI revisa tus carpetas personales
                  para encontrar archivos grandes. No elimina
                  ni modifica ninguno.
                </p>
              </div>

              <button
                className="primary-button"
                onClick={() =>
                  scanStorage(storageThreshold)
                }
                disabled={storageLoading}
              >
                {storageLoading
                  ? "Analizando..."
                  : "Analizar nuevamente"}
              </button>
            </section>

            <section className="storage-filters">
              <div>
                <span className="status-label">
                  TAMAÑO MÍNIMO
                </span>

                <div className="threshold-buttons">
                  {[100, 500, 1024].map((value) => (
                    <button
                      key={value}
                      className={
                        storageThreshold === value
                          ? "threshold active"
                          : "threshold"
                      }
                      onClick={() => {
                        setStorageThreshold(value);
                        scanStorage(value);
                      }}
                      disabled={storageLoading}
                    >
                      {value === 1024
                        ? "Más de 1 GB"
                        : `Más de ${value} MB`}
                    </button>
                  ))}
                </div>
              </div>
            </section>

            <section className="cleanup-summary">
              <article>
                <span>Archivos revisados</span>

                <strong>
                  {(
                    storage?.total_files_scanned ?? 0
                  ).toLocaleString("es-AR")}
                </strong>
              </article>

              <article>
                <span>Archivos grandes</span>

                <strong>
                  {(
                    storage?.total_large_files ?? 0
                  ).toLocaleString("es-AR")}
                </strong>
              </article>

              <article>
                <span>Espacio ocupado</span>

                <strong>
                  {formatBytes(
                    storage?.total_large_bytes ?? 0,
                  )}
                </strong>
              </article>
            </section>

            <section className="large-files-panel">
              <div className="large-files-header">
                <div>
                  <span className="eyebrow">
                    RESULTADOS
                  </span>

                  <h3>Archivos más grandes</h3>
                </div>

                <span>
                  Máximo 500 resultados
                </span>
              </div>

              {storageLoading && (
                <div className="storage-empty">
                  Analizando carpetas personales...
                </div>
              )}

              {!storageLoading &&
                (storage?.files.length ?? 0) === 0 && (
                  <div className="storage-empty">
                    No encontramos archivos que superen
                    el tamaño seleccionado.
                  </div>
                )}

              {!storageLoading &&
                (storage?.files ?? []).map(
                  (file, index) => (
                    <article
                      className="large-file-row"
                      key={`${file.path}-${index}`}
                    >
                      <div className="file-rank">
                        {index + 1}
                      </div>

                      <div className="file-main">
                        <strong>{file.name}</strong>
                        <span>{file.path}</span>
                      </div>

                      <div className="file-size">
                        <strong>
                          {formatBytes(file.size_bytes)}
                        </strong>

                        <span>
                          {file.modified_unix > 0
                            ? new Date(
                                file.modified_unix *
                                  1000,
                              ).toLocaleDateString(
                                "es-AR",
                              )
                            : "Fecha desconocida"}
                        </span>
                      </div>
                    </article>
                  ),
                )}
            </section>

            <section className="local-panel">
              <div className="shield">✓</div>

              <div>
                <strong>
                  Análisis de almacenamiento seguro
                </strong>

                <p>
                  WinCare AI únicamente lee nombres,
                  tamaños y fechas. No elimina ni mueve
                  archivos desde este módulo.
                </p>
              </div>
            </section>
          </>
        )}
        {activeView === "processes" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  PROCESOS
                </span>

                <h2>Procesos en tiempo real</h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                Gestión protegida
              </div>
            </header>

            <section className="process-hero">
              <div>
                <span className="status-label">
                  PROCESOS DETECTADOS
                </span>

                <strong className="cleanup-total">
                  {processesLoading
                    ? "Actualizando..."
                    : (
                        processes?.process_count ?? 0
                      ).toLocaleString("es-AR")}
                </strong>

                <p>
                  WinCare AI muestra qué procesos están
                  utilizando más memoria y CPU en este
                  momento.
                </p>
              </div>

              <button
                className="primary-button"
                onClick={loadProcesses}
                disabled={processesLoading}
              >
                {processesLoading
                  ? "Actualizando..."
                  : "Actualizar procesos"}
              </button>
            </section>

            <section className="cleanup-summary">
              <article>
                <span>Procesos mostrados</span>

                <strong>
                  {visibleProcesses.length.toLocaleString(
                    "es-AR",
                  )}
                </strong>
              </article>

              <article>
                <span>RAM usada por lista</span>

                <strong>
                  {formatBytes(
                    visibleProcessesRam,
                  )}
                </strong>
              </article>

              <article>
                <span>Modo</span>

                <strong>
                  {processFilter === "all"
                    ? "Todos"
                    : "Pesados"}
                </strong>
              </article>
            </section>

            <section className="storage-filters">
              <div>
                <span className="status-label">
                  FILTRO
                </span>

                <div className="process-filter-buttons">
                  <button
                    className={
                      processFilter === "all"
                        ? "process-filter-button active"
                        : "process-filter-button"
                    }
                    onClick={() =>
                      setProcessFilter("all")
                    }
                  >
                    Todos
                  </button>

                  <button
                    className={
                      processFilter === "heavy"
                        ? "process-filter-button active"
                        : "process-filter-button"
                    }
                    onClick={() =>
                      setProcessFilter("heavy")
                    }
                  >
                    Procesos pesados
                  </button>
                </div>
              </div>
            </section>

            <section className="process-panel">
              <div className="process-header">
                <span>Proceso</span>
                <span>PID</span>
                <span>CPU</span>
                <span>RAM</span>
              </div>

              {processesLoading && (
                <div className="storage-empty">
                  Leyendo procesos...
                </div>
              )}

              {!processesLoading &&
                visibleProcesses.map((process) => (
                    <article
                      className="process-row"
                      key={`${process.pid}-${process.name}`}
                    >
                      <div className="process-name">
                        <div className="process-icon">
                          {process.name
                            .slice(0, 1)
                            .toUpperCase()}
                        </div>

                        <strong>
                          {process.name}
                        </strong>
                      </div>

                      <span className="process-pid">
                        {process.pid}
                      </span>

                      <div className="process-value">
                        <strong>
                          {process.cpu_usage.toFixed(1)}%
                        </strong>

                        <div className="mini-progress">
                          <div
                            className="mini-progress-value"
                            style={{
                              width: `${Math.min(
                                process.cpu_usage,
                                100,
                              )}%`,
                            }}
                          />
                        </div>
                      </div>

                      <div className="process-value">
                        <strong>
                          {formatBytes(
                            process.memory_bytes,
                          )}
                        </strong>
                      </div>
                    </article>
                  ))}
            </section>

            <section className="local-panel">
              <div className="shield">✓</div>

              <div>
                <strong>
                  Monitor de procesos en modo seguro
                </strong>

                <p>
                  Esta versión únicamente consulta los
                  procesos activos. No puede cerrar ni
                  modificar ninguno.
                </p>
              </div>
            </section>
          </>
        )}
        {activeView === "startup" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  INICIO DE WINDOWS
                </span>

                <h2>Programas que arrancan con tu PC</h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                Gestión protegida
              </div>
            </header>

            <section className="startup-hero">
              <div>
                <span className="status-label">
                  ELEMENTOS DE INICIO DETECTADOS
                </span>

                <strong className="cleanup-total">
                  {startupLoading
                    ? "Leyendo..."
                    : (
                        startupItems?.total_items ?? 0
                      ).toLocaleString("es-AR")}
                </strong>

                <p>
                  Estos programas pueden iniciarse
                  automáticamente al entrar a Windows.
                  En esta versión solo los mostramos.
                </p>
              </div>

              <button
                className="primary-button"
                onClick={loadStartupItems}
                disabled={startupLoading}
              >
                {startupLoading
                  ? "Actualizando..."
                  : "Actualizar lista"}
              </button>
            </section>

            <section className="cleanup-summary">
              <article>
                <span>Elementos detectados</span>

                <strong>
                  {(
                    startupItems?.total_items ?? 0
                  ).toLocaleString("es-AR")}
                </strong>
              </article>

              <article>
                <span>Modo actual</span>

                <strong>Protegido</strong>
              </article>

              <article>
                <span>Modificaciones</span>

                <strong>{startupChanges}</strong>
              </article>
            </section>

            <section className="startup-panel">
              <div className="startup-header startup-header-managed">
                <span>Programa</span>
                <span>Origen</span>
                <span>Estado</span>
                <span>Acción</span>
              </div>

              {startupLoading && (
                <div className="storage-empty">
                  Leyendo configuración de inicio...
                </div>
              )}

              {!startupLoading &&
                (startupItems?.items.length ?? 0) === 0 && (
                  <div className="storage-empty">
                    No encontramos elementos de inicio
                    en las ubicaciones analizadas.
                  </div>
                )}

              {!startupLoading &&
                (startupItems?.items ?? []).map(
                  (item, index) => (
                    <article
                      className="startup-row startup-row-managed"
                      key={item.id || `${item.source}-${item.name}-${index}`}
                    >
                      <div className="startup-name">
                        <div className="process-icon">
                          {item.name
                            .slice(0, 1)
                            .toUpperCase()}
                        </div>

                        <div>
                          <strong>{item.name}</strong>

                          <span
                            className="startup-command"
                            title={item.command}
                          >
                            {item.command}
                          </span>
                        </div>
                      </div>

                      <span className="startup-source">
                        {item.source}
                      </span>

                      <div>
                        <span
                          className={
                            item.enabled
                              ? "startup-status enabled"
                              : "startup-status disabled"
                          }
                        >
                          <span />
                          {item.enabled
                            ? "Activo"
                            : "Desactivado"}
                        </span>
                      </div>

                      <div className="startup-action">
                        {item.editable ? (
                          <button
                            className={
                              item.enabled
                                ? "startup-toggle disable"
                                : "startup-toggle enable"
                            }
                            disabled={
                              startupChanging === item.id
                            }
                            onClick={() =>
                              setStartupConfirm(item)
                            }
                          >
                            {startupChanging === item.id
                              ? "Procesando..."
                              : item.enabled
                                ? "Desactivar"
                                : "Activar"}
                          </button>
                        ) : (
                          <span className="startup-protected">
                            Protegido
                          </span>
                        )}
                      </div>
                    </article>
                  ),
                )}
            </section>

            {startupError && (
              <section className="startup-error">
                <strong>No se pudo completar el cambio</strong>
                <span>{startupError}</span>
              </section>
            )}

            {startupConfirm && (
              <div className="confirm-overlay">
                <section className="confirm-dialog">
                  <div className="confirm-dialog-icon">
                    !
                  </div>

                  <span className="status-label">
                    CONFIRMACIÓN
                  </span>

                  <h3>
                    {startupConfirm.enabled
                      ? "¿Desactivar este programa?"
                      : "¿Volver a activar este programa?"}
                  </h3>

                  <strong className="confirm-app-name">
                    {startupConfirm.name}
                  </strong>

                  <p>
                    {startupConfirm.enabled
                      ? "WinCare AI guardará una copia de la configuración antes de desactivarlo. El programa dejará de iniciarse automáticamente con tu sesión."
                      : "WinCare AI restaurará la entrada original para que vuelva a iniciarse con tu sesión."}
                  </p>

                  <div className="confirm-actions">
                    <button
                      className="secondary-button"
                      onClick={() =>
                        setStartupConfirm(null)
                      }
                    >
                      Cancelar
                    </button>

                    <button
                      className="primary-button"
                      onClick={() =>
                        changeStartupItem(
                          startupConfirm,
                        )
                      }
                      disabled={
                        startupChanging !== null
                      }
                    >
                      {startupChanging
                        ? "Procesando..."
                        : startupConfirm.enabled
                          ? "Sí, desactivar"
                          : "Sí, activar"}
                    </button>
                  </div>
                </section>
              </div>
            )}

            <section className="local-panel">
              <div className="shield">✓</div>

              <div>
                <strong>
                  Gestión protegida del inicio
                </strong>

                <p>
                  Solo las entradas del usuario actual pueden modificarse.
                  Las entradas del equipo y otras ubicaciones permanecen protegidas.
                </p>
              </div>
            </section>
          </>
        )}
        {activeView === "performance" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  RENDIMIENTO
                </span>

                <h2>Estado de rendimiento</h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                Análisis local
              </div>
            </header>

            <section className="performance-hero">
              <div className="performance-score">
                <div
                  className="performance-ring"
                  style={{
                    background: `conic-gradient(
                      #627cff 0 ${performance?.score ?? 0}%,
                      #20252d ${performance?.score ?? 0}% 100%
                    )`,
                  }}
                >
                  <div>
                    <strong>
                      {performanceLoading
                        ? "--"
                        : performance?.score ?? "--"}
                    </strong>

                    <span>/100</span>
                  </div>
                </div>

                <div>
                  <span className="status-label">
                    HEALTH SCORE
                  </span>

                  <h3>
                    {performanceLoading
                      ? "Analizando..."
                      : performance?.status ??
                        "Sin analizar"}
                  </h3>

                  <p>
                    El puntaje se calcula localmente usando
                    CPU, RAM, almacenamiento, procesos y
                    programas de inicio.
                  </p>
                </div>
              </div>

              <button
                className="primary-button"
                onClick={loadPerformance}
                disabled={performanceLoading}
              >
                {performanceLoading
                  ? "Analizando..."
                  : "Analizar rendimiento"}
              </button>
            </section>

            <section className="performance-metrics">
              <article>
                <span>CPU</span>

                <strong>
                  {Math.round(
                    performance?.cpu_usage ?? 0,
                  )}%
                </strong>

                <div className="progress">
                  <div
                    className="progress-value"
                    style={{
                      width: `${Math.min(
                        performance?.cpu_usage ?? 0,
                        100,
                      )}%`,
                    }}
                  />
                </div>
              </article>

              <article>
                <span>RAM</span>

                <strong>
                  {Math.round(
                    performance?.ram_usage_percent ??
                      0,
                  )}%
                </strong>

                <div className="progress">
                  <div
                    className="progress-value"
                    style={{
                      width: `${Math.min(
                        performance?.ram_usage_percent ??
                          0,
                        100,
                      )}%`,
                    }}
                  />
                </div>
              </article>

              <article>
                <span>Disco C:</span>

                <strong>
                  {Math.round(
                    performance?.disk_usage_percent ??
                      0,
                  )}%
                </strong>

                <div className="progress">
                  <div
                    className="progress-value"
                    style={{
                      width: `${Math.min(
                        performance?.disk_usage_percent ??
                          0,
                        100,
                      )}%`,
                    }}
                  />
                </div>
              </article>

              <article>
                <span>Procesos pesados</span>

                <strong>
                  {performance?.heavy_processes ?? 0}
                </strong>

                <small>
                  CPU o RAM elevada
                </small>
              </article>

              <article>
                <span>Apps de inicio</span>

                <strong>
                  {performance?.active_startup_items ??
                    0}
                </strong>

                <small>
                  activas actualmente
                </small>
              </article>
            </section>

            <section className="recommendation-panel">
              <div className="recommendation-header">
                <div>
                  <span className="eyebrow">
                    RECOMENDACIONES
                  </span>

                  <h3>
                    Qué podés mejorar
                  </h3>
                </div>

                <span>
                  Reglas locales transparentes
                </span>
              </div>

              {(performance?.recommendations ?? []).map(
                (recommendation, index) => (
                  <article
                    className={`recommendation-row ${recommendation.level}`}
                    key={`${recommendation.title}-${index}`}
                  >
                    <div
                      className={`recommendation-indicator ${recommendation.level}`}
                    />

                    <div className="recommendation-main">
                      <strong>
                        {recommendation.title}
                      </strong>

                      <span>
                        {recommendation.description}
                      </span>
                    </div>

                    {recommendation.target !==
                      "dashboard" && (
                      <button
                        className="secondary-button"
                        onClick={() => {
                          if (
                            recommendation.target ===
                            "processes"
                          ) {
                            setActiveView("processes");
                            loadProcesses();
                          }

                          if (
                            recommendation.target ===
                            "startup"
                          ) {
                            setActiveView("startup");
                            loadStartupItems();
                          }

                          if (
                            recommendation.target ===
                            "storage"
                          ) {
                            setActiveView("storage");
                            scanStorage();
                          }
                        }}
                      >
                        Revisar
                      </button>
                    )}
                  </article>
                ),
              )}
            </section>

            <section className="local-panel">
              <div className="shield">✓</div>

              <div>
                <strong>
                  Puntaje calculado localmente
                </strong>

                <p>
                  El Health Score no se envía a ningún
                  servidor y las recomendaciones se basan
                  en reglas visibles del propio programa.
                </p>
              </div>
            </section>
          </>
        )}
        {activeView === "analysis" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  ANÁLISIS COMPLETO
                </span>

                <h2>
                  Estado integral de tu PC
                </h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                100% local
              </div>
            </header>

            {fullAnalysisLoading && (
              <section className="full-scan-running">
                <div className="scan-orb">
                  <div className="scan-orb-inner">
                    <strong>
                      {fullAnalysisProgress}%
                    </strong>
                  </div>
                </div>

                <div className="scan-running-copy">
                  <span className="status-label">
                    ANALIZANDO TU PC
                  </span>

                  <h3>
                    {fullAnalysisStep}
                  </h3>

                  <p>
                    WinCare AI está combinando varios
                    análisis locales para crear un
                    diagnóstico general del equipo.
                  </p>

                  <div className="full-progress">
                    <div
                      style={{
                        width:
                          `${fullAnalysisProgress}%`,
                      }}
                    />
                  </div>

                  <small>
                    Ningún dato sale de esta computadora.
                  </small>
                </div>
              </section>
            )}

            {!fullAnalysisLoading &&
              !fullAnalysis &&
              !fullAnalysisError && (
                <section className="analysis-empty">
                  <div className="analysis-empty-icon">
                    W
                  </div>

                  <span className="status-label">
                    CENTRO DE DIAGNÓSTICO
                  </span>

                  <h3>
                    Analizá toda la PC de una vez
                  </h3>

                  <p>
                    Revisaremos rendimiento, temporales,
                    almacenamiento, procesos y programas
                    de inicio.
                  </p>

                  <button
                    className="primary-button"
                    onClick={runFullAnalysis}
                  >
                    Analizar PC
                  </button>
                </section>
              )}

            {fullAnalysisError && (
              <section className="analysis-error">
                <strong>
                  El análisis no pudo completarse
                </strong>

                <span>
                  {fullAnalysisError}
                </span>

                <button
                  className="secondary-button"
                  onClick={runFullAnalysis}
                >
                  Intentar nuevamente
                </button>
              </section>
            )}

            {!fullAnalysisLoading &&
              fullAnalysis && (
                <>
                  <section className="analysis-result-hero">
                    <div className="analysis-score-block">
                      <div
                        className="analysis-score-ring"
                        style={{
                          background:
                            `conic-gradient(
                              #627cff 0 ${fullAnalysis.healthScore}%,
                              #20252d ${fullAnalysis.healthScore}% 100%
                            )`,
                        }}
                      >
                        <div>
                          <strong>
                            {fullAnalysis.healthScore}
                          </strong>

                          <span>/100</span>
                        </div>
                      </div>

                      <div>
                        <span className="status-label">
                          HEALTH SCORE
                        </span>

                        <h3>
                          {fullAnalysis.healthStatus}
                        </h3>

                        <p>
                          Análisis completado{" "}
                          {fullAnalysis.completedAt}
                        </p>
                      </div>
                    </div>

                    <button
                      className="primary-button"
                      onClick={runFullAnalysis}
                    >
                      Analizar nuevamente
                    </button>
                  </section>

                  <section className="analysis-kpi-grid">
                    <article>
                      <span>CPU</span>

                      <strong>
                        {Math.round(
                          fullAnalysis.cpuUsage,
                        )}%
                      </strong>

                      <small>
                        uso durante el análisis
                      </small>
                    </article>

                    <article>
                      <span>RAM</span>

                      <strong>
                        {Math.round(
                          fullAnalysis.ramUsage,
                        )}%
                      </strong>

                      <small>
                        memoria utilizada
                      </small>
                    </article>

                    <article>
                      <span>Temporales</span>

                      <strong>
                        {formatBytes(
                          fullAnalysis.cleanupBytes,
                        )}
                      </strong>

                      <small>
                        {fullAnalysis.cleanupFiles.toLocaleString(
                          "es-AR",
                        )}{" "}
                        archivos
                      </small>
                    </article>

                    <article>
                      <span>
                        Archivos grandes
                      </span>

                      <strong>
                        {formatBytes(
                          fullAnalysis.largeFilesBytes,
                        )}
                      </strong>

                      <small>
                        {
                          fullAnalysis.largeFilesCount
                        }{" "}
                        mayores a 500 MB
                      </small>
                    </article>

                    <article>
                      <span>
                        Procesos pesados
                      </span>

                      <strong>
                        {
                          fullAnalysis.heavyProcesses
                        }
                      </strong>

                      <small>
                        requieren revisión
                      </small>
                    </article>

                    <article>
                      <span>
                        Apps de inicio
                      </span>

                      <strong>
                        {
                          fullAnalysis.startupActive
                        }
                      </strong>

                      <small>
                        activas
                      </small>
                    </article>
                  </section>

                  <section className="analysis-findings">
                    <div className="analysis-findings-header">
                      <div>
                        <span className="eyebrow">
                          HALLAZGOS
                        </span>

                        <h3>
                          Qué encontramos
                        </h3>
                      </div>

                      <span>
                        {
                          fullAnalysis
                            .recommendations.length
                        }{" "}
                        recomendación
                        {fullAnalysis.recommendations
                          .length === 1
                          ? ""
                          : "es"}
                      </span>
                    </div>

                    {fullAnalysis.recommendations.map(
                      (recommendation, index) => (
                        <article
                          className="analysis-finding-row"
                          key={`${recommendation.title}-${index}`}
                        >
                          <div
                            className={`recommendation-indicator ${recommendation.level}`}
                          />

                          <div className="recommendation-main">
                            <strong>
                              {
                                recommendation.title
                              }
                            </strong>

                            <span>
                              {
                                recommendation.description
                              }
                            </span>
                          </div>

                          {recommendation.target !==
                            "dashboard" && (
                            <button
                              className="secondary-button"
                              onClick={() => {
                                if (
                                  recommendation.target ===
                                  "processes"
                                ) {
                                  setActiveView(
                                    "processes",
                                  );

                                  loadProcesses();
                                }

                                if (
                                  recommendation.target ===
                                  "startup"
                                ) {
                                  setActiveView(
                                    "startup",
                                  );

                                  loadStartupItems();
                                }

                                if (
                                  recommendation.target ===
                                  "storage"
                                ) {
                                  setActiveView(
                                    "storage",
                                  );

                                  scanStorage();
                                }
                              }}
                            >
                              Revisar
                            </button>
                          )}
                        </article>
                      ),
                    )}
                  </section>

                  <section className="analysis-actions-grid">
                    <button
                      onClick={() =>
                        setActiveView("cleanup")
                      }
                    >
                      <span>01</span>
                      <strong>
                        Revisar limpieza
                      </strong>
                      <small>
                        {
                          formatBytes(
                            fullAnalysis.cleanupBytes,
                          )
                        }{" "}
                        detectados
                      </small>
                    </button>

                    <button
                      onClick={() =>
                        setActiveView("storage")
                      }
                    >
                      <span>02</span>
                      <strong>
                        Ver almacenamiento
                      </strong>
                      <small>
                        {
                          fullAnalysis.largeFilesCount
                        }{" "}
                        archivos grandes
                      </small>
                    </button>

                    <button
                      onClick={() =>
                        setActiveView("processes")
                      }
                    >
                      <span>03</span>
                      <strong>
                        Revisar procesos
                      </strong>
                      <small>
                        {
                          fullAnalysis.heavyProcesses
                        }{" "}
                        procesos pesados
                      </small>
                    </button>

                    <button
                      onClick={() =>
                        setActiveView("startup")
                      }
                    >
                      <span>04</span>
                      <strong>
                        Revisar inicio
                      </strong>
                      <small>
                        {
                          fullAnalysis.startupActive
                        }{" "}
                        programas activos
                      </small>
                    </button>
                  </section>

                  <section className="local-panel">
                    <div className="shield">
                      ✓
                    </div>

                    <div>
                      <strong>
                        Análisis completo local
                      </strong>

                      <p>
                        Todos los resultados fueron
                        obtenidos directamente desde tu PC.
                        No se utilizó ningún servidor.
                      </p>
                    </div>
                  </section>
                </>
              )}
          </>
        )}
        {activeView === "history" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  HISTORIAL LOCAL
                </span>

                <h2>
                  Evolución de tu PC
                </h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                Guardado local
              </div>
            </header>

            <section className="history-hero">
              <div>
                <span className="status-label">
                  ANÁLISIS GUARDADOS
                </span>

                <strong className="cleanup-total">
                  {history.length}
                </strong>

                <p>
                  Cada análisis completo queda guardado
                  únicamente en esta PC para poder comparar
                  su evolución con el tiempo.
                </p>
              </div>

              <div className="history-actions">
                <button
                  className="secondary-button"
                  onClick={loadHistory}
                  disabled={historyLoading}
                >
                  Actualizar
                </button>

                <button
                  className="secondary-button history-clear"
                  onClick={clearHistory}
                  disabled={history.length === 0}
                >
                  Borrar historial
                </button>
              </div>
            </section>

            {history.length > 0 && (() => {
              const average =
                history.reduce(
                  (sum, item) =>
                    sum + item.score,
                  0,
                ) / history.length;

              const latest = history[0];

              const previous =
                history.length > 1
                  ? history[1]
                  : null;

              const scoreChange =
                previous
                  ? latest.score - previous.score
                  : 0;

              const ramChange =
                previous
                  ? latest.ram_usage -
                    previous.ram_usage
                  : 0;

              return (
                <section className="history-summary">
                  <article>
                    <span>
                      Promedio Health Score
                    </span>

                    <strong>
                      {Math.round(average)}
                    </strong>

                    <small>/100</small>
                  </article>

                  <article>
                    <span>
                      Último resultado
                    </span>

                    <strong>
                      {latest.score}
                    </strong>

                    <small>
                      {latest.status}
                    </small>
                  </article>

                  <article>
                    <span>
                      Cambio desde anterior
                    </span>

                    <strong
                      className={
                        scoreChange > 0
                          ? "positive"
                          : scoreChange < 0
                            ? "negative"
                            : ""
                      }
                    >
                      {previous
                        ? `${scoreChange > 0 ? "+" : ""}${scoreChange}`
                        : "--"}
                    </strong>

                    <small>
                      puntos
                    </small>
                  </article>

                  <article>
                    <span>
                      Cambio de RAM
                    </span>

                    <strong
                      className={
                        ramChange < 0
                          ? "positive"
                          : ramChange > 0
                            ? "negative"
                            : ""
                      }
                    >
                      {previous
                        ? `${ramChange > 0 ? "+" : ""}${ramChange.toFixed(0)}%`
                        : "--"}
                    </strong>

                    <small>
                      vs. análisis anterior
                    </small>
                  </article>
                </section>
              );
            })()}

            <section className="history-panel">
              <div className="history-header">
                <span>Fecha</span>
                <span>Score</span>
                <span>RAM</span>
                <span>CPU</span>
                <span>Disco</span>
                <span>Temporales</span>
                <span>Inicio</span>
              </div>

              {historyLoading && (
                <div className="storage-empty">
                  Leyendo historial...
                </div>
              )}

              {!historyLoading &&
                history.length === 0 && (
                  <div className="history-empty">
                    <div className="history-empty-icon">
                      ↺
                    </div>

                    <h3>
                      Todavía no hay historial
                    </h3>

                    <p>
                      Ejecutá un Análisis completo y WinCare AI
                      guardará automáticamente el resultado.
                    </p>

                    <button
                      className="primary-button"
                      onClick={runFullAnalysis}
                    >
                      Analizar PC
                    </button>
                  </div>
                )}

              {!historyLoading &&
                history.map((item, index) => {
                  const previous =
                    history[index + 1];

                  const change =
                    previous
                      ? item.score - previous.score
                      : null;

                  return (
                    <article
                      className="history-row"
                      key={item.id}
                    >
                      <div className="history-date">
                        <strong>
                          {new Date(
                            item.timestamp * 1000,
                          ).toLocaleDateString(
                            "es-AR",
                          )}
                        </strong>

                        <span>
                          {new Date(
                            item.timestamp * 1000,
                          ).toLocaleTimeString(
                            "es-AR",
                            {
                              hour: "2-digit",
                              minute: "2-digit",
                            },
                          )}
                        </span>
                      </div>

                      <div className="history-score">
                        <strong>
                          {item.score}
                        </strong>

                        {change !== null && (
                          <small
                            className={
                              change > 0
                                ? "positive"
                                : change < 0
                                  ? "negative"
                                  : ""
                            }
                          >
                            {change > 0
                              ? `+${change}`
                              : change}
                          </small>
                        )}
                      </div>

                      <span>
                        {Math.round(
                          item.ram_usage,
                        )}%
                      </span>

                      <span>
                        {Math.round(
                          item.cpu_usage,
                        )}%
                      </span>

                      <span>
                        {Math.round(
                          item.disk_usage,
                        )}%
                      </span>

                      <span>
                        {formatBytes(
                          item.cleanup_bytes,
                        )}
                      </span>

                      <span>
                        {item.startup_active}
                      </span>
                    </article>
                  );
                })}
            </section>

            <section className="local-panel">
              <div className="shield">✓</div>

              <div>
                <strong>
                  Historial privado
                </strong>

                <p>
                  Los análisis se guardan en un archivo
                  JSON dentro de la carpeta local de
                  WinCare AI y no se envían a servidores.
                </p>
              </div>
            </section>
          </>
        )}
        {activeView === "baseline" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  BASELINE DEL EQUIPO
                </span>

                <h2>
                  Cómo funciona normalmente tu PC
                </h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                Aprendizaje local
              </div>
            </header>

            {!baseline && (
              <section className="baseline-empty">
                <div className="baseline-empty-icon">
                  ∿
                </div>

                <span className="status-label">
                  SIN INFORMACIÓN
                </span>

                <h3>
                  Necesitamos análisis anteriores
                </h3>

                <p>
                  Ejecutá varios análisis completos para
                  que WinCare AI pueda aprender el
                  comportamiento normal de esta PC.
                </p>

                <button
                  className="primary-button"
                  onClick={runFullAnalysis}
                >
                  Analizar PC
                </button>
              </section>
            )}

            {baseline && (
              <>
                <section
                  className={`baseline-hero ${baseline.level}`}
                >
                  <div>
                    <span className="status-label">
                      ESTADO DEL BASELINE
                    </span>

                    <h3>
                      {baseline.level ===
                      "established"
                        ? "Baseline establecido"
                        : baseline.level ===
                            "preliminary"
                          ? "Baseline preliminar"
                          : "Aprendiendo"}
                    </h3>

                    <p>
                      {baseline.level ===
                      "established"
                        ? `WinCare AI está usando ${baseline.sampleCount} análisis para comparar el estado actual con el comportamiento habitual.`
                        : `Tenemos ${baseline.sampleCount} análisis. Con 5 o más podremos establecer un baseline más confiable.`}
                    </p>
                  </div>

                  <div className="baseline-samples">
                    <strong>
                      {baseline.sampleCount}
                    </strong>

                    <span>
                      análisis disponibles
                    </span>
                  </div>
                </section>

                <section className="baseline-comparison">
                  <div className="baseline-comparison-header">
                    <div>
                      <span className="eyebrow">
                        COMPARACIÓN
                      </span>

                      <h3>
                        Actual vs habitual
                      </h3>
                    </div>

                    <span>
                      Últimos 20 análisis como máximo
                    </span>
                  </div>

                  {[
                    {
                      label: "Health Score",
                      metric: baseline.score,
                      suffix: "",
                      inverse:
                        false,
                    },
                    {
                      label: "Memoria RAM",
                      metric: baseline.ram,
                      suffix: "%",
                      inverse:
                        true,
                    },
                    {
                      label: "CPU",
                      metric: baseline.cpu,
                      suffix: "%",
                      inverse:
                        true,
                    },
                    {
                      label: "Disco C:",
                      metric: baseline.disk,
                      suffix: "%",
                      inverse:
                        true,
                    },
                    {
                      label:
                        "Procesos pesados",
                      metric:
                        baseline.heavyProcesses,
                      suffix: "",
                      inverse:
                        true,
                    },
                    {
                      label:
                        "Apps de inicio",
                      metric: baseline.startup,
                      suffix: "",
                      inverse:
                        true,
                    },
                  ].map(
                    ({
                      label,
                      metric,
                      suffix,
                    }) => (
                      <article
                        className="baseline-row"
                        key={label}
                      >
                        <div className="baseline-name">
                          <strong>
                            {label}
                          </strong>
                        </div>

                        <div className="baseline-value">
                          <span>
                            Habitual
                          </span>

                          <strong>
                            {metric.average.toFixed(
                              suffix === "%"
                                ? 0
                                : 1,
                            )}
                            {suffix}
                          </strong>
                        </div>

                        <div className="baseline-value">
                          <span>
                            Actual
                          </span>

                          <strong>
                            {metric.current.toFixed(
                              suffix === "%"
                                ? 0
                                : 1,
                            )}
                            {suffix}
                          </strong>
                        </div>

                        <div
                          className={`baseline-delta ${metric.status}`}
                        >
                          <strong>
                            {metric.difference >
                            0
                              ? "+"
                              : ""}
                            {metric.difference.toFixed(
                              suffix === "%"
                                ? 0
                                : 1,
                            )}
                            {suffix}
                          </strong>

                          <span>
                            {metric.status ===
                            "normal"
                              ? "Normal"
                              : metric.status ===
                                  "better"
                                ? "Mejor"
                                : metric.status ===
                                    "critical"
                                  ? "Anomalía"
                                  : "Atención"}
                          </span>
                        </div>
                      </article>
                    ),
                  )}
                </section>

                <section
                  className={`baseline-diagnosis ${
                    baseline.primaryFinding.includes(
                      "Principal",
                    )
                      ? "warning"
                      : "good"
                  }`}
                >
                  <div className="baseline-diagnosis-icon">
                    {baseline.primaryFinding.includes(
                      "Principal",
                    )
                      ? "!"
                      : "✓"}
                  </div>

                  <div>
                    <span className="status-label">
                      DIAGNÓSTICO
                    </span>

                    <h3>
                      {
                        baseline.primaryFinding
                      }
                    </h3>

                    <p>
                      {baseline.summary}
                    </p>
                  </div>
                </section>

                <section className="baseline-explanation">
                  <span className="eyebrow">
                    CÓMO FUNCIONA
                  </span>

                  <h3>
                    No comparamos tu PC con una
                    computadora genérica
                  </h3>

                  <p>
                    WinCare AI utiliza los análisis
                    anteriores de esta misma PC para
                    aprender sus valores habituales.
                    Esto permite detectar cambios que
                    podrían pasar desapercibidos usando
                    únicamente límites genéricos.
                  </p>
                </section>

                <section className="local-panel">
                  <div className="shield">
                    ✓
                  </div>

                  <div>
                    <strong>
                      Baseline 100% local
                    </strong>

                    <p>
                      El patrón se calcula a partir del
                      historial almacenado únicamente en
                      esta computadora.
                    </p>
                  </div>
                </section>
              </>
            )}
          </>
        )}
      
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
      
        {activeView === "changes" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">
                  QUÉ CAMBIÓ
                </span>

                <h2>
                  Cambios concretos entre análisis
                </h2>
              </div>

              <div className="privacy-badge">
                <span className="privacy-dot" />
                Snapshots locales
              </div>
            </header>

            {changeSnapshotsLoading && (
              <section className="changes-empty">
                <div className="changes-empty-icon">
                  …
                </div>

                <h3>
                  Leyendo snapshots...
                </h3>
              </section>
            )}

            {!changeSnapshotsLoading &&
              !concreteChanges && (
                <section className="changes-empty">
                  <div className="changes-empty-icon">
                    Δ
                  </div>

                  <span className="status-label">
                    NECESITAMOS DOS SNAPSHOTS
                  </span>

                  <h3>
                    Todavía no podemos detectar cambios concretos
                  </h3>

                  <p>
                    Esta función empieza a guardar snapshots
                    desde el BLOQUE 0018. Ejecutá dos análisis
                    completos para comparar programas de inicio,
                    procesos pesados, archivos grandes y temporales.
                  </p>

                  <button
                    className="primary-button"
                    onClick={runFullAnalysis}
                  >
                    Analizar PC
                  </button>
                </section>
              )}

            {!changeSnapshotsLoading &&
              concreteChanges && (
                <>
                  <section className="changes-hero">
                    <div>
                      <span className="status-label">
                        CAMBIOS DETECTADOS
                      </span>

                      <strong className="cleanup-total">
                        {concreteChanges.totalChanges}
                      </strong>

                      <p>
                        Comparamos el snapshot de{" "}
                        {new Date(
                          concreteChanges.previous.timestamp *
                            1000,
                        ).toLocaleString("es-AR")}{" "}
                        con el de{" "}
                        {new Date(
                          concreteChanges.current.timestamp *
                            1000,
                        ).toLocaleString("es-AR")}.
                      </p>
                    </div>

                    <button
                      className="primary-button"
                      onClick={runFullAnalysis}
                    >
                      Crear nuevo snapshot
                    </button>
                  </section>

                  {concreteChanges.totalChanges === 0 && (
                    <section className="changes-stable">
                      <div>✓</div>

                      <div>
                        <span className="status-label">
                          SIN CAMBIOS IMPORTANTES
                        </span>

                        <h3>
                          La configuración observada se mantiene estable
                        </h3>

                        <p>
                          No aparecieron ni desaparecieron elementos
                          relevantes entre los dos últimos snapshots.
                        </p>
                      </div>
                    </section>
                  )}

                  <section className="changes-grid">
                    <article className="changes-card">
                      <div className="changes-card-header">
                        <div>
                          <span className="eyebrow">
                            INICIO DE WINDOWS
                          </span>

                          <h3>
                            Programas de inicio
                          </h3>
                        </div>

                        <strong>
                          {concreteChanges.startupAdded.length +
                            concreteChanges.startupRemoved.length}
                        </strong>
                      </div>

                      {concreteChanges.startupAdded.map(
                        (name) => (
                          <div
                            className="change-item added"
                            key={`startup-added-${name}`}
                          >
                            <span>+</span>
                            <div>
                              <strong>{name}</strong>
                              <small>
                                Apareció como inicio automático
                              </small>
                            </div>
                          </div>
                        ),
                      )}

                      {concreteChanges.startupRemoved.map(
                        (name) => (
                          <div
                            className="change-item removed"
                            key={`startup-removed-${name}`}
                          >
                            <span>−</span>
                            <div>
                              <strong>{name}</strong>
                              <small>
                                Ya no figura como inicio automático
                              </small>
                            </div>
                          </div>
                        ),
                      )}

                      {concreteChanges.startupAdded.length === 0 &&
                        concreteChanges.startupRemoved.length === 0 && (
                          <div className="change-none">
                            Sin cambios
                          </div>
                        )}
                    </article>

                    <article className="changes-card">
                      <div className="changes-card-header">
                        <div>
                          <span className="eyebrow">
                            PROCESOS PESADOS
                          </span>

                          <h3>
                            Procesos destacados
                          </h3>
                        </div>

                        <strong>
                          {concreteChanges.heavyAdded.length +
                            concreteChanges.heavyRemoved.length}
                        </strong>
                      </div>

                      {concreteChanges.heavyAdded.map(
                        (name) => (
                          <div
                            className="change-item added"
                            key={`heavy-added-${name}`}
                          >
                            <span>+</span>
                            <div>
                              <strong>{name}</strong>
                              <small>
                                Ahora aparece entre los procesos pesados
                              </small>
                            </div>
                          </div>
                        ),
                      )}

                      {concreteChanges.heavyRemoved.map(
                        (name) => (
                          <div
                            className="change-item removed"
                            key={`heavy-removed-${name}`}
                          >
                            <span>−</span>
                            <div>
                              <strong>{name}</strong>
                              <small>
                                Ya no aparece entre los procesos pesados
                              </small>
                            </div>
                          </div>
                        ),
                      )}

                      {concreteChanges.heavyAdded.length === 0 &&
                        concreteChanges.heavyRemoved.length === 0 && (
                          <div className="change-none">
                            Sin cambios
                          </div>
                        )}
                    </article>

                    <article className="changes-card">
                      <div className="changes-card-header">
                        <div>
                          <span className="eyebrow">
                            ALMACENAMIENTO
                          </span>

                          <h3>
                            Archivos grandes
                          </h3>
                        </div>

                        <strong>
                          {concreteChanges.largeFilesAdded.length +
                            concreteChanges.largeFilesRemoved.length}
                        </strong>
                      </div>

                      {concreteChanges.largeFilesAdded
                        .slice(0, 8)
                        .map((file) => (
                          <div
                            className="change-item added"
                            key={`large-added-${file.path}`}
                          >
                            <span>+</span>
                            <div>
                              <strong>{file.name}</strong>
                              <small>
                                Nuevo · {formatBytes(file.size_bytes)}
                              </small>
                            </div>
                          </div>
                        ))}

                      {concreteChanges.largeFilesRemoved
                        .slice(0, 8)
                        .map((file) => (
                          <div
                            className="change-item removed"
                            key={`large-removed-${file.path}`}
                          >
                            <span>−</span>
                            <div>
                              <strong>{file.name}</strong>
                              <small>
                                Ya no aparece · {formatBytes(file.size_bytes)}
                              </small>
                            </div>
                          </div>
                        ))}

                      {concreteChanges.largeFilesAdded.length === 0 &&
                        concreteChanges.largeFilesRemoved.length === 0 && (
                          <div className="change-none">
                            Sin cambios
                          </div>
                        )}
                    </article>

                    <article className="changes-card">
                      <div className="changes-card-header">
                        <div>
                          <span className="eyebrow">
                            LIMPIEZA
                          </span>

                          <h3>
                            Temporales
                          </h3>
                        </div>

                        <strong>
                          {concreteChanges.cleanupChanges.length}
                        </strong>
                      </div>

                      {concreteChanges.cleanupChanges.map(
                        (change) => (
                          <div
                            className={
                              change.bytesDifference > 0
                                ? "change-item added"
                                : "change-item removed"
                            }
                            key={change.id}
                          >
                            <span>
                              {change.bytesDifference > 0
                                ? "+"
                                : "−"}
                            </span>

                            <div>
                              <strong>
                                {change.name}
                              </strong>

                              <small>
                                {change.bytesDifference > 0
                                  ? "Aumentó "
                                  : "Disminuyó "}
                                {formatBytes(
                                  Math.abs(
                                    change.bytesDifference,
                                  ),
                                )}
                              </small>
                            </div>
                          </div>
                        ),
                      )}

                      {concreteChanges.cleanupChanges.length === 0 && (
                        <div className="change-none">
                          Sin cambios significativos
                        </div>
                      )}
                    </article>
                  </section>

                  <section className="changes-explanation">
                    <span className="eyebrow">
                      POR QUÉ IMPORTA
                    </span>

                    <h3>
                      Ahora WinCare AI puede observar cambios reales
                    </h3>

                    <p>
                      Antes comparábamos únicamente números. Estos
                      snapshots permiten detectar qué programa apareció
                      en el inicio, qué proceso pasó a ser pesado, qué
                      archivo grande apareció o desapareció y cómo
                      evolucionaron los temporales.
                    </p>
                  </section>

                  <section className="local-panel">
                    <div className="shield">✓</div>

                    <div>
                      <strong>
                        Snapshots privados
                      </strong>

                      <p>
                        Se almacenan localmente en
                        %LOCALAPPDATA%\WinCareAI\change-snapshots.json.
                      </p>
                    </div>
                  </section>
                </>
              )}
          </>
        )}
      
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
                  Preparando el Diagnóstico Inteligente
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
      
        {activeView === "evidence" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">MOTOR DE EVIDENCIAS</span>
                <h2>Evidencias avanzadas</h2>
              </div>
              <div className="privacy-badge">
                <span className="privacy-dot" />
                Solo lectura · 100% local
              </div>
            </header>

            <section className="evidence-hero">
              <div>
                <span className="status-label">SNAPSHOT AVANZADO</span>
                <h3>Observá qué datos sustentan el diagnóstico</h3>
                <p>
                  WinCare AI registra indicadores y crea evidencias
                  explicables. Esta etapa no modifica configuraciones
                  de Windows.
                </p>
              </div>
              <div className="evidence-hero-actions">
                <button
                  className="primary-button"
                  onClick={captureAdvancedSnapshot}
                  disabled={advancedSnapshotLoading}
                >
                  {advancedSnapshotLoading
                    ? "Capturando..."
                    : "Capturar estado ahora"}
                </button>
                <button
                  className="secondary-button"
                  onClick={loadAdvancedSnapshots}
                  disabled={advancedSnapshotLoading}
                >
                  Actualizar historial
                </button>
              </div>
            </section>

            {advancedSnapshotError && (
              <section className="evidence-error">
                <strong>No se pudo completar la operación</strong>
                <span>{advancedSnapshotError}</span>
              </section>
            )}

            {!advancedSnapshotLoading &&
              advancedSnapshots.length === 0 && (
                <section className="changes-empty">
                  <div className="changes-empty-icon">◉</div>
                  <span className="status-label">SIN CAPTURAS TODAVÍA</span>
                  <h3>Creá el primer snapshot avanzado</h3>
                  <p>
                    Se observarán CPU, RAM, almacenamiento, procesos
                    e inicio de Windows. Solo se generarán evidencias
                    cuando un indicador supere los umbrales actuales.
                  </p>
                  <button
                    className="primary-button"
                    onClick={captureAdvancedSnapshot}
                  >
                    Capturar estado
                  </button>
                </section>
              )}

            {latestAdvancedSnapshot && (
              <>
                <section className="evidence-summary">
                  <article><span>CPU</span><strong>{latestAdvancedSnapshot.cpu_usage.toFixed(1)}%</strong></article>
                  <article><span>RAM</span><strong>{latestAdvancedSnapshot.ram_usage_percent.toFixed(1)}%</strong></article>
                  <article><span>Disco C:</span><strong>{latestAdvancedSnapshot.disk_usage_percent.toFixed(1)}%</strong></article>
                  <article><span>Procesos</span><strong>{latestAdvancedSnapshot.process_count}</strong></article>
                  <article><span>Pesados</span><strong>{latestAdvancedSnapshot.heavy_processes}</strong></article>
                  <article><span>Inicio activo</span><strong>{latestAdvancedSnapshot.startup_active}</strong></article>
                </section>

                <section className="evidence-current">
                  <div className="evidence-section-heading">
                    <div>
                      <span className="eyebrow">ÚLTIMA CAPTURA</span>
                      <h3>
                        {new Date(
                          latestAdvancedSnapshot.timestamp * 1000,
                        ).toLocaleString("es-AR")}
                      </h3>
                    </div>
                    <div className="evidence-count">
                      <strong>{latestAdvancedSnapshot.evidences.length}</strong>
                      <span>
                        {latestAdvancedSnapshot.evidences.length === 1
                          ? "evidencia"
                          : "evidencias"}
                      </span>
                    </div>
                  </div>

                  {latestAdvancedSnapshot.evidences.length === 0 ? (
                    <div className="evidence-stable">
                      <div className="evidence-stable-icon">✓</div>
                      <div>
                        <strong>
                          Sin evidencias de alerta en esta captura
                        </strong>
                        <p>
                          Los indicadores observados están dentro de
                          los umbrales actuales. WinCare AI no inventa
                          un problema cuando no encuentra evidencia
                          suficiente.
                        </p>
                      </div>
                    </div>
                  ) : (
                    <div className="evidence-list">
                      {latestAdvancedSnapshot.evidences.map((evidence) => (
                        <article
                          className={`evidence-card severity-${evidence.severity}`}
                          key={evidence.id}
                        >
                          <div className="evidence-card-top">
                            <div>
                              <div className="evidence-badges">
                                <span className={`evidence-severity severity-${evidence.severity}`}>
                                  {evidenceSeverityLabel(evidence.severity)}
                                </span>
                                <span>{evidence.category}</span>
                                <span>{evidence.source}</span>
                              </div>
                              <h4>{evidence.title}</h4>
                            </div>
                            <strong className="evidence-value">
                              {evidence.observed_value}
                            </strong>
                          </div>

                          <p>{evidence.explanation}</p>

                          <button
                            className="evidence-detail-button"
                            onClick={() =>
                              setExpandedEvidence(
                                expandedEvidence === evidence.id
                                  ? null
                                  : evidence.id,
                              )
                            }
                          >
                            {expandedEvidence === evidence.id
                              ? "Ocultar datos técnicos"
                              : "Ver datos técnicos"}
                          </button>

                          {expandedEvidence === evidence.id && (
                            <pre className="evidence-technical">
                              {evidence.technical_data}
                            </pre>
                          )}
                        </article>
                      ))}
                    </div>
                  )}
                </section>

                <section className="evidence-history">
                  <div className="evidence-section-heading">
                    <div>
                      <span className="eyebrow">HISTORIAL LOCAL</span>
                      <h3>Snapshots avanzados</h3>
                    </div>
                    <button
                      className="secondary-button"
                      onClick={clearAdvancedSnapshots}
                    >
                      Borrar historial
                    </button>
                  </div>

                  <div className="evidence-history-list">
                    {advancedSnapshots.slice(0, 20).map((snapshot, index) => (
                      <article
                        className="evidence-history-row"
                        key={snapshot.id}
                      >
                        <div>
                          <strong>
                            {index === 0 ? "Actual" : `Snapshot ${index + 1}`}
                          </strong>
                          <small>
                            {new Date(
                              snapshot.timestamp * 1000,
                            ).toLocaleString("es-AR")}
                          </small>
                        </div>
                        <span>CPU {snapshot.cpu_usage.toFixed(0)}%</span>
                        <span>RAM {snapshot.ram_usage_percent.toFixed(0)}%</span>
                        <span>Disco {snapshot.disk_usage_percent.toFixed(0)}%</span>
                        <span>{snapshot.evidences.length} evid.</span>
                      </article>
                    ))}
                  </div>
                </section>
              </>
            )}
          </>
        )}

        {activeView === "cpuAdvanced" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">DIAGNÓSTICO AVANZADO</span>
                <h2>Diagnóstico de CPU</h2>
              </div>
              <div className="privacy-badge">
                <span className="privacy-dot" />
                Solo lectura · 100% local
              </div>
            </header>

            <section className="cpu-advanced-hero">
              <div>
                <span className="status-label">MUESTREO REAL</span>
                <h3>¿La CPU está realmente saturada o fue solo un pico?</h3>
                <p>
                  WinCare AI toma varias muestras consecutivas y analiza
                  los procesos activos para evitar conclusiones basadas
                  en una única lectura instantánea.
                </p>
              </div>
              <button
                className="primary-button"
                onClick={runCpuAdvancedDiagnosis}
                disabled={cpuAdvancedLoading}
              >
                {cpuAdvancedLoading
                  ? "Analizando CPU..."
                  : cpuAdvanced
                    ? "Analizar nuevamente"
                    : "Analizar CPU"}
              </button>
            </section>

            {cpuAdvancedError && (
              <section className="evidence-error">
                <strong>No se pudo analizar la CPU</strong>
                <span>{cpuAdvancedError}</span>
              </section>
            )}

            {!cpuAdvanced && !cpuAdvancedLoading && (
              <section className="changes-empty">
                <div className="changes-empty-icon">CPU</div>
                <span className="status-label">LISTO PARA ANALIZAR</span>
                <h3>Iniciá un muestreo de CPU</h3>
                <p>
                  El análisis dura unos segundos. No detiene procesos,
                  no cambia prioridades y no modifica Windows.
                </p>
                <button
                  className="primary-button"
                  onClick={runCpuAdvancedDiagnosis}
                >
                  Iniciar diagnóstico
                </button>
              </section>
            )}

            {cpuAdvancedLoading && (
              <section className="cpu-sampling">
                <div className="spinner" />
                <div>
                  <strong>Tomando muestras de CPU...</strong>
                  <p>
                    Estamos observando carga sostenida y procesos
                    responsables. No cierres esta pantalla.
                  </p>
                </div>
              </section>
            )}

            {cpuAdvanced && !cpuAdvancedLoading && (
              <>
                <section className="cpu-processor-card">
                  <div>
                    <span className="eyebrow">PROCESADOR DETECTADO</span>
                    <h3>{cpuAdvanced.brand}</h3>
                    <p>
                      {cpuAdvanced.logical_cpus} procesadores lógicos ·{" "}
                      {cpuAdvanced.sample_count} muestras · intervalo{" "}
                      {cpuAdvanced.sample_interval_ms} ms
                    </p>
                  </div>
                  <div className={`cpu-health-badge ${
                    cpuAdvanced.average_usage >= 85
                      ? "critical"
                      : cpuAdvanced.average_usage >= 65
                        ? "warning"
                        : "good"
                  }`}>
                    <strong>{cpuAdvanced.average_usage.toFixed(1)}%</strong>
                    <span>promedio</span>
                  </div>
                </section>

                <section className="cpu-metrics-grid">
                  <article>
                    <span>Uso promedio</span>
                    <strong>{cpuAdvanced.average_usage.toFixed(1)}%</strong>
                    <small>Carga durante todo el muestreo</small>
                  </article>
                  <article>
                    <span>Pico máximo</span>
                    <strong>{cpuAdvanced.peak_usage.toFixed(1)}%</strong>
                    <small>Mayor lectura observada</small>
                  </article>
                  <article>
                    <span>Mínimo</span>
                    <strong>{cpuAdvanced.minimum_usage.toFixed(1)}%</strong>
                    <small>Menor lectura observada</small>
                  </article>
                  <article>
                    <span>Carga sostenida</span>
                    <strong>
                      {cpuAdvanced.sustained_high_samples}/
                      {cpuAdvanced.sample_count}
                    </strong>
                    <small>Muestras iguales o superiores al 80%</small>
                  </article>
                </section>

                <section className="cpu-diagnosis-grid">
                  <article className="cpu-panel">
                    <div className="cpu-panel-heading">
                      <div>
                        <span className="eyebrow">RESPONSABLES</span>
                        <h3>Procesos con mayor uso de CPU</h3>
                      </div>
                      <span className="cpu-panel-count">
                        {cpuAdvanced.top_processes.length}
                      </span>
                    </div>

                    {cpuAdvanced.top_processes.length === 0 ? (
                      <div className="cpu-empty-inline">
                        No se detectaron procesos con consumo relevante.
                      </div>
                    ) : (
                      <div className="cpu-process-list">
                        {cpuAdvanced.top_processes.map((process, index) => (
                          <div className="cpu-process-row" key={`${process.pid}-${process.name}`}>
                            <span className="cpu-process-rank">{index + 1}</span>
                            <div>
                              <strong>{process.name}</strong>
                              <small>PID {process.pid}</small>
                            </div>
                            <strong>{process.cpu_percent.toFixed(1)}%</strong>
                          </div>
                        ))}
                      </div>
                    )}
                  </article>

                  <article className="cpu-panel">
                    <div className="cpu-panel-heading">
                      <div>
                        <span className="eyebrow">EVIDENCIA</span>
                        <h3>Interpretación de WinCare AI</h3>
                      </div>
                      <span className="cpu-panel-count">
                        {cpuAdvanced.evidences.length}
                      </span>
                    </div>

                    {cpuAdvanced.evidences.length === 0 ? (
                      <div className="cpu-good-result">
                        <span>✓</span>
                        <div>
                          <strong>Sin presión anormal de CPU</strong>
                          <p>
                            El muestreo no encontró carga sostenida ni
                            un proceso dominante que supere los umbrales
                            actuales.
                          </p>
                        </div>
                      </div>
                    ) : (
                      <div className="cpu-evidence-list">
                        {cpuAdvanced.evidences.map((evidence) => (
                          <div
                            className={`cpu-evidence-item severity-${evidence.severity}`}
                            key={evidence.id}
                          >
                            <div>
                              <span>{evidence.severity}</span>
                              <strong>{evidence.title}</strong>
                            </div>
                            <b>{evidence.observed_value}</b>
                            <p>{evidence.explanation}</p>
                          </div>
                        ))}
                      </div>
                    )}
                  </article>
                </section>
              </>
            )}
          </>
        )}

        {activeView === "ramAdvanced" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">DIAGNÓSTICO AVANZADO</span>
                <h2>Diagnóstico de RAM</h2>
              </div>
              <div className="privacy-badge">
                <span className="privacy-dot" />
                Solo lectura · 100% local
              </div>
            </header>

            <section className="cpu-advanced-hero">
              <div>
                <span className="status-label">MEMORIA FÍSICA Y VIRTUAL</span>
                <h3>¿La memoria disponible alcanza para la carga actual?</h3>
                <p>
                  WinCare AI analiza la presión de RAM, el uso de memoria
                  virtual y los procesos que concentran memoria para
                  distinguir falta de capacidad de un consumo puntual.
                </p>
              </div>
              <button
                className="primary-button"
                onClick={runRamAdvancedDiagnosis}
                disabled={ramAdvancedLoading}
              >
                {ramAdvancedLoading
                  ? "Analizando RAM..."
                  : ramAdvanced
                    ? "Analizar nuevamente"
                    : "Analizar RAM"}
              </button>
            </section>

            {ramAdvancedError && (
              <section className="evidence-error">
                <strong>No se pudo analizar la RAM</strong>
                <span>{ramAdvancedError}</span>
              </section>
            )}

            {!ramAdvanced && !ramAdvancedLoading && (
              <section className="changes-empty">
                <div className="changes-empty-icon">RAM</div>
                <span className="status-label">LISTO PARA ANALIZAR</span>
                <h3>Iniciá el diagnóstico de memoria</h3>
                <p>
                  La lectura es local y no cierra aplicaciones,
                  no libera memoria automáticamente y no modifica Windows.
                </p>
                <button className="primary-button" onClick={runRamAdvancedDiagnosis}>
                  Iniciar diagnóstico
                </button>
              </section>
            )}

            {ramAdvancedLoading && (
              <section className="cpu-sampling">
                <div className="spinner" />
                <div>
                  <strong>Analizando memoria...</strong>
                  <p>Revisando RAM física, memoria virtual y procesos activos.</p>
                </div>
              </section>
            )}

            {ramAdvanced && !ramAdvancedLoading && (
              <>
                <section className="cpu-processor-card">
                  <div>
                    <span className="eyebrow">MEMORIA DEL SISTEMA</span>
                    <h3>{formatBytes(ramAdvanced.total_bytes)} instalados</h3>
                    <p>
                      {formatBytes(ramAdvanced.used_bytes)} en uso ·{" "}
                      {formatBytes(ramAdvanced.available_bytes)} disponibles ·{" "}
                      {ramAdvanced.process_count} procesos
                    </p>
                  </div>
                  <div className={`cpu-health-badge ${
                    ramAdvanced.usage_percent >= 90
                      ? "critical"
                      : ramAdvanced.usage_percent >= 75
                        ? "warning"
                        : "good"
                  }`}>
                    <strong>{ramAdvanced.usage_percent.toFixed(1)}%</strong>
                    <span>RAM en uso</span>
                  </div>
                </section>

                <section className="cpu-metrics-grid">
                  <article>
                    <span>RAM usada</span>
                    <strong>{formatBytes(ramAdvanced.used_bytes)}</strong>
                    <small>{ramAdvanced.usage_percent.toFixed(1)}% de la memoria física</small>
                  </article>
                  <article>
                    <span>Disponible</span>
                    <strong>{formatBytes(ramAdvanced.available_bytes)}</strong>
                    <small>Memoria disponible para nuevas cargas</small>
                  </article>
                  <article>
                    <span>Memoria virtual</span>
                    <strong>{formatBytes(ramAdvanced.swap_used_bytes)}</strong>
                    <small>{ramAdvanced.swap_usage_percent.toFixed(1)}% del swap en uso</small>
                  </article>
                  <article>
                    <span>Procesos +500 MB</span>
                    <strong>{ramAdvanced.processes_over_500mb}</strong>
                    <small>Aplicaciones con consumo individual elevado</small>
                  </article>
                </section>

                <section className="cpu-diagnosis-grid">
                  <article className="cpu-panel">
                    <div className="cpu-panel-heading">
                      <div>
                        <span className="eyebrow">RESPONSABLES</span>
                        <h3>Procesos con mayor uso de RAM</h3>
                      </div>
                      <span className="cpu-panel-count">{ramAdvanced.top_processes.length}</span>
                    </div>

                    {ramAdvanced.top_processes.length === 0 ? (
                      <div className="cpu-empty-inline">
                        No se detectaron procesos con consumo de memoria relevante.
                      </div>
                    ) : (
                      <div className="cpu-process-list">
                        {ramAdvanced.top_processes.map((process, index) => (
                          <div className="cpu-process-row" key={`${process.pid}-${process.name}`}>
                            <span className="cpu-process-rank">{index + 1}</span>
                            <div>
                              <strong>{process.name}</strong>
                              <small>PID {process.pid} · {process.memory_percent.toFixed(1)}%</small>
                            </div>
                            <strong>{formatBytes(process.memory_bytes)}</strong>
                          </div>
                        ))}
                      </div>
                    )}
                  </article>

                  <article className="cpu-panel">
                    <div className="cpu-panel-heading">
                      <div>
                        <span className="eyebrow">EVIDENCIA</span>
                        <h3>Interpretación de WinCare AI</h3>
                      </div>
                      <span className="cpu-panel-count">{ramAdvanced.evidences.length}</span>
                    </div>

                    {ramAdvanced.evidences.length === 0 ? (
                      <div className="cpu-good-result">
                        <span>✓</span>
                        <div>
                          <strong>Sin presión anormal de memoria</strong>
                          <p>
                            La lectura actual no supera los umbrales de presión
                            configurados y no aparece un proceso dominante.
                          </p>
                        </div>
                      </div>
                    ) : (
                      <div className="cpu-evidence-list">
                        {ramAdvanced.evidences.map((evidence) => (
                          <div
                            className={`cpu-evidence-item severity-${evidence.severity}`}
                            key={evidence.id}
                          >
                            <div>
                              <span>{evidence.severity}</span>
                              <strong>{evidence.title}</strong>
                            </div>
                            <b>{evidence.observed_value}</b>
                            <p>{evidence.explanation}</p>
                          </div>
                        ))}
                      </div>
                    )}
                  </article>
                </section>
              </>
            )}
          </>
        )}

        {activeView === "storageAdvanced" && (<>
          <header className="topbar"><div><span className="eyebrow">DIAGNÓSTICO AVANZADO</span><h2>Diagnóstico de almacenamiento</h2></div><div className="privacy-badge"><span className="privacy-dot"/>Solo lectura · 100% local</div></header>
          <section className="cpu-advanced-hero"><div><span className="status-label">ALMACENAMIENTO Y SALUD FÍSICA</span><h3>¿El almacenamiento está sano y tiene margen suficiente?</h3><p>WinCare AI combina espacio disponible, TRIM, volúmenes y la información física que Windows expone sobre SSD, NVMe y discos.</p></div><button className="primary-button" onClick={runStorageAdvancedDiagnosis} disabled={storageAdvancedLoading}>{storageAdvancedLoading?"Analizando almacenamiento...":storageAdvanced?"Analizar nuevamente":"Analizar almacenamiento"}</button></section>
          {storageAdvancedError&&<section className="evidence-error"><strong>No se pudo analizar el almacenamiento</strong><span>{storageAdvancedError}</span></section>}
          {!storageAdvanced&&!storageAdvancedLoading&&<section className="changes-empty"><div className="changes-empty-icon">SSD</div><span className="status-label">LISTO PARA ANALIZAR</span><h3>Iniciá el diagnóstico de almacenamiento</h3><p>No borra archivos, no optimiza unidades y no modifica TRIM ni Windows.</p><button className="primary-button" onClick={runStorageAdvancedDiagnosis}>Iniciar diagnóstico</button></section>}
          {storageAdvancedLoading&&<section className="cpu-sampling"><div className="spinner"/><div><strong>Consultando almacenamiento...</strong><p>Revisando volúmenes, TRIM y datos físicos disponibles.</p></div></section>}
          {storageAdvanced&&!storageAdvancedLoading&&<>
            <section className="cpu-processor-card"><div><span className="eyebrow">ALMACENAMIENTO DETECTADO</span><h3>{storageAdvanced.volume_count} volúmenes</h3><p>{formatBytes(storageAdvanced.total_bytes)} totales · {formatBytes(storageAdvanced.available_bytes)} disponibles</p></div><div className={`cpu-health-badge ${storageAdvanced.usage_percent>=95?"critical":storageAdvanced.usage_percent>=85?"warning":"good"}`}><strong>{storageAdvanced.usage_percent.toFixed(1)}%</strong><span>ocupado</span></div></section>
            <section className="cpu-metrics-grid">
              <article><span>Espacio usado</span><strong>{formatBytes(storageAdvanced.used_bytes)}</strong><small>{storageAdvanced.usage_percent.toFixed(1)}% del total</small></article>
              <article><span>Disponible</span><strong>{formatBytes(storageAdvanced.available_bytes)}</strong><small>Margen libre detectado</small></article>
              <article><span>TRIM</span><strong>{!storageAdvanced.trim_query_available?"No disponible":storageAdvanced.trim_enabled===true?"Habilitado":storageAdvanced.trim_enabled===false?"Deshabilitado":"Sin determinar"}</strong><small>Estado informado por Windows</small></article>
              <article><span>Discos físicos</span><strong>{storageAdvanced.physical_disks_available?storageAdvanced.physical_disks.length:"No disponible"}</strong><small>Información física expuesta</small></article>
            </section>
            <section className="cpu-diagnosis-grid">
              <article className="cpu-panel"><div className="cpu-panel-heading"><div><span className="eyebrow">VOLÚMENES</span><h3>Uso del almacenamiento</h3></div><span className="cpu-panel-count">{storageAdvanced.volumes.length}</span></div><div className="storage-volume-list">{storageAdvanced.volumes.map(v=><div className="storage-volume-row" key={`${v.mount_point}-${v.name}`}><div><strong>{v.mount_point||v.name}</strong><small>{v.file_system||"Sistema de archivos no disponible"}{v.removable?" · Extraíble":""}</small></div><div><strong>{v.usage_percent.toFixed(1)}%</strong><small>{formatBytes(v.available_bytes)} libres de {formatBytes(v.total_bytes)}</small></div></div>)}</div></article>
              <article className="cpu-panel"><div className="cpu-panel-heading"><div><span className="eyebrow">SALUD FÍSICA</span><h3>Discos detectados por Windows</h3></div><span className="cpu-panel-count">{storageAdvanced.physical_disks.length}</span></div>{!storageAdvanced.physical_disks_available?<div className="cpu-empty-inline">Datos físicos no disponibles{storageAdvanced.physical_disks_error?` · ${storageAdvanced.physical_disks_error}`:""}</div>:<div className="storage-disk-list">{storageAdvanced.physical_disks.map((d,i)=><div className="storage-disk-card" key={`${d.friendly_name}-${i}`}><div><strong>{d.friendly_name}</strong><small>{d.media_type} · {d.bus_type} · {formatBytes(d.size_bytes)}</small></div><div className="storage-disk-facts"><span>Salud: <b>{d.health_status||"No disponible"}</b></span><span>Temperatura: <b>{d.temperature_celsius==null?"No disponible":`${d.temperature_celsius.toFixed(0)} °C`}</b></span><span>Desgaste: <b>{d.wear_percent==null?"No disponible":`${d.wear_percent.toFixed(0)}%`}</b></span><span>Horas: <b>{d.power_on_hours==null?"No disponible":d.power_on_hours.toLocaleString()}</b></span></div></div>)}</div>}</article>
            </section>
            <section className="cpu-panel storage-evidence-panel"><div className="cpu-panel-heading"><div><span className="eyebrow">EVIDENCIA</span><h3>Interpretación de WinCare AI</h3></div><span className="cpu-panel-count">{storageAdvanced.evidences.length}</span></div>{storageAdvanced.evidences.length===0?<div className="cpu-good-result"><span>✓</span><div><strong>Sin alertas de almacenamiento</strong><p>Los datos no expuestos por el hardware se consideran no disponibles, no fallos.</p></div></div>:<div className="cpu-evidence-list">{storageAdvanced.evidences.map(e=><div className={`cpu-evidence-item severity-${e.severity}`} key={e.id}><div><span>{e.severity}</span><strong>{e.title}</strong></div><b>{e.observed_value}</b><p>{e.explanation}</p></div>)}</div>}</section>
          </>}
        </>)}

        {activeView === "startupAdvanced" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">DIAGNÓSTICO AVANZADO</span>
                <h2>Diagnóstico de inicio</h2>
              </div>
              <div className="privacy-badge">
                <span className="privacy-dot" />
                Solo lectura · 100% local
              </div>
            </header>

            <section className="cpu-advanced-hero">
              <div>
                <span className="status-label">ARRANQUE E INICIO DE SESIÓN</span>
                <h3>¿Qué carga Windows automáticamente al iniciar?</h3>
                <p>
                  WinCare AI revisa programas configurados para iniciar con Windows
                  y tareas programadas asociadas al arranque o inicio de sesión.
                </p>
              </div>
              <button
                className="primary-button"
                onClick={runStartupAdvancedDiagnosis}
                disabled={startupAdvancedLoading}
              >
                {startupAdvancedLoading
                  ? "Analizando inicio..."
                  : startupAdvanced
                    ? "Analizar nuevamente"
                    : "Analizar inicio"}
              </button>
            </section>

            {startupActionMessage && (
              <section className="startup-action-feedback success">
                <strong>Cambio aplicado</strong>
                <span>{startupActionMessage}</span>
              </section>
            )}

            {startupActionError && (
              <section className="startup-action-feedback error">
                <strong>No se pudo aplicar el cambio</strong>
                <span>{startupActionError}</span>
              </section>
            )}
            {startupAdvancedError && (
              <section className="evidence-error">
                <strong>No se pudo analizar el inicio</strong>
                <span>{startupAdvancedError}</span>
              </section>
            )}

            {!startupAdvanced && !startupAdvancedLoading && (
              <section className="changes-empty">
                <div className="changes-empty-icon">▶</div>
                <span className="status-label">LISTO PARA ANALIZAR</span>
                <h3>Iniciá el diagnóstico de arranque</h3>
                <p>
                  Esta lectura no deshabilita programas, servicios ni tareas
                  programadas. Primero reúne evidencia para poder decidir.
                </p>
                <button className="primary-button" onClick={runStartupAdvancedDiagnosis}>
                  Iniciar diagnóstico
                </button>
              </section>
            )}

            {startupAdvancedLoading && (
              <section className="cpu-sampling">
                <div className="spinner" />
                <div>
                  <strong>Revisando el inicio de Windows...</strong>
                  <p>Consultando programas de inicio y tareas Boot/Logon.</p>
                </div>
              </section>
            )}

            {startupAdvanced && !startupAdvancedLoading && (
              <>
                <section className="cpu-processor-card">
                  <div>
                    <span className="eyebrow">CARGA DE INICIO</span>
                    <h3>
                      {startupAdvanced.startup_count +
                        startupAdvanced.scheduled_task_count}{" "}
                      elementos detectados
                    </h3>
                    <p>
                      {startupAdvanced.startup_count} programas ·{" "}
                      {startupAdvanced.scheduled_task_count} tareas de arranque/login
                    </p>
                  </div>
                  <div
                    className={`cpu-health-badge ${
                      startupAdvanced.startup_count >= 20
                        ? "warning"
                        : startupAdvanced.startup_count >= 12
                          ? "warning"
                          : "good"
                    }`}
                  >
                    <strong>{startupAdvanced.startup_count}</strong>
                    <span>programas</span>
                  </div>
                </section>

                <section className="cpu-metrics-grid">
                  <article>
                    <span>Programas de inicio</span>
                    <strong>{startupAdvanced.startup_count}</strong>
                    <small>Registrados por Windows</small>
                  </article>
                  <article>
                    <span>Tareas Boot / Logon</span>
                    <strong>{startupAdvanced.scheduled_task_count}</strong>
                    <small>Disparadas al arrancar o iniciar sesión</small>
                  </article>
                  <article>
                    <span>Consulta</span>
                    <strong>
                      {startupAdvanced.query_available ? "Disponible" : "Parcial"}
                    </strong>
                    <small>Lectura local del sistema</small>
                  </article>
                  <article>
                    <span>Acciones realizadas</span>
                    <strong>{startupActionHistory.length}</strong>
                    <small>Cambios registrados por WinCare AI</small>
                  </article>
                </section>

                {!startupAdvanced.query_available && startupAdvanced.query_error && (
                  <section className="startup-query-note">
                    <strong>Información parcial</strong>
                    <span>{startupAdvanced.query_error}</span>
                  </section>
                )}

                <section className="cpu-diagnosis-grid">
                  <article className="cpu-panel">
                    <div className="cpu-panel-heading">
                      <div>
                        <span className="eyebrow">PROGRAMAS</span>
                        <h3>Inicio automático</h3>
                      </div>
                      <span className="cpu-panel-count">
                        {startupAdvanced.startup_items.length}
                      </span>
                    </div>

                    <div className="startup-action-safety">
                      <strong>Acciones protegidas</strong>
                      <span>
                        En esta primera versión, WinCare AI solo permite desactivar
                        entradas HKCU Run del usuario actual. Antes del cambio crea
                        un respaldo local. El resto permanece en solo lectura.
                      </span>
                    </div>
                    {startupAdvanced.startup_items.length === 0 ? (
                      <div className="cpu-empty-inline">
                        No se detectaron programas de inicio en esta lectura.
                      </div>
                    ) : (
                      <div className="startup-advanced-list">
                        {startupAdvanced.startup_items.map((item, index) => (
                          <div
                            className="startup-advanced-row"
                            key={`${item.name}-${item.location}-${index}`}
                          >
                            <div className="startup-advanced-main">
                              <strong>{item.name}</strong>
                              <small>{item.command || "Comando no disponible"}</small>
                            </div>
                            <div className="startup-advanced-meta">
                              <span>{item.location || "Ubicación no disponible"}</span>
                              <small>{item.user || "Usuario no disponible"}</small>
                              {startupAdvancedIsActionable(item.location) ? (
                                <button
                                  className="startup-action-button danger"
                                  disabled={
                                    startupActionBusy ===
                                    `${item.name}|${item.location}`
                                  }
                                  onClick={() =>
                                    setStartupConfirmAction({
                                      mode: "disable",
                                      item,
                                    })
                                  }
                                >
                                  {startupActionBusy ===
                                  `${item.name}|${item.location}`
                                    ? "Aplicando..."
                                    : "Desactivar"}
                                </button>
                              ) : (
                                <span className="startup-action-protected">
                                  Solo lectura
                                </span>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </article>

                  <article className="cpu-panel">
                    <div className="cpu-panel-heading">
                      <div>
                        <span className="eyebrow">TAREAS PROGRAMADAS</span>
                        <h3>Arranque e inicio de sesión</h3>
                      </div>
                      <span className="cpu-panel-count">
                        {startupAdvanced.scheduled_tasks.length}
                      </span>
                    </div>

                    {startupAdvanced.scheduled_tasks.length === 0 ? (
                      <div className="cpu-empty-inline">
                        No se detectaron tareas Boot/Logon en esta lectura.
                      </div>
                    ) : (
                      <div className="startup-advanced-list">
                        {startupAdvanced.scheduled_tasks.map((task, index) => (
                          <div
                            className="startup-task-row"
                            key={`${task.task_path}-${task.task_name}-${index}`}
                          >
                            <div>
                              <strong>{task.task_name}</strong>
                              <small>
                                {task.task_path || "Ruta no disponible"}
                              </small>
                            </div>
                            <div className="startup-task-meta">
                              <span>{task.state || "Estado no disponible"}</span>
                              <small>{task.triggers || "Trigger no disponible"}</small>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </article>
                </section>

                <section className="cpu-panel startup-disabled-panel">
                  <div className="cpu-panel-heading">
                    <div>
                      <span className="eyebrow">REVERSIÓN</span>
                      <h3>Desactivados por WinCare AI</h3>
                    </div>
                    <span className="cpu-panel-count">{startupDisabledItems.length}</span>
                  </div>
                  {startupDisabledItems.length===0 ? (
                    <div className="cpu-empty-inline">
                      Todavía no hay elementos desactivados por WinCare AI.
                    </div>
                  ) : (
                    <div className="startup-disabled-list">
                      {startupDisabledItems.map(item=>(
                        <div className="startup-disabled-row" key={item.id}>
                          <div>
                            <strong>{item.name}</strong>
                            <small>{item.backup_type==="startup_folder"?"Carpeta Startup":"Registro HKCU Run"} · respaldo local</small>
                          </div>
                          <button
                            className="startup-action-button restore"
                            disabled={startupActionBusy===`restore|${item.id}`}
                            onClick={() =>
                              setStartupConfirmAction({
                                mode: "restore",
                                item,
                              })
                            }
                          >
                            {startupActionBusy===`restore|${item.id}`?"Restaurando...":"Reactivar"}
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </section>
                <section className="cpu-panel startup-evidence-panel">
                  <div className="cpu-panel-heading">
                    <div>
                      <span className="eyebrow">EVIDENCIA</span>
                      <h3>Interpretación de WinCare AI</h3>
                    </div>
                    <span className="cpu-panel-count">
                      {startupAdvanced.evidences.length}
                    </span>
                  </div>

                  {startupAdvanced.evidences.length === 0 ? (
                    <div className="cpu-good-result">
                      <span>✓</span>
                      <div>
                        <strong>Sin alertas por cantidad de elementos</strong>
                        <p>
                          WinCare AI no encontró una carga de inicio que supere los
                          umbrales actuales. Esto no clasifica aplicaciones
                          individuales como necesarias o innecesarias.
                        </p>
                      </div>
                    </div>
                  ) : (
                    <div className="cpu-evidence-list">
                      {startupAdvanced.evidences.map((evidence) => (
                        <div
                          className={`cpu-evidence-item severity-${evidence.severity}`}
                          key={evidence.id}
                        >
                          <div>
                            <span>{evidence.severity}</span>
                            <strong>{evidence.title}</strong>
                          </div>
                          <b>{evidence.observed_value}</b>
                          <p>{evidence.explanation}</p>
                        </div>
                      ))}
                    </div>
                  )}
                </section>
              </>
            )}
          </>
        )}

        {activeView === "networkAdvanced" && (
          <>
            <header className="topbar">
              <div>
                <span className="eyebrow">DIAGNÓSTICO AVANZADO</span>
                <h2>Diagnóstico de red</h2>
              </div>
              <div className="privacy-badge">
                <span className="privacy-dot" />
                Solo lectura · 100% local
              </div>
            </header>

            <section className="cpu-advanced-hero">
              <div>
                <span className="status-label">CONECTIVIDAD Y CONFIGURACIÓN</span>
                <h3>¿El problema está en la PC, la red local o Internet?</h3>
                <p>
                  WinCare AI revisa adaptadores, IP, gateway, DNS y realiza
                  pruebas básicas de conectividad para reunir evidencia.
                </p>
              </div>
              <button
                className="primary-button"
                onClick={runNetworkAdvancedDiagnosis}
                disabled={networkAdvancedLoading}
              >
                {networkAdvancedLoading
                  ? "Analizando red..."
                  : networkAdvanced
                    ? "Analizar nuevamente"
                    : "Analizar red"}
              </button>
            </section>

            {networkAdvancedError && (
              <section className="evidence-error">
                <strong>No se pudo analizar la red</strong>
                <span>{networkAdvancedError}</span>
              </section>
            )}

            {!networkAdvanced && !networkAdvancedLoading && (
              <section className="changes-empty">
                <div className="changes-empty-icon">NET</div>
                <span className="status-label">LISTO PARA ANALIZAR</span>
                <h3>Iniciá el diagnóstico de red</h3>
                <p>
                  No cambia DNS, direcciones IP, firewall, Wi-Fi ni adaptadores.
                  Las pruebas de conectividad son muestras puntuales.
                </p>
                <button className="primary-button" onClick={runNetworkAdvancedDiagnosis}>
                  Iniciar diagnóstico
                </button>
              </section>
            )}

            {networkAdvancedLoading && (
              <section className="cpu-sampling">
                <div className="spinner" />
                <div>
                  <strong>Analizando conectividad...</strong>
                  <p>Consultando adaptadores, gateway, DNS e Internet.</p>
                </div>
              </section>
            )}

            {networkAdvanced && !networkAdvancedLoading && (
              <>
                <section className="cpu-processor-card">
                  <div>
                    <span className="eyebrow">ESTADO DE RED</span>
                    <h3>
                      {networkAdvanced.active_adapter_count > 0
                        ? `${networkAdvanced.active_adapter_count} adaptador(es) activo(s)`
                        : "Sin adaptadores activos"}
                    </h3>
                    <p>
                      Internet por IP:{" "}
                      {networkAdvanced.internet_reachable ? "responde" : "sin respuesta"} ·
                      DNS/nombre: {networkAdvanced.dns_reachable ? "responde" : "sin respuesta"}
                    </p>
                  </div>
                  <div
                    className={`cpu-health-badge ${
                      networkAdvanced.internet_reachable &&
                      networkAdvanced.dns_reachable
                        ? "good"
                        : networkAdvanced.active_adapter_count === 0
                          ? "critical"
                          : "warning"
                    }`}
                  >
                    <strong>
                      {networkAdvanced.internet_reachable &&
                      networkAdvanced.dns_reachable
                        ? "OK"
                        : "REVISAR"}
                    </strong>
                    <span>conectividad</span>
                  </div>
                </section>

                <section className="cpu-metrics-grid">
                  <article>
                    <span>Gateway</span>
                    <strong>
                      {networkAdvanced.gateway_reachable ? "Responde" : "Sin respuesta"}
                    </strong>
                    <small>
                      {networkAdvanced.gateway_latency_ms == null
                        ? "Latencia no disponible"
                        : `${networkAdvanced.gateway_latency_ms.toFixed(0)} ms`}
                    </small>
                  </article>
                  <article>
                    <span>Internet por IP</span>
                    <strong>
                      {networkAdvanced.internet_reachable ? "Responde" : "Sin respuesta"}
                    </strong>
                    <small>
                      {networkAdvanced.internet_latency_ms == null
                        ? "Latencia no disponible"
                        : `${networkAdvanced.internet_latency_ms.toFixed(0)} ms`}
                    </small>
                  </article>
                  <article>
                    <span>Prueba por nombre</span>
                    <strong>
                      {networkAdvanced.dns_reachable ? "Responde" : "Sin respuesta"}
                    </strong>
                    <small>
                      {networkAdvanced.dns_latency_ms == null
                        ? "Latencia no disponible"
                        : `${networkAdvanced.dns_latency_ms.toFixed(0)} ms`}
                    </small>
                  </article>
                  <article>
                    <span>Adaptadores activos</span>
                    <strong>{networkAdvanced.active_adapter_count}</strong>
                    <small>{networkAdvanced.adapters.length} configurados/detectados</small>
                  </article>
                </section>

                {!networkAdvanced.query_available && networkAdvanced.query_error && (
                  <section className="network-query-note">
                    <strong>Información parcial</strong>
                    <span>{networkAdvanced.query_error}</span>
                  </section>
                )}

                <section className="cpu-panel">
                  <div className="cpu-panel-heading">
                    <div>
                      <span className="eyebrow">ADAPTADORES</span>
                      <h3>Configuración detectada</h3>
                    </div>
                    <span className="cpu-panel-count">
                      {networkAdvanced.adapters.length}
                    </span>
                  </div>

                  {networkAdvanced.adapters.length === 0 ? (
                    <div className="cpu-empty-inline">
                      No se detectaron adaptadores en esta lectura.
                    </div>
                  ) : (
                    <div className="network-adapter-list">
                      {networkAdvanced.adapters.map((adapter, index) => (
                        <div
                          className="network-adapter-card"
                          key={`${adapter.name}-${index}`}
                        >
                          <div className="network-adapter-title">
                            <div>
                              <strong>{adapter.name}</strong>
                              <small>
                                {adapter.description || "Descripción no disponible"}
                              </small>
                            </div>
                            <span
                              className={`network-status ${
                                adapter.status.toLowerCase() === "up"
                                  ? "good"
                                  : "neutral"
                              }`}
                            >
                              {adapter.status || "No disponible"}
                            </span>
                          </div>

                          <div className="network-facts">
                            <span>
                              Velocidad: <b>{adapter.link_speed || "No disponible"}</b>
                            </span>
                            <span>
                              IPv4:{" "}
                              <b>
                                {adapter.ipv4.length
                                  ? adapter.ipv4.join(", ")
                                  : "No disponible"}
                              </b>
                            </span>
                            <span>
                              Gateway:{" "}
                              <b>
                                {adapter.gateways.length
                                  ? adapter.gateways.join(", ")
                                  : "No disponible"}
                              </b>
                            </span>
                            <span>
                              DNS:{" "}
                              <b>
                                {adapter.dns_servers.length
                                  ? adapter.dns_servers.join(", ")
                                  : "No disponible"}
                              </b>
                            </span>
                            <span>
                              DHCP: <b>{adapter.dhcp_enabled ? "Sí" : "No"}</b>
                            </span>
                            <span>
                              MAC: <b>{adapter.mac_address || "No disponible"}</b>
                            </span>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </section>

                <section className="cpu-panel network-evidence-panel">
                  <div className="cpu-panel-heading">
                    <div>
                      <span className="eyebrow">EVIDENCIA</span>
                      <h3>Interpretación de WinCare AI</h3>
                    </div>
                    <span className="cpu-panel-count">
                      {networkAdvanced.evidences.length}
                    </span>
                  </div>

                  {networkAdvanced.evidences.length === 0 ? (
                    <div className="cpu-good-result">
                      <span>✓</span>
                      <div>
                        <strong>Sin alertas de red en esta muestra</strong>
                        <p>
                          Las pruebas actuales no superaron los umbrales de alerta.
                          Una prueba de ping aislada no sustituye una medición
                          prolongada de calidad de conexión.
                        </p>
                      </div>
                    </div>
                  ) : (
                    <div className="cpu-evidence-list">
                      {networkAdvanced.evidences.map((evidence) => (
                        <div
                          className={`cpu-evidence-item severity-${evidence.severity}`}
                          key={evidence.id}
                        >
                          <div>
                            <span>{evidence.severity}</span>
                            <strong>{evidence.title}</strong>
                          </div>
                          <b>{evidence.observed_value}</b>
                          <p>{evidence.explanation}</p>
                        </div>
                      ))}
                    </div>
                  )}
                </section>
              </>
            )}
          </>
        )}

        {activeView === "windowsAdvanced" && (<>
          <header className="topbar"><div><span className="eyebrow">DIAGNÓSTICO AVANZADO</span><h2>Diagnóstico de Windows</h2></div><div className="privacy-badge"><span className="privacy-dot"/>Solo lectura · 100% local</div></header>
          <section className="cpu-advanced-hero"><div><span className="status-label">ESTABILIDAD DEL SISTEMA</span><h3>¿Windows muestra señales que conviene revisar?</h3><p>WinCare AI reúne uptime, reinicios pendientes, Windows Update y eventos críticos o errores recientes del registro System.</p></div><button className="primary-button" onClick={runWindowsAdvancedDiagnosis} disabled={windowsAdvancedLoading}>{windowsAdvancedLoading?"Analizando Windows...":windowsAdvanced?"Analizar nuevamente":"Analizar Windows"}</button></section>
          {windowsAdvancedError&&<section className="evidence-error"><strong>No se pudo analizar Windows</strong><span>{windowsAdvancedError}</span></section>}
          {!windowsAdvanced&&!windowsAdvancedLoading&&<section className="changes-empty"><div className="changes-empty-icon">WIN</div><span className="status-label">LISTO PARA ANALIZAR</span><h3>Iniciá el diagnóstico de Windows</h3><p>No instala actualizaciones, no ejecuta reparaciones y no reinicia el equipo.</p><button className="primary-button" onClick={runWindowsAdvancedDiagnosis}>Iniciar diagnóstico</button></section>}
          {windowsAdvancedLoading&&<section className="cpu-sampling"><div className="spinner"/><div><strong>Consultando Windows...</strong><p>Revisando estabilidad, mantenimiento pendiente y eventos recientes.</p></div></section>}
          {windowsAdvanced&&!windowsAdvancedLoading&&<>
            <section className="cpu-processor-card"><div><span className="eyebrow">ESTADO DEL SISTEMA</span><h3>{windowsAdvanced.reboot_pending?"Reinicio pendiente detectado":"Sin reinicio pendiente detectado"}</h3><p>Último arranque: {windowsAdvanced.last_boot?new Date(windowsAdvanced.last_boot).toLocaleString():"No disponible"}</p></div><div className={`cpu-health-badge ${windowsAdvanced.recent_system_critical_count>0?"critical":windowsAdvanced.reboot_pending||windowsAdvanced.recent_system_error_count>=10?"warning":"good"}`}><strong>{windowsAdvanced.recent_system_critical_count>0?"REVISAR":"OK"}</strong><span>estado</span></div></section>
            <section className="cpu-metrics-grid">
              <article><span>Uptime</span><strong>{windowsAdvanced.uptime_hours<24?`${windowsAdvanced.uptime_hours.toFixed(1)} h`:`${(windowsAdvanced.uptime_hours/24).toFixed(1)} días`}</strong><small>Tiempo desde el último arranque</small></article>
              <article><span>Actualizaciones</span><strong>{windowsAdvanced.pending_updates_available?windowsAdvanced.pending_update_count:"No disponible"}</strong><small>{windowsAdvanced.pending_updates_available?"Pendientes detectadas":"Consulta no disponible"}</small></article>
              <article><span>Eventos críticos</span><strong>{windowsAdvanced.recent_system_critical_count}</strong><small>Registro System · últimas 24 h</small></article>
              <article><span>Errores</span><strong>{windowsAdvanced.recent_system_error_count}</strong><small>Registro System · últimas 24 h</small></article>
            </section>
            <section className="windows-status-grid">
              <article className="cpu-panel"><div className="cpu-panel-heading"><div><span className="eyebrow">MANTENIMIENTO</span><h3>Estado de Windows</h3></div></div>
                <div className="windows-fact-list">
                  <div><span>Reinicio pendiente</span><strong>{windowsAdvanced.reboot_pending?"Sí":"No"}</strong></div>
                  <div><span>Windows Update</span><strong>{windowsAdvanced.update_service_status||"No disponible"}</strong></div>
                  <div><span>Consulta de actualizaciones</span><strong>{windowsAdvanced.pending_updates_available?"Disponible":"No disponible"}</strong></div>
                  <div><span>Motivos de reinicio</span><strong>{windowsAdvanced.reboot_reasons.length?windowsAdvanced.reboot_reasons.join(", "):"Ninguno detectado"}</strong></div>
                </div>
              </article>
              <article className="cpu-panel"><div className="cpu-panel-heading"><div><span className="eyebrow">EVIDENCIA</span><h3>Interpretación de WinCare AI</h3></div><span className="cpu-panel-count">{windowsAdvanced.evidences.length}</span></div>
                {windowsAdvanced.evidences.length===0?<div className="cpu-good-result"><span>✓</span><div><strong>Sin alertas relevantes en esta lectura</strong><p>No se superaron los umbrales actuales de estabilidad y mantenimiento.</p></div></div>:<div className="cpu-evidence-list">{windowsAdvanced.evidences.map(e=><div className={`cpu-evidence-item severity-${e.severity}`} key={e.id}><div><span>{e.severity}</span><strong>{e.title}</strong></div><b>{e.observed_value}</b><p>{e.explanation}</p></div>)}</div>}
              </article>
            </section>
            <section className="cpu-panel windows-events-panel"><div className="cpu-panel-heading"><div><span className="eyebrow">REGISTRO SYSTEM</span><h3>Eventos críticos y errores recientes</h3></div><span className="cpu-panel-count">{windowsAdvanced.recent_events.length}</span></div>
              {windowsAdvanced.recent_events.length===0?<div className="cpu-empty-inline">No se recuperaron eventos críticos/error de las últimas 24 horas.</div>:<div className="windows-event-list">{windowsAdvanced.recent_events.map((event,index)=><div className="windows-event-row" key={`${event.time_created}-${event.provider}-${event.event_id}-${index}`}><div className="windows-event-head"><div><strong>{event.provider||"Proveedor no disponible"}</strong><small>{event.time_created?new Date(event.time_created).toLocaleString():"Fecha no disponible"} · ID {event.event_id}</small></div><span className={`windows-event-level ${event.level.toLowerCase().includes("critical")||event.level.toLowerCase().includes("crít")?"critical":"error"}`}>{event.level}</span></div><p>{event.message||"Windows no proporcionó una descripción para este evento."}</p></div>)}</div>}
            </section>
            {!windowsAdvanced.query_available&&windowsAdvanced.query_error&&<section className="windows-query-note"><strong>Información parcial</strong><span>{windowsAdvanced.query_error}</span></section>}
          </>}
        </>)}
        {startupConfirmAction && (
          <div
            className="wincare-modal-backdrop"
            onMouseDown={(event) => {
              if (
                event.target === event.currentTarget &&
                !startupActionBusy
              ) {
                setStartupConfirmAction(null);
              }
            }}
          >
            <section
              className="wincare-confirm-modal"
              role="dialog"
              aria-modal="true"
              aria-labelledby="startup-confirm-title"
            >
              <div
                className={`wincare-confirm-icon ${startupConfirmAction.mode}`}
              >
                {startupConfirmAction.mode === "disable" ? "!" : "↻"}
              </div>

              <span className="eyebrow">
                {startupConfirmAction.mode === "disable"
                  ? "CAMBIO REVERSIBLE"
                  : "RESTAURACIÓN"}
              </span>

              <h3 id="startup-confirm-title">
                {startupConfirmAction.mode === "disable"
                  ? `¿Desactivar "${startupConfirmAction.item.name}"?`
                  : `¿Reactivar "${startupConfirmAction.item.name}"?`}
              </h3>

              <p>
                {startupConfirmAction.mode === "disable"
                  ? "Este elemento dejará de iniciarse automáticamente con Windows. WinCare AI creará un respaldo local antes de aplicar el cambio."
                  : "WinCare AI restaurará este elemento utilizando el respaldo local creado al desactivarlo."}
              </p>

              <div className="wincare-confirm-summary">
                <div>
                  <span>Elemento</span>
                  <strong>{startupConfirmAction.item.name}</strong>
                </div>

                <div>
                  <span>Riesgo</span>
                  <strong>Bajo · reversible</strong>
                </div>

                <div>
                  <span>Privacidad</span>
                  <strong>100% local</strong>
                </div>
              </div>

              <div className="wincare-confirm-actions">
                <button
                  className="wincare-modal-cancel"
                  disabled={Boolean(startupActionBusy)}
                  onClick={() => setStartupConfirmAction(null)}
                >
                  Cancelar
                </button>

                <button
                  className={`wincare-modal-primary ${startupConfirmAction.mode}`}
                  disabled={Boolean(startupActionBusy)}
                  onClick={async () => {
                    const current = startupConfirmAction;

                    if (current.mode === "disable") {
                      const item = current.item as {
                        name: string;
                        command: string;
                        location: string;
                      };

                      await runStartupAdvancedAction(item, false);
                    } else {
                      await restoreStartupItem(
                        current.item as api.StartupDisabledItem,
                      );
                    }

                    setStartupConfirmAction(null);
                  }}
                >
                  {startupActionBusy
                    ? "Aplicando..."
                    : startupConfirmAction.mode === "disable"
                      ? "Desactivar"
                      : "Reactivar"}
                </button>
              </div>
            </section>
          </div>
        )}
</main>
    </div>
  );
}

export default App;





























