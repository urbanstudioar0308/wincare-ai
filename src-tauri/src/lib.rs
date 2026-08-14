use serde::Serialize;
use std::{
    env,
    fs,
    path::{Path, PathBuf},
    thread,
    time::{Duration, SystemTime},
};
use sysinfo::{Disks, System};

#[derive(Serialize)]
struct SystemStats {
    cpu_usage: f32,
    ram_used_gb: f64,
    ram_total_gb: f64,
    ram_usage_percent: f64,
    disk_used_gb: f64,
    disk_total_gb: f64,
    disk_free_gb: f64,
    disk_usage_percent: f64,
}

#[derive(Serialize, Clone)]
struct CleanupCategory {
    id: String,
    name: String,
    path: String,
    file_count: u64,
    size_bytes: u64,
    accessible: bool,
}

#[derive(Serialize)]
struct CleanupScan {
    total_files: u64,
    total_bytes: u64,
    categories: Vec<CleanupCategory>,
}

#[derive(Serialize)]
struct CleanupResult {
    deleted_files: u64,
    deleted_bytes: u64,
    skipped_files: u64,
    failed_files: u64,
    categories_processed: u64,
}

fn scan_directory(path: &Path) -> (u64, u64, bool) {
    if !path.exists() {
        return (0, 0, false);
    }

    let mut files = 0_u64;
    let mut bytes = 0_u64;
    let mut stack: Vec<PathBuf> = vec![path.to_path_buf()];

    const MAX_FILES: u64 = 250_000;

    while let Some(current) = stack.pop() {
        let entries = match fs::read_dir(&current) {
            Ok(entries) => entries,
            Err(_) => continue,
        };

        for entry in entries.flatten() {
            if files >= MAX_FILES {
                return (files, bytes, true);
            }

            let entry_path = entry.path();

            let metadata = match fs::symlink_metadata(&entry_path) {
                Ok(metadata) => metadata,
                Err(_) => continue,
            };

            if metadata.file_type().is_symlink() {
                continue;
            }

            if metadata.is_dir() {
                stack.push(entry_path);
            } else if metadata.is_file() {
                files = files.saturating_add(1);
                bytes = bytes.saturating_add(metadata.len());
            }
        }
    }

    (files, bytes, true)
}

fn make_category(id: &str, name: &str, path: PathBuf) -> CleanupCategory {
    let (file_count, size_bytes, accessible) = scan_directory(&path);

    CleanupCategory {
        id: id.to_string(),
        name: name.to_string(),
        path: path.to_string_lossy().to_string(),
        file_count,
        size_bytes,
        accessible,
    }
}

fn category_path(id: &str) -> Option<PathBuf> {
    match id {
        "user_temp" => Some(env::temp_dir()),

        "windows_temp" => Some(PathBuf::from(r"C:\Windows\Temp")),

        "thumbnail_cache" => {
            env::var("LOCALAPPDATA").ok().map(|local| {
                PathBuf::from(local)
                    .join("Microsoft")
                    .join("Windows")
                    .join("Explorer")
            })
        }

        _ => None,
    }
}

fn is_old_enough(metadata: &fs::Metadata) -> bool {
    const MIN_AGE_HOURS: u64 = 24;

    let modified = match metadata.modified() {
        Ok(value) => value,
        Err(_) => return false,
    };

    let age = match SystemTime::now().duration_since(modified) {
        Ok(value) => value,
        Err(_) => return false,
    };

    age >= Duration::from_secs(MIN_AGE_HOURS * 60 * 60)
}

fn clean_directory(path: &Path) -> (u64, u64, u64, u64) {
    if !path.exists() {
        return (0, 0, 0, 0);
    }

    let mut deleted_files = 0_u64;
    let mut deleted_bytes = 0_u64;
    let mut skipped_files = 0_u64;
    let mut failed_files = 0_u64;

    let mut stack: Vec<(PathBuf, bool)> =
        vec![(path.to_path_buf(), false)];

    const MAX_ITEMS: u64 = 250_000;
    let mut processed = 0_u64;

    while let Some((current, visited)) = stack.pop() {
        if processed >= MAX_ITEMS {
            break;
        }

        if visited {
            // Nunca eliminar la carpeta raíz de la categoría.
            if current != path {
                let _ = fs::remove_dir(&current);
            }

            continue;
        }

        let metadata = match fs::symlink_metadata(&current) {
            Ok(metadata) => metadata,
            Err(_) => continue,
        };

        if metadata.file_type().is_symlink() {
            skipped_files = skipped_files.saturating_add(1);
            continue;
        }

        if metadata.is_file() {
            processed = processed.saturating_add(1);

            if !is_old_enough(&metadata) {
                skipped_files = skipped_files.saturating_add(1);
                continue;
            }

            let size = metadata.len();

            match fs::remove_file(&current) {
                Ok(_) => {
                    deleted_files = deleted_files.saturating_add(1);
                    deleted_bytes = deleted_bytes.saturating_add(size);
                }
                Err(_) => {
                    failed_files = failed_files.saturating_add(1);
                }
            }

            continue;
        }

        if metadata.is_dir() {
            stack.push((current.clone(), true));

            let entries = match fs::read_dir(&current) {
                Ok(entries) => entries,
                Err(_) => continue,
            };

            for entry in entries.flatten() {
                stack.push((entry.path(), false));
            }
        }
    }

    (
        deleted_files,
        deleted_bytes,
        skipped_files,
        failed_files,
    )
}

#[tauri::command]
fn run_cleanup(category_ids: Vec<String>) -> CleanupResult {
    let mut deleted_files = 0_u64;
    let mut deleted_bytes = 0_u64;
    let mut skipped_files = 0_u64;
    let mut failed_files = 0_u64;
    let mut categories_processed = 0_u64;

    for id in category_ids {
        // Lista blanca estricta.
        let Some(path) = category_path(&id) else {
            continue;
        };

        categories_processed =
            categories_processed.saturating_add(1);

        let (
            category_deleted,
            category_bytes,
            category_skipped,
            category_failed,
        ) = clean_directory(&path);

        deleted_files =
            deleted_files.saturating_add(category_deleted);

        deleted_bytes =
            deleted_bytes.saturating_add(category_bytes);

        skipped_files =
            skipped_files.saturating_add(category_skipped);

        failed_files =
            failed_files.saturating_add(category_failed);
    }

    CleanupResult {
        deleted_files,
        deleted_bytes,
        skipped_files,
        failed_files,
        categories_processed,
    }
}

#[tauri::command]
fn scan_cleanup() -> CleanupScan {
    let mut categories: Vec<CleanupCategory> = Vec::new();

    categories.push(make_category(
        "user_temp",
        "Temporales del usuario",
        env::temp_dir(),
    ));

    categories.push(make_category(
        "windows_temp",
        "Temporales de Windows",
        PathBuf::from(r"C:\Windows\Temp"),
    ));

    if let Ok(local_app_data) = env::var("LOCALAPPDATA") {
        let thumbnail_cache =
            PathBuf::from(local_app_data)
                .join("Microsoft")
                .join("Windows")
                .join("Explorer");

        categories.push(make_category(
            "thumbnail_cache",
            "Caché de miniaturas",
            thumbnail_cache,
        ));
    }

    let total_files =
        categories.iter().map(|c| c.file_count).sum();

    let total_bytes =
        categories.iter().map(|c| c.size_bytes).sum();

    CleanupScan {
        total_files,
        total_bytes,
        categories,
    }
}

#[tauri::command]
fn get_system_stats() -> SystemStats {
    let mut system = System::new_all();

    system.refresh_cpu_usage();
    thread::sleep(sysinfo::MINIMUM_CPU_UPDATE_INTERVAL);
    system.refresh_cpu_usage();
    system.refresh_memory();

    let cpu_usage = system.global_cpu_usage();

    let total_memory = system.total_memory() as f64;
    let used_memory = system.used_memory() as f64;

    let bytes_per_gb = 1024_f64.powi(3);

    let ram_total_gb = total_memory / bytes_per_gb;
    let ram_used_gb = used_memory / bytes_per_gb;

    let ram_usage_percent = if total_memory > 0.0 {
        (used_memory / total_memory) * 100.0
    } else {
        0.0
    };

    let disks = Disks::new_with_refreshed_list();

    let mut disk_total = 0_u64;
    let mut disk_available = 0_u64;

    for disk in disks.list() {
        let mount = disk.mount_point().to_string_lossy();

        if mount.eq_ignore_ascii_case("C:\\") {
            disk_total = disk.total_space();
            disk_available = disk.available_space();
            break;
        }
    }

    let disk_used = disk_total.saturating_sub(disk_available);

    let disk_total_gb =
        disk_total as f64 / bytes_per_gb;

    let disk_free_gb =
        disk_available as f64 / bytes_per_gb;

    let disk_used_gb =
        disk_used as f64 / bytes_per_gb;

    let disk_usage_percent = if disk_total > 0 {
        (disk_used as f64 / disk_total as f64) * 100.0
    } else {
        0.0
    };

    SystemStats {
        cpu_usage,
        ram_used_gb,
        ram_total_gb,
        ram_usage_percent,
        disk_used_gb,
        disk_total_gb,
        disk_free_gb,
        disk_usage_percent,
    }
}


#[derive(Serialize, Clone)]
struct LargeFile {
    name: String,
    path: String,
    size_bytes: u64,
    modified_unix: u64,
}

#[derive(Serialize)]
struct StorageScan {
    total_files_scanned: u64,
    total_large_files: u64,
    total_large_bytes: u64,
    files: Vec<LargeFile>,
}

