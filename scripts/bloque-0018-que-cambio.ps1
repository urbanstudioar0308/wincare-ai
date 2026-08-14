$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$LibRsPath = "$ProjectRoot\src-tauri\src\lib.rs"
$AppPath = "$ProjectRoot\src\App.tsx"
$CssPath = "$ProjectRoot\src\App.css"
$BackupDir = "$ProjectRoot\Downloads\backup-0018"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - BLOQUE 0018" -ForegroundColor Cyan
Write-Host " Que cambio - snapshots concretos" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($Path in @($LibRsPath, $AppPath, $CssPath)) {
    if (-not (Test-Path $Path)) {
        throw "No se encontro: $Path"
    }
}

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

Copy-Item $LibRsPath "$BackupDir\lib.rs" -Force
Copy-Item $AppPath "$BackupDir\App.tsx" -Force
Copy-Item $CssPath "$BackupDir\App.css" -Force

Write-Host "[OK] Backup creado" -ForegroundColor Green

# ============================================================
# 1. RUST - SNAPSHOTS DE CAMBIOS
# ============================================================

$Lib = Get-Content $LibRsPath -Raw

if ($Lib -notmatch "struct ChangeSnapshot") {

$ChangeRust = @'

#[derive(Serialize, serde::Deserialize, Clone)]
struct SnapshotLargeFile {
    name: String,
    path: String,
    size_bytes: u64,
}

#[derive(Serialize, serde::Deserialize, Clone)]
struct SnapshotCleanupCategory {
    id: String,
    name: String,
    size_bytes: u64,
    file_count: u64,
}

#[derive(Serialize, serde::Deserialize, Clone)]
struct ChangeSnapshot {
    id: String,
    timestamp: u64,
    startup_active: Vec<String>,
    heavy_processes: Vec<String>,
    large_files: Vec<SnapshotLargeFile>,
    cleanup_categories: Vec<SnapshotCleanupCategory>,
}

fn change_snapshot_file_path() -> PathBuf {
    let base = env::var("LOCALAPPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."));

    let folder = base.join("WinCareAI");

    let _ = fs::create_dir_all(&folder);

    folder.join("change-snapshots.json")
}

fn load_change_snapshots_internal() -> Vec<ChangeSnapshot> {
    let path = change_snapshot_file_path();

    if !path.exists() {
        return Vec::new();
    }

    let content = match fs::read_to_string(&path) {
        Ok(content) => content,
        Err(_) => return Vec::new(),
    };

    serde_json::from_str::<Vec<ChangeSnapshot>>(&content)
        .unwrap_or_default()
}

fn save_change_snapshots_internal(
    snapshots: &[ChangeSnapshot],
) -> Result<(), String> {
    let path = change_snapshot_file_path();

    let json = serde_json::to_string_pretty(snapshots)
        .map_err(|e| format!(
            "No se pudo serializar snapshots: {}",
            e
        ))?;

    fs::write(&path, json)
        .map_err(|e| format!(
            "No se pudieron guardar snapshots: {}",
            e
        ))
}

#[tauri::command]
fn save_change_snapshot(
    startup_active: Vec<String>,
    heavy_processes: Vec<String>,
    large_files: Vec<SnapshotLargeFile>,
    cleanup_categories: Vec<SnapshotCleanupCategory>,
) -> Result<ChangeSnapshot, String> {
    let mut snapshots = load_change_snapshots_internal();

    let timestamp = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .map_err(|e| format!(
            "No se pudo calcular timestamp: {}",
            e
        ))?
        .as_secs();

    let snapshot = ChangeSnapshot {
        id: format!("{}", timestamp),
        timestamp,
        startup_active,
        heavy_processes,
        large_files,
        cleanup_categories,
    };

    snapshots.push(snapshot.clone());

    if snapshots.len() > 100 {
        let excess = snapshots.len() - 100;
        snapshots.drain(0..excess);
    }

    save_change_snapshots_internal(&snapshots)?;

    Ok(snapshot)
}

