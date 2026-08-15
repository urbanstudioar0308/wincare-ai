
export type DiagnosticSeverity = "critical" | "high" | "medium" | "low" | "info" | "ok";
export type DiagnosticConfidence = "high" | "medium" | "low";
export type DiagnosticRiskLevel = "low" | "medium" | "high";
export type DiagnosticEvidence = { source:string; metric:string; value:string; expected:string|null; message:string; technical_data:string|null; };
export type DiagnosticRecommendation = { id:string; title:string; explanation:string; expected_impact:string|null; risk:DiagnosticRiskLevel; action_id:string|null; };
export type DiagnosticFinding = { id:string; module:string; title:string; description:string; severity:DiagnosticSeverity; confidence:DiagnosticConfidence; impacts:string[]; evidence:DiagnosticEvidence[]; recommendations:DiagnosticRecommendation[]; detected_at:number; };
import { invoke } from "@tauri-apps/api/core";

import type {
  SystemStats,
  CleanupScan,
  CleanupResult,
  StorageScan,
  ProcessSnapshot,
  StartupSnapshot,
  PerformanceAnalysis,
  AnalysisHistoryEntry,
  ChangeSnapshot,
  AboutSystemInfo,
  AdvancedSystemSnapshot,
} from "../types";

export const getSystemStats = () =>
  invoke<SystemStats>("get_system_stats");

export const scanCleanup = () =>
  invoke<CleanupScan>("scan_cleanup");

export const runCleanup = (categoryIds: string[]) =>
  invoke<CleanupResult>("run_cleanup", { categoryIds });

export const scanLargeFiles = (minSizeMb: number) =>
  invoke<StorageScan>("scan_large_files", { minSizeMb });

export const getProcesses = () =>
  invoke<ProcessSnapshot>("get_processes");

export const getStartupItems = () =>
  invoke<StartupSnapshot>("get_startup_items");

export const setStartupEnabled = (name: string, enabled: boolean) =>
  invoke<void>("set_startup_enabled", { name, enabled });

export const getPerformanceAnalysis = () =>
  invoke<PerformanceAnalysis>("get_performance_analysis");

export const saveAnalysisHistory = (args: {
  score: number;
  status: string;
  cpuUsage: number;
  ramUsage: number;
  diskUsage: number;
  cleanupBytes: number;
  largeFilesBytes: number;
  heavyProcesses: number;
  startupActive: number;
}) => invoke<void>("save_analysis_history", args);

export const getAnalysisHistory = () =>
  invoke<AnalysisHistoryEntry[]>("get_analysis_history");

export const clearAnalysisHistory = () =>
  invoke<void>("clear_analysis_history");

export const saveChangeSnapshot = (args: {
  startupActive: string[];
  heavyProcesses: string[];
  largeFiles: { name: string; path: string; size_bytes: number }[];
  cleanupCategories: {
    id: string;
    name: string;
    size_bytes: number;
    file_count: number;
  }[];
}) => invoke<void>("save_change_snapshot", args);

export const getChangeSnapshots = () =>
  invoke<ChangeSnapshot[]>("get_change_snapshots");

export const getAboutSystemInfo = () =>
  invoke<AboutSystemInfo>("get_about_system_info");
export const captureAdvancedSystemSnapshot = () =>
  invoke<AdvancedSystemSnapshot>("capture_advanced_system_snapshot");

export const getAdvancedSystemSnapshots = () =>
  invoke<AdvancedSystemSnapshot[]>("get_advanced_system_snapshots");

export const clearAdvancedSystemSnapshots = () =>
  invoke<void>("clear_advanced_system_snapshots");

export type CpuProcessSample = {
  pid: number;
  name: string;
  cpu_percent: number;
};

export type CpuAdvancedDiagnosis = {
  timestamp: number;
  logical_cpus: number;
  brand: string;
  sample_count: number;
  sample_interval_ms: number;
  average_usage: number;
  peak_usage: number;
  minimum_usage: number;
  sustained_high_samples: number;
  top_processes: CpuProcessSample[];
  evidences: AdvancedSystemSnapshot["evidences"];
};

export const getCpuAdvancedDiagnosis = () =>
  invoke<CpuAdvancedDiagnosis>("get_cpu_advanced_diagnosis");
export type RamProcessSample = {
  pid: number;
  name: string;
  memory_bytes: number;
  memory_percent: number;
};

export type RamAdvancedDiagnosis = {
  timestamp: number;
  total_bytes: number;
  used_bytes: number;
  available_bytes: number;
  usage_percent: number;
  swap_total_bytes: number;
  swap_used_bytes: number;
  swap_free_bytes: number;
  swap_usage_percent: number;
  process_count: number;
  processes_over_500mb: number;
  top_processes: RamProcessSample[];
  evidences: AdvancedSystemSnapshot["evidences"];
};

