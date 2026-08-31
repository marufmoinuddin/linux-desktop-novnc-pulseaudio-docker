// Command audiobridge is the audio relay for the
// linux-desktop-novnc-pulseaudio container family.
//
// It is a production rewrite of the recovered /opt/bin/server from
// thuonghai2711/ubuntu-novnc-pulseaudio:22.04 (see GO-SERVER.md and
// go-server-reconstructed.go). The wire protocol is preserved exactly:
//
//	UDP MPEG-TS datagrams in  ->  one binary WebSocket frame per datagram out
//
// so the browser-side jsmpeg client keeps working unchanged.
//
// All 7 documented bugs in the original are fixed here:
//  1. clean-disconnect leak      -> context cancellation + immediate map removal
//  2. map data race              -> sync.RWMutex around the client set
//  3. partial-write bail         -> gorilla WriteMessage is atomic; errors handled
//  4. silent UDP error path      -> UDP listen errors are fatal, not ignored
//  5. no backpressure            -> per-client buffered queue with drop-oldest
//  6. no reconnection signalling -> optional /healthz endpoint
//  7. protocol compatibility     -> -port (1699), -audio-port (10000), /audio path
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/gorilla/websocket"
)

// defaultQueueSize is the default per-client outbound frame queue depth.
const defaultQueueSize = 256

// client is a single connected WebSocket client. Each client owns a bounded
// outbound queue so a slow browser cannot stall the shared UDP pump (bug #5).
type client struct {
	conn  *websocket.Conn
	queue chan []byte // bounded; drop-oldest on overflow
	done  chan struct{}
}

// close is idempotent: it signals the writer goroutine to stop and closes the
// underlying connection exactly once.
func (c *client) close() {
	select {
	case <-c.done:
	default:
		close(c.done)
	}
	_ = c.conn.Close()
}

// writeLoop drains the client's queue, writing one binary frame per datagram.
func (c *client) writeLoop() {
	for {
		select {
		case p := <-c.queue:
			// gorilla's WriteMessage is atomic: it either writes the whole
			// message or returns an error, so a short write can never silently
			// drop the remaining clients (bug #3).
			if err := c.conn.WriteMessage(websocket.BinaryMessage, p); err != nil {
				c.close()
				return
			}
		case <-c.done:
			return
		}
	}
}

// readLoop blocks until the peer disconnects (clean or otherwise), which lets
// us tear the client down immediately instead of leaking the goroutine until
// the next audio packet (bug #1).
func (c *client) readLoop() {
	for {
		if _, _, err := c.conn.ReadMessage(); err != nil {
			c.close()
			return
		}
	}
}

// hub fans each incoming UDP datagram out to every connected client.
type hub struct {
	mu        sync.RWMutex // guards clients (bug #2)
	clients   map[*client]struct{}
	queueSize int
}

func newHub(queueSize int) *hub {
	return &hub{
		clients:   make(map[*client]struct{}),
		queueSize: queueSize,
	}
}

func (h *hub) add(c *client) {
	h.mu.Lock()
	h.clients[c] = struct{}{}
	h.mu.Unlock()
}

func (h *hub) remove(c *client) {
	h.mu.Lock()
	delete(h.clients, c)
	h.mu.Unlock()
}

// broadcast enqueues one datagram to every client. A full queue drops the
// oldest frame (drop-oldest backpressure) so a slow client only loses its own
// audio, never everyone's (bug #5).
func (h *hub) broadcast(p []byte) {
	h.mu.RLock()
	clients := make([]*client, 0, len(h.clients))
	for c := range h.clients {
		clients = append(clients, c)
	}
	h.mu.RUnlock()

	for _, c := range clients {
		select {
		case c.queue <- p:
		default:
			// Queue full: drop the oldest frame, then enqueue the newest.
			select {
			case <-c.queue:
			default:
			}
			select {
			case c.queue <- p:
			default:
				// Still full (writer is gone); drop this frame for this client.
			}
		}
	}
}

// handleWS upgrades the /audio endpoint. For protocol compatibility with the
// original image the handler requires an Origin header (403 without it) but
// accepts any origin value.
func (h *hub) handleWS(w http.ResponseWriter, r *http.Request) {
	if r.Header.Get("Origin") == "" {
		http.Error(w, "missing Origin header", http.StatusForbidden)
		return
	}

	upgrader := websocket.Upgrader{
		CheckOrigin: func(*http.Request) bool { return true },
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("websocket upgrade failed: %v", err)
		return
	}

	c := &client{
		conn:  conn,
		queue: make(chan []byte, h.queueSize),
		done:  make(chan struct{}),
	}

	h.add(c)
	defer func() {
		h.remove(c) // immediate removal on disconnect (bug #1)
		c.close()
	}()

	go c.writeLoop()
	c.readLoop() // blocks until the peer disconnects
}

// serveUDP receives MPEG-TS datagrams from ffmpeg and broadcasts them to all
// connected clients. A read error is logged and the loop continues; the caller
// is responsible for closing pc.
func serveUDP(ctx context.Context, pc net.PacketConn, h *hub) error {
	defer pc.Close()

	log.Printf("Jsmpeg udp listening on %s", pc.LocalAddr())

	buf := make([]byte, 65536)
	for {
		n, _, err := pc.ReadFrom(buf)
		if err != nil {
			select {
			case <-ctx.Done():
				return nil
			default:
			}
			log.Printf("udp read error: %v", err)
			continue
		}
		// Copy the datagram: broadcast enqueues asynchronously, so the shared
		// buffer cannot be reused.
		p := make([]byte, n)
		copy(p, buf[:n])
		h.broadcast(p)
	}
}

// runUDP binds a UDP socket and serves it. A listen error is returned (and
// treated as fatal by main) instead of being silently ignored and then closing
// a nil conn (bug #4).
func runUDP(ctx context.Context, addr string, h *hub) error {
	pc, err := net.ListenPacket("udp", addr)
	if err != nil {
		return fmt.Errorf("udp listen on %s: %w", addr, err)
	}
	return serveUDP(ctx, pc, h)
}

// healthz is the optional liveness endpoint (bug #6 / P1 improvement).
func healthz(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

func main() {
	port := flag.Int("port", 1699, "http/websocket listen port")
	audioPort := flag.Int("audio-port", 10000, "udp audio listen port")
	queueSize := flag.Int("queue-size", defaultQueueSize, "per-client outbound frame queue size")
	flag.Parse()

	h := newHub(*queueSize)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	udpErr := make(chan error, 1)
	go func() { udpErr <- runUDP(ctx, fmt.Sprintf(":%d", *audioPort), h) }()

	mux := http.NewServeMux()
	mux.HandleFunc("/audio", h.handleWS)
	mux.HandleFunc("/healthz", healthz)

	srv := &http.Server{
		Addr:              fmt.Sprintf(":%d", *port),
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("Http listening on %s", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("http server: %v", err)
		}
	}()

	select {
	case err := <-udpErr:
		if err != nil {
			log.Fatalf("udp listener: %v", err)
		}
	case <-ctx.Done():
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
}