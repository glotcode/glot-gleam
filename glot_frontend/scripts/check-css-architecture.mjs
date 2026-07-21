import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const cssRoot = resolve(root, "css");
const styles = readFileSync(resolve(cssRoot, "styles.css"), "utf8");
const adminEntry = readFileSync(resolve(cssRoot, "admin-entry.css"), "utf8");
const accessibility = readFileSync(resolve(cssRoot, "accessibility.css"), "utf8");
const violations = [];

const layerContract =
  "@layer reset, tokens, base, components, pages, admin, overrides;";
if (!styles.includes(layerContract)) {
  violations.push("styles.css must declare the canonical cascade layer order");
}

const imports = [...styles.matchAll(/^@import\s+[^;]+;/gm)].map((match) => match[0]);
if (imports.some((statement) => !statement.includes(" layer("))) {
  violations.push("every styles.css import must declare its cascade layer");
}
if (imports.at(-1) !== '@import "./accessibility.css" layer(overrides);') {
  violations.push("accessibility.css must be the final styles.css import");
}
if (!adminEntry.includes('@import "./admin.css" layer(admin);')) {
  violations.push("admin-entry.css must load admin.css in the admin layer");
}

for (const required of [
  "prefers-reduced-motion: reduce",
  "prefers-contrast: more",
  "forced-colors: active",
]) {
  if (!accessibility.includes(required)) {
    violations.push(`accessibility.css must handle ${required}`);
  }
}

const literalColor = /#[0-9a-f]{3,8}\b|\brgba?\(/i;
for (const file of readdirSync(cssRoot).filter((file) => file.endsWith(".css"))) {
  if (file === "tokens.css") continue;
  const source = readFileSync(resolve(cssRoot, file), "utf8");
  if (literalColor.test(source)) {
    violations.push(`${file} contains a literal color; add a token instead`);
  }
}

if (violations.length > 0) {
  console.error("CSS architecture violations:\n" + violations.join("\n"));
  process.exitCode = 1;
} else {
  console.log("CSS architecture is valid.");
}
