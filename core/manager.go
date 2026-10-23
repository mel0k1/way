package waycore

import (
        "context"
        "encoding/json"
        "errors"
        "fmt"
        "sync"
        "time"

        box "github.com/sagernet/sing-box"
        "github.com/sagernet/sing-box/experimental/deprecated"
        "github.com/sagernet/sing-box/include"
        "github.com/sagernet/sing-box/log"
        "github.com/sagernet/sing-box/option"
        singjson "github.com/sagernet/sing/common/json"
        "github.com/sagernet/sing/service"
)

const (
        EngineSingBox = "singbox"
        EngineXray    = "xray"
        ModeTun       = "tun"
        ModeProxy     = "proxy"
)

type StartRequest struct {
        Engine          string          `json:"engine"`
        Mode            string          `json:"mode"`
        Config          json.RawMessage `json:"config,omitempty"`
        Bridge          json.RawMessage `json:"bridge,omitempty"`
        SystemProxy     bool            `json:"system_proxy,omitempty"`
        SystemProxyPort int             `json:"system_proxy_port,omitempty"`
        KillSwitch      bool            `json:"kill_switch,omitempty"`
}

type Status struct {
        Running    bool   `json:"running"`
        Engine     string `json:"engine"`
        Mode       string `json:"mode"`
        Uptime     int64  `json:"uptime"`
        Admin      bool   `json:"admin"`
        Platform   string `json:"platform"`
        KillSwitch bool   `json:"kill_switch"`
        Watchdog   bool   `json:"watchdog"`
        Error      string `json:"error,omitempty"`
}

type Manager struct {
        mu         sync.Mutex
        ctx        context.Context
        cancel     context.CancelFunc
        instance   *box.Box
        bridge     *box.Box
        xray       *XrayController
        engine     string
        mode       string
        started    time.Time
        lastErr    string
        desired    bool
        killSwitch bool
        lastReq    *StartRequest
        watchStop  chan struct{}
        watchOnce  sync.Once
}

func NewManager() *Manager {
        return &Manager{xray: NewXrayController()}
}

func buildContext() (context.Context, context.CancelFunc) {
        ctx, cancel := context.WithCancel(context.Background())
        ctx = service.ContextWith(ctx, deprecated.NewStderrManager(log.StdLogger()))
        ctx = include.Context(ctx)
        return ctx, cancel
}

func (m *Manager) Start(req StartRequest) error {
        m.mu.Lock()
        defer m.mu.Unlock()
        if m.instance != nil || m.xray.Running() {
                return errors.New("way: engine already running")
        }
        if req.Engine != EngineSingBox && req.Engine != EngineXray {
                return fmt.Errorf("way: unknown engine %q", req.Engine)
        }
        if len(req.Config) == 0 {
                return errors.New("way: empty config")
        }
        if err := m.startLocked(req); err != nil {
                return err
        }
        m.desired = true
        m.lastReq = &req
        m.killSwitch = req.KillSwitch
        m.startWatchdogLocked()
        return nil
}

func (m *Manager) startLocked(req StartRequest) error {
        ctx, cancel := buildContext()
        cleanup := func() {
                cancel()
                m.lastErr = ""
        }
        if req.KillSwitch {
                if err := killSwitchArm(0); err != nil {
                        cancel()
                        m.lastErr = err.Error()
                        return fmt.Errorf("way: kill switch: %w", err)
                }
        }

        if req.Engine == EngineSingBox {
                instance, err := startSingBox(ctx, req.Config)
                if err != nil {
                        m.lastErr = err.Error()
                        cleanup()
                        killSwitchDisarm()
                        return err
                }
                m.instance = instance
        } else {
                if err := m.xray.Start(req.Config); err != nil {
                        m.lastErr = err.Error()
                        cleanup()
                        killSwitchDisarm()
                        return err
                }
                if len(req.Bridge) > 0 {
                        bridgeInstance, err := startSingBox(ctx, req.Bridge)
                        if err != nil {
                                m.xray.Stop()
                                m.lastErr = err.Error()
                                cleanup()
                                killSwitchDisarm()
                                return err
                        }
                        m.bridge = bridgeInstance
                }
        }

        if req.KillSwitch && req.Mode == ModeTun {
                if err := m.armTunKillSwitch(); err != nil {
                        m.closeEnginesLocked()
                        m.lastErr = err.Error()
                        cleanup()
                        killSwitchDisarm()
                        return err
                }
        }

        if req.SystemProxy && req.SystemProxyPort > 0 {
                if err := setSystemProxy(true, fmt.Sprintf("127.0.0.1:%d", req.SystemProxyPort)); err != nil {
                        m.lastErr = err.Error()
                }
        }

        m.ctx, m.cancel = ctx, cancel
        m.engine = req.Engine
        m.mode = req.Mode
        m.started = time.Now()
        m.lastErr = ""
        return nil
}

