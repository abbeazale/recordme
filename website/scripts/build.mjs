import { cp, mkdir, rm } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const output = new URL("dist/", root);
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
for (const path of [
  "index.html",
  "styles.css",
  "main.js",
  "assets",
  "robots.txt",
  "sitemap.xml",
]) {
  await cp(new URL(path, root), new URL(path, output), { recursive: true });
}
console.log("Built RecordMe landing page in dist/");
