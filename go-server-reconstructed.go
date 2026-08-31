// go-server-reconstructed.go
//
// Faithful reconstruction of /opt/bin/server from the image
// thuonghai2711/ubuntu-novnc-pulseaudio:22.04 (md5 b5bd67147f89d6ed2614609a0f0282ab).
// Recovered from symbol table + full disassembly (source path /app/main.go).
// Deliberately kept close to the original so the diff shows what a fixed
// version changes. The bugs listed in GO-SERVER.md are preserved here as-is
// (leak, map race, partial-write bail, nil-conn Close).
package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"

	"golang.org/x/net/websocket"
)

// WsMultiWriter fans each incoming UDP chunk out to all connected WS clients.
// NOTE: original has NO mutex — concurrent map access races (handler goroutines
// assign while Write iterates). Do not copy that into a production build.
type WsMultiWriter struct {
	wsList map[*websocket.Conn]chan struct{}
}

func main() {
	port := flag.Int("port", 1699, "http port")
	audioPort := flag.Int("audio-port", 10000, "udp audio port")
	flag.Parse()

	w := &WsMultiWriter{wsList: make(map[*websocket.Conn]chan struct{})}

	// UDP pump goroutine
	go func() {
		addr := fmt.Sprintf(":%d", *audioPort)
		RunJsmpegUDP(addr, w)
	}()

	// WebSocket endpoint: one binary message per UDP datagram
	http.Handle("/audio", websocket.Handler(func(ws *websocket.Conn) {
		defer ws.Close()
		ws.PayloadType = websocket.BinaryFrame // 2
		ch := make(chan struct{}, 1)
		w.wsList[ws] = ch
		<-ch // unblocked by Write() on error
	}))

	log.Printf("Http listening on %s", fmt.Sprintf(":%d", *port))
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", *port), http.DefaultServeMux))
}

// RunJsmpegUDP receives the MPEG-TS UDP stream from ffmpeg and pushes it to
// every connected websocket client via io.Writer semantics.
func RunJsmpegUDP(addr string, w io.Writer) {
	udpAddr, err := net.ResolveUDPAddr("udp", addr)
	conn, err := net.ListenUDP("udp", udpAddr)
	if err != nil {
		fmt.Fprintln(os.Stdout, err) // original continues; conn may be nil -> panic on Close
	}
	defer conn.Close()
	log.Printf("Jsmpeg udp listening on %s", addr)
	io.Copy(w, conn)
}

// Write sends p (one UDP datagram = one jsmpeg TS chunk) to all clients.
// On a failing client: signal its handler goroutine to exit, nil the entry.
// On short write: bail immediately (original behavior).
func (mws *WsMultiWriter) Write(p []byte) (int, error) {
	for ws, ch := range mws.wsList {
		if ch == nil {
			continue
		}
		n, err := ws.Write(p)
		if err != nil {
			ch <- struct{}{}
			mws.wsList[ws] = nil
			continue
		}
		if n != len(p) {
			return n, nil
		}
	}
	return len(p), nil
}