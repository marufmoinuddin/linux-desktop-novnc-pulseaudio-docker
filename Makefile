# Makefile for linux-desktop-novnc-pulseaudio-docker
#
# Targets:
#   make build            build one image (OS/DE selectable)
#   make run              build + run interactively (no --privileged)
#   make smoke            build + run the CI-style smoke test
#   make push             push the image
#   make clean            remove test containers
#
# Examples:
#   make build OS=ubuntu DE=xfce
#   make smoke OS=fedora DE=kde

OS ?= ubuntu
DE ?= xfce
IMAGE := linux-desktop-novnc-pulseaudio-$(OS)-$(DE)
DOCKERFILE := images/$(OS)/$(DE)/Dockerfile

BASE_IMAGE_ubuntu := ubuntu:24.04
BASE_IMAGE_fedora := fedora:41
BASE_IMAGE_arch := archlinux:latest
BASE_IMAGE := $(BASE_IMAGE_$(OS))

.PHONY: build run smoke push clean

build:
	docker build -f $(DOCKERFILE) \
	  --build-arg BASE_IMAGE=$(BASE_IMAGE) \
	  --build-arg IMAGE_FLAVOR=$(OS)-$(DE) \
	  -t $(IMAGE) .

run: build
	docker run --rm -it --shm-size 1g \
	  -e VNC_PASSWD=password -e PORT=8080 \
	  -p 8080:8080 \
	  $(IMAGE)

smoke: build
	@CID=$$(docker run -d --name $(IMAGE)-smoke \
	  -e VNC_PASSWD=testpass -e PORT=10000 \
	  -e WEBSOCKIFY_PORT=6900 -e VNC_PORT=5900 \
	  -e AUDIO_SERVER=1699 -e FFMPEG_UDP_PORT=10000 \
	  -e SCREEN_WIDTH=1024 -e SCREEN_HEIGHT=768 \
	  -p 127.0.0.1::10000 $(IMAGE)); \
	PORT=$$(docker port $$CID 10000/tcp | sed 's/.*://'); \
	echo "container $$CID on 127.0.0.1:$$PORT"; \
	ok=0; \
	for i in $$(seq 1 60); do \
	  if curl -fsS http://127.0.0.1:$$PORT/ >/dev/null 2>&1; then ok=1; break; fi; \
	  sleep 2; \
	done; \
	[ $$ok = 1 ] || { echo "FAIL: no HTTP 200"; docker logs $$CID; docker rm -f $$CID >/dev/null; exit 1; }; \
	curl -fsS http://127.0.0.1:$$PORT/ | grep -qi noVNC && echo "PASS: noVNC served"; \
	docker logs $$CID | grep -q "entered RUNNING state" && echo "PASS: supervisor RUNNING"; \
	docker rm -f $$CID >/dev/null

push:
	docker push $(IMAGE)

clean:
	docker rm -f $(IMAGE)-smoke 2>/dev/null || true