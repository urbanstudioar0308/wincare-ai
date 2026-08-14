// BLOQUE 0024 V2 - Tipos compartidos de WinCare AI.
export type SystemStats = {
  cpu_usage: number;
  ram_used_gb: number;
  ram_total_gb: number;
  ram_usage_percent: number;
  disk_used_gb: number;
  disk_total_gb: number;
  disk_free_gb: number;
  disk_usage_percent: number;
};

export type CleanupCategory = {
  id: string;
  name: string;
  path: string;
  file_count: number;
  size_bytes: number;
  accessible: boolean;
};

export type CleanupScan = {
  total_files: number;
  total_bytes: number;
  categories: CleanupCategory[];
};

export type CleanupResult = {
  deleted_files: number;
  deleted_bytes: number;
  skipped_files: number;
  failed_files: number;
  categories_processed: number;
};


export type LargeFile = {
  name: string;
  path: string;
  size_bytes: number;
  modified_unix: number;
};

export type StorageScan = {
  total_files_scanned: number;
  total_large_files: number;
  total_large_bytes: number;
  files: LargeFile[];
};

export type ProcessInfo = {
  pid: number;
  name: string;
  cpu_usage: number;
  memory_bytes: number;
};

export type ProcessSnapshot = {
  process_count: number;
  total_memory_bytes: number;
  processes: ProcessInfo[];
};

export type StartupItem = {
  id: string;
  name: string;
  command: string;
  source: string;
  location: string;
  enabled: boolean;
  editable: boolean;
};

export type StartupSnapshot = {
  total_items: number;
  items: StartupItem[];
};

export type PerformanceRecommendation = {
  level: string;
  title: string;
  description: string;
  target: string;
};

export type PerformanceAnalysis = {
  score: number;
  status: string;
  cpu_usage: number;
  ram_usage_percent: number;
  disk_usage_percent: number;
  heavy_processes: number;
  active_startup_items: number;
  recommendations: PerformanceRecommendation[];
};

export type FullAnalysisResult = {
  healthScore: number;
  healthStatus: string;

  cpuUsage: number;
  ramUsage: number;
  diskUsage: number;

  cleanupBytes: number;
  cleanupFiles: number;

  largeFilesBytes: number;
  largeFilesCount: number;

  heavyProcesses: number;

  startupActive: number;

  recommendations: PerformanceRecommendation[];

  completedAt: string;
};

export type AnalysisHistoryEntry = {
  id: string;
  timestamp: number;
  score: number;
  status: string;
  cpu_usage: number;
  ram_usage: number;
  disk_usage: number;
  cleanup_bytes: number;
  large_files_bytes: number;
  heavy_processes: number;
  startup_active: number;
};

export type BaselineMetric = {
  average: number;
  current: number;
  difference: number;
  status: "normal" | "warning" | "critical" | "better";
};

export type BaselineResult = {
  sampleCount: number;
  level: "insufficient" | "preliminary" | "established";

  score: BaselineMetric;
  cpu: BaselineMetric;
  ram: BaselineMetric;
  disk: BaselineMetric;
  heavyProcesses: BaselineMetric;
  startup: BaselineMetric;

  primaryFinding: string;
  summary: string;
};

export type SnapshotLargeFile = {
  name: string;
  path: string;
  size_bytes: number;
};

export type SnapshotCleanupCategory = {
  id: string;
  name: string;
  size_bytes: number;
  file_count: number;
};

export type ChangeSnapshot = {
  id: string;
  timestamp: number;
  startup_active: string[];
  heavy_processes: string[];
  large_files: SnapshotLargeFile[];
  cleanup_categories: SnapshotCleanupCategory[];
};

export type AboutSystemInfo = {
  os_name: string;
  os_version: string;
  app_version: string;
  build: string;
  architecture: string;
  username: string;
  computer_name: string;
  app_ok: boolean;
  app_status: string;
};

export type EvidenceItem = {
  id: string;
  timestamp: number;
  source: string;
  category: string;
  severity: string;
  title: string;
  observed_value: string;
  explanation: string;
  technical_data: string;
};

export type AdvancedSystemSnapshot = {
  id: string;
  timestamp: number;
  cpu_usage: number;
  ram_usage_percent: number;
  disk_usage_percent: number;
  process_count: number;
  heavy_processes: number;
  startup_active: number;
  evidences: EvidenceItem[];
};
