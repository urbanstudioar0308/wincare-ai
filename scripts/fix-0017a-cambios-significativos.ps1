$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Dev\wincare-ai"
$AppPath = "$ProjectRoot\src\App.tsx"
$BackupDir = "$ProjectRoot\Downloads\backup-0017a"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " WINCARE AI - FIX 0017A" -ForegroundColor Cyan
Write-Host " Filtrar cambios insignificantes" -ForegroundColor Cyan
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

# ------------------------------------------------------------
# 1. Agregar noiseFloor a cada metrica
# ------------------------------------------------------------

$replacements = @(
    @{
        old = 'critical: 15,' + "`r`n" + '      },'
        new = 'critical: 15,' + "`r`n" + '        noiseFloor: 1,' + "`r`n" + '      },'
        count = 1
    },
    @{
        old = 'critical: 20,' + "`r`n" + '      },'
        new = 'critical: 20,' + "`r`n" + '        noiseFloor: 2,' + "`r`n" + '      },'
        count = 1
    },
    @{
        old = 'critical: 30,' + "`r`n" + '      },'
        new = 'critical: 30,' + "`r`n" + '        noiseFloor: 3,' + "`r`n" + '      },'
        count = 1
    },
    @{
        old = 'critical: 10,' + "`r`n" + '      },'
        new = 'critical: 10,' + "`r`n" + '        noiseFloor: 1,' + "`r`n" + '      },'
        count = 1
    },
    @{
        old = 'critical: 5,' + "`r`n" + '      },'
        new = 'critical: 5,' + "`r`n" + '        noiseFloor: 1,' + "`r`n" + '      },'
        count = 2
    },
    @{
        old = 'critical: 1024 * 1024 * 1024,' + "`r`n" + '      },'
        new = 'critical: 1024 * 1024 * 1024,' + "`r`n" + '        noiseFloor: 50 * 1024 * 1024,' + "`r`n" + '      },'
        count = 1
    },
    @{
        old = 'critical: 15 * 1024 * 1024 * 1024,' + "`r`n" + '      },'
        new = 'critical: 15 * 1024 * 1024 * 1024,' + "`r`n" + '        noiseFloor: 500 * 1024 * 1024,' + "`r`n" + '      },'
        count = 1
    }
)

foreach ($r in $replacements) {
    for ($i = 0; $i -lt $r.count; $i++) {
        $idx = $App.IndexOf($r.old)
        if ($idx -ge 0) {
            $App = $App.Substring(0, $idx) + $r.new + $App.Substring($idx + $r.old.Length)
        }
    }
}

# ------------------------------------------------------------
# 2. Reemplazar la logica de direction para ignorar ruido
# ------------------------------------------------------------

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
        metric.noiseFloor ?? 0;

      if (magnitude >= noiseFloor && magnitude > 0) {
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
    $App = $App.Replace($OldDirection, $NewDirection)
    Write-Host "[OK] Filtro de ruido agregado" -ForegroundColor Green
}
else {
    throw "No se encontro la logica direction esperada."
}

# ------------------------------------------------------------
# 3. El cambio principal solo puede ser warning/critical
# ------------------------------------------------------------

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
    $App = $App.Replace($OldWorst, $NewWorst)
    Write-Host "[OK] Diagnostico principal endurecido" -ForegroundColor Green
}
else {
    throw "No se encontro el filtro worst."
}

# ------------------------------------------------------------
# 4. Mejorar headline cuando el score general sube
# ------------------------------------------------------------

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
    $App = $App.Replace($OldSummary, $NewSummary)
    Write-Host "[OK] Resumen general mejorado" -ForegroundColor Green
}
else {
    throw "No se encontro el bloque de resumen."
}

Set-Content -Path $AppPath -Value $App -Encoding UTF8

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
Write-Host " FIX 0017A COMPLETADO" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Ejecuta ahora:" -ForegroundColor Cyan
Write-Host "npm run tauri dev" -ForegroundColor White
Write-Host ""
