/**
 * CineTrekker Production Web Server for AWS EC2
 * Native Node.js ESM HTTP server (Zero runtime dependencies).
 * Serves the Vite SPA build, handles client-side routing fallback,
 * provides /health endpoint for the AWS Application Load Balancer.
 */

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = parseInt(process.env.PORT || "8080", 10);
const HOST = "0.0.0.0";
const DIST_DIR = path.resolve(__dirname, "dist");

// MIME types mapping
const MIME_TYPES = {
  ".html": "text/html; charset=UTF-8",
  ".js": "application/javascript; charset=UTF-8",
  ".mjs": "application/javascript; charset=UTF-8",
  ".css": "text/css; charset=UTF-8",
  ".json": "application/json; charset=UTF-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".webp": "image/webp",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".txt": "text/plain; charset=UTF-8",
  ".xml": "application/xml; charset=UTF-8",
  ".map": "application/json; charset=UTF-8",
};

const server = http.createServer((req, res) => {
  const parsedUrl = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  let pathname = decodeURIComponent(parsedUrl.pathname);

  // 1. Health check for AWS Application Load Balancer (ALB)
  if (pathname === "/health" || pathname === "/api/health") {
    res.writeHead(200, {
      "Content-Type": "application/json; charset=UTF-8",
      "Cache-Control": "no-store, no-cache, must-revalidate",
    });
    res.end(
      JSON.stringify({
        status: "ok",
        app: "cinetrekker",
        service: "cinetrekker-web",
        uptimeSeconds: Math.floor(process.uptime()),
        timestamp: new Date().toISOString(),
        host: process.env.HOSTNAME || "ec2-instance",
      })
    );
    return;
  }

  // 2. TMDB API Proxy (routes to Supabase edge function where TMDB credentials reside)
  if (pathname === "/api/tmdb-proxy") {
    if (req.method === "OPTIONS") {
      res.writeHead(204, {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
      });
      res.end();
      return;
    }

    const supabaseUrl = process.env.VITE_SUPABASE_URL || "https://nvssyuxghwlubxklvgrn.supabase.co";
    const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52c3N5dXhnaHdsdWJ4a2x2Z3JuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA1NjI1NDgsImV4cCI6MjA4NjEzODU0OH0.O2kkd5tu-u-pKq9vVkTT7-4SnZ-kA1YBagdski-U8nQ";
    const targetUrl = `${supabaseUrl}/functions/v1/tmdb-proxy?${parsedUrl.searchParams.toString()}`;

    fetch(targetUrl, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${supabaseAnonKey}`,
        "apikey": supabaseAnonKey,
      },
    })
      .then(async (upstreamRes) => {
        const bodyText = await upstreamRes.text();
        res.writeHead(upstreamRes.status, {
          "Content-Type": "application/json; charset=UTF-8",
          "Access-Control-Allow-Origin": "*",
          "Cache-Control": "s-maxage=300, stale-while-revalidate=600",
        });
        res.end(bodyText);
      })
      .catch((err) => {
        res.writeHead(200, {
          "Content-Type": "application/json; charset=UTF-8",
          "Access-Control-Allow-Origin": "*",
        });
        res.end(JSON.stringify({ page: 1, results: [], total_pages: 0, total_results: 0, error: err.message }));
      });
    return;
  }

  // Normalize path and prevent directory traversal
  let safePath = path.normalize(pathname).replace(/^(\.\.[\/\\])+/, "");
  let filePath = path.join(DIST_DIR, safePath);

  // If path is a directory or root, look for index.html
  try {
    const stats = fs.statSync(filePath);
    if (stats.isDirectory()) {
      filePath = path.join(filePath, "index.html");
    }
  } catch (err) {
    // File not found on disk: SPA fallback to index.html for client-side routing
    filePath = path.join(DIST_DIR, "index.html");
  }

  // Check if file exists
  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      // If even index.html doesn't exist, dist has not been built
      res.writeHead(404, { "Content-Type": "text/plain; charset=UTF-8" });
      res.end("404 Not Found - Please ensure the CineTrekker build exists in dist/");
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || "application/octet-stream";

    // Caching headers
    const headers = {
      "Content-Type": contentType,
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "SAMEORIGIN",
    };

    // Static assets with hash in filename can be cached long-term
    if (filePath.includes("assets") || ext === ".woff2" || ext === ".png" || ext === ".svg") {
      headers["Cache-Control"] = "public, max-age=31536000, immutable";
    } else {
      headers["Cache-Control"] = "no-cache, must-revalidate";
    }

    // Support Gzip compression
    const acceptEncoding = req.headers["accept-encoding"] || "";
    const isCompressible = /text|javascript|json|xml|svg/.test(contentType);

    if (isCompressible && acceptEncoding.includes("gzip")) {
      headers["Content-Encoding"] = "gzip";
      res.writeHead(200, headers);
      const rawStream = fs.createReadStream(filePath);
      const gzipStream = zlib.createGzip();
      rawStream.pipe(gzipStream).pipe(res);
    } else {
      headers["Content-Length"] = stats.size;
      res.writeHead(200, headers);
      fs.createReadStream(filePath).pipe(res);
    }
  });
});

server.listen(PORT, HOST, () => {
  console.log(`[CineTrekker] Production server running at http://${HOST}:${PORT}`);
  console.log(`[CineTrekker] Serving static files from: ${DIST_DIR}`);
  console.log(`[CineTrekker] ALB Health check endpoint: http://${HOST}:${PORT}/health`);
});
