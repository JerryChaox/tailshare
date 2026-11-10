# Opening a shared web app from a browser, with nothing installed

Tailcat is Go and builds for `GOOS=js GOARCH=wasm`. In a browser it reaches
the DERP relay over WebSocket, so a static page (any HTTPS host) can open a
tunnel to a `tailcat serve` and show the shared web app. Build this only
when a guest really can't run `tailcat browse`.

## Design that worked

1. **WASM tunnel.** A small Go `main` (js/wasm) keeps one `tailcat.Client`
   (`Server: tailcat.Addr(addr)`, `Key: key.NewNode()`, retry `Ping` until it
   answers), then an `http.Client` whose `Transport.DialContext` returns
   `c.DialTCPPort(ctx, 80)`. A custom `DialContext` makes Go use its own
   HTTP/1.1 stack instead of the browser's `fetch`. Expose
   `connect({addr})` and `fetch({method, path, headers, body})` to JS as
   promises. Build: `GOOS=js GOARCH=wasm go build -trimpath -ldflags=-s`,
   plus `wasm_exec.js` from `$(go env GOROOT)/lib/wasm/`.
2. **Service Worker proxy.** The page loads the shared app in an iframe under
   a path prefix such as `./s/`. A Service Worker catches every request from
   that frame (by URL prefix or by the requesting client's URL), sends it to
   the page over `postMessage` with a `MessageChannel`, and the page answers
   through the WASM `fetch`. Strip `accept-encoding` on the way in and
   `content-encoding`/`transfer-encoding` on the way out; give 101/204/205/304
   and HEAD a null body; rewrite `Location` redirects back under the prefix.
3. **Address from the URL fragment** (`#addr=tc...`), never the query
   string: the fragment isn't sent to the page's host.

## Limits (measured)

- Relay only, no direct path: ~2 s to connect, 0.6–1.8 s per request through
  a US relay. Fine for a dashboard, poor for asset-heavy apps.
- The WASM file is ~34 MB raw, ~8 MB gzip, ~6 MB brotli.
- No WebSocket: a Service Worker can't intercept it. Apps that need live
  sockets won't work.
- Service Workers need HTTPS (or localhost); `file://` won't do.
- The guest runs whatever JS the hosting page serves, so host it yourself
  or somewhere the guest trusts.
- With an ephemeral browser key the server can't use `--allow`. Either keep
  the address private, or have the page generate and persist a key and add
  it to `--allow`.

Tailcat is BSD-3-Clause; ship its LICENSE with any bundled build.
