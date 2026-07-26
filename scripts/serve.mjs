import { createReadStream, existsSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(fileURLToPath(new URL("..", import.meta.url)));
const port = Number(process.env.PORT || 8000);
const types = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".webmanifest": "application/manifest+json",
};

createServer((request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, `http://${request.headers.host}`).pathname);
  const requested = pathname === "/" ? "index.html" : pathname.slice(1);
  const safePath = normalize(requested).replace(/^(\.\.(\/|\\|$))+/, "");
  let file = join(root, safePath);
  if (!existsSync(file)) file = join(root, "index.html");
  response.setHeader("Content-Type", types[extname(file)] || "application/octet-stream");
  response.setHeader("Cache-Control", "no-cache");
  createReadStream(file).pipe(response);
}).listen(port, "0.0.0.0", () => {
  console.log(`Aisle Rally running at http://localhost:${port}`);
});
