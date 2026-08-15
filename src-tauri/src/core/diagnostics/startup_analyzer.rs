use super::models::{Confidence, Evidence, Finding, Impact, Severity};
use super::startup_collector::{StartupCollectedTask, StartupCollection};

const MEDIUM_ACTIVE_ITEMS: u64 = 8;
const HIGH_ACTIVE_ITEMS: u64 = 15;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum TaskClassification {
    WindowsSystem,
    KnownLocation,
    Reviewable,
    Anomalous,
    Unknown,
    Disabled,
}

fn now_unix_seconds() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
fn active_item_severity(count: u64) -> Severity {
    if count >= HIGH_ACTIVE_ITEMS {
        Severity::Medium
    } else if count >= MEDIUM_ACTIVE_ITEMS {
        Severity::Low
    } else {
        Severity::Ok
    }
}
fn normalized(value: &str) -> String {
    value
        .trim()
        .trim_matches('"')
        .to_ascii_lowercase()
        .replace('/', "\\")
}
fn executable_name(value: &str) -> String {
    let n = normalized(value);
    n.rsplit('\\')
        .next()
        .unwrap_or(n.as_str())
        .trim_matches('"')
        .to_string()
}
fn is_windows_task_path(v: &str) -> bool {
    normalized(v).starts_with("\\microsoft\\windows\\")
}
fn is_enabled(v: &str) -> bool {
    matches!(normalized(v).as_str(), "ready" | "running" | "queued")
}
fn startup_trigger(v: &str) -> bool {
    let n = normalized(v);
    n.contains("logontrigger") || n.contains("boottrigger")
}
fn windows_binary(v: &str) -> bool {
    let n = normalized(v);
    n.contains("\\windows\\system32\\")
        || n.contains("\\windows\\syswow64\\")
        || n.starts_with("%systemroot%\\")
        || n.starts_with("%windir%\\")
}
fn program_files(v: &str) -> bool {
    let n = normalized(v);
    n.contains("\\program files\\") || n.contains("\\program files (x86)\\")
}
fn user_profile(v: &str) -> bool {
    let n = normalized(v);
    n.contains("\\users\\") || n.starts_with("%userprofile%\\")
}
fn temp_location(v: &str) -> bool {
    let n = normalized(v);
    n.contains("\\appdata\\local\\temp")
        || n.contains("\\windows\\temp")
        || n.starts_with("%temp%")
        || n.starts_with("$env:temp")
}
fn script_host(v: &str) -> bool {
    matches!(
        executable_name(v).as_str(),
        "powershell.exe" | "pwsh.exe" | "cmd.exe" | "wscript.exe" | "cscript.exe" | "mshta.exe"
    )
}
fn encoded_or_hidden(v: &str) -> bool {
    let n = normalized(v);
    n.contains("-encodedcommand")
        || n.contains("-enc ")
        || n.contains("-windowstyle hidden")
        || n.contains("-w hidden")
        || n.contains("frombase64string")
}
fn network_script(v: &str) -> bool {
    let n = normalized(v);
    (n.contains("http://") || n.contains("https://"))
        && (n.contains("invoke-webrequest")
            || n.contains("iwr ")
            || n.contains("downloadstring")
            || n.contains("curl "))
}
fn classify_task(t: &StartupCollectedTask) -> TaskClassification {
    if normalized(&t.state) == "disabled" {
        return TaskClassification::Disabled;
    }
    let startup = is_enabled(&t.state) && startup_trigger(&t.triggers);
    if is_windows_task_path(&t.task_path)
        && (t.execute.trim().is_empty() || windows_binary(&t.execute))
    {
        return TaskClassification::WindowsSystem;
    }
    let temp = temp_location(&t.execute) || temp_location(&t.working_directory);
    let host = script_host(&t.execute);
    let encoded = host && encoded_or_hidden(&t.arguments);
    let network = host && network_script(&t.arguments);
    let strong = u8::from(temp) + u8::from(encoded) + u8::from(network);
    if startup && strong >= 2 {
        return TaskClassification::Anomalous;
    }
    if startup && program_files(&t.execute) {
        return TaskClassification::KnownLocation;
    }
    if startup && (host || temp || user_profile(&t.execute) || !t.execute.trim().is_empty()) {
        return TaskClassification::Reviewable;
    }
    TaskClassification::Unknown
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum TaskDecision {
    Keep,
    Optional,
    Review,
    PriorityReview,
}

impl TaskDecision {
    fn label(self) -> &'static str {
        match self {
            Self::Keep => "Mantener",
            Self::Optional => "Opcional",
            Self::Review => "Revisar",
            Self::PriorityReview => "Prioridad de revisión",
        }
    }
}

