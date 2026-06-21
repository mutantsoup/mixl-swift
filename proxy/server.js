// server.js — standalone Node HTTP server for the Mixl key proxy.
//
// Run: MIXLAYER_API_KEY=... node server.js   (see README.md and .env.example)

import http from "node:http";
import {
  assertConfigured,
  authenticate,
  checkRateLimit,
  forwardToMixLayer,
  pipeWebStreamToNode,
  log,
  logRequestStart,
  logAuthenticated,
  logRequestEnd,
  logRequestError,
  maskSecret,
  PROXY_CONFIG,
  ProxyError,
} from "./core.js";

assertConfigured();

const PORT = process.env.PORT ?? 8787;

const server = http.createServer(async (req, res) => {
  const startedAt = logRequestStart({
    method: req.method,
    path: req.url,
    callerAuth: req.headers["authorization"],
  });
  try {
    const { userId } = await authenticate(req.headers);
    logAuthenticated(userId);
    await checkRateLimit(userId);

    const body = await readBody(req);
    const upstream = await forwardToMixLayer({
      method: req.method,
      incomingPath: req.url,
      headers: req.headers,
      body,
    });

    res.writeHead(upstream.status, {
      "content-type": upstream.headers.get("content-type") ?? "application/json",
    });
    logRequestEnd({ status: upstream.status, startedAt, note: "streaming back" });
    pipeWebStreamToNode(upstream.body, res);
  } catch (err) {
    logRequestError(err);
    sendError(res, err);
  }
});

server.listen(PORT, () => {
  const localBaseURL = `http://localhost:${PORT}${PROXY_CONFIG.mountPath}`;
  log(`Mixl key proxy listening on http://localhost:${PORT}`);
  log(`Point your app's baseURL at: ${localBaseURL}`);
  log(`  (e.g. export MIXLAYER_BASE_URL="${localBaseURL}")`);
  log(`Forwarding to upstream:      ${PROXY_CONFIG.upstreamBaseURL}`);
  log(`Upstream key loaded:         Bearer ${maskSecret(process.env.MIXLAYER_API_KEY)}`);
});

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

function sendError(res, err) {
  const status = err instanceof ProxyError ? err.status : 500;
  // Never leak internal details or the upstream key in error responses.
  const message = err instanceof ProxyError ? err.message : "Internal proxy error.";
  if (!res.headersSent) {
    res.writeHead(status, { "content-type": "application/json" });
  }
  res.end(JSON.stringify({ error: { message } }));
}