fn scan_large_files_in_directory(
    root: &Path,
    min_size: u64,
    results: &mut Vec<LargeFile>,
    scanned: &mut u64,
) {
    if !root.exists() {
        return;
    }

    let mut stack: Vec<PathBuf> = vec![root.to_path_buf()];

    const MAX_SCANNED_FILES: u64 = 300_000;
    const MAX_RESULTS: usize = 500;

    while let Some(current) = stack.pop() {
        if *scanned >= MAX_SCANNED_FILES {
            break;
        }

        let entries = match fs::read_dir(&current) {
            Ok(entries) => entries,
            Err(_) => continue,
        };

        for entry in entries.flatten() {
            if *scanned >= MAX_SCANNED_FILES {
                break;
            }

            let path = entry.path();

            let metadata = match fs::symlink_metadata(&path) {
                Ok(metadata) => metadata,
                Err(_) => continue,
            };

            if metadata.file_type().is_symlink() {
                continue;
            }

            if metadata.is_dir() {
                stack.push(path);
                continue;
            }

            if !metadata.is_file() {
                continue;
            }

            *scanned = scanned.saturating_add(1);

            let size = metadata.len();

            if size < min_size {
                continue;
            }

            let modified_unix = metadata
                .modified()
                .ok()
                .and_then(|time| {
                    time.duration_since(SystemTime::UNIX_EPOCH).ok()
                })
                .map(|duration| duration.as_secs())
                .unwrap_or(0);

            let name = path
                .file_name()
                .map(|name| name.to_string_lossy().to_string())
                .unwrap_or_else(|| "Archivo".to_string());

            results.push(LargeFile {
                name,
                path: path.to_string_lossy().to_string(),
                size_bytes: size,
                modified_unix,
            });

            if results.len() > MAX_RESULTS * 2 {
                results.sort_by(|a, b| b.size_bytes.cmp(&a.size_bytes));
                results.truncate(MAX_RESULTS);
            }
        }
    }
}

#[tauri::command]
fn scan_large_files(min_size_mb: u64) -> StorageScan {
    let min_size = min_size_mb
        .saturating_mul(1024)
        .saturating_mul(1024);

    let mut roots: Vec<PathBuf> = Vec::new();

    if let Ok(user_profile) = env::var("USERPROFILE") {
        let user = PathBuf::from(user_profile);

        for folder in [
            "Desktop",
            "Documents",
            "Downloads",
            "Pictures",
            "Videos",
            "Music",
        ] {
            let path = user.join(folder);

            if path.exists() {
                roots.push(path);
            }
        }
    }

    let mut files: Vec<LargeFile> = Vec::new();
    let mut total_files_scanned = 0_u64;

    for root in roots {
        scan_large_files_in_directory(
            &root,
            min_size,
            &mut files,
            &mut total_files_scanned,
        );
    }

    files.sort_by(|a, b| b.size_bytes.cmp(&a.size_bytes));
    files.truncate(500);

    let total_large_bytes =
        files.iter().map(|file| file.size_bytes).sum();

    let total_large_files = files.len() as u64;

    StorageScan {
        total_files_scanned,
        total_large_files,
        total_large_bytes,
        files,
    }
}

#[derive(Serialize, Clone)]
struct ProcessInfo {
    pid: u32,
    name: String,
    cpu_usage: f32,
    memory_bytes: u64,
}

#[derive(Serialize)]
struct ProcessSnapshot {
    process_count: u64,
    total_memory_bytes: u64,
    processes: Vec<ProcessInfo>,
}

#[tauri::command]
fn get_processes() -> ProcessSnapshot {
    let mut system = System::new_all();

    system.refresh_processes(
        sysinfo::ProcessesToUpdate::All,
        true,
    );

    thread::sleep(sysinfo::MINIMUM_CPU_UPDATE_INTERVAL);

    system.refresh_processes(
        sysinfo::ProcessesToUpdate::All,
        true,
    );

    let mut processes: Vec<ProcessInfo> = system
        .processes()
        .iter()
        .map(|(pid, process)| ProcessInfo {
            pid: pid.as_u32(),
            name: process
                .name()
                .to_string_lossy()
                .to_string(),
            cpu_usage: process.cpu_usage(),
            memory_bytes: process.memory(),
        })
        .collect();

    processes.sort_by(|a, b| {
        b.memory_bytes
            .cmp(&a.memory_bytes)
            .then_with(|| {
                b.cpu_usage
                    .partial_cmp(&a.cpu_usage)
                    .unwrap_or(std::cmp::Ordering::Equal)
            })
    });

    processes.truncate(200);

    let total_memory_bytes =
        processes.iter().map(|p| p.memory_bytes).sum();

    ProcessSnapshot {
        process_count: processes.len() as u64,
        total_memory_bytes,
        processes,
    }
}

#[cfg(target_os = "windows")]
use winreg::{
    enums::{HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE},
    RegKey,
};

#[derive(Serialize, Clone)]
struct StartupItem {
    id: String,
    name: String,
    command: String,
    source: String,
    location: String,
    enabled: bool,
    editable: bool,
}

#[derive(Serialize)]
struct StartupSnapshot {
    total_items: u64,
    items: Vec<StartupItem>,
}

#[cfg(target_os = "windows")]
fn read_registry_startup(
    hive: winreg::HKEY,
    key_path: &str,
    source_name: &str,
    editable: bool,
    items: &mut Vec<StartupItem>,
) {
    let root = RegKey::predef(hive);

    let key = match root.open_subkey(key_path) {
        Ok(key) => key,
        Err(_) => return,
    };

    for value in key.enum_values().flatten() {
        let (name, _) = value;

        let command: String = match key.get_value(&name) {
            Ok(value) => value,
            Err(_) => continue,
        };

        items.push(StartupItem {
            id: format!("registry:{}:{}", source_name, name),
            name,
            command,
            source: source_name.to_string(),
            location: key_path.to_string(),
            enabled: true,
            editable,
        });
    }
}

#[cfg(target_os = "windows")]
fn read_disabled_user_startup(
    items: &mut Vec<StartupItem>,
) {
    let root = RegKey::predef(HKEY_CURRENT_USER);

    let key = match root.open_subkey(
        r"Software\WinCareAI\DisabledStartup"
    ) {
        Ok(key) => key,
        Err(_) => return,
    };

    for value in key.enum_values().flatten() {
        let (name, _) = value;

        let command: String = match key.get_value(&name) {
            Ok(value) => value,
            Err(_) => continue,
        };

        items.push(StartupItem {
            id: format!("disabled-user:{}", name),
            name,
            command,
            source: "Registro - Usuario".to_string(),
            location:
                r"Software\Microsoft\Windows\CurrentVersion\Run"
                    .to_string(),
            enabled: false,
            editable: true,
        });
    }
}

#[cfg(target_os = "windows")]
#[tauri::command]
fn set_startup_enabled(
    name: String,
    enabled: bool,
) -> Result<(), String> {
    if name.trim().is_empty() {
        return Err("Nombre de entrada invalido".to_string());
    }

    let hkcu = RegKey::predef(HKEY_CURRENT_USER);

    let run_path =
        r"Software\Microsoft\Windows\CurrentVersion\Run";

    let backup_path =
        r"Software\WinCareAI\DisabledStartup";

    let (run_key, _) = hkcu
        .create_subkey(run_path)
        .map_err(|e| format!(
            "No se pudo abrir la clave de inicio: {}",
            e
        ))?;

    let (backup_key, _) = hkcu
        .create_subkey(backup_path)
        .map_err(|e| format!(
            "No se pudo crear el respaldo: {}",
            e
        ))?;

    if enabled {
        let command: String = backup_key
            .get_value(&name)
            .map_err(|_| {
                "No existe una copia de respaldo para esta entrada"
                    .to_string()
            })?;

        run_key
            .set_value(&name, &command)
            .map_err(|e| format!(
                "No se pudo restaurar la entrada: {}",
                e
            ))?;

        backup_key
            .delete_value(&name)
            .map_err(|e| format!(
                "La entrada se restauro pero no se pudo quitar el respaldo: {}",
                e
            ))?;
    } else {
        let command: String = run_key
            .get_value(&name)
            .map_err(|_| {
                "No se encontro la entrada activa"
                    .to_string()
            })?;

        backup_key
            .set_value(&name, &command)
            .map_err(|e| format!(
                "No se pudo crear la copia de seguridad: {}",
                e
            ))?;

        run_key
            .delete_value(&name)
            .map_err(|e| format!(
                "Se creo el respaldo pero no se pudo desactivar: {}",
                e
            ))?;
    }

    Ok(())
}
fn read_startup_folder(
    folder: PathBuf,
    source_name: &str,
    items: &mut Vec<StartupItem>,
) {
    if !folder.exists() {
        return;
    }

    let entries = match fs::read_dir(&folder) {
        Ok(entries) => entries,
        Err(_) => return,
    };

    for entry in entries.flatten() {
        let path = entry.path();

        let metadata = match fs::symlink_metadata(&path) {
            Ok(metadata) => metadata,
            Err(_) => continue,
        };

        if !metadata.is_file() {
            continue;
        }

        let name = path
            .file_name()
            .map(|name| name.to_string_lossy().to_string())
            .unwrap_or_else(|| "Elemento".to_string());

        if name.eq_ignore_ascii_case("desktop.ini") {
            continue;
        }

        items.push(StartupItem {
            id: format!(
                "folder:{}:{}",
                source_name,
                path.to_string_lossy()
            ),
            name,
            command: path.to_string_lossy().to_string(),
            source: source_name.to_string(),
            location: folder.to_string_lossy().to_string(),
            enabled: true,
            editable: false,
        });
    }
}

#[tauri::command]
fn get_startup_items() -> StartupSnapshot {
    let mut items: Vec<StartupItem> = Vec::new();

    #[cfg(target_os = "windows")]
    {
        read_registry_startup(
            HKEY_CURRENT_USER,
            r"Software\Microsoft\Windows\CurrentVersion\Run",
            "Registro - Usuario",
            true,
            &mut items,
        );

        read_disabled_user_startup(
            &mut items,
        );

        read_registry_startup(
            HKEY_LOCAL_MACHINE,
            r"Software\Microsoft\Windows\CurrentVersion\Run",
            "Registro - Equipo",
            false,
            &mut items,
        );
    }

    if let Ok(appdata) = env::var("APPDATA") {
        let user_startup = PathBuf::from(appdata)
            .join("Microsoft")
            .join("Windows")
            .join("Start Menu")
            .join("Programs")
            .join("Startup");

        read_startup_folder(
            user_startup,
            "Carpeta Inicio - Usuario",
            &mut items,
        );
    }

    if let Ok(program_data) = env::var("PROGRAMDATA") {
        let common_startup = PathBuf::from(program_data)
            .join("Microsoft")
            .join("Windows")
            .join("Start Menu")
            .join("Programs")
            .join("StartUp");

        read_startup_folder(
            common_startup,
            "Carpeta Inicio - Equipo",
            &mut items,
        );
    }

    items.sort_by(|a, b| {
        a.name
            .to_lowercase()
            .cmp(&b.name.to_lowercase())
    });

    StartupSnapshot {
        total_items: items.len() as u64,
        items,
    }
}