fn has_resolved_missing_executable(task: &StartupCollectedTask) -> bool {
    !task.resolved_executable.trim().is_empty() && !task.executable_exists
}

fn executable_existence_label(task: &StartupCollectedTask) -> &'static str {
    if task.executable_exists {
        "Sí"
    } else if has_resolved_missing_executable(task) {
        "No — destino inexistente"
    } else {
        "No determinado"
    }
}

fn residual_task_intelligence(task: &StartupCollectedTask) -> Option<String> {
    if !has_resolved_missing_executable(task) {
        return None;
    }

    Some(format!(
        "Posible tarea residual | Evidencia: la tarea conserva la ruta '{}' pero el destino no existe actualmente | Recomendación: revisar si el software asociado sigue instalado antes de limpiar la tarea",
        task.resolved_executable.trim()
    ))
}

fn has_trusted_executable_identity(task: &StartupCollectedTask) -> bool {
    task.executable_exists
        && !task.resolved_executable.trim().is_empty()
        && normalized(&task.signature_status) == "valid"
        && (!task.signer.trim().is_empty()
            || !task.product_name.trim().is_empty()
            || !task.file_description.trim().is_empty())
}

fn has_strong_review_signal(task: &StartupCollectedTask) -> bool {
    temp_location(&task.execute)
        || temp_location(&task.working_directory)
        || script_host(&task.execute)
        || encoded_or_hidden(&task.arguments)
        || network_script(&task.arguments)
}

fn task_decision(task: &StartupCollectedTask, classification: TaskClassification) -> TaskDecision {
    match classification {
        TaskClassification::WindowsSystem | TaskClassification::KnownLocation => TaskDecision::Keep,
        TaskClassification::Anomalous => TaskDecision::PriorityReview,
        TaskClassification::Disabled => TaskDecision::Keep,
        TaskClassification::Reviewable => {
            let exe = executable_name(&task.execute);
            let args = normalized(&task.arguments);
            let name = normalized(&task.task_name);

            let looks_like_updater = name.contains("update")
                || name.contains("updater")
                || name.contains("autoupdate")
                || args.contains("--update")
                || args.contains("--autoupdate");

            if has_resolved_missing_executable(task) {
                TaskDecision::Review
            } else if looks_like_updater
                && !script_host(&task.execute)
                && !temp_location(&task.execute)
            {
                TaskDecision::Optional
            } else if has_trusted_executable_identity(task) && !has_strong_review_signal(task) {
                TaskDecision::Keep
            } else {
                TaskDecision::Review
            }
        }
        TaskClassification::Unknown => TaskDecision::Review,
    }
}

fn task_reason(task: &StartupCollectedTask, classification: TaskClassification) -> String {
    match classification {
        TaskClassification::WindowsSystem => "Tarea estándar de Windows.".into(),
        TaskClassification::KnownLocation => {
            "Ejecutable ubicado en una ruta de programa conocida.".into()
        }
        TaskClassification::Disabled => "La tarea está deshabilitada.".into(),
        TaskClassification::Anomalous => {
            let mut reasons = Vec::new();
            if temp_location(&task.execute) || temp_location(&task.working_directory) {
                reasons.push("usa una ubicación temporal");
            }
            if script_host(&task.execute) && encoded_or_hidden(&task.arguments) {
                reasons.push("usa un intérprete con argumentos codificados u ocultos");
            }
            if script_host(&task.execute) && network_script(&task.arguments) {
                reasons.push("el intérprete contiene una acción de red");
            }
            format!(
                "Combina señales de revisión prioritaria: {}.",
                reasons.join(" y ")
            )
        }
        TaskClassification::Reviewable => {
            if has_resolved_missing_executable(task) {
                "La tarea conserva una ruta de ejecutable que actualmente no existe. Puede ser un residuo de software desinstalado o actualizado; conviene revisar su origen antes de realizar cambios.".into()
            } else if script_host(&task.execute) {
                "Usa un intérprete de comandos o scripts y requiere contexto antes de recomendar cambios.".into()
            } else if temp_location(&task.execute) || temp_location(&task.working_directory) {
                "Se ejecuta desde una ubicación temporal y requiere contexto adicional.".into()
            } else if has_trusted_executable_identity(task) && !has_strong_review_signal(task) {
                "El ejecutable existe, tiene firma válida e identidad de archivo disponible; no se detectaron señales fuertes de revisión.".into()
            } else if user_profile(&task.execute) {
                "Se ejecuta desde el perfil del usuario; puede ser legítima, pero conviene identificar su función.".into()
            } else {
                "Es una tarea de inicio de terceros que WinCare todavía no puede clasificar con suficiente contexto.".into()
            }
        }
        TaskClassification::Unknown => {
            "No hay información suficiente para clasificarla automáticamente.".into()
        }
    }
}

