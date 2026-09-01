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
| `AUDIO_CAPTURE_SOURCE` | `audio_bridge.monitor` | PulseAudio source ffmpeg records (falls back to `default`) |
| `AUDIO_BITRATE` | `128k` | MP2 audio bitrate for the streamed MPEG-TS |
| `SCREEN_WIDTH` / `SCREEN_HEIGHT` | `1600` / `900` | resolution |
| `SCREEN_DEPTH` | `24` | color depth |
| `SCREEN_DPI` | `96` | dpi |
| `DISPLAY` | `:99` | headless display |

### Security baseline

- Runs **without `--privileged`**.
- `Xvfb` uses `-nolisten tcp` (unix socket only); tigervnc (`x0vncserver`)
  binds `127.0.0.1`.
- nginx `:80` default site removed; only `$PORT` is exposed.
- Dedicated `<distro>` user (uid/gid **1000** — `ubuntu`, `fedora`, or `arch`
  matching the base OS) with passwordless sudo; no world-writable
  `/etc/passwd`. Ubuntu reuses the base image's built-in `ubuntu` account;
  Fedora/Arch create `fedora`/`arch`. Overridable at build time via
  `--build-arg USER_NAME=... --build-arg USER_UID=... --build-arg USER_GID=...`.
- `HEALTHCHECK` curls `http://localhost:${PORT:-8080}/`.
- `LANG=C.UTF-8` and `TZ` are set.

### Essential applications

Each flavor ships a native toolset (verified against the distro repos at build
time): terminal, file manager, image viewer, PDF viewer, archive manager, text
editor, screenshot utility, and Firefox.

| DE | Apps |
|---|---|
| **GNOME** | GNOME Console, Nautilus, Loupe, Evince, File Roller, GNOME Text Editor, GNOME Screenshot, Firefox |
| **KDE** | Konsole, Dolphin, Gwenview, Okular, Ark, Kate, Spectacle, Firefox |
| **Xfce** | Xfce Terminal, Thunar, Ristretto, Atril, Xarchiver, Mousepad, Xfce Screenshooter, Firefox |

Notes:

- Ubuntu's apt `firefox` is a snap transitional package (cannot run in this
  container), so Ubuntu images install Firefox from the **mozillateam PPA**
  with a pin override; the Mozilla tarball is the automatic fallback if the
  PPA is unreachable. Fedora/Arch use their distro packages.
- Where a distro/DE lacks the screenshot utility (e.g. `spectacle` in KDE
  23.08-era apt repos), the build automatically installs the **FireShot**
  Firefox add-on (signed AMO XPI pre-seeded into the user's profile). Today
  every variant has a native utility; the fallback is wired in for safety.
- Install scope is "applications + what they need": MIME handling
  (`shared-mime-info`, `gvfs`, `xdg-utils`, `xdg-user-dirs`), notifications,
  fonts, icons/themes (from the DE), and polkit authentication daemon + DE
  agent. No whole-DE meta groups or extras beyond that.
- `/etc/flavor-essentials.txt` in each image lists the actual binaries; CI
  asserts every one exists and launches a representative GUI app on the
  display.

### CI

Each image has its own workflow (`.github/workflows/build-<os>-<de>.yml`).
Workflows run on `workflow_dispatch` (manual) and on a scheduled monthly
rebuild (1st of the month, 03:00 UTC) — build steps are deliberately
restricted to those triggers to save CI minutes; push/PR/tag triggers are not
enabled. Images are built for `linux/amd64,linux/arm64` with buildx GHA cache
and published to GHCR (and optionally Docker Hub when the
`DOCKERHUB_USERNAME` / `DOCKERHUB_PASSWORD` secrets are set). Each build tags
`<git-sha>`, `latest`, and `<os>-latest`. A shared composite action
(`.github/actions/smoke-test`) runs the end-to-end smoke test: HTTP 200 +
noVNC, `/audio` WebSocket handshake (101), binary MPEG-TS frames, **real audio
content** (an 880 Hz tone played inside the container must measure above
-60 dB on the captured stream — silence fails the test), supervisor programs
RUNNING, no fatal errors.

## Audio notes

- PulseAudio runs with a deterministic `/etc/pulse/default.pa` that loads a
  fixed `audio_bridge` null sink at 44.1 kHz stereo on daemon start. Every
  application plays to it and ffmpeg records its `audio_bridge.monitor`
  source — the stream never depends on PulseAudio's lazy `auto_null` sink.
- Browsers block WebAudio autoplay until a user gesture, so the player
  starts with `autoplay: true` immediately and is unlocked silently on the
  first click/keypress/touch anywhere on the page (no button or overlay). The
  audio WebSocket also upgrades to `wss://` automatically when the page is
  served over HTTPS.
- Sounds play inside the desktop (Firefox, system sounds, `paplay`) are
  captured and streamed; with nothing playing the stream is digital silence.

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