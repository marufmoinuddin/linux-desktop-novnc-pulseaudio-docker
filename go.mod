module github.com/marufmoinuddin/linux-desktop-novnc-pulseaudio-docker

go 1.22

require (
	github.com/gorilla/websocket v1.5.3
	// golang.org/x/net is required only by the standalone reference file
	// go-server-reconstructed.go (kept for provenance); the production relay
	// in cmd/audiobridge uses gorilla/websocket.
	golang.org/x/net v0.0.0-20220809012201-f428fae20770
)