#[derive(Serialize, Clone)]
struct PerformanceRecommendation {
    level: String,
    title: String,
    description: String,
    target: String,
}

#[derive(Serialize)]
struct PerformanceAnalysis {
    score: u32,
    status: String,
    cpu_usage: f32,
    ram_usage_percent: f64,
    disk_usage_percent: f64,
    heavy_processes: u64,
    active_startup_items: u64,
    recommendations: Vec<PerformanceRecommendation>,
}

#[tauri::command]
fn get_performance_analysis() -> PerformanceAnalysis {
    let mut system = System::new_all();

    system.refresh_cpu_usage();

    system.refresh_processes(
        sysinfo::ProcessesToUpdate::All,
        true,
    );

    thread::sleep(sysinfo::MINIMUM_CPU_UPDATE_INTERVAL);

    system.refresh_cpu_usage();

    system.refresh_processes(
        sysinfo::ProcessesToUpdate::All,
        true,
    );

    system.refresh_memory();

    let cpu_usage = system.global_cpu_usage();

    let total_memory = system.total_memory() as f64;
    let used_memory = system.used_memory() as f64;

    let ram_usage_percent = if total_memory > 0.0 {
        (used_memory / total_memory) * 100.0
    } else {
        0.0
    };

    let disks = Disks::new_with_refreshed_list();

    let mut disk_total = 0_u64;
    let mut disk_available = 0_u64;

    for disk in disks.list() {
        let mount = disk.mount_point().to_string_lossy();

        if mount.eq_ignore_ascii_case("C:\\") {
            disk_total = disk.total_space();
            disk_available = disk.available_space();
            break;
        }
    }

    let disk_used =
        disk_total.saturating_sub(disk_available);

    let disk_usage_percent = if disk_total > 0 {
        (disk_used as f64 / disk_total as f64) * 100.0
    } else {
        0.0
    };

    let cpu_count =
        system.cpus().len().max(1) as f32;

    let heavy_processes = system
        .processes()
        .values()
        .filter(|process| {
            let normalized_cpu =
                process.cpu_usage() / cpu_count;

            process.memory() >= 300 * 1024 * 1024
                || normalized_cpu >= 5.0
        })
        .count() as u64;

    let startup_snapshot = get_startup_items();

    let active_startup_items = startup_snapshot
        .items
        .iter()
        .filter(|item| item.enabled)
        .count() as u64;

    let mut score: i32 = 100;

    // RAM
    if ram_usage_percent >= 90.0 {
        score -= 28;
    } else if ram_usage_percent >= 80.0 {
        score -= 20;
    } else if ram_usage_percent >= 70.0 {
        score -= 12;
    } else if ram_usage_percent >= 60.0 {
        score -= 6;
    }

    // CPU
    if cpu_usage >= 90.0 {
        score -= 20;
    } else if cpu_usage >= 75.0 {
        score -= 14;
    } else if cpu_usage >= 60.0 {
        score -= 8;
    } else if cpu_usage >= 40.0 {
        score -= 4;
    }

    // Disco
    if disk_usage_percent >= 95.0 {
        score -= 25;
    } else if disk_usage_percent >= 90.0 {
        score -= 18;
    } else if disk_usage_percent >= 80.0 {
        score -= 10;
    } else if disk_usage_percent >= 70.0 {
        score -= 5;
    }

    // Procesos pesados
    if heavy_processes >= 10 {
        score -= 12;
    } else if heavy_processes >= 6 {
        score -= 8;
    } else if heavy_processes >= 3 {
        score -= 4;
    }

    // Inicio
    if active_startup_items >= 15 {
        score -= 10;
    } else if active_startup_items >= 10 {
        score -= 7;
    } else if active_startup_items >= 6 {
        score -= 4;
    }

    score = score.clamp(0, 100);

    let status = if score >= 90 {
        "Excelente"
    } else if score >= 75 {
        "Bueno"
    } else if score >= 60 {
        "Atención"
    } else {
        "Necesita revisión"
    }
    .to_string();

    let mut recommendations: Vec<PerformanceRecommendation> =
        Vec::new();

    if ram_usage_percent >= 75.0 {
        recommendations.push(
            PerformanceRecommendation {
                level: if ram_usage_percent >= 90.0 {
                    "high"
                } else {
                    "medium"
                }
                .to_string(),

                title:
                    "Uso elevado de memoria RAM".to_string(),

                description: format!(
                    "La memoria está utilizando aproximadamente {:.0}% de su capacidad.",
                    ram_usage_percent
                ),

                target: "processes".to_string(),
            },
        );
    }

    if heavy_processes >= 3 {
        recommendations.push(
            PerformanceRecommendation {
                level: "medium".to_string(),

                title:
                    "Hay procesos con consumo elevado".to_string(),

                description: format!(
                    "Detectamos {} procesos con consumo elevado de CPU o memoria.",
                    heavy_processes
                ),

                target: "processes".to_string(),
            },
        );
    }

    if active_startup_items >= 6 {
        recommendations.push(
            PerformanceRecommendation {
                level: "medium".to_string(),

                title:
                    "Revisá los programas de inicio".to_string(),

                description: format!(
                    "{} programas están configurados para iniciarse automáticamente.",
                    active_startup_items
                ),

                target: "startup".to_string(),
            },
        );
    }

    if disk_usage_percent >= 80.0 {
        recommendations.push(
            PerformanceRecommendation {
                level: if disk_usage_percent >= 90.0 {
                    "high"
                } else {
                    "medium"
                }
                .to_string(),

                title:
                    "Poco espacio disponible".to_string(),

                description: format!(
                    "La unidad C está ocupada aproximadamente al {:.0}%.",
                    disk_usage_percent
                ),

                target: "storage".to_string(),
            },
        );
    }

    if cpu_usage >= 75.0 {
        recommendations.push(
            PerformanceRecommendation {
                level: "medium".to_string(),

                title:
                    "CPU con carga elevada".to_string(),

                description: format!(
                    "El procesador está trabajando aproximadamente al {:.0}%.",
                    cpu_usage
                ),

                target: "processes".to_string(),
            },
        );
    }

    if recommendations.is_empty() {
        recommendations.push(
            PerformanceRecommendation {
                level: "good".to_string(),

                title:
                    "No detectamos problemas importantes".to_string(),

                description:
                    "Los principales indicadores del sistema están dentro de valores razonables."
                        .to_string(),

                target: "dashboard".to_string(),
            },
        );
    }

    PerformanceAnalysis {
        score: score as u32,
        status,
        cpu_usage,
        ram_usage_percent,
        disk_usage_percent,
        heavy_processes,
        active_startup_items,
        recommendations,
    }
}

#[derive(Serialize, serde::Deserialize, Clone)]
struct AnalysisHistoryEntry {
    id: String,
    timestamp: u64,
    score: u32,
    status: String,
    cpu_usage: f32,
    ram_usage: f64,
    disk_usage: f64,
    cleanup_bytes: u64,
    large_files_bytes: u64,
    heavy_processes: u64,
    startup_active: u64,
}

fn history_file_path() -> PathBuf {
    let base = env::var("LOCALAPPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."));

    let folder = base.join("WinCareAI");

    let _ = fs::create_dir_all(&folder);

    folder.join("analysis-history.json")
}

fn load_history_internal() -> Vec<AnalysisHistoryEntry> {
    let path = history_file_path();

    if !path.exists() {
        return Vec::new();
    }

    let content = match fs::read_to_string(&path) {
        Ok(content) => content,
        Err(_) => return Vec::new(),
    };

    serde_json::from_str::<Vec<AnalysisHistoryEntry>>(&content)
        .unwrap_or_default()
}

fn save_history_internal(
    history: &[AnalysisHistoryEntry],
) -> Result<(), String> {
    let path = history_file_path();

    let json = serde_json::to_string_pretty(history)
        .map_err(|e| format!(
            "No se pudo serializar el historial: {}",
            e
        ))?;

    fs::write(&path, json)
        .map_err(|e| format!(
            "No se pudo guardar el historial: {}",
            e
        ))
}

#[tauri::command]
fn save_analysis_history(
    score: u32,
    status: String,
    cpu_usage: f32,
    ram_usage: f64,
    disk_usage: f64,
    cleanup_bytes: u64,
    large_files_bytes: u64,
    heavy_processes: u64,
    startup_active: u64,
) -> Result<AnalysisHistoryEntry, String> {
    let mut history = load_history_internal();

    let timestamp = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .map_err(|e| format!(
            "No se pudo calcular timestamp: {}",
            e
        ))?
        .as_secs();

    let entry = AnalysisHistoryEntry {
        id: format!("{}", timestamp),
        timestamp,
        score,
        status,
        cpu_usage,
        ram_usage,
        disk_usage,
        cleanup_bytes,
        large_files_bytes,
        heavy_processes,
        startup_active,
    };

    history.push(entry.clone());

    // Mantener un maximo razonable para el MVP.
    if history.len() > 500 {
        let excess = history.len() - 500;
        history.drain(0..excess);
    }

    save_history_internal(&history)?;

    Ok(entry)
}

#[tauri::command]
fn get_analysis_history() -> Vec<AnalysisHistoryEntry> {
    let mut history = load_history_internal();

    history.sort_by(|a, b| {
        b.timestamp.cmp(&a.timestamp)
    });

    history
}

#[tauri::command]
fn clear_analysis_history() -> Result<(), String> {
    let path = history_file_path();

    if path.exists() {
        fs::remove_file(&path)
            .map_err(|e| format!(
                "No se pudo borrar el historial: {}",
                e
            ))?;
    }

    Ok(())
}

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


#[derive(Serialize, serde::Deserialize, Clone)]
struct EvidenceItem {
    id: String,
    timestamp: u64,
    source: String,
    category: String,
    severity: String,
    title: String,
    observed_value: String,
    explanation: String,
    technical_data: String,
}

#[derive(Serialize, serde::Deserialize, Clone)]
struct AdvancedSystemSnapshot {
    id: String,
    timestamp: u64,
    cpu_usage: f32,
    ram_usage_percent: f64,
    disk_usage_percent: f64,
    process_count: u64,
    heavy_processes: u64,
    startup_active: u64,
    evidences: Vec<EvidenceItem>,
}

