export const projectFileExtension = "kawa";

export function normalizeProjectSavePath(path: string) {
  const segments = path.split(/[\\/]/u);
  const filename = segments[segments.length - 1] ?? "";
  if (filename.lastIndexOf(".") > 0) return path;
  return `${path}.${projectFileExtension}`;
}
