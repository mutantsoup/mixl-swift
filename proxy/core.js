// core.js — shared forwarding logic for the Mixl key proxy.
//
// This is REFERENCE / STARTER code, not a hardened production gateway. The
// `authenticate` and `checkRateLimit` functions are deliberately minimal stubs:
// replace them with real verification and limiting before deploying. See README.md.
//
// Requires Node 18+ (global `fetch`, `stream.Readable.fromWeb`). No dependencies.

import { Readable } from "node:stream";

const MIXLAYER_BASE_URL = process.env.MIXLAYER_BASE_URL ?? "https://models.mixlayer.ai/v1";
const MIXLAYER_API_KEY = process.env.MIXLAYER_API_KEY;
const MOUNT_PATH = process.env.PROXY_MOUNT_PATH ?? "/mixlayer/v1";

// Only these upstream paths may be proxied, so the proxy cannot be used as an open
// relay to arbitrary MixLayer endpoints. Add more as your app needs them.
const ALLOWED_PATHS = new Set(["/chat/completions"]);

/** Non-secret configuration, exposed for startup logging / diagnostics. */
export const PROXY_CONFIG = {
  upstreamBaseURL: MIXLAYER_BASE_URL,
  mountPath: MOUNT_PATH,
};

/** An error carrying an HTTP status to return to the caller. */
export class ProxyError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// --- Logging (set PROXY_LOG=false to silence) -------------------------------

const LOG_ENABLED = (process.env.PROXY_LOG ?? "true").toLowerCase() !== "false";

/** Obscures a secret, revealing only the last 4 characters. */
export function maskSecret(value) {
  if (!value) return "(none)";
  if (value.length <= 4) return "****";
  return `****${value.slice(-4)}`;
}

/** Masks a `Bearer <token>` header value. */
function maskAuthHeader(headerValue) {
  if (!headerValue) return "(none)";
  const match = /^Bearer\s+(.+)$/i.exec(headerValue);
  return match ? `Bearer ${maskSecret(match[1].trim())}` : "(malformed)";
}

export function log(...args) {
  if (LOG_ENABLED) console.log(`[${new Date().toISOString()}] [proxy]`, ...args);
}

/** Logs an inbound request (caller token masked) and returns a start timestamp. */
export function logRequestStart({ method, path, callerAuth }) {
  log(`← ${method} ${path}  caller=${maskAuthHeader(callerAuth)}`);
  return Date.now();
}

/** Logs the resolved caller identity from `authenticate`. */
export function logAuthenticated(userId) {
  log(`  authenticated user=${userId}`);
}

/** Logs a completed request with status and elapsed time. */
export function logRequestEnd({ status, startedAt, note }) {
  const ms = startedAt ? Date.now() - startedAt : 0;
  log(`✓ ${status} (${ms}ms${note ? `, ${note}` : ""})`);
}

/** Logs a failed request. */
export function logRequestError(err) {
  const status = err instanceof ProxyError ? err.status : 500;
  log(`✗ ${status} ${err.message}`);
}

/** Fail fast at startup if the upstream key is missing. */
export function assertConfigured() {
  if (!MIXLAYER_API_KEY) {
    throw new Error("MIXLAYER_API_KEY is not set. Refusing to start without an upstream key.");
  }
}

/**
 * Authenticate the calling app/user from request headers.
 *
 * STUB: this only checks for a non-empty bearer token. Replace with real
 * verification — validate a JWT signature and expiry, look up a session, etc. —
 * and return a stable user identifier. Throw `ProxyError(401, ...)` on failure.
 */
export async function authenticate(headers) {
  const auth = headers["authorization"];
  if (!auth || !auth.toLowerCase().startsWith("bearer ")) {
    throw new ProxyError(401, "Missing bearer token.");
  }
  const userToken = auth.slice(auth.indexOf(" ") + 1).trim();
  if (userToken.length === 0) {
    throw new ProxyError(401, "Empty bearer token.");
  }
  // TODO: verify `userToken` here. Returning a real userId enables per-user limits.
  return { userId: "stub-user" };
}

/**
 * Enforce per-user rate limits / quotas.
 *
 * STUB: no-op. Replace with a real limiter (e.g. a Redis token bucket) and throw
 * `ProxyError(429, ...)` when a caller exceeds their allowance.
 */
export async function checkRateLimit(_userId) {
  return;
}

/** Map an inbound request path to the upstream MixLayer URL, enforcing the allow-list. */
export function resolveUpstreamUrl(incomingPath) {
  const withoutMount = incomingPath.startsWith(MOUNT_PATH)
    ? incomingPath.slice(MOUNT_PATH.length)
    : incomingPath;

  const queryIndex = withoutMount.indexOf("?");
  const pathOnly = queryIndex >= 0 ? withoutMount.slice(0, queryIndex) : withoutMount;
  const query = queryIndex >= 0 ? withoutMount.slice(queryIndex) : "";

  if (!ALLOWED_PATHS.has(pathOnly)) {
    throw new ProxyError(404, `Path not allowed: ${pathOnly}`);
  }
  return `${MIXLAYER_BASE_URL}${pathOnly}${query}`;
}

/**
 * Forward a request to MixLayer with the REAL key swapped in, returning the
 * upstream `fetch` Response (whose body streams without buffering).
 */
export async function forwardToMixLayer({ method, incomingPath, headers, body }) {
  if ((method ?? "").toUpperCase() !== "POST") {
    throw new ProxyError(405, "Only POST is supported.");
  }
  const url = resolveUpstreamUrl(incomingPath);

  const upstreamHeaders = {
    // Swap the caller's session token for the real MixLayer key.
    authorization: `Bearer ${MIXLAYER_API_KEY}`,
    "content-type": headers["content-type"] ?? "application/json",
  };
  // Preserve streaming negotiation if the SDK sent it.
  if (headers["accept"]) upstreamHeaders["accept"] = headers["accept"];

  log(`→ forwarding to ${url}`);
  log(`  swapped Authorization → Bearer ${maskSecret(MIXLAYER_API_KEY)} (real MixLayer key)`);

  return fetch(url, { method: "POST", headers: upstreamHeaders, body });
}

/**
 * Pipe a web ReadableStream (a `fetch` response body) to a Node Writable without
 * buffering, preserving SSE token-by-token streaming.
 */
export function pipeWebStreamToNode(webStream, nodeWritable) {
  if (!webStream) {
    nodeWritable.end();
    return;
  }
  Readable.fromWeb(webStream).pipe(nodeWritable);
}

/** Convert a web ReadableStream into an async-iterable Node Readable. */
export function webStreamToAsyncIterable(webStream) {
  return webStream ? Readable.fromWeb(webStream) : null;
}
