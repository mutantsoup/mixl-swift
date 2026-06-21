// aws-lambda.js — AWS Lambda handler for the Mixl key proxy.
//
// Uses Lambda response streaming so SSE token streaming is preserved. Deploy on a
// Lambda Function URL with invoke mode RESPONSE_STREAM (Node 18+/20 runtime), and
// set MIXLAYER_API_KEY in the function environment. `awslambda` is a runtime-provided
// global — this file is meant to run inside Lambda, not locally.

import {
  authenticate,
  checkRateLimit,
  forwardToMixLayer,
  webStreamToAsyncIterable,
  logRequestStart,
  logAuthenticated,
  logRequestEnd,
  logRequestError,
  ProxyError,
} from "../core.js";

/* global awslambda */
export const handler = awslambda.streamifyResponse(async (event, responseStream) => {
  const headers = lowerCaseHeaders(event.headers ?? {});
  const method = event.requestContext?.http?.method ?? "POST";
  const incomingPath = event.rawPath ?? event.requestContext?.http?.path ?? "/";
  const startedAt = logRequestStart({ method, path: incomingPath, callerAuth: headers["authorization"] });
  try {
    const { userId } = await authenticate(headers);
    logAuthenticated(userId);
    await checkRateLimit(userId);

    const body = event.body
      ? event.isBase64Encoded
        ? Buffer.from(event.body, "base64")
        : event.body
      : undefined;

    const upstream = await forwardToMixLayer({ method, incomingPath, headers, body });

    const out = awslambda.HttpResponseStream.from(responseStream, {
      statusCode: upstream.status,
      headers: {
        "content-type": upstream.headers.get("content-type") ?? "application/json",
      },
    });

    const stream = webStreamToAsyncIterable(upstream.body);
    if (stream) {
      for await (const chunk of stream) {
        out.write(chunk);
      }
    }
    logRequestEnd({ status: upstream.status, startedAt, note: "streamed" });
    out.end();
  } catch (err) {
    logRequestError(err);
    const status = err instanceof ProxyError ? err.status : 500;
    const message = err instanceof ProxyError ? err.message : "Internal proxy error.";
    const out = awslambda.HttpResponseStream.from(responseStream, {
      statusCode: status,
      headers: { "content-type": "application/json" },
    });
    out.write(JSON.stringify({ error: { message } }));
    out.end();
  }
});

function lowerCaseHeaders(headers) {
  const out = {};
  for (const [key, value] of Object.entries(headers)) {
    out[key.toLowerCase()] = value;
  }
  return out;
}
