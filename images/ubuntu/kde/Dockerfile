# syntax=docker/dockerfile:1

# linux-desktop-novnc-pulseaudio-ubuntu-kde
# Browser-accessible Linux desktop (noVNC) + streaming audio
# (PulseAudio -> ffmpeg -> Go relay -> WebSocket -> jsmpeg).
# Non-privileged rebuild of thuonghai2711/ubuntu-novnc-pulseaudio:22.04.

ARG BASE_IMAGE=ubuntu:24.04

# ---- builder: compile the Go audio relay (static) ----
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY cmd/ ./cmd/
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /audiobridge ./cmd/audiobridge

# ---- runtime ----
FROM ${BASE_IMAGE}

ARG IMAGE_FLAVOR=ubuntu-kde
ARG USER_NAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=1000
ENV DE=kde \
    LANG=C.UTF-8 \
    TZ=UTC \
    DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

LABEL org.opencontainers.image.title="linux-desktop-novnc-pulseaudio-${IMAGE_FLAVOR}" \
      org.opencontainers.image.description="KDE Plasma desktop with noVNC + PulseAudio streaming audio" \
      org.opencontainers.image.source="https://github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker" \
      org.opencontainers.image.licenses="MIT"

# Runtime + DE packages
COPY scripts/ /opt/scripts/
RUN chmod +x /opt/scripts/*.sh && \
    /opt/scripts/install-ubuntu-packages.sh "${DE}"

# noVNC (pinned modern release) + jsmpeg (pinned commit)
RUN mkdir -p /usr/share/novnc && \
    curl -fsSL https://github.com/novnc/noVNC/archive/refs/tags/v1.5.0.tar.gz | tar -xz --strip-components=1 -C /usr/share/novnc && \
    curl -fsSL https://raw.githubusercontent.com/phoboslab/jsmpeg/924acfbd96fdf15e6748d1368a36d79d8f4cecf6/jsmpeg.min.js -o /usr/share/novnc/jsmpeg.min.js

# Web assets (index.html with noVNC iframe + jsmpeg audio)
COPY web/index.html /usr/share/novnc/index.html

# Deterministic PulseAudio config: fixed audio_bridge null sink (capture source)
COPY pulse/default.pa /etc/pulse/default.pa

# nginx + supervisor configs
COPY nginx.conf.template /etc/nginx/conf.d/nginx.conf.template
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Render the configured user identity into the runtime configs/scripts
# (the repo keeps the original 'ubuntu' names as the template).
RUN sed -i "s/ubuntu/${USER_NAME}/g" \
      /etc/supervisor/supervisord.conf /opt/scripts/*.sh

# Go relay binary
COPY --from=builder /audiobridge /usr/local/bin/audiobridge

# Dedicated unprivileged user: reuse the base image's 'ubuntu' user
# (uid/gid 1000) as-is; add passwordless sudo + runtime dirs.
# No world-writable /etc/passwd (unlike the original).
RUN usermod -aG sudo ubuntu && \
    echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ubuntu && \
    chmod 440 /etc/sudoers.d/ubuntu && \
    mkdir -p /home/ubuntu/.vnc /tmp/.X11-unix /tmp/.ICE-unix && \
    chmod 1777 /tmp/.X11-unix /tmp/.ICE-unix && \
    chown -R ubuntu:ubuntu /home/ubuntu

EXPOSE 8080
VOLUME ["/home/ubuntu"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD /bin/sh -c 'curl -fsS "http://localhost:${PORT:-8080}/" >/dev/null || exit 1' 

ENTRYPOINT ["/opt/scripts/entry_point.sh"]