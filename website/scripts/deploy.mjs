import { readFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const website = new URL("../", import.meta.url);
const link = JSON.parse(
  await readFile(new URL(".vercel/project.json", website), "utf8"),
);
if (link.projectName !== "recordme-website") {
  throw new Error(
    "Link website/ to the recordme-website Vercel project before deploying.",
  );
}

// Always upload website/, even when this script is called from the repo root.
const result = spawnSync(
  "npx",
  [
    "--yes",
    "vercel@59.16.0",
    "deploy",
    "--prod",
    "--yes",
    "--scope",
    "abbe-azales-projects",
  ],
  {
    cwd: fileURLToPath(website),
    stdio: "inherit",
  },
);
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
