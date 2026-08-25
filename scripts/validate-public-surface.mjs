import { readFile, readdir } from "node:fs/promises";
import { extname, join, relative } from "node:path";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const root = new URL("../", import.meta.url);
const textExtensions = new Set([".md", ".json", ".mjs", ".yml"]);
const forbidden = [
  /api[_-]?key\s*[:=]\s*["'][^"']+/i,
  /client[_-]?secret\s*[:=]\s*["'][^"']+/i,
  /authorization:\s*bearer\s+\S+/i,
  /\/api\/(?:oba|trains|subway|ecobici|nearby)/i,
  new RegExp(`vercel\\.${"app"}`, "i"),
  new RegExp(`anden-${"internal"}`, "i"),
];

async function files(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const result = [];
  for (const entry of entries) {
    if ([".git", "node_modules"].includes(entry.name)) continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) result.push(...await files(path));
    else if (textExtensions.has(extname(entry.name))) result.push(path);
  }
  return result;
}

const rootPath = root.pathname;
const allFiles = await files(rootPath);
const failures = [];
const ajv = new Ajv2020({ allErrors: true });
addFormats(ajv);

for (const path of allFiles) {
  const content = await readFile(path, "utf8");
  const label = relative(rootPath, path);
  for (const pattern of forbidden) {
    if (pattern.test(content)) failures.push(`${label}: patrón privado ${pattern}`);
  }
  if (extname(path) === ".json") JSON.parse(content);
  if (extname(path) !== ".md") continue;
  for (const match of content.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
    const target = match[1].split("#", 1)[0];
    if (!target || /^https?:/.test(target) || /^mailto:/.test(target)) continue;
    const resolved = new URL(target, new URL(`file://${path}`));
    try {
      await readFile(resolved);
    } catch {
      failures.push(`${label}: enlace local roto ${target}`);
    }
  }
}

for (const name of ["transport-observation", "place", "source-status"]) {
  const schema = JSON.parse(await readFile(join(rootPath, "schemas", `${name}.schema.json`), "utf8"));
  const example = JSON.parse(await readFile(join(rootPath, "examples", `${name}.json`), "utf8"));
  const validate = ajv.compile(schema);
  if (!validate(example)) {
    failures.push(`${name}: ejemplo incompatible ${ajv.errorsText(validate.errors)}`);
  }
}

if (failures.length) {
  console.error(failures.join("\n"));
  process.exitCode = 1;
} else {
  console.log(`Superficie pública válida: ${allFiles.length} archivos.`);
}
