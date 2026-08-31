# linux-desktop-novnc-pulseaudio-docker

> Open-source rebuild project: an Ubuntu desktop (Xfce) + noVNC + PulseAudio
> container, engineered from a complete reverse-engineering of the
> `thuonghai2711/ubuntu-novnc-pulseaudio:22.04` image.

This repository contains the full teardown — build recipe, recovered startup
scripts, reconstructed Go audio relay (buildable + smoke-tested), asset/env/port
matrices — plus a prioritized roadmap (`IMPROVEMENTS.md`) for the improved,
open-source, non-privileged rebuild of this container family.

> Evidence artifacts (extracted rootfs, original binaries, configs) were held in
> temporary local files during the investigation and are intentionally **not**
> committed here; the docs below contain everything needed to reproduce the
> findings.

## Images

Nine image variants are built and published — 3 base OS × 3 desktop
environments — all with noVNC + PulseAudio streaming audio. **No
`--privileged` is required** (unlike the original image); `--shm-size 1g` is
recommended for the desktop session.

| OS \ DE | KDE | GNOME | Xfce |
|---|---|---|---|
| **Ubuntu 24.04** | `linux-desktop-novnc-pulseaudio-ubuntu-kde` | `linux-desktop-novnc-pulseaudio-ubuntu-gnome` | `linux-desktop-novnc-pulseaudio-ubuntu-xfce` |
| **Fedora 41** | `linux-desktop-novnc-pulseaudio-fedora-kde` | `linux-desktop-novnc-pulseaudio-fedora-gnome` | `linux-desktop-novnc-pulseaudio-fedora-xfce` |
| **Arch Linux** | `linux-desktop-novnc-pulseaudio-arch-kde` | `linux-desktop-novnc-pulseaudio-arch-gnome` | `linux-desktop-novnc-pulseaudio-arch-xfce` |

### CI status

| Workflow | Status |
|---|---|
| ubuntu-kde | [![build-ubuntu-kde](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-ubuntu-kde.yml/badge.svg)](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-ubuntu-kde.yml) |
| ubuntu-gnome | [![build-ubuntu-gnome](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-ubuntu-gnome.yml/badge.svg)](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-ubuntu-gnome.yml) |
| ubuntu-xfce | [![build-ubuntu-xfce](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-ubuntu-xfce.yml/badge.svg)](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-ubuntu-xfce.yml) |
| fedora-kde | [![build-fedora-kde](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-fedora-kde.yml/badge.svg)](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-fedora-kde.yml) |
| fedora-gnome | [![build-fedora-gnome](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-fedora-gnome.yml/badge.svg)](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-fedora-gnome.yml) |
| fedora-xfce | [![build-fedora-xfce](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-fedora-xfce.yml/badge.svg)](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-fedora-xfce.yml) |
| arch-kde | [![build-arch-kde](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-arch-kde.yml/badge.svg)](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-arch-kde.yml) |
| arch-gnome | [![build-arch-gnome](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-arch-gnome.yml/badge.svg)](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-arch-gnome.yml) |
| arch-xfce | [![build-arch-xfce](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-arch-xfce.yml/badge.svg)](https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker/actions/workflows/build-arch-xfce.yml) |

## Usage

```bash
# Xfce on Ubuntu (the classic flavor)
docker run -d --name desktop --shm-size 1g \
  -e VNC_PASSWD=secret \
  -p 8080:8080 \
  ghcr.io/marufmoinuddin/linux-desktop-novnc-pulseaudio-ubuntu-xfce:latest
```

Then open <http://localhost:8080> — noVNC loads and audio streams automatically.

