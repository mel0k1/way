package waycore

import (
        "context"
        "fmt"
        "io"
        "net/http"
        "net/url"
        "time"

        box "github.com/sagernet/sing-box"
        "github.com/sagernet/sing-box/experimental/deprecated"
        "github.com/sagernet/sing-box/include"
        "github.com/sagernet/sing-box/log"
        "github.com/sagernet/sing-box/option"
        singjson "github.com/sagernet/sing/common/json"
        "github.com/sagernet/sing/service"
)

const urlTestTarget = "http://www.gstatic.com/generate_204"

func UrlTest(singboxConfig string, xrayConfig string, port int, timeoutMs int) int {
        if timeoutMs <= 0 || timeoutMs > 20000 {
                timeoutMs = 8000
        }
        if port <= 0 {
                return -1
        }
        deadline := time.Now().Add(time.Duration(timeoutMs) * time.Millisecond)
        switch {
        case singboxConfig != "":
                stop, err := startProbeBox(singboxConfig, deadline)
                if err != nil {
                        return -1
                }
                defer stop()
        case xrayConfig != "":
                stop, err := startProbeXray(xrayConfig, deadline)
                if err != nil {
                        return -1
                }
                defer stop()
        default:
                return -1
        }
        return probeHttp(port, time.Until(deadline))
}

func startProbeBox(config string, deadline time.Time) (func(), error) {
        ctx, cancel := context.WithDeadline(context.Background(), deadline)
        ctx = service.ContextWith(ctx, deprecated.NewStderrManager(log.StdLogger()))
        ctx = include.Context(ctx)
        options, err := singjson.UnmarshalExtendedContext[option.Options](ctx, []byte(config))
        if err != nil {
                cancel()
                return nil, err
        }
        instance, err := box.New(box.Options{
                Options: options,
                Context: ctx,
        })
        if err != nil {
                cancel()
                return nil, err
        }
        if err = instance.Start(); err != nil {
                instance.Close()
                cancel()
                return nil, err
        }
        return func() {
                instance.Close()
                cancel()
        }, nil
}

func startProbeXray(config string, deadline time.Time) (func(), error) {
        controller := NewXrayController()
        if err := controller.Start([]byte(config)); err != nil {
                return nil, err
        }
        return func() {
                _ = controller.Stop()
        }, nil
}

func probeHttp(port int, timeout time.Duration) int {
        if timeout <= 0 {
                return -1
        }
        proxyURL := &url.URL{
                Scheme: "socks5",
                Host:   fmt.Sprintf("127.0.0.1:%d", port),
        }
        client := &http.Client{
                Transport: &http.Transport{
                        Proxy:                 http.ProxyURL(proxyURL),
                        DisableKeepAlives:     true,
                        TLSHandshakeTimeout:   timeout,
                        ResponseHeaderTimeout: timeout,
                },
                Timeout: timeout,
        }
        start := time.Now()
        req, err := http.NewRequest(http.MethodGet, urlTestTarget, nil)
        if err != nil {
                return -1
        }
        req.Header.Set("User-Agent", "Way/1.3")
        resp, err := client.Do(req)
        if err != nil {
                return -1
        }
        defer resp.Body.Close()
        _, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
        return int(time.Since(start).Milliseconds())
}
