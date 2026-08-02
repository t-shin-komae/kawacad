import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { nativePlatformCommand } from "./platform.mjs";

export class CommandFailure extends Error {
  constructor(command, result) {
    const status = result.error?.message ?? `exit code ${result.status}`;
    super(`Command failed: ${formatCommand(command)} (${status})`);
    this.name = "CommandFailure";
    this.command = command;
    this.result = result;
  }
}

export function formatCommand({ program, args = [] }) {
  return [program, ...args].map((part) => quote(part)).join(" ");
}

function quote(value) {
  const text = String(value);
  return /^[A-Za-z0-9_./:=+-]+$/u.test(text) ? text : JSON.stringify(text);
}

export function command(program, args = [], options = {}) {
  return { program, args, ...options };
}

export function runCommand(spec, { dryRun = false, env = {}, cwd, capture = false } = {}) {
  console.log(`[run] ${formatCommand(spec)}`);
  if (dryRun) return { status: 0, stdout: "", stderr: "", dryRun: true };

  const result = spawnSync(spec.program, spec.args, {
    cwd,
    env: { ...process.env, ...env },
    encoding: "utf8",
    shell: false,
    stdio: capture ? ["ignore", "pipe", "pipe"] : "inherit",
  });
  if (result.error || result.status !== 0) {
    if (capture && result.stdout) process.stdout.write(result.stdout);
    if (capture && result.stderr) process.stderr.write(result.stderr);
    throw new CommandFailure(spec, result);
  }
  return result;
}

export function localBinary(directory, name) {
  return path.join(directory, "node_modules", ".bin", nativePlatformCommand(name));
}

export function npmCommand(args, options = {}) {
  return command(nativePlatformCommand("npm"), args, options);
}

export function ensureDirectory(directory) {
  fs.mkdirSync(directory, { recursive: true });
}

export function removeDirectory(directory) {
  fs.rmSync(directory, { recursive: true, force: true });
}

export function copyDirectory(source, destination) {
  removeDirectory(destination);
  ensureDirectory(path.dirname(destination));
  fs.cpSync(source, destination, { recursive: true });
}

export function copyFile(source, destination) {
  ensureDirectory(path.dirname(destination));
  fs.copyFileSync(source, destination);
}

export function assertExecutable(filePath, label = filePath) {
  if (!fs.existsSync(filePath)) throw new Error(`${label} was not produced: ${filePath}`);
  if (process.platform !== "win32" && (fs.statSync(filePath).mode & 0o111) === 0) {
    throw new Error(`${label} is not executable: ${filePath}`);
  }
}

export function findExisting(candidates, label) {
  const found = candidates.find((candidate) => fs.existsSync(candidate));
  if (!found) throw new Error(`${label} was not found. Checked:\n${candidates.join("\n")}`);
  return found;
}