export const getRamAdvancedDiagnosis = () =>
  invoke<RamAdvancedDiagnosis>("get_ram_advanced_diagnosis");
export type StorageVolumeDiagnosis={name:string;mount_point:string;file_system:string;total_bytes:number;available_bytes:number;used_bytes:number;usage_percent:number;removable:boolean};
export type PhysicalDiskHealth={friendly_name:string;serial_number:string;media_type:string;bus_type:string;health_status:string;operational_status:string;size_bytes:number;temperature_celsius:number|null;wear_percent:number|null;read_errors_total:number|null;write_errors_total:number|null;power_on_hours:number|null;reliability_available:boolean};
export type StorageAdvancedDiagnosis={timestamp:number;volume_count:number;total_bytes:number;available_bytes:number;used_bytes:number;usage_percent:number;trim_query_available:boolean;trim_enabled:boolean|null;trim_raw:string;physical_disks_available:boolean;physical_disks_error:string;physical_disks:PhysicalDiskHealth[];volumes:StorageVolumeDiagnosis[];evidences:AdvancedSystemSnapshot["evidences"]};
export const getStorageAdvancedDiagnosis=()=>invoke<StorageAdvancedDiagnosis>("get_storage_advanced_diagnosis");
export type StartupAdvancedItem = {
  name: string;
  command: string;
  location: string;
  user: string;
};

export type StartupScheduledTask = {
  task_name: string;
  task_path: string;
  state: string;
  triggers: string;
};

export type StartupAdvancedDiagnosis = {
  timestamp: number;
  startup_count: number;
  scheduled_task_count: number;
  startup_items: StartupAdvancedItem[];
  scheduled_tasks: StartupScheduledTask[];
  query_available: boolean;
  query_error: string;
  evidences: AdvancedSystemSnapshot["evidences"];
};

export const getStartupAdvancedDiagnosis = () =>
  invoke<StartupAdvancedDiagnosis>("get_startup_advanced_diagnosis");
export type NetworkAdapterDiagnosis = {
  name: string;
  description: string;
  status: string;
  link_speed: string;
  mac_address: string;
  ipv4: string[];
  gateways: string[];
  dns_servers: string[];
  dhcp_enabled: boolean;
};

export type NetworkAdvancedDiagnosis = {
  timestamp: number;
  query_available: boolean;
  query_error: string;
  active_adapter_count: number;
  adapters: NetworkAdapterDiagnosis[];
  internet_reachable: boolean;
  internet_latency_ms: number | null;
  dns_reachable: boolean;
  dns_latency_ms: number | null;
  gateway_reachable: boolean;
  gateway_latency_ms: number | null;
  evidences: AdvancedSystemSnapshot["evidences"];
};

export const getNetworkAdvancedDiagnosis = () =>
  invoke<NetworkAdvancedDiagnosis>("get_network_advanced_diagnosis");
export type WindowsRecentEvent={time_created:string;log_name:string;provider:string;event_id:number;level:string;message:string};
export type WindowsAdvancedDiagnosis={timestamp:number;query_available:boolean;query_error:string;uptime_hours:number;last_boot:string;reboot_pending:boolean;reboot_reasons:string[];update_service_status:string;pending_update_count:number;pending_updates_available:boolean;recent_system_critical_count:number;recent_system_error_count:number;recent_events:WindowsRecentEvent[];evidences:AdvancedSystemSnapshot["evidences"]};
export const getWindowsAdvancedDiagnosis=()=>invoke<WindowsAdvancedDiagnosis>("get_windows_advanced_diagnosis");
export type StartupActionResult = {
  success: boolean;
  action: string;
  name: string;
  location: string;
  backup_path: string;
  message: string;
};

export const setStartupAdvancedEnabled = (
  name: string,
  command: string,
  location: string,
  enabled: boolean,
) =>
  invoke<StartupActionResult>("set_startup_advanced_enabled", {
    name,
    command,
    location,
    enabled,
  });
export type StartupDisabledItem = {
  id: string;
  name: string;
  command: string;
  original_location: string;
  backup_type: string;
  backup_path: string;
  disabled_at: number;
};
export type StartupActionHistoryItem = {
  timestamp: number;
  action: string;
  name: string;
  location: string;
  success: boolean;
};
export const getStartupDisabledItems=()=>invoke<StartupDisabledItem[]>("get_startup_disabled_items");
export const getStartupActionHistory=()=>invoke<StartupActionHistoryItem[]>("get_startup_action_history");
export const setStartupFolderEnabled=(name:string,command:string,location:string,enabled:boolean)=>
  invoke<StartupActionResult>("set_startup_folder_enabled",{name,command,location,enabled});
export const restoreStartupDisabledItem=(item:StartupDisabledItem)=>
  invoke<StartupActionResult>("restore_startup_disabled_item",{item});
export const getStartupFindings = () =>
  invoke<DiagnosticFinding[]>("get_startup_findings");
