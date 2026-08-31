# ASSETS.md — Inventory, versions, env matrix, ports

## Embedded assets (image vs repos)

| Asset | In image | In repo | Match |
|---|---|---|---|
| `/opt/bin/server` | 6,657,214 B, md5 `b5bd6714…` | otp-bin.zip + bin.zip + loose `server` | ✅ byte-identical |
| `/opt/bin/*.sh` (15 scripts) | /opt/bin | otp-bin.zip | ✅ identical except: |
| `start-ffmpeg.sh` | `-b:a 128k` | `-b:a 384k` | ❌ image lowered bitrate |
| `start-ui.sh` | `/usr/bin/startxfce4` (no shebang) | has `#!/usr/bin/env bash` | ~ (regenerated at build) |
| `/usr/share/novnc/*` | served bundle | `novnc.zip` (repo `no-vnc.zip`) | ✅ `index.html` md5 `e35abb16` matches |
| `/etc/nginx/conf.d/nginx.conf.template` | 522 B | 522 B | ✅ |
| `/etc/supervisor/supervisord.conf` | 4973 B | 4973 B | ✅ |
| `jsmpeg.min.js` | 138,012 B | (fetched at build) | ✅ src = phoboslab/jsmpeg master |

## Bundled software versions (frozen 2022-08)

| Component | Version | Notes |
|---|---|---|
| noVNC (served) | **2018-era snapshot** (~1.0.x: has `vnc_auto.html`/`vnc_lite.html`) | NOT the apt package |
| apt `novnc` | 1:1.0.0-5 | installed but replaced |
| websockify | 0.10.0 | |
| tigervnc-standalone-server | 1.12.0 | daemonized; localhost-only |
| x11vnc | 0.9.16 | only used for `-storepasswd` |
| Xvfb | 2:21.1.3-2ubuntu2.1 | `-ac -listen tcp` |
| pulseaudio | 15.99.1 | |
| ffmpeg | 7:4.4.2 | MP2/MPEG-TS encoder |
| nginx | 1.18.0 | |
| firefox | 104.0 (Mozilla PPA) | |
| xfce4-session | 4.16.0 | |
| supervisor | 4.2.1 | |
| jsmpeg (client) | master @ Aug 2022 | WASM-capable build |

## Image configuration

- Default user: `ubuntu` uid/gid 1001, in `sudo`, password `ubuntu`, passwordless sudo (`ALL ALL = (ALL) NOPASSWD: ALL`)
- No EXPOSE / LABEL / HEALTHCHECK / VOLUME
- Entry: `CMD ["/opt/bin/entry_point.sh"]` runs as `ubuntu`
- `--privileged` required by the documented usage; live capset = full
  (`CapEff=000001ffffffffff`), host `/dev` grafted, no seccomp/apparmor
- `/etc/passwd` measured **664 root:root** in shipped image (relax script intends 777;
  the later `xfce4-goodies` apt layer rewrote it)
- `/opt/bin`, `/var/run/supervisor`, `/var/log/supervisor`, `/etc/nginx`, `/usr/share/novnc` = 777, group 0

## Env-var matrix

| Env | Default in image | Consumed by | Effect |
|---|---|---|---|
| `VNC_PASSWD` | `password` | start-vnc.sh → `x11vnc -storepasswd` | VNC auth password (VncAuth) |
| `PORT` | **none** ⚠️ | start-nginx.sh envsubst `$PORT` | nginx listen port; no default → nginx fails to start if unset |
| `WEBSOCKIFY_PORT` | `6900` | start-novnc.sh + nginx envsubst | websockify listen + nginx proxy target |
| `VNC_PORT` | `5900` | start-vnc.sh + websockify | tigervnc RFB port |
| `AUDIO_SERVER` | `1699` | start-audioserver.sh + nginx envsubst | Go server HTTP/WS port + nginx /audio target |
| `AUDIO_PORT` | — | **nothing** ⚠️ | README suggests it; image ignores it |
| `FFMPEG_UDP_PORT` | `10000` | start-ffmpeg.sh + start-audioserver.sh | UDP audio port (ffmpeg → Go relay) |
| `SCREEN_WIDTH/HEIGHT` | `1600`/`900` | start-xvfb.sh + start-vnc.sh | resolution (both X servers) |
| `SCREEN_DEPTH` | `24` | start-xvfb.sh + start-vnc.sh | color depth |
| `SCREEN_DPI` | `96` | start-xvfb.sh | dpi |
| `DISPLAY` / `DISPLAY_NUM` | `:99` / `99` | Xvfb / session | headless display |
| `GUI` | `xfce` | install_gui.sh (build-time) | desktop choice |
| `USERNAME` / `HOME` | `ubuntu` / `/home/ubuntu` | entry_point.sh, supervisor env | session user |

## Port map (inside container, live-verified)

| Port | Proto | Binds | Service | Auth |
|---|---|---|---|---|
| 10000 | TCP | 0.0.0.0 | nginx (user-facing: noVNC UI + /audio) | via VNC |
| 80 | TCP | 0.0.0.0 | nginx stock default site (leftover) | none |
| 6900 | TCP | 0.0.0.0 | websockify (VNC over WS) | container-internal only |
| 5900 | TCP | 127.0.0.1 | Xtigervnc | VncAuth (passwd file) |
| 1699 | TCP | 0.0.0.0 | Go audio WS server | Origin header check only |
| 10000 | UDP | 0.0.0.0 | Go relay input (ffmpeg TS) | none (localhost) |
| 6099 | TCP | 0.0.0.0 | Xvfb `-ac` unauth X | **none** — do not publish |
| 55558 | UDP | * | ffmpeg source port (ephemeral) | — |

## Live verification evidence (2026-08-31, host)

- `curl :8080/` → HTTP 200, serves noVNC UI (index.html, 18,415 B)
- `curl -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: …" -H "Origin: http://localhost:8080" :8080/audio` → **101 Switching Protocols**, then streams MPEG-TS audio frames (contains `FFmpeg Service01` string)
- Same handshake **without** Origin → 403 (Go server validates Origin)
- Container processes: 9 supervisor programs all RUNNING; `vnc` program shows supervisor "exited" (daemonized tigervnc)
- Resize applied live: Xvfb + Xtigervnc both at 1024×768×24 from the given env
- `docker diff` at runtime: only logs + `/var/tmp/Xvfb_screen0` + nginx dirs changed (no runtime downloads)