func (m *Manager) armTunKillSwitch() error {
        var luid uint64
        var err error
        for i := 0; i < 25; i++ {
                luid, err = tunLUID()
                if err == nil {
                        break
                }
                time.Sleep(200 * time.Millisecond)
        }
        if err != nil {
                return err
        }
        killSwitchDisarm()
        return killSwitchArm(luid)
}

func (m *Manager) startWatchdogLocked() {
        if m.watchStop != nil {
                return
        }
        m.watchStop = make(chan struct{})
        stop := m.watchStop
        go func() {
                ticker := time.NewTicker(5 * time.Second)
                defer ticker.Stop()
                for {
                        select {
                        case <-stop:
                                return
                        case <-ticker.C:
                                m.mu.Lock()
                                req := m.lastReq
                                if m.desired && m.instance == nil && !m.xray.Running() && req != nil {
                                        m.closeEnginesLocked()
                                        if m.cancel != nil {
                                                m.cancel()
                                                m.cancel = nil
                                        }
                                        if err := m.startLocked(*req); err != nil {
                                                m.lastErr = err.Error()
                                        }
                                }
                                m.mu.Unlock()
                        }
                }
        }()
}

func (m *Manager) closeEnginesLocked() {
        if m.bridge != nil {
                _ = m.bridge.Close()
                m.bridge = nil
        }
        if m.instance != nil {
                _ = m.instance.Close()
                m.instance = nil
        }
        _ = m.xray.Stop()
}

func (m *Manager) Stop() error {
        m.mu.Lock()
        defer m.mu.Unlock()
        m.desired = false
        m.lastReq = nil
        if m.watchStop != nil {
                m.watchOnce.Do(func() { close(m.watchStop) })
                m.watchStop = nil
                m.watchOnce = sync.Once{}
        }
        var firstErr error
        m.closeEnginesLocked()
        if m.cancel != nil {
                m.cancel()
                m.cancel = nil
        }
        if err := setSystemProxy(false, ""); err != nil && firstErr == nil {
                firstErr = err
        }
        killSwitchDisarm()
        m.engine = ""
        m.mode = ""
        m.killSwitch = false
        return firstErr
}

func (m *Manager) Status() Status {
        m.mu.Lock()
        defer m.mu.Unlock()
        running := m.instance != nil || m.xray.Running()
        var uptime int64
        if running && !m.started.IsZero() {
                uptime = int64(time.Since(m.started).Seconds())
        }
        return Status{
                Running:    running,
                Engine:     m.engine,
                Mode:       m.mode,
                Uptime:     uptime,
                Admin:      IsAdmin(),
                Platform:   PlatformName,
                KillSwitch: m.killSwitch,
                Watchdog:   m.watchStop != nil,
                Error:      m.lastErr,
        }
}

func startSingBox(ctx context.Context, configContent []byte) (*box.Box, error) {
        options, err := singjson.UnmarshalExtendedContext[option.Options](ctx, configContent)
        if err != nil {
                return nil, err
        }
        instance, err := box.New(box.Options{
                Options: options,
                Context: ctx,
        })
        if err != nil {
                return nil, err
        }
        if err = instance.Start(); err != nil {
                instance.Close()
                return nil, err
        }
        return instance, nil
}
