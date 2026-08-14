export function formatBytes(bytes: number) {
  if (bytes <= 0) return "0 MB";

  const units = ["B", "KB", "MB", "GB", "TB"];

  const index = Math.min(
    Math.floor(Math.log(bytes) / Math.log(1024)),
    units.length - 1,
  );

  const value = bytes / Math.pow(1024, index);

  return `${value.toFixed(index >= 3 ? 2 : 1)} ${units[index]}`;
}
