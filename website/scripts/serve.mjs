import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(
  fileURLToPath(new URL("../", import.meta.url)),
  process.argv[2] ?? ".",
);
const port = Number(process.env.PORT ?? 4173);
const types = {
  ".html": "text/html",
  ".css": "text/css",
  ".js": "text/javascript",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".xml": "application/xml",
  ".txt": "text/plain",
};

createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(
      new URL(request.url, "http://localhost").pathname,
    );
    const path = resolve(
      root,
      `.${pathname === "/" ? "/index.html" : pathname}`,
    );
    if (!path.startsWith(`${root}${sep}`)) {
      response.writeHead(403).end("Forbidden");
      return;
    }
    const body = await readFile(path);
    response.writeHead(200, {
      "Content-Type": `${types[extname(path)] ?? "application/octet-stream"}; charset=utf-8`,
    });
    response.end(body);
  } catch (error) {
    response
      .writeHead(error.code === "ENOENT" || error.code === "EISDIR" ? 404 : 400)
      .end("Not found");
  }
}).listen(port, "127.0.0.1", () =>
  console.log(`RecordMe website: http://localhost:${port}`),
);
