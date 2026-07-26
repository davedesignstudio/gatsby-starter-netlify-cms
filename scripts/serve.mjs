import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, resolve, sep } from "node:path";

const root = resolve(process.cwd(), process.argv[2] || ".");
const port = Number(process.env.PORT || 8000);
const mimeTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".webmanifest": "application/manifest+json; charset=utf-8",
};

createServer(async function (request, response) {
  try {
    const pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
    let filePath = resolve(root, `.${pathname}`);
    if (filePath !== root && !filePath.startsWith(`${root}${sep}`)) throw new Error("Invalid path");
    if ((await stat(filePath)).isDirectory()) filePath = resolve(filePath, "index.html");

    response.writeHead(200, {
      "Content-Type": mimeTypes[extname(filePath)] || "application/octet-stream",
      "Cache-Control": "no-cache",
    });
    createReadStream(filePath).pipe(response);
  } catch {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Not found");
  }
}).listen(port, function () {
  console.log(`Aisle Drifters is running at http://localhost:${port}`);
});