#[tauri::command]
fn get_change_snapshots() -> Vec<ChangeSnapshot> {
    let mut snapshots = load_change_snapshots_internal();

    snapshots.sort_by(|a, b| {
        b.timestamp.cmp(&a.timestamp)
    });

    snapshots
}
'@

    $Marker = '#[cfg_attr(mobile, tauri::mobile_entry_point)]'
    $Index = $Lib.IndexOf($Marker)

    if ($Index -lt 0) {
        throw "No se encontro el marcador mobile_entry_point."
    }

    $Lib = $Lib.Insert(
        $Index,
        $ChangeRust + "`r`n"
    )

    if ($Lib -notmatch 'save_change_snapshot') {
        throw "No se pudo insertar el motor de snapshots."
    }

    # Registrar comandos en invoke_handler, insertando antes del cierre final de generate_handler.
    $HandlerPattern = '(?s)(tauri::generate_handler!\[)(.*?)(\]\))'
    $HandlerMatch = [regex]::Match($Lib, $HandlerPattern)

    if (-not $HandlerMatch.Success) {
        throw "No se encontro tauri::generate_handler."
    }

    $HandlerBody = $HandlerMatch.Groups[2].Value

    if ($HandlerBody -notmatch 'save_change_snapshot') {
        $Trimmed = $HandlerBody.TrimEnd()

        if ($Trimmed.EndsWith(",")) {
            $NewBody = $Trimmed + "`r`n            save_change_snapshot,`r`n            get_change_snapshots`r`n        "
        }
        else {
            $NewBody = $Trimmed + ",`r`n            save_change_snapshot,`r`n            get_change_snapshots`r`n        "
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
    Write-Host "[OK] Persistencia de snapshots agregada" -ForegroundColor Green
}
else {
    Write-Host "[OK] Motor de snapshots ya existe" -ForegroundColor Green
}

# ============================================================
# 2. REACT - TIPOS Y ESTADO
# ============================================================

$App = Get-Content $AppPath -Raw

if ($App -notmatch "type ChangeSnapshot") {

$ChangeTypes = @'

type SnapshotLargeFile = {
  name: string;
  path: string;
  size_bytes: number;
};

type SnapshotCleanupCategory = {
  id: string;
  name: string;
  size_bytes: number;
  file_count: number;
};

type ChangeSnapshot = {
  id: string;
  timestamp: number;
  startup_active: string[];
  heavy_processes: string[];
  large_files: SnapshotLargeFile[];
  cleanup_categories: SnapshotCleanupCategory[];
};
'@

    $ConstIndex = $App.IndexOf("const emptyStats")

    if ($ConstIndex -lt 0) {
        throw "No se encontro const emptyStats."
    }

    $App = $App.Insert(
        $ConstIndex,
        $ChangeTypes + "`r`n"
    )

    Write-Host "[OK] Tipos de snapshots agregados" -ForegroundColor Green
}

# Agregar "changes" al union de activeView de forma robusta.
$ActiveViewPattern = '(?s)(const\s+\[activeView,\s*setActiveView\]\s*=\s*useState<)(.*?)(>\s*\()'
$ActiveViewMatch = [regex]::Match($App, $ActiveViewPattern)

if (-not $ActiveViewMatch.Success) {
    throw "No se pudo localizar activeView."
}

$Union = $ActiveViewMatch.Groups[2].Value

if ($Union -notmatch '"changes"') {
    $NewUnion = $Union.TrimEnd() + ' | "changes"'

    $Replacement =
        $ActiveViewMatch.Groups[1].Value +
        $NewUnion +
        $ActiveViewMatch.Groups[3].Value

    $App =
        $App.Substring(0, $ActiveViewMatch.Index) +
        $Replacement +
        $App.Substring($ActiveViewMatch.Index + $ActiveViewMatch.Length)

    Write-Host "[OK] Vista changes agregada a activeView" -ForegroundColor Green
}

if ($App -notmatch "changeSnapshotsLoading") {

$ChangeState = @'

  const [changeSnapshots, setChangeSnapshots] =
    useState<ChangeSnapshot[]>([]);

  const [changeSnapshotsLoading, setChangeSnapshotsLoading] =
    useState(false);

  async function loadChangeSnapshots() {
    setChangeSnapshotsLoading(true);

    try {
      const data =
        await invoke<ChangeSnapshot[]>(
          "get_change_snapshots",
        );

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
'@

    $LoadStatsIndex = $App.IndexOf("  async function loadStats()")

    if ($LoadStatsIndex -lt 0) {
        throw "No se encontro loadStats."
    }

    $App = $App.Insert(
        $LoadStatsIndex,
        $ChangeState + "`r`n"
    )

    Write-Host "[OK] Estado de Que cambio agregado" -ForegroundColor Green
}

# ============================================================
# 3. GUARDAR SNAPSHOT AL FINAL DEL ANALISIS COMPLETO
# ============================================================

if ($App -notmatch '"save_change_snapshot"') {

$SnapshotSave = @'

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

        await invoke("save_change_snapshot", {
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

'@

    $SetFullAnalysisIndex = $App.IndexOf("      setFullAnalysis({")

    if ($SetFullAnalysisIndex -lt 0) {
        throw "No se encontro setFullAnalysis."
    }

    $App = $App.Insert(
        $SetFullAnalysisIndex,
        $SnapshotSave
    )

    Write-Host "[OK] Guardado automatico de snapshots conectado" -ForegroundColor Green
}

# ============================================================
# 4. LOGICA DE CAMBIOS CONCRETOS
# ============================================================

if ($App -notmatch "const concreteChanges =") {

$ConcreteLogic = @'

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
'@

    # Insertar antes de loadStats para que quede dentro de App().
    $LoadStatsIndex = $App.IndexOf("  async function loadStats()")

    if ($LoadStatsIndex -lt 0) {
        throw "No se encontro loadStats para insertar concreteChanges."
    }

    $App = $App.Insert(
        $LoadStatsIndex,
        $ConcreteLogic + "`r`n"
    )

    Write-Host "[OK] Comparador de cambios concretos agregado" -ForegroundColor Green
}

# ============================================================
# 5. SIDEBAR
# ============================================================

$NavPattern = '(?s)(<nav className="nav">)(.*?)(</nav>)'
$NavMatch = [regex]::Match($App, $NavPattern)

if (-not $NavMatch.Success) {
    throw "No se encontro el sidebar."
}

$NavContent = $NavMatch.Groups[2].Value

if ($NavContent -notmatch '(?s)>\s*Qué cambió\s*</button>') {

$ChangesButton = @'

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

'@

    $HistoryPosition = $NavContent.IndexOf("Historial")

    if ($HistoryPosition -lt 0) {
        throw "No se encontro Historial para insertar Que cambio."
    }

    $HistoryButtonStart = $NavContent.LastIndexOf(
        "<button",
        $HistoryPosition
    )

    if ($HistoryButtonStart -lt 0) {
        throw "No se encontro el inicio del boton Historial."
    }

    $NewNavContent = $NavContent.Insert(
        $HistoryButtonStart,
        $ChangesButton
    )

    $NewNav =
        $NavMatch.Groups[1].Value +
        $NewNavContent +
        $NavMatch.Groups[3].Value

    $App =
        $App.Substring(0, $NavMatch.Index) +
        $NewNav +
        $App.Substring($NavMatch.Index + $NavMatch.Length)

    Write-Host "[OK] Que cambio agregado al sidebar" -ForegroundColor Green
}

# ============================================================
# 6. VISTA QUE CAMBIO
# ============================================================

if ($App -notmatch 'activeView === "changes" &&') {

$ChangesView = @'

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
'@

    $MainClose = $App.LastIndexOf("</main>")

    if ($MainClose -lt 0) {
        throw "No se encontro </main>."
    }

    $App = $App.Insert(
        $MainClose,
        $ChangesView + "`r`n      "
    )

    Write-Host "[OK] Vista Que cambio creada" -ForegroundColor Green
}

Set-Content -Path $AppPath -Value $App -Encoding UTF8

# ============================================================
# 7. CSS
# ============================================================

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch '\.changes-hero') {

$ChangesCss = @'

.changes-hero {
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

.changes-hero p {
  max-width: 720px;
  color: #76818e;
  line-height: 1.6;
}

.changes-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.changes-card {
  border: 1px solid #22272f;
  border-radius: 18px;
  background: #0f1318;
  overflow: hidden;
}

.changes-card-header {
  padding: 18px 20px;
  border-bottom: 1px solid #22272f;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.changes-card-header h3 {
  margin: 5px 0 0;
}

.changes-card-header > strong {
  min-width: 36px;
  height: 36px;
  padding: 0 10px;
  border-radius: 11px;
  background: #171c22;
  border: 1px solid #29303a;
  display: grid;
  place-items: center;
}

.change-item {
  padding: 14px 18px;
  border-bottom: 1px solid #20252b;
  display: grid;
  grid-template-columns: 30px 1fr;
  gap: 11px;
  align-items: center;
}

.change-item:last-child {
  border-bottom: 0;
}

.change-item > span {
  width: 28px;
  height: 28px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  font-weight: 900;
}

.change-item.added > span {
  color: #e3ad55;
  background: rgba(225, 170, 79, 0.09);
}

.change-item.removed > span {
  color: #64d493;
  background: rgba(62, 201, 125, 0.09);
}

.change-item > div {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.change-item strong {
  font-size: 12px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.change-item small {
  color: #64707d;
  font-size: 10px;
}

.change-none {
  padding: 30px 18px;
  text-align: center;
  color: #596470;
  font-size: 11px;
}

.changes-stable {
  margin-bottom: 18px;
  padding: 22px;
  border: 1px solid #28503a;
  background: rgba(56, 196, 116, 0.05);
  border-radius: 18px;
  display: flex;
  gap: 15px;
  align-items: center;
}

.changes-stable > div:first-child {
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: #62d491;
  background: rgba(62, 201, 125, 0.1);
  font-weight: 900;
}

.changes-stable h3 {
  margin: 5px 0;
}

.changes-stable p {
  margin: 0;
  color: #71808a;
  font-size: 11px;
}

.changes-explanation {
  margin-top: 18px;
  border: 1px solid #22272f;
  border-radius: 18px;
  background: #101419;
  padding: 24px;
}

.changes-explanation h3 {
  margin: 6px 0 8px;
}

.changes-explanation p {
  margin: 0;
  max-width: 900px;
  color: #6e7986;
  font-size: 12px;
  line-height: 1.7;
}

.changes-empty {
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

.changes-empty-icon {
  width: 70px;
  height: 70px;
  border: 1px solid #303846;
  border-radius: 22px;
  display: grid;
  place-items: center;
  margin-bottom: 18px;
  color: #7584ff;
  font-size: 28px;
}

.changes-empty h3 {
  margin: 8px 0;
  font-size: 26px;
}

.changes-empty p {
  max-width: 590px;
  color: #727d89;
  line-height: 1.65;
}

.changes-empty button {
  margin-top: 13px;
}

@media (max-width: 900px) {
  .changes-hero {
    flex-direction: column;
    align-items: flex-start;
  }

  .changes-grid {
    grid-template-columns: 1fr;
  }
}
'@

    Add-Content -Path $CssPath -Value $ChangesCss -Encoding UTF8
    Write-Host "[OK] Estilos Que cambio agregados" -ForegroundColor Green
}

# ============================================================
# 8. VERIFICAR + BUILD
# ============================================================

$CheckApp = Get-Content $AppPath -Raw
$CheckNav = [regex]::Match($CheckApp, $NavPattern).Groups[2].Value

if ($CheckNav -notmatch '(?s)>\s*Qué cambió\s*</button>') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    Copy-Item "$BackupDir\lib.rs" $LibRsPath -Force
    throw "No se pudo verificar Que cambio en sidebar. Backup restaurado."
}

Write-Host ""
Write-Host "Comprobando Rust..." -ForegroundColor Yellow

Set-Location "$ProjectRoot\src-tauri"
cargo check

if ($LASTEXITCODE -ne 0) {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    Copy-Item "$BackupDir\lib.rs" $LibRsPath -Force
    throw "cargo check fallo. Backup restaurado."
}

Write-Host ""
Write-Host "Comprobando frontend..." -ForegroundColor Yellow

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
Write-Host " BLOQUE 0018 COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANTE:" -ForegroundColor Yellow
Write-Host "Que cambio necesita 2 Analisis completos NUEVOS" -ForegroundColor Yellow
Write-Host "realizados despues de instalar este bloque." -ForegroundColor Yellow
Write-Host ""
Write-Host "Ejecuta ahora:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
