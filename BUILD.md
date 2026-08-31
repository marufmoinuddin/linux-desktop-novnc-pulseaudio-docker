# BUILD.md — Exact build recipe

Source of truth: `docker history --no-trunc` on the image, verified against
`kmille36/docker-gui-novnc/develop-tester/` (the actual build context).

## Reconstructed Dockerfile (22.04)

```dockerfile
# Build context: kmille36/docker-gui-novnc/develop-tester/
FROM ubuntu:22.04

ARG GUI=xfce

ENV DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    USERNAME=ubuntu HOME=/home/ubuntu GUI=xfce \
    SCREEN_WIDTH=1600 SCREEN_HEIGHT=900 SCREEN_DEPTH=24 SCREEN_DPI=96 \
    DISPLAY=:99 DISPLAY_NUM=99 FFMPEG_UDP_PORT=10000 \
    WEBSOCKIFY_PORT=6900 VNC_PORT=5900 AUDIO_SERVER=1699 VNC_PASSWD=password

RUN apt update ; apt install unzip zip -y

COPY  otp-bin.zip /opt/
RUN cd /opt/ && unzip otp-bin.zip          # -> /opt/bin/*.sh + /opt/bin/server (Go relay)

RUN apt-get -qqy update && apt-get -qqy --no-install-recommends install \
      sudo supervisor dbus-x11 xvfb x11vnc x11-xserver-utils \
      tigervnc-standalone-server tigervnc-common novnc websockify \
      wget curl unzip gettext && bash /opt/bin/apt_clean.sh

RUN apt-get -qqy update && apt-get -qqy --no-install-recommends install \
      pulseaudio pavucontrol alsa-base ffmpeg nginx && bash /opt/bin/apt_clean.sh

RUN chmod +x /dev/shm
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

RUN groupadd $USERNAME --gid 1001 && useradd $USERNAME --create-home --gid 1001 \
      --shell /bin/bash --uid 1001 && usermod -a -G sudo $USERNAME \
      && echo 'ALL ALL = (ALL) NOPASSWD: ALL' >> /etc/sudoers \
      && echo "$USERNAME:$USERNAME" | chpasswd

COPY supervisord.conf /etc/supervisor/
COPY nginx.conf /etc/nginx/conf.d/nginx.conf.template

RUN bash /opt/bin/install_gui.sh       # if GUI==xfce: xfce4 via apt_install.sh; writes /opt/bin/start-ui.sh
RUN bash /opt/bin/install_utils.sh     # htop terminator software-properties-common gpg-agent; mozillateam PPA pin; firefox
RUN bash /opt/bin/setup_audio.sh       # wget jsmpeg.min.js from phoboslab/jsmpeg master (build-time only)

COPY no-vnc.zip /usr/share/
RUN rm -rf /usr/share/novnc/ && cd /usr/share/ && unzip no-vnc.zip

RUN bash /opt/bin/relax_permission.sh  # chmod -R 777 /opt/bin,/var/run/supervisor,/var/log/supervisor,/etc/nginx,/usr/share/novnc,/etc/passwd; chgrp 0; g=u
RUN sed -i "s/UI.initSetting('resize', 'off');/UI.initSetting('resize', 'remote');/g" /usr/share/novnc/app/ui.js

# 22.04-only extra layer (not in the 20.04 recipe):
RUN sudo apt update; sudo apt install xfce4-goodies -y ; bash /opt/bin/apt_clean.sh

USER ubuntu
CMD ["/opt/bin/entry_point.sh"]
```

Notes:
- Deleting /usr/share/novnc + unzipping `no-vnc.zip` REPLACES the apt `novnc`
  package (1.0.0) with the author's own snapshot (2018-era noVNC).
- No `EXPOSE`, no `LABEL`, no `HEALTHCHECK`, no `VOLUME` in the shipped image.
- `PORT` env var has **no default** in the image. Without `-e PORT=...`,
  envsubst renders `listen ;` and nginx fails → no web UI. (In practice always set.)
- `AUDIO_PORT` (as in the README) is **ignored** — the pipeline reads `AUDIO_SERVER`.

## Reproduce

```bash
git clone https://github.com/kmille36/docker-gui-novnc.git
cd docker-gui-novnc/develop-tester
sed -i 's/FROM ubuntu:20.04/FROM ubuntu:22.04/' Dockerfile   # + add the xfce4-goodies layer
docker build -t my-novnc:22.04 .
```

## Layer breakdown (sizes from history)

| Layer | Size |
|---|---|
| base ubuntu:22.04 | 87.5 MB |
| +zip, otp-bin.zip → /opt/bin | 3.8 MB |
| +GUI/VNC stack (sudo supervisor xvfb x11vnc tigervnc novnc websockify …) | 474 MB |
| +audio stack (pulseaudio pavucontrol alsa-base ffmpeg nginx) | 299 MB |
| useradd/sudoers/chpasswd | 410 KB |
| install_gui (xfce4) | 20.8 MB |
| install_utils (firefox etc.) | 286 MB |
| setup_audio (jsmpeg) | 168 KB |
| no-vnc.zip → /usr/share/novnc | 5.1 MB |
| relax_permission | 11.9 MB |
| xfce4-goodies (22.04 only) | 84.6 MB |