fn unix_now() -> Result<u64, String> {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .map_err(|e| format!("No se pudo calcular timestamp: {}", e))
}

fn advanced_snapshot_file_path() -> PathBuf {
    let base = env::var("LOCALAPPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."));
    let folder = base.join("WinCareAI");
    let _ = fs::create_dir_all(&folder);
    folder.join("advanced-system-snapshots.json")
}

fn load_advanced_snapshots_internal() -> Vec<AdvancedSystemSnapshot> {
    let path = advanced_snapshot_file_path();
    if !path.exists() { return Vec::new(); }
    fs::read_to_string(path)
        .ok()
        .and_then(|v| serde_json::from_str(&v).ok())
        .unwrap_or_default()
}

fn save_advanced_snapshots_internal(items: &[AdvancedSystemSnapshot]) -> Result<(), String> {
    let json = serde_json::to_string_pretty(items)
        .map_err(|e| format!("No se pudo serializar snapshot avanzado: {}", e))?;
    fs::write(advanced_snapshot_file_path(), json)
        .map_err(|e| format!("No se pudo guardar snapshot avanzado: {}", e))
}

fn make_evidence(
    timestamp: u64, source: &str, category: &str, severity: &str,
    title: &str, observed_value: String, explanation: &str, technical_data: String
) -> EvidenceItem {
    EvidenceItem {
        id: format!("{}-{}-{}", timestamp, category, source),
        timestamp,
        source: source.to_string(),
        category: category.to_string(),
        severity: severity.to_string(),
        title: title.to_string(),
        observed_value,
        explanation: explanation.to_string(),
        technical_data,
    }
}

#[tauri::command]
fn capture_advanced_system_snapshot() -> Result<AdvancedSystemSnapshot, String> {
    let timestamp = unix_now()?;
    let stats = get_system_stats();
    let processes = get_processes();
    let startup = get_startup_items();

    let cpu_count = System::new_all().cpus().len().max(1) as f32;
    let heavy_processes = processes.processes.iter().filter(|p| {
        p.memory_bytes >= 300 * 1024 * 1024 || (p.cpu_usage / cpu_count) >= 5.0
    }).count() as u64;
    let startup_active = startup.items.iter().filter(|i| i.enabled).count() as u64;

    let mut evidences = Vec::new();

    if stats.ram_usage_percent >= 75.0 {
        evidences.push(make_evidence(
            timestamp, "system", "ram",
            if stats.ram_usage_percent >= 90.0 { "high" } else { "medium" },
            "Uso elevado de memoria RAM",
            format!("{:.1}%", stats.ram_usage_percent),
            "La memoria en uso supera el umbral de observacion de WinCare AI.",
            format!("used_gb={:.2};total_gb={:.2}", stats.ram_used_gb, stats.ram_total_gb),
        ));
    }

    if stats.disk_usage_percent >= 80.0 {
        evidences.push(make_evidence(
            timestamp, "system", "storage",
            if stats.disk_usage_percent >= 90.0 { "high" } else { "medium" },
            "Unidad del sistema con ocupacion elevada",
            format!("{:.1}%", stats.disk_usage_percent),
            "La unidad C tiene poco margen libre y puede requerir revision.",
            format!("used_gb={:.2};free_gb={:.2};total_gb={:.2}",
                stats.disk_used_gb, stats.disk_free_gb, stats.disk_total_gb),
        ));
    }

    if stats.cpu_usage >= 75.0 {
        evidences.push(make_evidence(
            timestamp, "system", "cpu", "medium",
            "Carga elevada de CPU",
            format!("{:.1}%", stats.cpu_usage),
            "La CPU presento una carga elevada durante la captura.",
            format!("cpu_usage={:.2}", stats.cpu_usage),
        ));
    }

    if heavy_processes >= 3 {
        evidences.push(make_evidence(
            timestamp, "processes", "processes", "medium",
            "Procesos con consumo elevado",
            heavy_processes.to_string(),
            "Se detectaron varios procesos que superan los criterios actuales de consumo.",
            format!("heavy_processes={};captured_processes={}", heavy_processes, processes.process_count),
        ));
    }

    if startup_active >= 6 {
        evidences.push(make_evidence(
            timestamp, "startup", "startup", "medium",
            "Carga de inicio relevante",
            startup_active.to_string(),
            "Hay varias entradas activas configuradas para ejecutarse con Windows.",
            format!("active={};total={}", startup_active, startup.total_items),
        ));
    }

    let snapshot = AdvancedSystemSnapshot {
        id: format!("advanced-{}", timestamp),
        timestamp,
        cpu_usage: stats.cpu_usage,
        ram_usage_percent: stats.ram_usage_percent,
        disk_usage_percent: stats.disk_usage_percent,
        process_count: processes.process_count,
        heavy_processes,
        startup_active,
        evidences,
    };

    let mut history = load_advanced_snapshots_internal();
    history.push(snapshot.clone());
    if history.len() > 100 {
        let excess = history.len() - 100;
        history.drain(0..excess);
    }
    save_advanced_snapshots_internal(&history)?;
    Ok(snapshot)
}

#[tauri::command]
fn get_advanced_system_snapshots() -> Vec<AdvancedSystemSnapshot> {
    let mut items = load_advanced_snapshots_internal();
    items.sort_by(|a,b| b.timestamp.cmp(&a.timestamp));
    items
}

#[tauri::command]
fn clear_advanced_system_snapshots() -> Result<(), String> {
    let path = advanced_snapshot_file_path();
    if path.exists() {
        fs::remove_file(path)
            .map_err(|e| format!("No se pudieron borrar snapshots avanzados: {}", e))?;
    }
    Ok(())
}

#[derive(Serialize, Clone)]
struct CpuProcessSample {
    pid: u32,
    name: String,
    cpu_percent: f32,
}

#[derive(Serialize, Clone)]
struct CpuAdvancedDiagnosis {
    timestamp: u64,
    logical_cpus: u64,
    brand: String,
    sample_count: u64,
    sample_interval_ms: u64,
    average_usage: f32,
    peak_usage: f32,
    minimum_usage: f32,
    sustained_high_samples: u64,
    top_processes: Vec<CpuProcessSample>,
    evidences: Vec<EvidenceItem>,
}

#[tauri::command]
fn get_cpu_advanced_diagnosis() -> Result<CpuAdvancedDiagnosis, String> {
    let timestamp = unix_now()?;
    let mut system = System::new_all();

    system.refresh_cpu_usage();
    system.refresh_processes(sysinfo::ProcessesToUpdate::All, true);

    let logical_cpus = system.cpus().len().max(1) as u64;
    let brand = system.cpus().first()
        .map(|cpu| cpu.brand().to_string())
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "CPU".to_string());

    const SAMPLE_COUNT: usize = 5;
    let interval = sysinfo::MINIMUM_CPU_UPDATE_INTERVAL;
    let sample_interval_ms = interval.as_millis() as u64;

    let mut samples: Vec<f32> = Vec::with_capacity(SAMPLE_COUNT);

    for _ in 0..SAMPLE_COUNT {
        thread::sleep(interval);
        system.refresh_cpu_usage();
        system.refresh_processes(sysinfo::ProcessesToUpdate::All, true);
        samples.push(system.global_cpu_usage());
    }

    let average_usage =
        samples.iter().copied().sum::<f32>() / samples.len() as f32;
    let peak_usage = samples.iter().copied().fold(0.0_f32, f32::max);
    let minimum_usage = samples.iter().copied().fold(100.0_f32, f32::min);
    let sustained_high_samples =
        samples.iter().filter(|value| **value >= 80.0).count() as u64;

    let cpu_divisor = logical_cpus.max(1) as f32;
    let mut top_processes: Vec<CpuProcessSample> = system.processes()
        .iter()
        .map(|(pid, process)| CpuProcessSample {
            pid: pid.as_u32(),
            name: process.name().to_string_lossy().to_string(),
            cpu_percent: process.cpu_usage() / cpu_divisor,
        })
        .filter(|process| process.cpu_percent >= 0.1)
        .collect();

    top_processes.sort_by(|a,b|
        b.cpu_percent.partial_cmp(&a.cpu_percent)
            .unwrap_or(std::cmp::Ordering::Equal)
    );
    top_processes.truncate(10);

    let mut evidences = Vec::new();

    if sustained_high_samples >= 4 || average_usage >= 85.0 {
        evidences.push(make_evidence(
            timestamp,
            "cpu_sampler",
            "cpu",
            "high",
            "Carga de CPU alta y sostenida",
            format!("{:.1}% promedio", average_usage),
            "La carga se mantuvo elevada durante la mayor parte del muestreo, no solo en un pico aislado.",
            format!(
                "samples={:?};peak={:.2};minimum={:.2};high_samples={}/{}",
                samples, peak_usage, minimum_usage, sustained_high_samples, SAMPLE_COUNT
            ),
        ));
    } else if sustained_high_samples >= 2 || average_usage >= 65.0 {
        evidences.push(make_evidence(
            timestamp,
            "cpu_sampler",
            "cpu",
            "medium",
            "Actividad elevada de CPU",
            format!("{:.1}% promedio", average_usage),
            "El procesador mostró actividad relevante durante varias muestras. Conviene revisar los procesos responsables.",
            format!(
                "samples={:?};peak={:.2};minimum={:.2};high_samples={}/{}",
                samples, peak_usage, minimum_usage, sustained_high_samples, SAMPLE_COUNT
            ),
        ));
    } else if peak_usage >= 90.0 && average_usage < 65.0 {
        evidences.push(make_evidence(
            timestamp,
            "cpu_sampler",
            "cpu",
            "low",
            "Pico breve de CPU",
            format!("{:.1}% pico", peak_usage),
            "Se observó un pico alto, pero no fue sostenido durante el muestreo.",
            format!("samples={:?};average={:.2}", samples, average_usage),
        ));
    }

    if let Some(top) = top_processes.first() {
        if top.cpu_percent >= 25.0 {
            evidences.push(make_evidence(
                timestamp,
                "process_sampler",
                "cpu",
                if top.cpu_percent >= 50.0 { "high" } else { "medium" },
                "Proceso con consumo destacado de CPU",
                format!("{} · {:.1}%", top.name, top.cpu_percent),
                "Un proceso concentra una parte relevante del uso de CPU observado al finalizar el muestreo.",
                format!("pid={};process={};normalized_cpu={:.2}", top.pid, top.name, top.cpu_percent),
            ));
        }
    }

    Ok(CpuAdvancedDiagnosis {
        timestamp,
        logical_cpus,
        brand,
        sample_count: SAMPLE_COUNT as u64,
        sample_interval_ms,
        average_usage,
        peak_usage,
        minimum_usage,
        sustained_high_samples,
        top_processes,
        evidences,
    })
}

