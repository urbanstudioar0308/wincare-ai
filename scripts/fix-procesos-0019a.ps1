$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$CssPath = "$ProjectRoot\src\App.css"
$BackupDir = "$ProjectRoot\Downloads\backup-fix-procesos-0019a"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX PROCESOS 0019A" -ForegroundColor Cyan
Write-Host " Conteo filtrado + RAM filtrada + fondo estable" -ForegroundColor Cyan
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

if ($App -notmatch 'processFilter') {
    throw "No se encontro el filtro de Procesos."
}

# ============================================================
# 1. AGREGAR LISTA FILTRADA DERIVADA
# ============================================================

if ($App -notmatch 'const visibleProcesses =') {

$DerivedState = @'

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
'@

    $CpuMarker = '  const cpu = Math.round(stats.cpu_usage);'
    $Index = $App.IndexOf($CpuMarker)

    if ($Index -lt 0) {
        throw "No se encontro el bloque de metricas principales."
    }

    $App = $App.Insert(
        $Index,
        $DerivedState + "`r`n"
    )

    Write-Host "[OK] Lista filtrada derivada creada" -ForegroundColor Green
}
else {
    Write-Host "[OK] Lista filtrada derivada ya existe" -ForegroundColor Green
}

# ============================================================
# 2. CORREGIR TARJETAS DE RESUMEN
# ============================================================

$OldCount = @'
                  {(
                    processes?.process_count ?? 0
                  ).toLocaleString("es-AR")}
'@

$NewCount = @'
                  {visibleProcesses.length.toLocaleString(
                    "es-AR",
                  )}
'@

# Reemplazar solo una ocurrencia dentro de "Procesos mostrados"
$LabelIndex = $App.IndexOf('<span>Procesos mostrados</span>')

if ($LabelIndex -ge 0) {
    $CountIndex = $App.IndexOf($OldCount, $LabelIndex)

    if ($CountIndex -ge 0) {
        $App =
            $App.Substring(0, $CountIndex) +
            $NewCount +
            $App.Substring($CountIndex + $OldCount.Length)

        Write-Host "[OK] Conteo de procesos mostrados corregido" -ForegroundColor Green
    }
}
else {
    throw "No se encontro la tarjeta Procesos mostrados."
}

$OldRam = @'
                  {formatBytes(
                    processes?.total_memory_bytes ?? 0,
                  )}
'@

$NewRam = @'
                  {formatBytes(
                    visibleProcessesRam,
                  )}
'@

$RamLabelIndex = $App.IndexOf('<span>RAM usada por lista</span>')

if ($RamLabelIndex -ge 0) {
    $RamIndex = $App.IndexOf($OldRam, $RamLabelIndex)

    if ($RamIndex -ge 0) {
        $App =
            $App.Substring(0, $RamIndex) +
            $NewRam +
            $App.Substring($RamIndex + $OldRam.Length)

        Write-Host "[OK] RAM usada por lista corregida" -ForegroundColor Green
    }
}
else {
    throw "No se encontro la tarjeta RAM usada por lista."
}

# ============================================================
# 3. REEMPLAZAR EL MAP/FILTER INLINE POR visibleProcesses
# ============================================================

$InlineStart = @'
              {!processesLoading &&
                (processes?.processes ?? [])
                  .filter((process) => {
                    if (processFilter === "all") {
                      return true;
                    }

                    return (
                      process.memory_bytes >=
                        300 * 1024 * 1024 ||
                      process.cpu_usage >= 5
                    );
                  })
                  .map((process) => (
'@

$InlineNew = @'
              {!processesLoading &&
                visibleProcesses.map((process) => (
'@

if ($App.Contains($InlineStart)) {
    $App = $App.Replace(
        $InlineStart,
        $InlineNew
    )

    Write-Host "[OK] Render de procesos conectado a lista filtrada" -ForegroundColor Green
}
elseif ($App -match 'visibleProcesses\.map') {
    Write-Host "[OK] Render ya usa visibleProcesses" -ForegroundColor Green
}
else {
    throw "No se encontro el filtro inline de procesos."
}

# ============================================================
# 4. AISLAR ESTILOS DEL FILTRO DE PROCESOS
# ============================================================

$App = $App.Replace(
@'
                <div className="threshold-buttons">
                  <button
                    className={
                      processFilter === "all"
                        ? "threshold active"
                        : "threshold"
                    }
'@,
@'
                <div className="process-filter-buttons">
                  <button
                    className={
                      processFilter === "all"
                        ? "process-filter-button active"
                        : "process-filter-button"
                    }
'@
)

$App = $App.Replace(
@'
                  <button
                    className={
                      processFilter === "heavy"
                        ? "threshold active"
                        : "threshold"
                    }
'@,
@'
                  <button
                    className={
                      processFilter === "heavy"
                        ? "process-filter-button active"
                        : "process-filter-button"
                    }
'@
)

Write-Host "[OK] Filtros de Procesos aislados de estilos compartidos" -ForegroundColor Green

Set-Content -Path $AppPath -Value $App -Encoding UTF8

# ============================================================
# 5. CSS DE FILTROS + FONDO ESTABLE
# ============================================================

$Css = Get-Content $CssPath -Raw

if ($Css -notmatch '\.process-filter-buttons') {

$ExtraCss = @'

.process-filter-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}

.process-filter-button {
  border: 1px solid #2b313b;
  background: #151a20;
  color: #8f98a4;
  border-radius: 9px;
  padding: 9px 13px;
  cursor: pointer;
  transition:
    border-color 0.15s ease,
    color 0.15s ease,
    background 0.15s ease;
}

.process-filter-button:hover {
  color: #ffffff;
  border-color: #3a4350;
}

.process-filter-button.active {
  color: #ffffff;
  border-color: #637dff;
  background: #171c24;
}

/* Mantener el fondo de Procesos visualmente estable entre filtros */
.process-panel,
.process-hero,
.storage-filters {
  background-color: #0f1318;
}

'@

    Add-Content -Path $CssPath -Value $ExtraCss -Encoding UTF8

    Write-Host "[OK] Estilos de Procesos corregidos" -ForegroundColor Green
}

# ============================================================
# 6. VERIFICACION Y BUILD
# ============================================================

$CheckApp = Get-Content $AppPath -Raw

if ($CheckApp -notmatch 'visibleProcesses\.length') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico el nuevo conteo. Backup restaurado."
}

if ($CheckApp -notmatch 'visibleProcessesRam') {
    Copy-Item "$BackupDir\App.tsx" $AppPath -Force
    Copy-Item "$BackupDir\App.css" $CssPath -Force
    throw "No se verifico la RAM filtrada. Backup restaurado."
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
Write-Host " FIX PROCESOS 0019A COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Ejecuta ahora:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