fn display_value(value: &str) -> &str {
    if value.trim().is_empty() {
        "No informado"
    } else {
        value.trim()
    }
}

fn task_intelligence_line(
    task: &StartupCollectedTask,
    classification: TaskClassification,
) -> String {
    let decision = task_decision(task, classification);
    format!(
        "{} — {} | Ejecuta: {} | Archivo: {} | Existe: {} | Firma: {} | Firmante: {} | Producto: {} | Descripción: {} | Argumentos: {} | Carpeta: {} | Motivo: {}",
        task.task_name,
        decision.label(),
        display_value(&task.execute),
        display_value(&task.resolved_executable),
        executable_existence_label(task),
        display_value(&task.signature_status),
        display_value(&task.signer),
        display_value(&task.product_name),
        display_value(&task.file_description),
        display_value(&task.arguments),
        display_value(&task.working_directory),
        match residual_task_intelligence(task) {
            Some(residual) => format!("{} | {}", task_reason(task, classification), residual),
            None => task_reason(task, classification),
        }
    )
}

fn task_intelligence_details(
    tasks: &[&StartupCollectedTask],
    classification: TaskClassification,
    max: usize,
) -> String {
    tasks
        .iter()
        .take(max)
        .map(|task| task_intelligence_line(task, classification))
        .collect::<Vec<_>>()
        .join("\n")
}
fn names(tasks: &[&StartupCollectedTask], max: usize) -> String {
    let mut n = tasks
        .iter()
        .take(max)
        .map(|t| t.task_name.as_str())
        .collect::<Vec<_>>();
    if tasks.len() > max {
        n.push("…");
    }
    n.join(", ")
}
pub fn analyze(collection: &StartupCollection) -> Vec<Finding> {
    let mut findings = Vec::new();
    let detected_at = now_unix_seconds();
    let sev = active_item_severity(collection.active_item_count);
    if sev != Severity::Ok {
        findings.push(Finding{
            id:"startup.active_items.load".into(),module:"startup".into(),title:"Carga de programas al iniciar".into(),
            description:format!("Hay {} programas configurados para iniciar con Windows. La cantidad se usa como señal de carga, no como prueba de que deban desactivarse.",collection.active_item_count),
            severity:sev,confidence:Confidence::Medium,impacts:vec![Impact::Startup,Impact::Performance],
            evidence:vec![Evidence{source:"startup_collector".into(),metric:"active_item_count".into(),value:collection.active_item_count.to_string(),expected:None,
                message:format!("WinCare detectó {} programas configurados para el inicio.",collection.active_item_count),
                technical_data:Some("El conteo aislado no clasifica software como dañino ni justifica desactivarlo.".into())}],
            recommendations:vec![],detected_at
        });
    }
    let classified = collection
        .scheduled_tasks
        .iter()
        .map(|t| (t, classify_task(t)))
        .collect::<Vec<_>>();
    let count = |c| classified.iter().filter(|(_, x)| *x == c).count() as u64;
    let windows = count(TaskClassification::WindowsSystem);
    let known = count(TaskClassification::KnownLocation);
    let review = count(TaskClassification::Reviewable);
    let anomalous = count(TaskClassification::Anomalous);
    let unknown = count(TaskClassification::Unknown);
    let disabled = count(TaskClassification::Disabled);
    let anomalous_tasks = classified
        .iter()
        .filter(|(_, c)| *c == TaskClassification::Anomalous)
        .map(|(t, _)| *t)
        .collect::<Vec<_>>();
    let review_tasks = classified
        .iter()
        .filter(|(_, c)| *c == TaskClassification::Reviewable)
        .map(|(t, _)| *t)
        .collect::<Vec<_>>();
    let summary=format!("{} sistema/Windows · {} ubicación conocida · {} revisables · {} anómalas · {} desconocidas · {} deshabilitadas.",windows,known,review,anomalous,unknown,disabled);
    if anomalous > 0 {
        findings.push(Finding{id:"startup.scheduled_tasks.anomalous".into(),module:"startup".into(),title:"Tareas de inicio con señales anómalas".into(),
            description:format!("WinCare detectó {} tarea(s) con una combinación de señales que merece revisión prioritaria.",anomalous),
            severity:Severity::Medium,confidence:Confidence::Medium,impacts:vec![Impact::Startup,Impact::Performance],
            evidence:vec![Evidence{source:"startup_task_classifier".into(),metric:"anomalous_scheduled_tasks".into(),value:anomalous.to_string(),expected:Some("0".into()),
                message:format!("Tareas: {}.",names(&anomalous_tasks,5)),technical_data:Some(format!("{}\n\nDetalle individual:\n{}", summary.clone(), task_intelligence_details(&anomalous_tasks, TaskClassification::Anomalous, 8)))}],recommendations:vec![],detected_at});
    }
    if review > 0 {
        findings.push(Finding{id:"startup.scheduled_tasks.reviewable".into(),module:"startup".into(),title:"Tareas de terceros para revisar".into(),
            description:format!("WinCare identificó {} tarea(s) de inicio que requieren contexto adicional antes de recomendar cambios.",review),
            severity:Severity::Low,confidence:Confidence::Medium,impacts:vec![Impact::Startup],
            evidence:vec![Evidence{source:"startup_task_classifier".into(),metric:"reviewable_scheduled_tasks".into(),value:review.to_string(),expected:None,
                message:format!("Revisables: {}.",names(&review_tasks,8)),technical_data:Some(format!("{} Revisable no significa maliciosa ni innecesaria.\n\nDetalle individual:\n{}", summary, task_intelligence_details(&review_tasks, TaskClassification::Reviewable, 12)))}],
            recommendations:vec![],detected_at});
    }
    findings
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::diagnostics::startup_collector::{
        StartupCollectedItem, StartupCollectedTask, StartupItemState, StartupSourceKind,
    };
    fn item(i: usize) -> StartupCollectedItem {
        StartupCollectedItem {
            id: format!("i{i}"),
            name: format!("Item {i}"),
            command: "x.exe".into(),
            location: "Startup".into(),
            user: "u".into(),
            source_kind: StartupSourceKind::StartupFolder,
            state: StartupItemState::Active,
            editable: true,
        }
    }
    fn task(execute: &str, args: &str, wd: &str) -> StartupCollectedTask {
        StartupCollectedTask {
            id: "t".into(),
            task_name: "Test".into(),
            task_path: "\\Vendor\\Task\\".into(),
            state: "Ready".into(),
            triggers: "MSFT_TaskLogonTrigger".into(),
            execute: execute.into(),
            arguments: args.into(),
            working_directory: wd.into(),
            executable_exists: false,
            resolved_executable: String::new(),
            signature_status: String::new(),
            signer: String::new(),
            file_description: String::new(),
            product_name: String::new(),
            source_kind: StartupSourceKind::ScheduledTask,
        }
    }
    fn collection(items: usize, tasks: Vec<StartupCollectedTask>) -> StartupCollection {
        StartupCollection {
            items: (0..items).map(item).collect(),
            scheduled_task_count: tasks.len() as u64,
            scheduled_tasks: tasks,
            active_item_count: items as u64,
        }
    }

    #[test]
    fn signal_full_powershell_path() {
        assert!(script_host(
            r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
        ));
    }
    #[test]
    fn signal_temp_directory() {
        assert!(temp_location(r"C:\Users\User\AppData\Local\Temp"));
        assert!(temp_location(r"C:\Users\User\AppData\Local\Temp\abc.exe"));
    }
    #[test]
    fn signal_encoded_command() {
        assert!(encoded_or_hidden("-EncodedCommand AAAA"));
        assert!(encoded_or_hidden("-enc AAAA"));
    }
    #[test]
    fn signal_hidden_window() {
        assert!(encoded_or_hidden("-WindowStyle Hidden"));
        assert!(encoded_or_hidden("-w hidden"));
    }
    #[test]
    fn combined_temp_encoded_powershell_is_anomalous() {
        let t = task(
            r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
            "-EncodedCommand AAAA -WindowStyle Hidden",
            r"C:\Users\User\AppData\Local\Temp",
        );
        assert!(script_host(&t.execute));
        assert!(temp_location(&t.working_directory));
        assert!(encoded_or_hidden(&t.arguments));
        assert_eq!(classify_task(&t), TaskClassification::Anomalous);
        let f = analyze(&collection(3, vec![t]));
        assert_eq!(f[0].id, "startup.scheduled_tasks.anomalous");
        assert_eq!(f[0].severity, Severity::Medium);
    }
    #[test]
    fn powershell_alone_is_reviewable_not_anomalous() {
        assert_eq!(
            classify_task(&task(
                "powershell.exe",
                "-File script.ps1",
                r"C:\Program Files\Example"
            )),
            TaskClassification::Reviewable
        );
    }
    #[test]
    fn program_files_is_known() {
        assert_eq!(
            classify_task(&task(
                r"C:\Program Files\Vendor\updater.exe",
                "--startup",
                ""
            )),
            TaskClassification::KnownLocation
        );
    }
    #[test]
    fn reviewable_updater_is_optional() {
        let mut t = task(
            r"C:\Users\User\AppData\Local\Programs\Opera\launcher.exe",
            "--autoupdate",
            r"C:\Users\User\AppData\Local\Programs\Opera",
        );
        t.task_name = "Opera scheduled Autoupdate".into();
        assert_eq!(
            task_decision(&t, TaskClassification::Reviewable),
            TaskDecision::Optional
        );
    }

    #[test]
    fn missing_resolved_updater_is_review_not_optional() {
        let mut t = task(
            r"C:\Users\User\AppData\Local\Programs\Vendor\autoupdate\updater.exe",
            "--scheduledtask --autoupdate",
            "",
        );
        t.task_name = "Vendor scheduled Autoupdate".into();
        t.resolved_executable =
            r"C:\Users\User\AppData\Local\Programs\Vendor\autoupdate\updater.exe".into();
        t.executable_exists = false;

        assert!(has_resolved_missing_executable(&t));
        assert_eq!(
            task_decision(&t, TaskClassification::Reviewable),
            TaskDecision::Review
        );
        assert_eq!(executable_existence_label(&t), "No — destino inexistente");
        assert!(task_reason(&t, TaskClassification::Reviewable).contains("actualmente no existe"));
    }

    #[test]
    fn resolved_missing_executable_gets_residual_intelligence() {
        let mut t = task(
            r"C:\Users\User\AppData\Local\Programs\Vendor\old.exe",
            "--startup",
            "",
        );
        t.resolved_executable = r"C:\Users\User\AppData\Local\Programs\Vendor\old.exe".into();
        t.executable_exists = false;

        let intelligence = residual_task_intelligence(&t).expect("expected residual intelligence");
        assert!(intelligence.contains("Posible tarea residual"));
        assert!(intelligence.contains("destino no existe actualmente"));
        assert!(intelligence.contains("revisar si el software asociado sigue instalado"));
        assert!(intelligence.contains(&t.resolved_executable));
    }

    #[test]
    fn unresolved_executable_gets_no_residual_claim() {
        let t = task("vendor.exe", "--startup", "");
        assert!(residual_task_intelligence(&t).is_none());
    }

    #[test]
    fn existing_executable_gets_no_residual_claim() {
        let mut t = task(
            r"C:\Users\User\AppData\Local\Programs\Vendor\app.exe",
            "--startup",
            "",
        );
        t.resolved_executable = r"C:\Users\User\AppData\Local\Programs\Vendor\app.exe".into();
        t.executable_exists = true;

        assert!(residual_task_intelligence(&t).is_none());
    }

    #[test]
    fn residual_intelligence_does_not_change_anomalous_priority() {
        let mut t = task(
            "powershell.exe",
            "-EncodedCommand AAAA",
            r"C:\Users\User\AppData\Local\Temp",
        );
        t.resolved_executable = r"C:\Missing\powershell.exe".into();
        t.executable_exists = false;

        assert_eq!(classify_task(&t), TaskClassification::Anomalous);
        assert_eq!(
            task_decision(&t, TaskClassification::Anomalous),
            TaskDecision::PriorityReview
        );
        assert!(residual_task_intelligence(&t).is_some());
    }

    #[test]
    fn unresolved_executable_is_not_claimed_missing() {
        let t = task("vendor.exe", "--startup", "");
        assert!(!has_resolved_missing_executable(&t));
        assert_eq!(executable_existence_label(&t), "No determinado");
    }

    #[test]
    fn existing_updater_can_remain_optional() {
        let mut t = task(
            r"C:\Users\User\AppData\Local\Programs\Vendor\updater.exe",
            "--autoupdate",
            "",
        );
        t.task_name = "Vendor Autoupdate".into();
        t.resolved_executable = r"C:\Users\User\AppData\Local\Programs\Vendor\updater.exe".into();
        t.executable_exists = true;

        assert_eq!(
            task_decision(&t, TaskClassification::Reviewable),
            TaskDecision::Optional
        );
        assert_eq!(executable_existence_label(&t), "Sí");
    }

    #[test]
    fn reviewable_script_host_stays_review() {
        let t = task("powershell.exe", "-File script.ps1", r"C:\Scripts");
        assert_eq!(
            task_decision(&t, TaskClassification::Reviewable),
            TaskDecision::Review
        );
    }

    #[test]
    fn anomalous_task_is_priority_review() {
        let t = task(
            "powershell.exe",
            "-EncodedCommand AAAA",
            r"C:\Users\User\AppData\Local\Temp",
        );
        assert_eq!(
            task_decision(&t, TaskClassification::Anomalous),
            TaskDecision::PriorityReview
        );
    }

    #[test]
    fn intelligence_line_explains_execution_context() {
        let mut t = task(
            r"C:\Users\User\AppData\Local\DS4Windows\DS4Windows.exe",
            "--minimized",
            r"C:\Users\User\AppData\Local\DS4Windows",
        );
        t.task_name = "RunDS4Windows".into();
        let line = task_intelligence_line(&t, TaskClassification::Reviewable);
        assert!(line.contains("RunDS4Windows"));
        assert!(line.contains("Ejecuta:"));
        assert!(line.contains("Argumentos:"));
        assert!(line.contains("Carpeta:"));
        assert!(line.contains("Motivo:"));
    }
    #[test]
    fn valid_signed_identity_can_keep_normal_reviewable_task() {
        let mut t = task(
            r"C:\Users\User\AppData\Local\Vendor\App.exe",
            "--startup",
            r"C:\Users\User\AppData\Local\Vendor",
        );
        t.executable_exists = true;
        t.resolved_executable = r"C:\Users\User\AppData\Local\Vendor\App.exe".into();
        t.signature_status = "Valid".into();
        t.signer = "CN=Vendor".into();
        t.product_name = "Vendor App".into();

        assert_eq!(
            task_decision(&t, TaskClassification::Reviewable),
            TaskDecision::Keep
        );
    }

    #[test]
    fn valid_signature_does_not_override_script_host_review() {
        let mut t = task("powershell.exe", "-File script.ps1", r"C:\Scripts");
        t.executable_exists = true;
        t.resolved_executable = r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe".into();
        t.signature_status = "Valid".into();
        t.signer = "CN=Microsoft Windows".into();

        assert_eq!(
            task_decision(&t, TaskClassification::Reviewable),
            TaskDecision::Review
        );
    }

    #[test]
    fn valid_signature_never_overrides_anomalous_priority() {
        let mut t = task(
            "powershell.exe",
            "-EncodedCommand AAAA",
            r"C:\Users\User\AppData\Local\Temp",
        );
        t.executable_exists = true;
        t.resolved_executable = r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe".into();
        t.signature_status = "Valid".into();
        t.signer = "CN=Microsoft Windows".into();

        assert_eq!(classify_task(&t), TaskClassification::Anomalous);
        assert_eq!(
            task_decision(&t, TaskClassification::Anomalous),
            TaskDecision::PriorityReview
        );
    }

    #[test]
    fn unresolved_executable_is_not_trusted_identity() {
        let mut t = task(
            r"C:\Users\User\AppData\Local\Vendor\App.exe",
            "--startup",
            r"C:\Users\User\AppData\Local\Vendor",
        );
        t.signature_status = "Valid".into();
        t.signer = "CN=Vendor".into();

        assert!(!has_trusted_executable_identity(&t));
        assert_eq!(
            task_decision(&t, TaskClassification::Reviewable),
            TaskDecision::Review
        );
    }

    #[test]
    fn high_program_count_only_medium() {
        let f = analyze(&collection(18, vec![]));
        assert_eq!(f[0].severity, Severity::Medium);
    }
}
