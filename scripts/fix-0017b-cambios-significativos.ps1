$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$BackupDir = "$ProjectRoot\Downloads\backup-0017b"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX 0017B" -ForegroundColor Cyan
Write-Host " Cambios significativos - version corregida" -ForegroundColor Cyan
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

if ($App -notmatch 'const comparison =') {
    throw "No se encontro el motor Antes vs ahora."
}

# ============================================================
# 1. FILTRO DE RUIDO SIN CAMBIAR EL TIPO DE metrics
# ============================================================

$OldDirection = @'
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
'@

$NewDirection = @'
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
'@

if ($App.Contains($OldDirection)) {
    $App = $App.Replace(
        $OldDirection,
        $NewDirection
    )

    Write-Host "[OK] Filtro de ruido agregado sin cambiar tipos" -ForegroundColor Green
}
elseif ($App -match 'const noiseFloor\s*=') {
    Write-Host "[OK] Filtro de ruido ya existe" -ForegroundColor Green
}
else {
    throw "No se encontro la logica direction esperada."
}

# ============================================================
# 2. CAMBIO PRINCIPAL SOLO PARA WARNING / CRITICAL
# ============================================================

$OldWorst = @'
    const worst = [...evaluated]
      .filter((metric) => metric.direction === "worse")
'@

$NewWorst = @'
    const worst = [...evaluated]
      .filter(
        (metric) =>
          metric.direction === "worse" &&
          metric.severity !== "normal",
      )
'@

if ($App.Contains($OldWorst)) {
    $App = $App.Replace(
        $OldWorst,
        $NewWorst
    )

    Write-Host "[OK] Diagnostico principal endurecido" -ForegroundColor Green
}
elseif ($App -match 'metric\.severity\s*!==\s*"normal"') {
    Write-Host "[OK] Diagnostico principal ya corregido" -ForegroundColor Green
}
else {
    throw "No se encontro el filtro worst."
}

# ============================================================
# 3. RESUMEN GENERAL MAS INTELIGENTE
# ============================================================

$OldSummary = @'
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
'@

$NewSummary = @'
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
'@

if ($App.Contains($OldSummary)) {
    $App = $App.Replace(
        $OldSummary,
        $NewSummary
    )

    Write-Host "[OK] Resumen general mejorado" -ForegroundColor Green
}
elseif ($App -match 'El estado general mejoró') {
    Write-Host "[OK] Resumen general ya mejorado" -ForegroundColor Green
}
else {
    throw "No se encontro el bloque de resumen."
}

# ============================================================
# 4. GUARDAR Y BUILD
# ============================================================

Set-Content `
    -Path $AppPath `
    -Value $App `
    -Encoding UTF8

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
Write-Host " FIX 0017B COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Ejecuta ahora:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
