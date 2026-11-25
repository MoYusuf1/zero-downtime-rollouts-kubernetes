// A tiny quote API used to measure what users see during a Kubernetes rollout.
package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"
)

// Set at build time with -ldflags, so each image tag is a different release.
var (
	version    = "dev"
	quoteTotal = "1200" // the bad release is built with 999
)

// expectedTotal is the known answer for the test case. It never changes with the release.
const expectedTotal = 1200

func total() int {
	n, err := strconv.Atoi(quoteTotal)
	if err != nil {
		return -1
	}
	return n
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func newMux() *http.ServeMux {
	mux := http.NewServeMux()
	// Liveness: the process is up.
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	// Readiness: the process is up AND gives the right answer for a known case.
	mux.HandleFunc("/readyz", func(w http.ResponseWriter, _ *http.Request) {
		if total() != expectedTotal {
			writeJSON(w, http.StatusServiceUnavailable, map[string]any{"ready": false, "total_cents": total(), "expected": expectedTotal})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ready": true})
	})
	mux.HandleFunc("/quote", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"version": version, "total_cents": total()})
	})
	return mux
}

func main() {
	// Real apps load config or warm caches before they can serve. This delay stands in for that.
	startup, _ := strconv.Atoi(os.Getenv("STARTUP_SECONDS"))
	log.Printf("version %s starting, warm-up %ds", version, startup)
	time.Sleep(time.Duration(startup) * time.Second)

	srv := &http.Server{Addr: ":8080", Handler: newMux(), ReadHeaderTimeout: 5 * time.Second}
	go func() {
		if err := srv.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()
	log.Printf("version %s listening on :8080", version)

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)
	<-stop
	log.Print("shutting down")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx) // finish requests already in progress
}
