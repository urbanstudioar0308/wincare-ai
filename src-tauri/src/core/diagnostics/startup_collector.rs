use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum StartupSourceKind {
    Registry,
    StartupFolder,
    ScheduledTask,
    Other,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum StartupItemState {
    Active,
    Disabled,
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct StartupCollectorInputItem {
    pub name: String,
    pub command: String,
    pub location: String,
    pub user: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct StartupCollectorInputTask {
    pub task_name: String,
    pub task_path: String,
    pub state: String,
    pub triggers: String,
    #[serde(default)]
    pub execute: String,
    #[serde(default)]
    pub arguments: String,
    #[serde(default)]
    pub working_directory: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct StartupCollectedItem {
    pub id: String,
    pub name: String,
    pub command: String,
    pub location: String,
    pub user: String,
    pub source_kind: StartupSourceKind,
    pub state: StartupItemState,
    pub editable: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct StartupCollectedTask {
    pub id: String,
    pub task_name: String,
    pub task_path: String,
    pub state: String,
    pub triggers: String,
    pub execute: String,
    pub arguments: String,
    pub working_directory: String,
    #[serde(default)]
    pub executable_exists: bool,
    #[serde(default)]
    pub resolved_executable: String,
    #[serde(default)]
    pub signature_status: String,
    #[serde(default)]
    pub signer: String,
    #[serde(default)]
    pub file_description: String,
    #[serde(default)]
    pub product_name: String,
    pub source_kind: StartupSourceKind,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct StartupCollection {
    pub items: Vec<StartupCollectedItem>,
    pub scheduled_tasks: Vec<StartupCollectedTask>,
    pub active_item_count: u64,
    pub scheduled_task_count: u64,
}

fn normalize(value: &str) -> String {
    value.trim().to_ascii_lowercase()
}

fn stable_id(prefix: &str, parts: &[&str]) -> String {
    let joined = parts
        .iter()
        .map(|part| normalize(part).replace(['\\', '/', ' ', ':'], "_"))
        .collect::<Vec<_>>()
        .join("__");

    format!("{prefix}:{joined}")
}

fn classify_source(location: &str) -> StartupSourceKind {
    let value = normalize(location);

    if value.contains("startup") {
        StartupSourceKind::StartupFolder
    } else if value.contains("currentversion") && value.contains("run") {
        StartupSourceKind::Registry
    } else {
        StartupSourceKind::Other
    }
}

fn is_editable_v1(location: &str) -> bool {
    let value = normalize(location);

    let hkcu_run = value.contains("hkcu")
        && value.contains("software")
        && value.contains("microsoft")
        && value.contains("windows")
        && value.contains("currentversion")
        && value.contains("run");

    let startup_folder = value.contains("startup");

    hkcu_run || startup_folder
}

pub fn collect(
    items: Vec<StartupCollectorInputItem>,
    scheduled_tasks: Vec<StartupCollectorInputTask>,
) -> StartupCollection {
    let mut normalized_items = items
        .into_iter()
        .map(|item| {
            let source_kind = classify_source(&item.location);
            let editable = is_editable_v1(&item.location);
            let id = stable_id("startup", &[&item.name, &item.location, &item.user]);

            StartupCollectedItem {
                id,
                name: item.name.trim().to_string(),
                command: item.command.trim().to_string(),
                location: item.location.trim().to_string(),
                user: item.user.trim().to_string(),
                source_kind,
                state: StartupItemState::Active,
                editable,
            }
        })
        .collect::<Vec<_>>();

    let mut normalized_tasks = scheduled_tasks
        .into_iter()
        .map(|task| StartupCollectedTask {
            id: stable_id("scheduled_task", &[&task.task_path, &task.task_name]),
            task_name: task.task_name.trim().to_string(),
            task_path: task.task_path.trim().to_string(),
            state: task.state.trim().to_string(),
            triggers: task.triggers.trim().to_string(),
            execute: task.execute.trim().to_string(),
            arguments: task.arguments.trim().to_string(),
            working_directory: task.working_directory.trim().to_string(),
            executable_exists: false,
            resolved_executable: String::new(),
            signature_status: String::new(),
            signer: String::new(),
            file_description: String::new(),
            product_name: String::new(),
            source_kind: StartupSourceKind::ScheduledTask,
        })
        .collect::<Vec<_>>();

    normalized_items.sort_by(|a, b| {
        a.name
            .to_ascii_lowercase()
            .cmp(&b.name.to_ascii_lowercase())
    });

    normalized_tasks.sort_by(|a, b| {
        a.task_name
            .to_ascii_lowercase()
            .cmp(&b.task_name.to_ascii_lowercase())
    });

    let active_item_count = normalized_items
        .iter()
        .filter(|item| item.state == StartupItemState::Active)
        .count() as u64;

    let scheduled_task_count = normalized_tasks.len() as u64;

    StartupCollection {
        items: normalized_items,
        scheduled_tasks: normalized_tasks,
        active_item_count,
        scheduled_task_count,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_real_startup_sources_without_modifying_them() {
        let collection = collect(
            vec![
                StartupCollectorInputItem {
                    name: "Example App".to_string(),
                    command: r#""C:\Apps\Example\example.exe""#.to_string(),
                    location:
                        r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run".to_string(),
                    user: "current-user".to_string(),
                },
                StartupCollectorInputItem {
                    name: "Example.lnk".to_string(),
                    command: r"C:\Users\User\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Example.lnk".to_string(),
                    location: "Startup".to_string(),
                    user: "current-user".to_string(),
                },
            ],
            vec![StartupCollectorInputTask {
                task_name: "ExampleTask".to_string(),
                task_path: r"\Example\".to_string(),
                state: "Ready".to_string(),
                triggers: "MSFT_TaskLogonTrigger".to_string(),
                execute: r"C:\Program Files\Example\example.exe".to_string(),
                arguments: "--startup".to_string(),
                working_directory: r"C:\Program Files\Example".to_string(),
            }],
        );

        assert_eq!(collection.active_item_count, 2);
        assert_eq!(collection.scheduled_task_count, 1);
        assert_eq!(collection.items[0].state, StartupItemState::Active);
        assert!(collection.items.iter().all(|item| item.editable));
        assert_eq!(
            collection.scheduled_tasks[0].source_kind,
            StartupSourceKind::ScheduledTask
        );
        assert_eq!(
            collection.scheduled_tasks[0].execute,
            r"C:\Program Files\Example\example.exe"
        );
        assert_eq!(collection.scheduled_tasks[0].arguments, "--startup");
        assert_eq!(
            collection.scheduled_tasks[0].working_directory,
            r"C:\Program Files\Example"
        );
    }

    #[test]
    fn unknown_location_stays_conservative() {
        let collection = collect(
            vec![StartupCollectorInputItem {
                name: "Unknown".to_string(),
                command: "unknown.exe".to_string(),
                location: "Unknown source".to_string(),
                user: String::new(),
            }],
            vec![],
        );

        assert_eq!(collection.items[0].source_kind, StartupSourceKind::Other);
        assert!(!collection.items[0].editable);
    }
}
