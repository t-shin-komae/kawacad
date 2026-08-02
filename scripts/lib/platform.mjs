export const supportedPlatforms = ["macos", "windows", "linux"];

export function currentPlatform(nodePlatform = process.platform) {
  switch (nodePlatform) {
    case "darwin":
      return "macos";
    case "win32":
      return "windows";
    case "linux":
      return "linux";
    default:
      return nodePlatform;
  }
}

export function isNativePlatform(platform, nodePlatform = process.platform) {
  return currentPlatform(nodePlatform) === platform;
}

export function nativePlatformCommand(name) {
  return process.platform === "win32" ? `${name}.cmd` : name;
}
