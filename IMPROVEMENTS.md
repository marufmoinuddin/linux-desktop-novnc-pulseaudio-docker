# IMPROVEMENTS.md — "Bells & whistles" plan for the open-source rebuild

Base your project on: modern image base + your own Go audio relay + this image's
proven architecture. Everything below is grounded in measured findings from the
teardown (see ASSETS.md / GO-SERVER.md for evidence).

## P0 — Must fix (bugs found in the original)

1. **Go relay concurrency**: add `sync.RWMutex` (or channel actor) around the
   client map — original races and can panic ("concurrent map iteration and map write").
2. **Go relay leak**: remove clients from the map in the handler exit path +
   `context.WithCancel`, so clean disconnects don't leak goroutines.
3. **Per-client backpressure**: buffered out-queues with drop-oldest so one slow
   browser can't stall audio for everyone (original: single shared pump).
4. **`PORT` default**: image has none — nginx renders invalid config if unset.
   Default it (8080) or render config with a fallback.
5. **Drop `--privileged`**: reverse-engineer what it actually needs —
   `chmod +x /dev/shm` (build-time only) and PulseAudio's needs. Ship
   `--cap-add` guidance or run non-privileged with explicit devices.
6. **`AUDIO_PORT` vs `AUDIO_SERVER`**: pick ONE env name and honor both (README
   says AUDIO_PORT, code uses AUDIO_SERVER) — this confused the original's own docs.

## P1 — Security & hygiene

- TLS end-to-end: websockify has `--cert`/`--key`; add `wss` + optional nginx TLS
  (or ship a Caddy front). Original: all plaintext incl. VNC auth.
- Replace VNC-auth-password-with-DES on the wire → at minimum document it:
  keep `VncAuth` but tunnel through TLS. (VNC RFB auth is sniffable.)
- `Xvfb -ac -listen tcp` on 0.0.0.0:6099 → bind 127.0.0.1 (nobody needs remote X).
- Remove/disable nginx stock `:80` default site (unused surface).
- Firefox PPA pin + version pinning, and a **rebuild pipeline** (base updates,
  Dependabot/renovate for packages, nightly CI).
- Image signing (cosign), SBOM (syft), and `HEALTHCHECK` (curl /audio upgrade or /healthz).
- `USER` + drop capabilities at runtime; keep sudo only where needed; random
  initial passwords via entrypoint (env `VNC_PASSWD` → generate if unset, print once).

## P2 — Capabilities the original lacks (bells & whistles)

- **Persistence**: `VOLUME /home/ubuntu` + `VOLUME /etc/supervisor/conf.d`; drop-in
  supervised apps; document `--user` override for OpenShift-style UIDs (entry already supports it).
- **Session resume / reconnection**: noVNC `reconnect` setting + websockify
  `--heartbeat`; container stop/start keeps desktop state (needs persistence above).
- **Multiple desktops / DEs**: `GUI=gnome|lxde|xfce|icewm` layers like ConSol;(original is xfce-only).
- **Audio quality options**: bitrate/codec env (`AUDIO_BITRATE`, `AUDIO_CODEC=mp2|aac`),
  per-client volume; WASM jsmpeg for better decode.
- **Clipboard**: wire x11vnc's `-display :0` clip support or XFIXES-based clipboard
  into the noVNC panel (noVNC has the UI; the server needs the X extension).
- **File transfer**: noVNC has an experimental file-transfer API; mount a
  `~/shared` volume + drag-drop tutorial.
- **Screenshots/recording**: built-in `scrot`-style hotkey + `ffmpeg -f x11grab`
  recipe for one-shot PNG/MP4 export from the VNC session.
- **Multi-user**: per-session containers (`docker run` per user) + optional
  router/lb; document k8s (ConSol has a sample Deployment manifest to crib).

## P3 — Engineering project shape (suggested layout)

```
your-repo/
├── Dockerfile                    # multi-arch (amd64/arm64) buildx
├── go.mod / cmd/audiobridge/     # your Go relay (source, tests, fuzz UDP)
├── scripts/                      # entry_point, start-*, install-*, supervisor conf
├── web/                          # modern noVNC submodule/pinned + index.html w/ jsmpeg
├── nginx/                        # template + TLS sample
├── tests/                        # bats: image smoke, ws handshake, audio bytes, race detector
├── .github/workflows/            # publisher (tags), nightly rebuild, SBOM, signing
└── docs/                         # env matrix, ports, security model, k8s sample
```

## Verification checklist (mirrors what this teardown did)

- `docker history --no-trunc` matches the README recipe
- fresh container: all supervisor programs RUNNING
- `curl :PORT/` serves noVNC; `/audio` WS upgrade → binary MPEG-TS frames
- `go test -race ./...` on the relay (original would fail)
- VNC connect via noVNC, keyboard/mouse/resize OK
- audio: `pactl play-sample` → frames visible on WS in <1 s
- non-privileged run passes smoke tests