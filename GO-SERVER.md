# GO-SERVER.md — The custom audio relay (`/opt/bin/server`)

This is the only custom-compiled code in the image (everything else is distro
packages + shell). Fully recovered via symbol table + full disassembly
(`go tool nm` / `go tool objdump`, binary not stripped, has debug info).

## Identity

| Property | Value |
|---|---|
| File | `/opt/bin/server`, 6,657,214 bytes |
| md5 | `b5bd67147f89d6ed2614609a0f0282ab` (identical in image and repos) |
| Toolchain | Go 1.19 (`CGO_ENABLED=1`, amd64), module path `command-line-arguments` |
| Only dep | `golang.org/x/net` v0.0.0-20220809012201 (for websocket) |
| Source layout | `/app/main.go`, ~78 lines (recovered) |
| Licensing | none declared; trivially reimplementable |

## Recovered source → see `go-server-reconstructed.go`

Behavior summary:
- Flags: `-port` (HTTP/WS listen, default **1699**), `-audio-port` (UDP listen, default **10000**).
- UDP path: `net.ResolveUDPAddr("udp", ":"+audioPort)` → `net.ListenUDP` →
  `io.Copy(WsMultiWriter, conn)` — a raw byte pump (no protocol parsing at all).
- HTTP path: `http.Handle("/audio", websocket.Handler(...))` on `http.DefaultServeMux`,
  then `log.Fatal(http.ListenAndServe(":"+port, nil))`.
- Handler: sets `ws.PayloadType = 2` (binary frames), registers the conn in the
  writer's map with a buffered-1 `chan struct{}`, blocks on `<-ch`.
- Write: for each connected client, `ws.Write(p)`; on error → `ch <- struct{}{}`
  (unblock the handler goroutine so it exits) and `map[ws] = nil` (skip next time).
- Logs: `Http listening on %s`, `Jsmpeg udp listening on %s`.

## Protocol contract (what it actually does on the wire)

1. ffmpeg streams **MPEG-TS** (MP2 audio, 44.1 kHz, stereo, 128 kbps in the
   22.04 image) over **UDP** to `localhost:10000`.
2. `/opt/bin/server` receives raw UDP datagrams and **re-marshals each datagram
   as one binary WebSocket message** to every connected client. No framing,
   no timestamp handling, no re-slicing (TS packets are ~188 B anyway from ffmpeg).
3. Browser: `jsmpeg.min.js` with `JSMpeg.Player("ws://host:port/audio", {
   video: false, audioBufferSize: 128*1024, maxAudioLag: 0.25, autoplay: true })`.
4. nginx proxies `/audio` → `localhost:1699/audio` with WebSocket upgrade headers.
5. The x/net websocket handler requires an `Origin` header (403 without it);
   browsers send it automatically.

## Discovered bugs / sharp edges (fix these in your rebuild)

1. **Clean-disconnect leak.** If a client closes TCP cleanly and no UDP packet
   arrives afterwards, `Write` never realizes the conn is dead → the client's
   handler goroutine stays blocked on `<-ch` and the map entry (with a non-nil
   channel) leaks. Self-heals only on the next audio write.
2. **Map data race.** `Write` iterates `wsList` while concurrent handler
   goroutines `mapassign` on connect. Go maps are not concurrency-safe →
   `concurrent map iteration and map write` panic under load. Original has no
   mutex. (Very likely latent crash trigger for multiple listeners.)
3. **Partial write = bail.** If `ws.Write` returns `n != len(p)`, `Write` returns
   immediately, dropping the remaining clients for that packet.
4. **Silent UDP error path.** `net.ListenUDP` error is printed to stdout but the
   program continues; the deferred `conn.Close()` then runs on a nil conn.
5. **No buffer/backpressure.** A slow client blocks the UDP pump (all clients
   share the same goroutine) — one slow browser stalls audio for everyone.
6. **No reconnection signalling.** Dead clients are only pruned lazily via nil
   channel; the `/audio` endpoint never tells the page anything.
7. **No TLS** — audio is plaintext WS.

## What to do differently in an open-source version

- `sync.RWMutex` (or actor/channel pattern) around the client set.
- `context` cancellation on conn close (`defer cancel()`), remove map entries
  in the handler exit path immediately (fixes leak #1).
- Per-client buffered out queues + drop-oldest policy (fixes #5).
- Optionally: true jsmpeg TS de-packetization or pass-through with
  `websocket.TextMessage`/binary flag parity for newer jsmpeg versions.
- Add `-max-clients`, health endpoint `/healthz`, Prometheus counters.
- Keep the public API identical: `-port`, `-audio-port`, `/audio` path.