#[derive(Serialize, Clone)]
struct RamProcessSample {
    pid: u32,
    name: String,
    memory_bytes: u64,
    memory_percent: f64,
}

#[derive(Serialize, Clone)]
struct RamAdvancedDiagnosis {
    timestamp: u64,
    total_bytes: u64,
    used_bytes: u64,
    available_bytes: u64,
    usage_percent: f64,
    swap_total_bytes: u64,
    swap_used_bytes: u64,
    swap_free_bytes: u64,
    swap_usage_percent: f64,
    process_count: u64,
    processes_over_500mb: u64,
    top_processes: Vec<RamProcessSample>,
    evidences: Vec<EvidenceItem>,
}

#[tauri::command]
fn get_ram_advanced_diagnosis() -> Result<RamAdvancedDiagnosis, String> {
    let timestamp = unix_now()?;
    let mut system = System::new_all();

    system.refresh_memory();
    system.refresh_processes(sysinfo::ProcessesToUpdate::All, true);

    let total_bytes = system.total_memory();
    let used_bytes = system.used_memory();
    let available_bytes = system.available_memory();

    let usage_percent = if total_bytes > 0 {
        (used_bytes as f64 / total_bytes as f64) * 100.0
    } else {
        0.0
    };

    let swap_total_bytes = system.total_swap();
    let swap_used_bytes = system.used_swap();
    let swap_free_bytes = system.free_swap();

    let swap_usage_percent = if swap_total_bytes > 0 {
        (swap_used_bytes as f64 / swap_total_bytes as f64) * 100.0
    } else {
        0.0
    };

    let process_count = system.processes().len() as u64;

    let mut top_processes: Vec<RamProcessSample> = system
        .processes()
        .iter()
        .map(|(pid, process)| {
            let memory_bytes = process.memory();
            let memory_percent = if total_bytes > 0 {
                (memory_bytes as f64 / total_bytes as f64) * 100.0
            } else {
                0.0
            };

            RamProcessSample {
                pid: pid.as_u32(),
                name: process.name().to_string_lossy().to_string(),
                memory_bytes,
                memory_percent,
            }
        })
        .filter(|process| process.memory_bytes > 0)
        .collect();

    top_processes.sort_by(|a, b| b.memory_bytes.cmp(&a.memory_bytes));

    let processes_over_500mb = top_processes
        .iter()
        .filter(|process| process.memory_bytes >= 500 * 1024 * 1024)
        .count() as u64;

    top_processes.truncate(10);

    let mut evidences = Vec::new();

    if usage_percent >= 90.0 {
        evidences.push(make_evidence(
            timestamp,
            "memory",
            "ram",
            "high",
            "Presión crítica de memoria RAM",
            format!("{:.1}% en uso", usage_percent),
            "La memoria física está muy ocupada. Windows puede depender con mayor frecuencia de memoria virtual y el equipo puede perder capacidad de respuesta.",
            format!(
                "used_bytes={};available_bytes={};total_bytes={};swap_used_bytes={}",
                used_bytes, available_bytes, total_bytes, swap_used_bytes
            ),
        ));
    } else if usage_percent >= 75.0 {
        evidences.push(make_evidence(
            timestamp,
            "memory",
            "ram",
            "medium",
            "Presión elevada de memoria RAM",
            format!("{:.1}% en uso", usage_percent),
            "La RAM disponible es reducida. Conviene revisar qué procesos concentran memoria antes de concluir que falta capacidad física.",
            format!(
                "used_bytes={};available_bytes={};total_bytes={}",
                used_bytes, available_bytes, total_bytes
            ),
        ));
    }

    if swap_total_bytes > 0 && swap_usage_percent >= 50.0 {
        evidences.push(make_evidence(
            timestamp,
            "memory",
            "ram",
            if swap_usage_percent >= 80.0 { "high" } else { "medium" },
            "Uso relevante de memoria virtual",
            format!("{:.1}% del swap en uso", swap_usage_percent),
            "El sistema está utilizando una parte importante de la memoria virtual. Esto puede acompañar una presión elevada de RAM, aunque por sí solo no demuestra un problema.",
            format!(
                "swap_used_bytes={};swap_total_bytes={};ram_usage={:.2}",
                swap_used_bytes, swap_total_bytes, usage_percent
            ),
        ));
    }

    if let Some(top) = top_processes.first() {
        if top.memory_bytes >= 1024 * 1024 * 1024 || top.memory_percent >= 20.0 {
            evidences.push(make_evidence(
                timestamp,
                "processes",
                "ram",
                if top.memory_percent >= 30.0 { "high" } else { "medium" },
                "Proceso con consumo destacado de memoria",
                format!("{} · {:.1}%", top.name, top.memory_percent),
                "Un proceso concentra una parte relevante de la memoria física. WinCare AI lo señala como evidencia, no como prueba automática de una fuga de memoria.",
                format!(
                    "pid={};process={};memory_bytes={};memory_percent={:.2}",
                    top.pid, top.name, top.memory_bytes, top.memory_percent
                ),
            ));
        }
    }

    if processes_over_500mb >= 4 {
        evidences.push(make_evidence(
            timestamp,
            "processes",
            "ram",
            "medium",
            "Varios procesos con consumo alto de memoria",
            processes_over_500mb.to_string(),
            "Hay varios procesos utilizando al menos 500 MB cada uno. La presión total puede deberse a la suma de aplicaciones y no a un único responsable.",
            format!(
                "processes_over_500mb={};process_count={}",
                processes_over_500mb, process_count
            ),
        ));
    }

    Ok(RamAdvancedDiagnosis {
        timestamp,
        total_bytes,
        used_bytes,
        available_bytes,
        usage_percent,
        swap_total_bytes,
        swap_used_bytes,
        swap_free_bytes,
        swap_usage_percent,
        process_count,
        processes_over_500mb,
        top_processes,
        evidences,
    })
}

#[derive(Serialize, Clone)]
struct StorageVolumeDiagnosis {
    name: String,
    mount_point: String,
    file_system: String,
    total_bytes: u64,
    available_bytes: u64,
    used_bytes: u64,
    usage_percent: f64,
    removable: bool,
}

#[derive(Serialize, Clone)]
struct PhysicalDiskHealth {
    friendly_name: String,
    serial_number: String,
    media_type: String,
    bus_type: String,
    health_status: String,
    operational_status: String,
    size_bytes: u64,
    temperature_celsius: Option<f64>,
    wear_percent: Option<f64>,
    read_errors_total: Option<u64>,
    write_errors_total: Option<u64>,
    power_on_hours: Option<u64>,
    reliability_available: bool,
}

#[derive(serde::Deserialize)]
struct PhysicalDiskPowerShellRow {
    #[serde(rename = "FriendlyName")]
    friendly_name: Option<String>,
    #[serde(rename = "SerialNumber")]
    serial_number: Option<String>,
    #[serde(rename = "MediaType")]
    media_type: Option<String>,
    #[serde(rename = "BusType")]
    bus_type: Option<String>,
    #[serde(rename = "HealthStatus")]
    health_status: Option<String>,
    #[serde(rename = "OperationalStatus")]
    operational_status: Option<serde_json::Value>,
    #[serde(rename = "Size")]
    size: Option<u64>,
    #[serde(rename = "Temperature")]
    temperature: Option<f64>,
    #[serde(rename = "Wear")]
    wear: Option<f64>,
    #[serde(rename = "ReadErrorsTotal")]
    read_errors_total: Option<u64>,
    #[serde(rename = "WriteErrorsTotal")]
    write_errors_total: Option<u64>,
    #[serde(rename = "PowerOnHours")]
    power_on_hours: Option<u64>,
}
#[derive(Serialize, Clone)]
struct StorageAdvancedDiagnosis {
    timestamp: u64,
    volume_count: u64,
    total_bytes: u64,
    available_bytes: u64,
    used_bytes: u64,
    usage_percent: f64,
    trim_query_available: bool,
    trim_enabled: Option<bool>,
    trim_raw: String,
    volumes: Vec<StorageVolumeDiagnosis>,
    physical_disks_available: bool,
    physical_disks_error: String,
    physical_disks: Vec<PhysicalDiskHealth>,    evidences: Vec<EvidenceItem>,
}

