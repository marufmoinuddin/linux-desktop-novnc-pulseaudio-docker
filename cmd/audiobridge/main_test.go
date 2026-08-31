package main

import (
	"context"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

// TestAudioRelay exercises the full relay path: /healthz, the Origin check,
// UDP datagram -> binary WebSocket frame, and clean-disconnect cleanup.
// Run with -race to prove the client map is concurrency-safe (bug #2).
func TestAudioRelay(t *testing.T) {
	h := newHub(16)

	httpLn, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("http listen: %v", err)
	}
	defer httpLn.Close()

	udpLn, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("udp listen: %v", err)
	}
	defer udpLn.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = serveUDP(ctx, udpLn, h) }()

	mux := http.NewServeMux()
	mux.HandleFunc("/audio", h.handleWS)
	mux.HandleFunc("/healthz", healthz)
	srv := &http.Server{Handler: mux}
	go func() { _ = srv.Serve(httpLn) }()
	defer srv.Close()

	base := "http://" + httpLn.Addr().String()

	// /healthz returns 200 (bug #6).
	resp, err := http.Get(base + "/healthz")
	if err != nil {
		t.Fatalf("healthz: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("healthz status = %d, want 200", resp.StatusCode)
	}

	// Missing Origin header -> 403 (protocol compatibility).
	req, _ := http.NewRequest(http.MethodGet, base+"/audio", nil)
	req.Header.Set("Connection", "Upgrade")
	req.Header.Set("Upgrade", "websocket")
	req.Header.Set("Sec-WebSocket-Version", "13")
	req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("missing-Origin request: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("missing-Origin status = %d, want 403", resp.StatusCode)
	}

	// Connect a WS client with an Origin header.
	wsURL := "ws" + strings.TrimPrefix(base, "http") + "/audio"
	ws, _, err := websocket.DefaultDialer.Dial(wsURL, http.Header{"Origin": []string{base}})
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer ws.Close()

	// Send a UDP datagram and expect it back as one binary frame.
	payload := []byte("FFmpeg Service01 test datagram")
	if _, err := udpLn.WriteTo(payload, udpLn.LocalAddr()); err != nil {
		t.Fatalf("udp write: %v", err)
	}

	ws.SetReadDeadline(time.Now().Add(5 * time.Second))
	mt, data, err := ws.ReadMessage()
	if err != nil {
		t.Fatalf("read message: %v", err)
	}
	if mt != websocket.BinaryMessage {
		t.Fatalf("message type = %d, want binary (%d)", mt, websocket.BinaryMessage)
	}
	if string(data) != string(payload) {
		t.Fatalf("payload mismatch: got %q want %q", data, payload)
	}

	// Clean-disconnect cleanup: after the client closes, the hub must drop it
	// without waiting for another UDP packet (bug #1).
	ws.Close()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		h.mu.RLock()
		n := len(h.clients)
		h.mu.RUnlock()
		if n == 0 {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("client not removed from hub after disconnect")
}

// TestBroadcastDropOldest verifies the drop-oldest backpressure: a client
// whose queue is full must not block the broadcast for other clients (bug #5).
func TestBroadcastDropOldest(t *testing.T) {
	h := newHub(2)

	// A client with a full queue (no writer draining it).
	c := &client{
		conn:  nil, // never written to; only the queue matters here
		queue: make(chan []byte, 2),
		done:  make(chan struct{}),
	}
	c.queue <- []byte("old1")
	c.queue <- []byte("old2")
	h.add(c)

	// Broadcast must not block even though the queue is full.
	done := make(chan struct{})
	go func() {
		h.broadcast([]byte("new"))
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("broadcast blocked on a full client queue")
	}

	// Drop-oldest: the oldest frame was evicted, the newest is queued.
	first := <-c.queue
	if string(first) != "old2" {
		t.Fatalf("drop-oldest failed: first queued frame = %q, want %q", first, "old2")
	}
	second := <-c.queue
	if string(second) != "new" {
		t.Fatalf("newest frame = %q, want %q", second, "new")
	}
}