// gcp-function.js — Google Cloud Functions (2nd gen) HTTP handler for the Mixl key proxy.
//
// 2nd-gen functions run on Cloud Run and support streamed responses, so SSE token
// streaming is preserved. Deploy with `--entry-point=mixlayerProxy` and set
// MIXLAYER_API_KEY in the function environment. The Functions Framework supplies the
// Express-style (req, res) signature at runtime; for local testing install
// @google-cloud/functions-framework (see README.md).

import {
  authenticate,
  checkRateLimit,
  forwardToMixLayer,
  pipeWebStreamToNode,
  logRequestStart,
  logAuthenticated,
  logRequestEnd,
  logRequestError,
  ProxyError,
} from "../core.js";

export const mixlayerProxy = async (req, res) => {
  const startedAt = logRequestStart({
    method: req.method,
    path: req.path ?? req.url,
    callerAuth: req.headers["authorization"],
  });
  try {
    const { userId } = await authenticate(req.headers);
    logAuthenticated(userId);
    await checkRateLimit(userId);

    // Prefer the raw bytes the Functions Framework preserves; fall back to a
    // re-serialized parsed body.
    const body =
      req.rawBody ?? (req.body ? Buffer.from(JSON.stringify(req.body)) : undefined);

    const upstream = await forwardToMixLayer({
      method: req.method,
      incomingPath: req.path ?? req.url,
      headers: req.headers,
      body,
    });

    res.status(upstream.status);
    res.setHeader(
      "content-type",
      upstream.headers.get("content-type") ?? "application/json"
    );
    logRequestEnd({ status: upstream.status, startedAt, note: "streamed" });
    pipeWebStreamToNode(upstream.body, res);
  } catch (err) {
    logRequestError(err);
    const status = err instanceof ProxyError ? err.status : 500;
    const message = err instanceof ProxyError ? err.message : "Internal proxy error.";
    res.status(status).json({ error: { message } });
  }
};
