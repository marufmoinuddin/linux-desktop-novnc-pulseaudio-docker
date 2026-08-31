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