| Image | `docker run` example |
|---|---|
| ubuntu-kde | `docker run -d --shm-size 1g -e VNC_PASSWD=secret -p 8080:8080 ghcr.io/marufmoinuddin/linux-desktop-novnc-pulseaudio-ubuntu-kde:latest` |
| ubuntu-gnome | `docker run -d --shm-size 1g -e VNC_PASSWD=secret -p 8080:8080 ghcr.io/marufmoinuddin/linux-desktop-novnc-pulseaudio-ubuntu-gnome:latest` |
| ubuntu-xfce | `docker run -d --shm-size 1g -e VNC_PASSWD=secret -p 8080:8080 ghcr.io/marufmoinuddin/linux-desktop-novnc-pulseaudio-ubuntu-xfce:latest` |
| fedora-kde | `docker run -d --shm-size 1g -e VNC_PASSWD=secret -p 8080:8080 ghcr.io/marufmoinuddin/linux-desktop-novnc-pulseaudio-fedora-kde:latest` |
| fedora-gnome | `docker run -d --shm-size 1g -e VNC_PASSWD=secret -p 8080:8080 ghcr.io/marufmoinuddin/linux-desktop-novnc-pulseaudio-fedora-gnome:latest` |
| fedora-xfce | `docker run -d --shm-size 1g -e VNC_PASSWD=secret -p 8080:8080 ghcr.io/marufmoinuddin/linux-desktop-novnc-pulseaudio-fedora-xfce:latest` |
| arch-kde | `docker run -d --shm-size 1g -e VNC_PASSWD=secret -p 8080:8080 ghcr.io/marufmoinuddin/linux-desktop-novnc-pulseaudio-arch-kde:latest` |
| arch-gnome | `docker run -d --shm-size 1g -e VNC_PASSWD=secret -p 8080:8080 ghcr.io/marufmoinuddin/linux-desktop-novnc-pulseaudio-arch-gnome:latest` |
| arch-xfce | `docker run -d --shm-size 1g -e VNC_PASSWD=secret -p 8080:8080 ghcr.io/marufmoinuddin/linux-desktop-novnc-pulseaudio-arch-xfce:latest` |

### Environment variables

| Env | Default | Effect |
|---|---|---|
| `VNC_PASSWD` | random (printed once) | VNC auth password |
| `PORT` | `8080` | nginx listen port (web UI + `/audio`) |
| `WEBSOCKIFY_PORT` | `6900` | websockify listen (internal) |
| `VNC_PORT` | `5900` | tigervnc RFB port (bound to 127.0.0.1) |
| `AUDIO_SERVER` | `1699` | Go relay HTTP/WS port (`AUDIO_PORT` accepted as an alias) |
| `FFMPEG_UDP_PORT` | `10000` | UDP audio port (ffmpeg → relay) |
| `SCREEN_WIDTH` / `SCREEN_HEIGHT` | `1600` / `900` | resolution |
| `SCREEN_DEPTH` | `24` | color depth |
| `SCREEN_DPI` | `96` | dpi |
| `DISPLAY` | `:99` | headless display |

### Security baseline

- Runs **without `--privileged`**.
- `Xvfb` uses `-nolisten tcp` (unix socket only); tigervnc (`x0vncserver`)
  binds `127.0.0.1`.
- nginx `:80` default site removed; only `$PORT` is exposed.
- Dedicated `ubuntu` user (uid/gid 1001) with passwordless sudo; no
  world-writable `/etc/passwd`.
- `HEALTHCHECK` curls `http://localhost:${PORT:-8080}/`.
- `LANG=C.UTF-8` and `TZ` are set.

### CI

Each image has its own workflow (`.github/workflows/build-<os>-<de>.yml`):
push to `main`, pull requests (build + smoke test only, never publish), tags
`v*`, `workflow_dispatch`, and a nightly `schedule`. Images are built for
`linux/amd64,linux/arm64` with buildx GHA cache and published to GHCR (and
optionally Docker Hub when the `DOCKERHUB_USERNAME` / `DOCKERHUB_PASSWORD`
secrets are set). A shared composite action (`.github/actions/smoke-test`)
runs the end-to-end smoke test: HTTP 200 + noVNC, `/audio` WebSocket handshake
(101), binary audio frames, supervisor programs RUNNING, no fatal errors.

## Quick facts

