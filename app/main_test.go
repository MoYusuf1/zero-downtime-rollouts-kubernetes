package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func get(t *testing.T, path string) (int, map[string]any) {
	t.Helper()
	rec := httptest.NewRecorder()
	newMux().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("%s: bad JSON: %v", path, err)
	}
	return rec.Code, body
}

func TestGoodRelease(t *testing.T) {
	quoteTotal = "1200"
	if code, _ := get(t, "/readyz"); code != http.StatusOK {
		t.Fatalf("readyz = %d, want 200", code)
	}
	if _, body := get(t, "/quote"); body["total_cents"] != float64(1200) {
		t.Fatalf("quote = %v, want 1200", body["total_cents"])
	}
}

func TestBadReleaseIsNotReady(t *testing.T) {
	quoteTotal = "999"
	defer func() { quoteTotal = "1200" }()
	if code, _ := get(t, "/healthz"); code != http.StatusOK {
		t.Fatalf("healthz = %d, want 200 (the bad release still looks alive)", code)
	}
	if code, _ := get(t, "/readyz"); code != http.StatusServiceUnavailable {
		t.Fatalf("readyz = %d, want 503", code)
	}
}
