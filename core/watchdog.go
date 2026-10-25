package waycore

import (
	"context"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

// probeTarget is a captive-portal style endpoint: any HTTP response (even 204,
// 302 or 4xx) proves the tunnel passes traffic, while a transport error means
// it does not.
const probeTarget = "http://www.gstatic.com/generate_204"

const (
	probeTimeout     = 6 * time.Second
	ProbeFailLimit   = 3
	restartBaseDelay = 5 * time.Second
	restartMaxDelay  = 60 * time.Second
	defaultMixedPort = 2080
)

// ProbeProxyPort checks that the tunnel actually passes traffic by making an
// HTTP request through the local proxy inbound (sing-box mixed or xray http).
// Loopback traffic never enters the TUN device, so the probe works in both
// tun and proxy modes.
func ProbeProxyPort(port int) bool {
	if port <= 0 {
		return true
	}
	proxyURL := &url.URL{
		Scheme: "http",
		Host:   net.JoinHostPort("127.0.0.1", strconv.Itoa(port)),
	}
	client := &http.Client{
		Timeout: probeTimeout,
		Transport: &http.Transport{
			Proxy:             http.ProxyURL(proxyURL),
			DisableKeepAlives: true,
		},
	}
	defer client.CloseIdleConnections()
	req, err := http.NewRequestWithContext(context.Background(), http.MethodGet, probeTarget, nil)
	if err != nil {
		return false
	}
	resp, err := client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 512))
	return true
}

// RestartBackoff grows exponentially with the failure streak:
// 5s, 10s, 20s, 40s, capped at 60s.
func RestartBackoff(failStreak int) time.Duration {
	d := restartBaseDelay
	for i := 0; i < failStreak && d < restartMaxDelay; i++ {
		d *= 2
	}
	if d > restartMaxDelay {
		d = restartMaxDelay
	}
	return d
}

// ProbePortFromConfig extracts the local mixed inbound port from a sing-box
// JSON config so the watchdog can probe it. Falls back to the default mixed
// port (2080) used by Way's config builder.
func ProbePortFromConfig(configJSON []byte) int {
	var parsed struct {
		Inbounds []struct {
			Type       string `json:"type"`
			ListenPort int    `json:"listen_port"`
		} `json:"inbounds"`
	}
	if err := json.Unmarshal(configJSON, &parsed); err == nil {
		for _, in := range parsed.Inbounds {
			if in.Type == "mixed" && in.ListenPort > 0 {
				return in.ListenPort
			}
		}
	}
	return defaultMixedPort
}
