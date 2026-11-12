import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
export const root = resolve(fileURLToPath(new URL("..", import.meta.url)));

// Use the same workspace selection as Lake, including a disclosed local gate.
export async function selectedPackage(name) {
  let overrides;
  try { overrides = JSON.parse(await readFile(resolve(root, ".lake/package-overrides.json"), "utf8")); }
  catch (error) { if (error.code !== "ENOENT") throw error; }
  const entry = overrides?.packages.find(entry => entry.name === name || entry.name === `«${name}»`);
  return entry?.type === "path" ? resolve(root, entry.dir) : resolve(root, ".lake/packages", name);
}
