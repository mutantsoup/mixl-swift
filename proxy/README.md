# Mixl Key Proxy (reference)

A minimal, dependency-free Node.js proxy that keeps your **MixLayer API key server-side** while letting client apps use the [Mixl Swift SDK](../README.md) unchanged.

The app points `MixLayerClient` at this proxy and authenticates with a *user* token; the proxy validates that token, swaps in the real MixLayer key, and streams the response back.

```
iOS app                                Your proxy                          MixLayer
───────                                ──────────                          ────────
MixLayerClient(apiKey: userToken,  ──► POST /mixlayer/v1/chat/completions
               baseURL: proxy)         1. authenticate(userToken)
                                       2. checkRateLimit(userId)
                                       3. swap Authorization → real key  ──► models.mixlayer.ai
        ◄────────────────────────────  4. stream SSE chunks back  ◄──────── (token stream)
```

> [!WARNING]
> This is **reference / starter code, not a hardened production gateway.** The
> `authenticate` and `checkRateLimit` functions in [`core.js`](core.js) are deliberately
> minimal **stubs** — replace them with real verification (JWT/session) and a real rate
> limiter before deploying. See [Hardening](#hardening) below.

## Layout

| File | Purpose |
| --- | --- |
| `core.js` | Shared logic: config, auth/rate-limit stubs, path allow-list, key swap, streaming forward. |
| `server.js` | Standalone Node HTTP server. |
| `handlers/aws-lambda.js` | AWS Lambda handler (Function URL, response streaming). |
| `handlers/gcp-function.js` | Google Cloud Functions (2nd gen) HTTP handler. |
| `.env.example` | Environment variables. |

All entry points are thin adapters around `core.js`, so the security-sensitive logic lives in exactly one place.

## Requirements

- **Node 18+** (uses the global `fetch` and `stream.Readable.fromWeb`; no npm dependencies).

## Configuration

| Variable | Required | Default | Notes |
| --- | --- | --- | --- |
| `MIXLAYER_API_KEY` | ✅ | — | Your real MixLayer key. Server-side only. |
| `MIXLAYER_BASE_URL` | | `https://models.mixlayer.ai/v1` | Upstream base URL. |
| `PROXY_MOUNT_PATH` | | `/mixlayer/v1` | Inbound prefix stripped before forwarding. |
| `PORT` | | `8787` | Standalone server only. |
| `PROXY_LOG` | | `true` | Per-request logging (keys always masked). Set `false` to silence. |

Copy `.env.example` and fill in your key. **Never commit a real `.env`.**

## Run locally

From the `proxy/` directory, provide your real key and start the server (no `npm install` needed — there are no dependencies):

```bash
cd proxy
export MIXLAYER_API_KEY="your-mixlayer-api-key"
npm start        # or: node server.js
```

Or use a git-ignored `.env` file instead of exporting (copy `.env.example` to `.env`, fill in the key) and load it:

```bash
node --env-file=.env server.js
```

On startup it prints where it's listening, the base URL to give your app, and the upstream it forwards to (the key is masked):

```
[…] [proxy] Mixl key proxy listening on http://localhost:8787
[…] [proxy] Point your app's baseURL at: http://localhost:8787/mixlayer/v1
[…] [proxy]   (e.g. export MIXLAYER_BASE_URL="http://localhost:8787/mixlayer/v1")
[…] [proxy] Forwarding to upstream:      https://models.mixlayer.ai/v1
[…] [proxy] Upstream key loaded:         Bearer ****a1b2
```

Then point the SDK at it (the only change from the Quick Start):

```swift
let client = MixLayerClient(
    apiKey: userSessionToken,                          // your token, not the MixLayer key
    baseURL: URL(string: "http://localhost:8787/mixlayer/v1")!
)
```

Try it with the bundled examples — set `MIXLAYER_BASE_URL` and the `MixlExamples` CLI routes through the proxy with a user token instead of an API key:

```bash
export MIXLAYER_BASE_URL="http://localhost:8787/mixlayer/v1"
export MIXLAYER_AUTH_TOKEN="any-user-token"   # this reference proxy accepts any non-empty token
swift run MixlExamples
```

Quick check with `curl` (a valid `Authorization` is required; the body is forwarded as-is):

```bash
curl -N http://localhost:8787/mixlayer/v1/chat/completions \
  -H "Authorization: Bearer test-user-token" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen/qwen3.5-4b-free","messages":[{"role":"user","content":"hi"}],"stream":true}'
```

## Deploy: AWS Lambda

`handlers/aws-lambda.js` uses Lambda **response streaming** so SSE tokens stream through.

1. Create a Node 18+/20 Lambda; set `handler` to `aws-lambda.handler` (bundle `core.js` alongside).
2. Set `MIXLAYER_API_KEY` in the function environment.
3. Add a **Function URL** with invoke mode **`RESPONSE_STREAM`**.
4. Point the SDK's `baseURL` at the Function URL plus the mount path (set `PROXY_MOUNT_PATH` to match your URL layout, or `/` if the Function URL has no prefix).

## Deploy: Google Cloud Functions (2nd gen)

`handlers/gcp-function.js` exports `mixlayerProxy` and relies on the Functions Framework's `(req, res)` signature; 2nd-gen functions stream responses.

```bash
gcloud functions deploy mixlayer-proxy \
  --gen2 --runtime=nodejs20 --region=us-central1 \
  --trigger-http --entry-point=mixlayerProxy \
  --set-env-vars=MIXLAYER_API_KEY=your-mixlayer-api-key
```

For local testing, install the framework as a dev dependency:

```bash
npm install --save-dev @google-cloud/functions-framework
npx functions-framework --target=mixlayerProxy --source=handlers/gcp-function.js
```

## Logging

With `PROXY_LOG=true` (the default), each request prints a few lines so you can watch it work. **The MixLayer key and caller tokens are always masked** (last 4 characters only). Example for one streamed completion:

```
[2026-06-20T15:04:01.220Z] [proxy] Mixl key proxy listening on http://localhost:8787
[2026-06-20T15:04:01.221Z] [proxy] Point your app's baseURL at: http://localhost:8787/mixlayer/v1
[2026-06-20T15:04:01.221Z] [proxy] Forwarding to upstream:      https://models.mixlayer.ai/v1
[2026-06-20T15:04:01.221Z] [proxy] Upstream key loaded:         Bearer ****a1b2
[2026-06-20T15:04:09.880Z] [proxy] ← POST /mixlayer/v1/chat/completions  caller=Bearer ****oken
[2026-06-20T15:04:09.881Z] [proxy]   authenticated user=stub-user
[2026-06-20T15:04:09.882Z] [proxy] → forwarding to https://models.mixlayer.ai/v1/chat/completions
[2026-06-20T15:04:09.882Z] [proxy]   swapped Authorization → Bearer ****a1b2 (real MixLayer key)
[2026-06-20T15:04:10.305Z] [proxy] ✓ 200 (423ms, streaming back)
```

The `caller=` token (from the app) and the `swapped → …` key (the real upstream key) have different last-4s — visible proof the proxy replaced the credential.

## Hardening

Before any real deployment, replace the stubs and tighten the edges:

- **`authenticate`** — verify the caller's token for real (JWT signature + expiry, or a session lookup) and return a stable `userId`. The default stub only checks that a bearer token is present.
- **`checkRateLimit`** — enforce per-user limits/quotas (e.g. a Redis token bucket). The default is a no-op.
- **Path allow-list** — `core.js` only forwards `/chat/completions`. Add endpoints explicitly rather than forwarding arbitrary paths.
- **CORS** — add the headers your app needs if calling from a browser context; native iOS/macOS apps don't require CORS.
- **Transport** — terminate TLS in front of the proxy; never run it over plain HTTP in production.
- **Secrets** — load `MIXLAYER_API_KEY` from your platform's secrets manager, not a checked-in file.
- **Logging** — log per-user usage for monitoring, but **never** the key or full prompt contents you don't intend to retain.

See the SDK's [Securing Your API Key](../README.md#securing-your-api-key) for the wider context.
