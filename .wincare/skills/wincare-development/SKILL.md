---
name: wincare-development
version: 1.1
title: WinCare Development — Master Skill
description: Protocolo de ingeniería para desarrollar WinCare AI de forma incremental, verificable, reversible y compatible con el estado real del repositorio.
---

# WinCare Development — Master Skill v1.1

## 1. Misión

Desarrollar WinCare AI con cambios pequeños, verificables y reversibles. La prioridad es preservar el último estado estable confirmado del proyecto.

Esta skill NO autoriza a asumir cómo está escrito el proyecto. El código real es la fuente de verdad.

## 2. Stack oficial

- Tauri: aplicación Windows.
- Rust: motor WinCare, recopilación, diagnóstico y acciones sobre Windows.
- React + TypeScript: interfaz.
- CSS: presentación.
- ECharts: visualizaciones cuando corresponda.
- SQLite: historial, snapshots y casos cuando corresponda.
- PowerShell 5.1: ejecución de bloques de modificación/validación en el entorno actual.

## 3. Regla cero — inspeccionar antes de modificar

Antes de generar un bloque que modifique el proyecto:

1. Identificar exactamente qué archivos y símbolos serán afectados.
2. Inspeccionar la versión REAL y ACTUAL de esos archivos.
3. Confirmar nombres de funciones, structs, tipos, imports, handlers, JSX y selectores CSS.
4. Diseñar el parche contra esa estructura real.
5. Si falta información, detenerse y solicitar/inspeccionar el archivo necesario.

PROHIBIDO:
- inventar nombres de funciones;
- asumir que una función sigue existiendo porque existió en un bloque anterior;
- buscar una cadena textual rígida cuando `cargo fmt`, Prettier o el formato normal del código pueda alterarla;
- aplicar un parche sobre una versión supuesta del archivo.

## 4. Estado estable y versiones de bloques

Cada bloque debe partir del último estado estable confirmado.

Si un bloque falla:
1. confirmar rollback;
2. determinar la causa real;
3. volver al último estado estable;
4. inspeccionar de nuevo;
5. crear una nueva versión del bloque.

Nunca “parchear el parche” sobre un estado incierto.

Convención recomendada:
`bloque-<numero>-<subbloque>-<descripcion>-vN.ps1`

## 5. Alcance mínimo

Modificar únicamente los archivos necesarios para el objetivo del bloque.

No hacer refactors oportunistas.
No cambiar estilos, APIs, nombres o comportamiento no relacionados.
No mezclar una corrección visual con cambios del motor salvo que exista dependencia técnica real.

Antes de escribir, el bloque debe comprobar que los puntos de integración esperados existen.

## 6. PowerShell 5.1

Todos los `.ps1` entregados para WinCare deben ser compatibles con Windows PowerShell 5.1.

Evitar características exclusivas de PowerShell 7+.

Reglas:
- usar rutas simples y conocidas;
- evitar backups con rutas excesivamente largas;
- no usar parámetros cuya compatibilidad con PowerShell 5.1 no haya sido confirmada;
- preferir `[IO.File]::ReadAllText`, `[IO.File]::WriteAllText` y operaciones controladas;
- comprobar `Test-Path`/existencia antes de operar;
- tratar `$LASTEXITCODE` después de comandos externos;
- fallar inmediatamente ante validaciones críticas.

Comando que se muestra al usuario:
`powershell -ExecutionPolicy Bypass -File .\Downloads\<archivo>.ps1`

No anteponer `cd C:\Dev\wincare-ai`.

## 7. Rollback obligatorio

Todo bloque que escriba archivos debe preservar el contenido original ANTES de la primera escritura.

El rollback debe:
- poder ejecutarse aunque una validación posterior falle;
- restaurar solo los archivos modificados;
- no depender de una ruta de backup larga o frágil;
- informar explícitamente si fue exitoso.

Para cambios pequeños se prefiere snapshot en memoria de los archivos afectados.

Nunca declarar `[OK] Restaurado` si la restauración no se verificó.

## 8. UTF-8 y mojibake — regla crítica

WinCare contiene español y debe preservar correctamente acentos, `ñ`, signos y separadores Unicode.

Los archivos de código modificados deben conservar una codificación UTF-8 coherente.

Antes de aceptar un bloque que modifique texto visible o código con Unicode, buscar secuencias típicas de mojibake, al menos:
- `Ã`
- `Â`
- `â€`
- `â€”`
- `â€“`
- `ï»¿`

Si aparecen nuevas secuencias de este tipo en el área modificada, el bloque falla y hace rollback.

Para PowerShell 5.1:
- evitar incrustar Unicode frágil en el propio `.ps1` cuando pueda corromperse;
- construir caracteres críticos mediante code points (`[char]0x....`) o escapes seguros cuando corresponda;
- escribir con `System.Text.UTF8Encoding($false)` cuando el archivo de destino deba quedar UTF-8 sin BOM.

No corregir mojibake globalmente a ciegas. Delimitar el área afectada y reparar solo secuencias verificadas.

## 9. Parches resistentes

Preferir, en este orden:
1. modificación basada en estructura/símbolos inspeccionados;
2. anclas pequeñas y estables;
3. regex cuidadosamente delimitada;
4. reemplazo textual exacto solo si el texto es estable y fue inspeccionado.