#[tauri::command]
fn get_storage_advanced_diagnosis() -> Result<StorageAdvancedDiagnosis, String> {
    let timestamp = unix_now()?;
    let disks = sysinfo::Disks::new_with_refreshed_list();

    let mut volumes = Vec::new();
    let mut total_bytes = 0_u64;
    let mut available_bytes = 0_u64;

    for disk in disks.list() {
        let total = disk.total_space();
        if total == 0 {
            continue;
        }

        let available = disk.available_space();
        let used = total.saturating_sub(available);
        let usage_percent = (used as f64 / total as f64) * 100.0;

        total_bytes = total_bytes.saturating_add(total);
        available_bytes = available_bytes.saturating_add(available);

        volumes.push(StorageVolumeDiagnosis {
            name: disk.name().to_string_lossy().to_string(),
            mount_point: disk.mount_point().to_string_lossy().to_string(),
            file_system: disk.file_system().to_string_lossy().to_string(),
            total_bytes: total,
            available_bytes: available,
            used_bytes: used,
            usage_percent,
            removable: disk.is_removable(),
        });
    }

    volumes.sort_by(|a, b| {
        b.usage_percent
            .partial_cmp(&a.usage_percent)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    let used_bytes = total_bytes.saturating_sub(available_bytes);
    let usage_percent = if total_bytes > 0 {
        (used_bytes as f64 / total_bytes as f64) * 100.0
    } else {
        0.0
    };

    // fsutil devuelve "0" cuando TRIM está habilitado y "1" cuando está
    // deshabilitado. Si Windows no permite consultar el dato, se informa
    // como no disponible: nunca se interpreta como una falla.
    let trim_output = std::process::Command::new("fsutil")
        .args(["behavior", "query", "DisableDeleteNotify"])
        .output();

    let (trim_query_available, trim_enabled, trim_raw) = match trim_output {
        Ok(output) if output.status.success() => {
            let raw = String::from_utf8_lossy(&output.stdout).trim().to_string();
            let ntfs_line = raw
                .lines()
                .find(|line| line.to_ascii_lowercase().contains("ntfs"))
                .unwrap_or(raw.as_str());

            let enabled = if ntfs_line.contains("= 0") {
                Some(true)
            } else if ntfs_line.contains("= 1") {
                Some(false)
            } else {
                None
            };

            (true, enabled, raw)
        }
        Ok(output) => {
            let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
            (false, None, stderr)
        }
        Err(error) => (false, None, error.to_string()),
    };

    // Windows puede no exponer ReliabilityCounter en ciertos USB/RAID/controladores.
    // La ausencia de esos datos se conserva como "no disponible", nunca como fallo.
    let physical_script = r#"
$ErrorActionPreference = 'Stop'
$rows = @()
Get-PhysicalDisk | ForEach-Object {
    $d = $_
    $r = $null
    try { $r = $d | Get-StorageReliabilityCounter -ErrorAction Stop } catch {}
    $rows += [PSCustomObject]@{
        FriendlyName      = [string]$d.FriendlyName
        SerialNumber      = [string]$d.SerialNumber
        MediaType         = [string]$d.MediaType
        BusType           = [string]$d.BusType
        HealthStatus      = [string]$d.HealthStatus
        OperationalStatus = @($d.OperationalStatus | ForEach-Object { [string]$_ })
        Size              = [uint64]$d.Size
        Temperature       = if ($null -ne $r -and $null -ne $r.Temperature) { [double]$r.Temperature } else { $null }
        Wear              = if ($null -ne $r -and $null -ne $r.Wear) { [double]$r.Wear } else { $null }
        ReadErrorsTotal   = if ($null -ne $r -and $null -ne $r.ReadErrorsTotal) { [uint64]$r.ReadErrorsTotal } else { $null }
        WriteErrorsTotal  = if ($null -ne $r -and $null -ne $r.WriteErrorsTotal) { [uint64]$r.WriteErrorsTotal } else { $null }
        PowerOnHours      = if ($null -ne $r -and $null -ne $r.PowerOnHours) { [uint64]$r.PowerOnHours } else { $null }
    }
}
@($rows) | ConvertTo-Json -Depth 5 -Compress
"#;

    let physical_output = std::process::Command::new("powershell")
        .args([
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            physical_script,
        ])
        .output();

    let mut physical_disks_available = false;
    let mut physical_disks_error = String::new();
    let mut physical_disks: Vec<PhysicalDiskHealth> = Vec::new();

    match physical_output {
        Ok(output) if output.status.success() => {
            let raw = String::from_utf8_lossy(&output.stdout).trim().to_string();

            if raw.is_empty() {
                physical_disks_error = "Windows no devolvio discos fisicos.".to_string();
            } else {
                match serde_json::from_str::<Vec<PhysicalDiskPowerShellRow>>(&raw) {
                    Ok(rows) => {
                        physical_disks_available = true;

                        physical_disks = rows.into_iter().map(|row| {
                            let operational_status = match row.operational_status {
                                Some(serde_json::Value::Array(values)) => values
                                    .iter()
                                    .filter_map(|value| value.as_str())
                                    .collect::<Vec<_>>()
                                    .join(", "),
                                Some(serde_json::Value::String(value)) => value,
                                Some(value) => value.to_string(),
                                None => "No disponible".to_string(),
                            };

                            let reliability_available =
                                row.temperature.is_some()
                                || row.wear.is_some()
                                || row.read_errors_total.is_some()
                                || row.write_errors_total.is_some()
                                || row.power_on_hours.is_some();

                            PhysicalDiskHealth {
                                friendly_name: row.friendly_name.unwrap_or_else(|| "Disco".to_string()),
                                serial_number: row.serial_number.unwrap_or_default(),
                                media_type: row.media_type.unwrap_or_else(|| "No disponible".to_string()),
                                bus_type: row.bus_type.unwrap_or_else(|| "No disponible".to_string()),
                                health_status: row.health_status.unwrap_or_else(|| "No disponible".to_string()),
                                operational_status,
                                size_bytes: row.size.unwrap_or(0),
                                temperature_celsius: row.temperature,
                                wear_percent: row.wear,
                                read_errors_total: row.read_errors_total,
                                write_errors_total: row.write_errors_total,
                                power_on_hours: row.power_on_hours,
                                reliability_available,
                            }
                        }).collect();
                    }
                    Err(error) => {
                        physical_disks_error =
                            format!("Windows devolvio datos fisicos no interpretables: {}", error);
                    }
                }
            }
        }
        Ok(output) => {
            physical_disks_error =
                String::from_utf8_lossy(&output.stderr).trim().to_string();

            if physical_disks_error.is_empty() {
                physical_disks_error =
                    "La consulta de salud fisica no estuvo disponible.".to_string();
            }
        }
        Err(error) => {
            physical_disks_error = error.to_string();
        }
    }
    let mut evidences = Vec::new();

    for volume in &volumes {
        if volume.removable {
            continue;
        }

        if volume.usage_percent >= 95.0 {
            evidences.push(make_evidence(
                timestamp,
                "storage",
                "disk",
                "high",
                "Volumen con espacio crítico",
                format!("{} · {:.1}% en uso", volume.mount_point, volume.usage_percent),
                "El volumen tiene muy poco espacio libre. Esto puede afectar actualizaciones, archivos temporales, memoria virtual y tareas de mantenimiento de Windows.",
                format!(
                    "mount={};total_bytes={};available_bytes={};usage_percent={:.2}",
                    volume.mount_point, volume.total_bytes, volume.available_bytes, volume.usage_percent
                ),
            ));
        } else if volume.usage_percent >= 85.0 {
            evidences.push(make_evidence(
                timestamp,
                "storage",
                "disk",
                "medium",
                "Volumen con poco espacio disponible",
                format!("{} · {:.1}% en uso", volume.mount_point, volume.usage_percent),
                "El volumen supera el umbral de ocupación recomendado por WinCare AI. Conviene revisar qué está creciendo antes de que el espacio sea crítico.",
                format!(
                    "mount={};total_bytes={};available_bytes={};usage_percent={:.2}",
                    volume.mount_point, volume.total_bytes, volume.available_bytes, volume.usage_percent
                ),
            ));
        }
    }

    if trim_query_available && trim_enabled == Some(false) {
        evidences.push(make_evidence(
            timestamp,
            "storage",
            "trim",
            "medium",
            "TRIM aparece deshabilitado",
            "DisableDeleteNotify = 1".to_string(),
            "Windows informa que las notificaciones de eliminación para TRIM están deshabilitadas. WinCare AI solo informa el estado; este bloque no modifica la configuración.",
            trim_raw.clone(),
        ));
    }

    if volumes.is_empty() {
        evidences.push(make_evidence(
            timestamp,
            "storage",
            "disk",
            "low",
            "No se pudieron enumerar volúmenes",
            "0 volúmenes".to_string(),
            "La API local no devolvió volúmenes de almacenamiento en esta lectura. Esto no implica por sí mismo una falla física.",
            "sysinfo Disks returned no volumes".to_string(),
        ));
    }

    for disk in &physical_disks {
        let health = disk.health_status.to_ascii_lowercase();

        if health.contains("unhealthy") || health.contains("warning") {
            evidences.push(make_evidence(
                timestamp,
                "storage",
                "physical_health",
                if health.contains("unhealthy") { "high" } else { "medium" },
                "Windows informa una advertencia de salud del disco",
                format!("{} · {}", disk.friendly_name, disk.health_status),
                "El estado proviene de la capa de almacenamiento de Windows. Conviene respaldar datos importantes y revisar el dispositivo antes de realizar optimizaciones.",
                format!(
                    "model={};bus={};media={};operational={}",
                    disk.friendly_name,
                    disk.bus_type,
                    disk.media_type,
                    disk.operational_status
                ),
            ));
        }

        if let Some(temp) = disk.temperature_celsius {
            if temp >= 70.0 {
                evidences.push(make_evidence(
                    timestamp,
                    "storage",
                    "temperature",
                    "high",
                    "Temperatura elevada del almacenamiento",
                    format!("{} · {:.0} °C", disk.friendly_name, temp),
                    "El dispositivo expone una temperatura elevada. Conviene revisar ventilacion y carga sostenida.",
                    format!("model={};temperature_celsius={:.1}", disk.friendly_name, temp),
                ));
            } else if temp >= 60.0 {
                evidences.push(make_evidence(
                    timestamp,
                    "storage",
                    "temperature",
                    "medium",
                    "Temperatura alta del almacenamiento",
                    format!("{} · {:.0} °C", disk.friendly_name, temp),
                    "La temperatura merece seguimiento si permanece elevada durante cargas normales.",
                    format!("model={};temperature_celsius={:.1}", disk.friendly_name, temp),
                ));
            }
        }

        if let Some(wear) = disk.wear_percent {
            if wear >= 90.0 {
                evidences.push(make_evidence(
                    timestamp,
                    "storage",
                    "wear",
                    "high",
                    "Desgaste elevado informado por el dispositivo",
                    format!("{} · {:.0}%", disk.friendly_name, wear),
                    "El contador de desgaste es elevado. Su interpretacion exacta depende del fabricante y controlador.",
                    format!("model={};wear={:.1}", disk.friendly_name, wear),
                ));
            }
        }
    }
    Ok(StorageAdvancedDiagnosis {
        timestamp,
        volume_count: volumes.len() as u64,
        total_bytes,
        available_bytes,
        used_bytes,
        usage_percent,
        trim_query_available,
        trim_enabled,
        trim_raw,
        volumes,
        physical_disks_available,
        physical_disks_error,
        physical_disks,        evidences,
    })
}

#[derive(Serialize, Clone)]
struct StartupAdvancedItem {
    name: String,
    command: String,
    location: String,
    user: String,
}

#[derive(Serialize, Clone)]
struct StartupScheduledTask {
    task_name: String,
    task_path: String,
    state: String,
    triggers: String,
}

#[derive(Serialize, Clone)]
struct StartupAdvancedDiagnosis {
    timestamp: u64,
    startup_count: u64,
    scheduled_task_count: u64,
    startup_items: Vec<StartupAdvancedItem>,
    scheduled_tasks: Vec<StartupScheduledTask>,
    query_available: bool,
    query_error: String,
    evidences: Vec<EvidenceItem>,
}

#[derive(serde::Deserialize)]
struct StartupAdvancedPowerShell {
    #[serde(rename = "StartupItems")]
    startup_items: Option<Vec<StartupAdvancedPowerShellItem>>,
    #[serde(rename = "ScheduledTasks")]
    scheduled_tasks: Option<Vec<StartupAdvancedPowerShellTask>>,
}

#[derive(serde::Deserialize)]
struct StartupAdvancedPowerShellItem {
    #[serde(rename = "Name")]
    name: Option<String>,
    #[serde(rename = "Command")]
    command: Option<String>,
    #[serde(rename = "Location")]
    location: Option<String>,
    #[serde(rename = "User")]
    user: Option<String>,
}

#[derive(serde::Deserialize)]
struct StartupAdvancedPowerShellTask {
    #[serde(rename = "TaskName")]
    task_name: Option<String>,
    #[serde(rename = "TaskPath")]
    task_path: Option<String>,
    #[serde(rename = "State")]
    state: Option<String>,
    #[serde(rename = "Triggers")]
    triggers: Option<String>,
}

#[tauri::command]
fn get_startup_advanced_diagnosis() -> Result<StartupAdvancedDiagnosis, String> {
    let timestamp = unix_now()?;

    // Solo lectura. Win32_StartupCommand cubre las fuentes principales de
    // inicio registradas por Windows. Las tareas se limitan a triggers de
    // arranque/inicio de sesion y no se modifican.
    let script = r#"
$ErrorActionPreference = 'Stop'

$startup = @(
    Get-CimInstance Win32_StartupCommand -ErrorAction Stop |
    ForEach-Object {
        [PSCustomObject]@{
            Name     = [string]$_.Name
            Command  = [string]$_.Command
            Location = [string]$_.Location
            User     = [string]$_.User
        }
    }
)

$tasks = @()
try {
    Get-ScheduledTask -ErrorAction Stop | ForEach-Object {
        $task = $_
        $triggerNames = @(
            $task.Triggers | ForEach-Object {
                if ($null -ne $_.CimClass) { [string]$_.CimClass.CimClassName }
            }
        )

        $interesting = @(
            $triggerNames | Where-Object {
                $_ -match 'BootTrigger|LogonTrigger'
            }
        )

        if ($interesting.Count -gt 0) {
            $tasks += [PSCustomObject]@{
                TaskName = [string]$task.TaskName
                TaskPath = [string]$task.TaskPath
                State    = [string]$task.State
                Triggers = [string]($interesting -join ', ')
            }
        }
    }
} catch {
    # StartupCommand sigue siendo util aunque Task Scheduler no este accesible.
}

[PSCustomObject]@{
    StartupItems   = @($startup)
    ScheduledTasks = @($tasks)
} | ConvertTo-Json -Depth 6 -Compress
"#;

    let output = std::process::Command::new("powershell")
        .args([
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            script,
        ])
        .output();

    let mut query_available = false;
    let mut query_error = String::new();
    let mut startup_items = Vec::new();
    let mut scheduled_tasks = Vec::new();

    match output {
        Ok(result) if result.status.success() => {
            let raw = String::from_utf8_lossy(&result.stdout).trim().to_string();

            if raw.is_empty() {
                query_error = "Windows no devolvio datos de inicio.".to_string();
            } else {
                match serde_json::from_str::<StartupAdvancedPowerShell>(&raw) {
                    Ok(data) => {
                        query_available = true;

                        startup_items = data.startup_items
                            .unwrap_or_default()
                            .into_iter()
                            .map(|item| StartupAdvancedItem {
                                name: item.name.unwrap_or_else(|| "Elemento de inicio".to_string()),
                                command: item.command.unwrap_or_default(),
                                location: item.location.unwrap_or_default(),
                                user: item.user.unwrap_or_default(),
                            })
                            .collect();

                        scheduled_tasks = data.scheduled_tasks
                            .unwrap_or_default()
                            .into_iter()
                            .map(|task| StartupScheduledTask {
                                task_name: task.task_name.unwrap_or_else(|| "Tarea".to_string()),
                                task_path: task.task_path.unwrap_or_default(),
                                state: task.state.unwrap_or_else(|| "No disponible".to_string()),
                                triggers: task.triggers.unwrap_or_default(),
                            })
                            .collect();
                    }
                    Err(error) => {
                        query_error = format!("Datos de inicio no interpretables: {}", error);
                    }
                }
            }
        }
        Ok(result) => {
            query_error = String::from_utf8_lossy(&result.stderr).trim().to_string();
            if query_error.is_empty() {
                query_error = "La consulta de inicio no estuvo disponible.".to_string();
            }
        }
        Err(error) => query_error = error.to_string(),
    }

    startup_items.sort_by(|a, b| a.name.to_ascii_lowercase().cmp(&b.name.to_ascii_lowercase()));
    scheduled_tasks.sort_by(|a, b| a.task_name.to_ascii_lowercase().cmp(&b.task_name.to_ascii_lowercase()));

    let startup_count = startup_items.len() as u64;
    let scheduled_task_count = scheduled_tasks.len() as u64;
    let mut evidences = Vec::new();

    // No clasificamos aplicaciones concretas como "malas". El volumen de
    // elementos es una señal operativa que luego se combina con contexto.
    if startup_count >= 20 {
        evidences.push(make_evidence(
            timestamp,
            "startup",
            "startup_items",
            "medium",
            "Muchos elementos configurados para iniciar con Windows",
            format!("{} elementos", startup_count),
            "Una cantidad alta de programas de inicio puede aumentar la competencia por CPU, RAM y disco durante el inicio de sesion. WinCare AI recomienda revisar cuales son realmente necesarios.",
            format!("startup_count={}", startup_count),
        ));
    } else if startup_count >= 12 {
        evidences.push(make_evidence(
            timestamp,
            "startup",
            "startup_items",
            "low",
            "Carga de inicio para revisar",
            format!("{} elementos", startup_count),
            "Hay varios elementos configurados para iniciar automaticamente. Esto no implica un problema por si solo, pero es un buen punto para revisar si el arranque se siente lento.",
            format!("startup_count={}", startup_count),
        ));
    }

    if scheduled_task_count >= 15 {
        evidences.push(make_evidence(
            timestamp,
            "startup",
            "scheduled_tasks",
            "low",
            "Varias tareas se activan al arrancar o iniciar sesion",
            format!("{} tareas", scheduled_task_count),
            "Windows tiene varias tareas programadas asociadas al arranque o inicio de sesion. Algunas pertenecen al sistema o a aplicaciones legitimas; WinCare AI no recomienda deshabilitarlas automaticamente.",
            format!("scheduled_task_count={}", scheduled_task_count),
        ));
    }

    Ok(StartupAdvancedDiagnosis {
        timestamp,
        startup_count,
        scheduled_task_count,
        startup_items,
        scheduled_tasks,
        query_available,
        query_error,
        evidences,
    })
}

#[derive(Serialize, Clone)]
struct NetworkAdapterDiagnosis {
    name: String,
    description: String,
    status: String,
    link_speed: String,
    mac_address: String,
    ipv4: Vec<String>,
    gateways: Vec<String>,
    dns_servers: Vec<String>,
    dhcp_enabled: bool,
}

#[derive(Serialize, Clone)]
struct NetworkAdvancedDiagnosis {
    timestamp: u64,
    query_available: bool,
    query_error: String,
    active_adapter_count: u64,
    adapters: Vec<NetworkAdapterDiagnosis>,
    internet_reachable: bool,
    internet_latency_ms: Option<f64>,
    dns_reachable: bool,
    dns_latency_ms: Option<f64>,
    gateway_reachable: bool,
    gateway_latency_ms: Option<f64>,
    evidences: Vec<EvidenceItem>,
}

#[derive(serde::Deserialize)]
struct NetworkPowerShellPayload {
    #[serde(rename = "Adapters")]
    adapters: Option<Vec<NetworkPowerShellAdapter>>,
    #[serde(rename = "InternetReachable")]
    internet_reachable: Option<bool>,
    #[serde(rename = "InternetLatencyMs")]
    internet_latency_ms: Option<f64>,
    #[serde(rename = "DnsReachable")]
    dns_reachable: Option<bool>,
    #[serde(rename = "DnsLatencyMs")]
    dns_latency_ms: Option<f64>,
    #[serde(rename = "GatewayReachable")]
    gateway_reachable: Option<bool>,
    #[serde(rename = "GatewayLatencyMs")]
    gateway_latency_ms: Option<f64>,
}

#[derive(serde::Deserialize)]
struct NetworkPowerShellAdapter {
    #[serde(rename = "Name")]
    name: Option<String>,
    #[serde(rename = "Description")]
    description: Option<String>,
    #[serde(rename = "Status")]
    status: Option<String>,
    #[serde(rename = "LinkSpeed")]
    link_speed: Option<String>,
    #[serde(rename = "MacAddress")]
    mac_address: Option<String>,
    #[serde(rename = "IPv4")]
    ipv4: Option<Vec<String>>,
    #[serde(rename = "Gateways")]
    gateways: Option<Vec<String>>,
    #[serde(rename = "DnsServers")]
    dns_servers: Option<Vec<String>>,
    #[serde(rename = "DhcpEnabled")]
    dhcp_enabled: Option<bool>,
}

#[tauri::command]
fn get_network_advanced_diagnosis() -> Result<NetworkAdvancedDiagnosis, String> {
    let timestamp = unix_now()?;

    // Solo lectura. No cambia DNS, IP, adaptadores ni firewall.
    // 1.1.1.1 se usa solo como objetivo IP de conectividad; la prueba DNS
    // usa www.microsoft.com para distinguir resolucion de conectividad IP.
    let script = r#"
$ErrorActionPreference = 'Stop'

$adapters = @()
$configs = @(Get-NetIPConfiguration -ErrorAction Stop)

foreach ($cfg in $configs) {
    if ($null -eq $cfg.NetAdapter) { continue }

    $adapter = $cfg.NetAdapter
    $ipv4 = @($cfg.IPv4Address | ForEach-Object { [string]$_.IPAddress } | Where-Object { $_ })
    $gateways = @($cfg.IPv4DefaultGateway | ForEach-Object { [string]$_.NextHop } | Where-Object { $_ })
    $dns = @()
    try {
        $dns = @(Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction Stop |
            ForEach-Object { $_.ServerAddresses } | Where-Object { $_ })
    } catch {}

    $dhcp = $false
    try {
        $ipif = Get-NetIPInterface -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction Stop
        $dhcp = ([string]$ipif.Dhcp -eq 'Enabled')
    } catch {}

    $adapters += [PSCustomObject]@{
        Name        = [string]$adapter.Name
        Description = [string]$adapter.InterfaceDescription
        Status      = [string]$adapter.Status
        LinkSpeed   = [string]$adapter.LinkSpeed
        MacAddress  = [string]$adapter.MacAddress
        IPv4        = @($ipv4)
        Gateways    = @($gateways)
        DnsServers  = @($dns)
        DhcpEnabled = [bool]$dhcp
    }
}

function Test-WinCarePing([string]$Target) {
    try {
        $result = Test-Connection -ComputerName $Target -Count 1 -ErrorAction Stop |
            Select-Object -First 1
        $latency = $null
        if ($null -ne $result.ResponseTime) {
            $latency = [double]$result.ResponseTime
        } elseif ($null -ne $result.Latency) {
            $latency = [double]$result.Latency
        }
        return [PSCustomObject]@{ Reachable = $true; Latency = $latency }
    } catch {
        return [PSCustomObject]@{ Reachable = $false; Latency = $null }
    }
}

$internet = Test-WinCarePing '1.1.1.1'
$dnsTest = Test-WinCarePing 'www.microsoft.com'

$gatewayTarget = @(
    $adapters | ForEach-Object { $_.Gateways } | Where-Object { $_ }
) | Select-Object -First 1

$gateway = [PSCustomObject]@{ Reachable = $false; Latency = $null }
if ($gatewayTarget) {
    $gateway = Test-WinCarePing ([string]$gatewayTarget)
}

[PSCustomObject]@{
    Adapters             = @($adapters)
    InternetReachable    = [bool]$internet.Reachable
    InternetLatencyMs    = $internet.Latency
    DnsReachable         = [bool]$dnsTest.Reachable
    DnsLatencyMs         = $dnsTest.Latency
    GatewayReachable     = [bool]$gateway.Reachable
    GatewayLatencyMs     = $gateway.Latency
} | ConvertTo-Json -Depth 7 -Compress
"#;

    let output = std::process::Command::new("powershell")
        .args([
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            script,
        ])
        .output();

    let mut query_available = false;
    let mut query_error = String::new();
    let mut adapters = Vec::new();
    let mut internet_reachable = false;
    let mut internet_latency_ms = None;
    let mut dns_reachable = false;
    let mut dns_latency_ms = None;
    let mut gateway_reachable = false;
    let mut gateway_latency_ms = None;

    match output {
        Ok(result) if result.status.success() => {
            let raw = String::from_utf8_lossy(&result.stdout).trim().to_string();
            if raw.is_empty() {
                query_error = "Windows no devolvio informacion de red.".to_string();
            } else {
                match serde_json::from_str::<NetworkPowerShellPayload>(&raw) {
                    Ok(data) => {
                        query_available = true;
                        internet_reachable = data.internet_reachable.unwrap_or(false);
                        internet_latency_ms = data.internet_latency_ms;
                        dns_reachable = data.dns_reachable.unwrap_or(false);
                        dns_latency_ms = data.dns_latency_ms;
                        gateway_reachable = data.gateway_reachable.unwrap_or(false);
                        gateway_latency_ms = data.gateway_latency_ms;

                        adapters = data.adapters
                            .unwrap_or_default()
                            .into_iter()
                            .map(|item| NetworkAdapterDiagnosis {
                                name: item.name.unwrap_or_else(|| "Adaptador".to_string()),
                                description: item.description.unwrap_or_default(),
                                status: item.status.unwrap_or_else(|| "No disponible".to_string()),
                                link_speed: item.link_speed.unwrap_or_default(),
                                mac_address: item.mac_address.unwrap_or_default(),
                                ipv4: item.ipv4.unwrap_or_default(),
                                gateways: item.gateways.unwrap_or_default(),
                                dns_servers: item.dns_servers.unwrap_or_default(),
                                dhcp_enabled: item.dhcp_enabled.unwrap_or(false),
                            })
                            .collect();
                    }
                    Err(error) => {
                        query_error = format!("Datos de red no interpretables: {}", error);
                    }
                }
            }
        }
        Ok(result) => {
            query_error = String::from_utf8_lossy(&result.stderr).trim().to_string();
            if query_error.is_empty() {
                query_error = "La consulta avanzada de red no estuvo disponible.".to_string();
            }
        }
        Err(error) => query_error = error.to_string(),
    }

    adapters.sort_by(|a, b| a.name.to_ascii_lowercase().cmp(&b.name.to_ascii_lowercase()));
    let active_adapter_count = adapters
        .iter()
        .filter(|adapter| adapter.status.eq_ignore_ascii_case("Up"))
        .count() as u64;

    let mut evidences = Vec::new();

    if query_available && active_adapter_count == 0 {
        evidences.push(make_evidence(
            timestamp,
            "network",
            "active_adapters",
            "high",
            "No hay adaptadores de red activos",
            "0 adaptadores activos".to_string(),
            "Windows no informa ningun adaptador de red en estado activo. Revisa Wi-Fi, cable Ethernet, modo avion o el estado del adaptador.",
            "active_adapter_count=0".to_string(),
        ));
    }

    if query_available && active_adapter_count > 0 && !gateway_reachable {
        evidences.push(make_evidence(
            timestamp,
            "network",
            "gateway",
            "medium",
            "La puerta de enlace no respondio",
            "Sin respuesta".to_string(),
            "Hay un adaptador activo, pero la puerta de enlace predeterminada no respondio a la prueba. Algunos routers bloquean ICMP, por lo que esta señal debe interpretarse junto con las otras pruebas.",
            "gateway_ping=false".to_string(),
        ));
    }

    if query_available && gateway_reachable && !internet_reachable {
        evidences.push(make_evidence(
            timestamp,
            "network",
            "internet",
            "high",
            "La red local responde pero Internet no",
            "1.1.1.1 sin respuesta".to_string(),
            "La puerta de enlace local respondio, pero el objetivo externo por IP no. Esto puede indicar un problema de salida a Internet, del proveedor o un bloqueo de ICMP.",
            "gateway=true;internet_ip=false".to_string(),
        ));
    }

    if query_available && internet_reachable && !dns_reachable {
        evidences.push(make_evidence(
            timestamp,
            "network",
            "dns",
            "medium",
            "Posible problema de DNS",
            "IP externa responde; nombre no".to_string(),
            "La conectividad por IP funciona, pero la prueba usando un nombre no respondio. Puede existir un problema de resolucion DNS, aunque algunos destinos pueden bloquear ping.",
            "internet_ip=true;dns_name=false".to_string(),
        ));
    }

    if let Some(latency) = internet_latency_ms {
        if latency >= 150.0 {
            evidences.push(make_evidence(
                timestamp,
                "network",
                "latency",
                "medium",
                "Latencia de Internet elevada",
                format!("{:.0} ms", latency),
                "La latencia observada en esta muestra es alta. Una sola medicion no diagnostica por si sola la conexion, pero puede justificar repetir la prueba.",
                format!("internet_latency_ms={:.1}", latency),
            ));
        } else if latency >= 80.0 {
            evidences.push(make_evidence(
                timestamp,
                "network",
                "latency",
                "low",
                "Latencia de Internet para observar",
                format!("{:.0} ms", latency),
                "La muestra presenta una latencia moderada. Conviene compararla con futuras mediciones antes de concluir que existe un problema.",
                format!("internet_latency_ms={:.1}", latency),
            ));
        }
    }

    Ok(NetworkAdvancedDiagnosis {
        timestamp,
        query_available,
        query_error,
        active_adapter_count,
        adapters,
        internet_reachable,
        internet_latency_ms,
        dns_reachable,
        dns_latency_ms,
        gateway_reachable,
        gateway_latency_ms,
        evidences,
    })
}
#[derive(Serialize, Clone)]
struct AboutSystemInfo {
    os_name: String,
    os_version: String,
    app_version: String,
    build: String,
    architecture: String,
    username: String,
    computer_name: String,
    app_ok: bool,
    app_status: String,
}

#[tauri::command]
fn get_about_system_info() -> AboutSystemInfo {
    let os_name = "Windows".to_string();

    let os_version = std::process::Command::new("cmd")
        .args(["/C", "ver"])
        .output()
        .ok()
        .and_then(|output| {
            String::from_utf8(output.stdout).ok()
        })
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "Windows".to_string());

    let username = std::env::var("USERNAME")
        .unwrap_or_else(|_| "Usuario".to_string());

    let computer_name = std::env::var("COMPUTERNAME")
        .unwrap_or_else(|_| "PC".to_string());

    let architecture = std::env::consts::ARCH.to_string();

    let app_version = env!("CARGO_PKG_VERSION").to_string();

    let build = format!(
        "{}-{}",
        env!("CARGO_PKG_VERSION"),
        std::env::consts::ARCH
    );

    AboutSystemInfo {
        os_name,
        os_version,
        app_version,
        build,
        architecture,
        username,
        computer_name,
        app_ok: true,
        app_status: "Funcionando correctamente".to_string(),
    }
}
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            get_system_stats,
            scan_cleanup,
            run_cleanup,
            scan_large_files,
            get_processes,
            get_startup_items,
            set_startup_enabled,
            get_performance_analysis,
            save_analysis_history,
            get_analysis_history,
            clear_analysis_history,
            save_change_snapshot,
            get_change_snapshots,
            get_about_system_info,
            capture_advanced_system_snapshot,
            get_advanced_system_snapshots,
            clear_advanced_system_snapshots,
            get_cpu_advanced_diagnosis,
            get_ram_advanced_diagnosis,
            get_storage_advanced_diagnosis,
            get_startup_advanced_diagnosis,
            get_network_advanced_diagnosis
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}