| Property | Value |
|---|---|
| Image | `thuonghai2711/ubuntu-novnc-pulseaudio:22.04` |
| Digest | `sha256:e72ee80ea972ba776183d2b6296a69b30a45ce89fcfb168fdfe07997ccc51a53` |
| Size | 1.76 GB (docker), ~1.2 GB inside, 742 packages |
| Base | Ubuntu 22.04.1 LTS, frozen **Aug 2022** (never updated since) |
| Docker Hub | 18,386 pulls, 4 stars, last push 2022-08-16 |
| License status | Original image declares none (lineage is MIT: ConSol/docker-headless-vnc-container); **this repository: MIT** |

## Lineage (proven)

```
ConSol/docker-headless-vnc-container        (original headless VNC container project)
  └─ kmille36/docker-headless-vnc-container (fork: cosmetic renames only — diff shows
       image-name swaps + novnc_proxy → launch.sh)
        └─ kmille36/DockerGUI-Novnc-Audio   (supervisor refactor, 20.04, bin.zip payloads)
             └─ kmille36/docker-gui-novnc/develop-tester   ★ THE ACTUAL BUILD CONTEXT
                  ├─ Dockerfile            (matches image layer history exactly)
                  ├─ otp-bin.zip           (identical payloads; zip repacked)
                  ├─ no-vnc.zip            (identical to image /usr/share/novnc)
                  ├─ nginx.conf            (identical, 522 B)
                  └─ supervisord.conf      (identical, 4973 B)
```

The 22.04 tag = same build context with `FROM ubuntu:22.04` + one extra layer
(`apt install xfce4-goodies`) + `start-ffmpeg.sh` bitrate changed 384k → 128k.
Not related: `kmille36/docker-ubuntu-vnc` (CrossOver+Chrome image, MAINTAINER "DCsunset").

## Architecture (runtime)

One entry script → supervisord → 9 daemons:

```
entry_point.sh (bash, PID 1, runs as ubuntu uid 1001)
  └─ supervisord
       ├─ xvfb        Xvfb :99 -screen 0 1024x768x24 -listen tcp -ac +extension RANDR   (0.0.0.0:6099)
       ├─ dbus        dbus-daemon --nofork (system bus)
       ├─ ui          startxfce4 → Xfce session on :99            (invisible desktop)
       ├─ vnc         tigervncserver → Xtigervnc :0 (own X server) — daemonizes, supervisor marks "exited"
       │              VncAuth with /home/ubuntu/.vnc/passwd, binds 127.0.0.1:5900
       ├─ novnc       websockify --web=/usr/share/novnc/ 6900 localhost:5900
       ├─ audioserver /opt/bin/server -audio-port 10000 -port 1699   (Go binary)
       ├─ nginx       envsubst-rendered config, listens $PORT (e.g. 10000) + stock :80
       ├─ pulseaudio  pulseaudio --exit-idle-time=-1
       └─ ffmpeg      -f alsa -i pulse -f mpegts -codec:a mp2 -ar 44100 -ac 2 -b:a 128k udp://localhost:10000
```

Data flow:

```
Browser ──http/ws──> nginx :10000 ──> websockify :6900 ──RFB/ws──> Xtigervnc :5900
Browser ──ws──> nginx /audio ──> Go server :1699 ──UDP──< ffmpeg <── PulseAudio
```

Two X servers run (Xvfb :99 hosts one Xfce session; Xtigervnc :0 hosts a second).
Users see the :0 session over noVNC. Xvfb is a near-redundant extra.

## Contents

- `BUILD.md` — the exact Dockerfile (reconstructed from layer history + develop-tester source) and how to reproduce the build.
- `GO-SERVER.md` — full reverse-engineering of the Go audio relay, with reconstructed source and discovered bugs.
- `go-server-reconstructed.go` — the recovered `main.go` (~78 lines) as reference implementation.
- `ASSETS.md` — file inventory, embedded versions, env-var matrix, port/protocol map, live verification evidence.
- `IMPROVEMENTS.md` — gap list and "bells & whistles" plan for the open-source rebuild.