package waycore

import (
	"net"
	"net/http"
)

func NewHandler(m *Manager) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /ping", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]any{"name": "waycore", "version": WayVersion, "xray": XrayCoreVersion()})
	})
	mux.HandleFunc("POST /start", func(w http.ResponseWriter, r *http.Request) {
		var req StartRequest
		if err := jsonDecode(r, &req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		if err := m.Start(req); err != nil {
			http.Error(w, err.Error(), http.StatusConflict)
			return
		}
		writeJSON(w, m.Status())
	})
	mux.HandleFunc("POST /stop", func(w http.ResponseWriter, r *http.Request) {
		if err := m.Stop(); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, m.Status())
	})
	mux.HandleFunc("GET /status", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, m.Status())
	})
	return mux
}

func Serve(addr string) error {
	manager := NewManager()
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	return http.Serve(listener, NewHandler(manager))
}
