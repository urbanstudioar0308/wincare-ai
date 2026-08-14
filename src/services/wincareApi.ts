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