Si una coincidencia esperada no existe:
- NO escribir;
- abortar;
- informar qué ancla no coincide.

No usar un `Replace()` gigantesco sobre funciones completas si una diferencia de formato puede invalidarlo.

## 10. Validación por capa

Ejecutar solo las validaciones relevantes, pero nunca omitir las necesarias.

### Rust / Tauri
Cuando se modifica Rust:
1. `cargo fmt`
2. `cargo check`
3. `cargo test`

### React / TypeScript / CSS
Cuando se modifica frontend:
1. `npm run build`

### Cambio full-stack
Ejecutar ambas cadenas.

Warnings existentes pueden registrarse, pero un error nuevo bloquea la aceptación.

## 11. Pruebas

Un build exitoso NO equivale a funcionalidad aprobada.

Cada bloque debe definir:
- qué valida automáticamente;
- qué requiere prueba manual;
- qué resultado se espera ver.

Después de un cambio visual, solicitar prueba visual.
Después de un cambio de recopilación/diagnóstico, probar con datos reales.
Después de una acción sobre Windows, verificar el estado posterior real.

## 12. Acciones sobre Windows

Distinguir explícitamente:

### SOLO LECTURA
Recopilar, diagnosticar, clasificar, mostrar, registrar.

### MODIFICA WINDOWS
Desactivar, activar, eliminar, restaurar, limpiar, cambiar configuración, servicios, tareas, registro, archivos, etc.

Nunca presentar un bloque como “solo lectura” si ejecuta una modificación.

Para acciones que modifican Windows:
1. precondición;
2. descripción clara de la acción;
3. confirmación de UI cuando corresponda;
4. ejecución;
5. verificación posterior;
6. historial;
7. rollback/restauración cuando sea técnicamente viable.

El éxito del comando no basta: la acción solo se considera verificada cuando el estado posterior coincide con lo esperado.

## 13. Diagnóstico conservador

WinCare no debe convertir una señal débil en un problema grave.

Principios:
- cantidad alta no implica anomalía;
- componentes Microsoft/Windows conocidos no se penalizan por existir;
- elementos deshabilitados no se penalizan como carga activa;
- software de terceros conocido puede ser “revisable” sin ser anómalo;
- una clasificación anómala debe apoyarse en señales verificables combinadas;
- la UI debe explicar por qué se tomó una decisión.

Nunca inventar fabricante, firma, identidad, impacto o riesgo. Si Windows no lo expone: `No disponible` / equivalente.

## 14. Contratos entre capas

Cuando se amplía un modelo Rust:
1. localizar todos los initializers;
2. localizar tests;
3. localizar bridges;
4. localizar tipos TypeScript equivalentes;
5. localizar renderizado UI;
6. actualizar toda la cadena en el mismo bloque o dividirla explícitamente en subbloques compatibles.

Antes de agregar campos a un struct, buscar todas sus construcciones para evitar errores `E0063`.

## 15. UI WinCare

Mantener coherencia con el diseño existente.

Reglas actuales:
- Dashboard = Estado general.
- Botón volver en pantallas internas, no en Dashboard.
- Sidebar y secciones existentes se preservan salvo objetivo explícito.
- Listas extensas deben usar scroll interno cuando mejore la navegación.
- Estados como confianza, impacto, riesgo, severidad y decisiones deben usar texto comprensible y color consistente.
- Iconos solo cuando mejoran jerarquía/comprensión.
- Evitar información duplicada (por ejemplo, decisión en título y badge simultáneamente).
- Corregir español y acentuación antes de aprobar la UI.

## 16. Salida de cada bloque

Al completar correctamente, informar de forma concreta:
- nombre del bloque;
- funcionalidades incorporadas;
- validaciones ejecutadas;
- si Windows fue modificado o no;
- si queda prueba manual.

No afirmar `OK` para una capacidad que no fue realmente validada.

## 17. Protocolo operativo

Antes de crear cualquier `.ps1`, completar mentalmente este checklist:

- [ ] Tengo el estado real de los archivos afectados.
- [ ] Confirmé símbolos/anclas reales.
- [ ] El cambio es mínimo.
- [ ] Sé exactamente qué archivos se escribirán.
- [ ] Hay rollback antes de la primera escritura.
- [ ] El script es PowerShell 5.1 compatible.
- [ ] Protegí UTF-8/mojibake.
- [ ] Actualicé todos los contratos afectados.
- [ ] Definí validaciones automáticas.
- [ ] Definí prueba manual si corresponde.
- [ ] Distinguí solo lectura vs modificación de Windows.

Si cualquiera de los puntos críticos no puede confirmarse, NO generar el parche todavía.

## 18. Criterio de terminado

Un bloque está terminado solo cuando:
1. prechecks pasan;
2. cambios se escriben;
3. validaciones técnicas pasan;
4. no se introdujo mojibake;
5. el estado de Windows fue respetado según el alcance declarado;
6. la prueba manual requerida fue aprobada por el usuario.

Hasta entonces: “técnicamente compilado”, “listo para prueba” o “pendiente”, según corresponda; nunca “cerrado” prematuramente.
