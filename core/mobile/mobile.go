package waycore

import (
        "context"
        "fmt"
        "net/netip"
        "sync"

        core "github.com/mel0k1/way/core"

        box "github.com/sagernet/sing-box"
        "github.com/sagernet/sing-box/adapter"
        "github.com/sagernet/sing-box/experimental/deprecated"
        "github.com/sagernet/sing-box/include"
        "github.com/sagernet/sing-box/log"
        "github.com/sagernet/sing-box/option"
        tun "github.com/sagernet/sing-tun"
        E "github.com/sagernet/sing/common/exceptions"
        singjson "github.com/sagernet/sing/common/json"
        "github.com/sagernet/sing/common/logger"
        "github.com/sagernet/sing/service"

        _ "github.com/sagernet/gomobile/bind"
)

var xrayController = core.NewXrayController()

func Version() string {
        return core.WayVersion
}

func CoreVersions() string {
        return fmt.Sprintf("sing-box %s / xray-core %s", core.SingBoxVersion(), core.XrayCoreVersion())
}

func StartXray(configJSON string) error {
        return xrayController.Start([]byte(configJSON))
}

func StopXray() error {
        return xrayController.Stop()
}

func XrayRunning() bool {
        return xrayController.Running()
}

func UrlTest(singboxConfig string, xrayConfig string, port int32, timeoutMs int32) int32 {
        return int32(core.UrlTest(singboxConfig, xrayConfig, int(port), int(timeoutMs)))
}

type StringIterator interface {
        Next() string
        HasNext() bool
}

type TunConfig interface {
        GetInet4Addresses() StringIterator
        GetInet6Addresses() StringIterator
        GetInet4Routes() StringIterator
        GetInet6Routes() StringIterator
        GetDNSServers() StringIterator
        GetMTU() int32
        GetAutoRoute() bool
}

type PlatformInterface interface {
        OpenTun(config TunConfig) (int32, error)
        AutoDetectInterfaceControl(fd int32) error
}

type tunConfigData struct {
        inet4     []string
        inet6     []string
        routes4   []string
        routes6   []string
        dns       []string
        mtu       int32
        autoRoute bool
}

func (c *tunConfigData) GetInet4Addresses() StringIterator { return newStringIterator(c.inet4) }
func (c *tunConfigData) GetInet6Addresses() StringIterator { return newStringIterator(c.inet6) }
func (c *tunConfigData) GetInet4Routes() StringIterator    { return newStringIterator(c.routes4) }
func (c *tunConfigData) GetInet6Routes() StringIterator    { return newStringIterator(c.routes6) }
func (c *tunConfigData) GetDNSServers() StringIterator     { return newStringIterator(c.dns) }
func (c *tunConfigData) GetMTU() int32                     { return c.mtu }
func (c *tunConfigData) GetAutoRoute() bool                { return c.autoRoute }

type stringIterator struct {
        items []string
        index int
}

func newStringIterator(items []string) StringIterator {
        return &stringIterator{items: items}
}

func (it *stringIterator) Next() string {
        if it.index >= len(it.items) {
                return ""
        }
        item := it.items[it.index]
        it.index++
        return item
}

func (it *stringIterator) HasNext() bool {
        return it.index < len(it.items)
}

type CommandServer struct {
        mu       sync.Mutex
        platform PlatformInterface
        instance *box.Box
        cancel   context.CancelFunc
}

func NewCommandServer(platform PlatformInterface) (*CommandServer, error) {
        return &CommandServer{platform: platform}, nil
}

func (s *CommandServer) Start() error {
        return nil
}

func (s *CommandServer) StartOrReloadService(configContent string) error {
        s.mu.Lock()
        defer s.mu.Unlock()
        if s.instance != nil {
                _ = s.instance.Close()
                s.instance = nil
                if s.cancel != nil {
                        s.cancel()
                        s.cancel = nil
                }
        }
        ctx, cancel := buildContext()
        wrapper := &platformWrapper{iif: s.platform}
        ctx = service.ContextWith[adapter.PlatformInterface](ctx, wrapper)
        options, err := singjson.UnmarshalExtendedContext[option.Options](ctx, []byte(configContent))
        if err != nil {
                cancel()
                return err
        }
        instance, err := box.New(box.Options{
                Options: options,
                Context: ctx,
        })
        if err != nil {
                cancel()
                return err
        }
        if err = instance.Start(); err != nil {
                _ = instance.Close()
                cancel()
                return err
        }
        s.instance = instance
        s.cancel = cancel
        return nil
}

func (s *CommandServer) CloseService() error {
        s.mu.Lock()
        defer s.mu.Unlock()
        var firstErr error
        if s.instance != nil {
                if err := s.instance.Close(); err != nil {
                        firstErr = err
                }
                s.instance = nil
        }
        if s.cancel != nil {
                s.cancel()
                s.cancel = nil
        }
        return firstErr
}

func (s *CommandServer) Close() error {
        return s.CloseService()
}

func buildContext() (context.Context, context.CancelFunc) {
        ctx, cancel := context.WithCancel(context.Background())
        ctx = service.ContextWith(ctx, deprecated.NewStderrManager(log.StdLogger()))
        ctx = include.Context(ctx)
        return ctx, cancel
}

var _ adapter.PlatformInterface = (*platformWrapper)(nil)

type platformWrapper struct {
        iif PlatformInterface
}

func (w *platformWrapper) Initialize(networkManager adapter.NetworkManager) error {
        return nil
}

func (w *platformWrapper) UsePlatformAutoDetectInterfaceControl() bool {
        return true
}

func (w *platformWrapper) AutoDetectInterfaceControl(fd int) error {
        return w.iif.AutoDetectInterfaceControl(int32(fd))
}

func (w *platformWrapper) UsePlatformInterface() bool {
        return true
}

func (w *platformWrapper) OpenInterface(options *tun.Options, platformOptions option.TunPlatformOptions) (tun.Tun, error) {
        routeRanges, err := options.BuildAutoRouteRanges(true)
        if err != nil {
                return nil, err
        }
        cfg := &tunConfigData{
                inet4:     prefixStrings(options.Inet4Address),
                inet6:     prefixStrings(options.Inet6Address),
                routes4:   prefixStrings(options.Inet4RouteAddress),
                routes6:   prefixStrings(options.Inet6RouteAddress),
                mtu:       int32(options.MTU),
                autoRoute: options.AutoRoute,
        }
        if options.AutoRoute {
                cfg.routes4 = append(cfg.routes4, prefixStrings(filterPrefixes(routeRanges, true))...)
                cfg.routes6 = append(cfg.routes6, prefixStrings(filterPrefixes(routeRanges, false))...)
        }
        if dnsServers, err := options.DNSServerAddress(); err == nil {
                for _, addr := range dnsServers {
                        cfg.dns = append(cfg.dns, addr.String())
                }
        }
        fd, err := w.iif.OpenTun(cfg)
        if err != nil {
                return nil, err
        }
        options.FileDescriptor = int(fd)
        return tun.New(*options)
}

func (w *platformWrapper) ProcessPlatformOptions(options option.TunPlatformOptions) error {
        return nil
}

func (w *platformWrapper) UsePlatformDefaultInterfaceMonitor() bool {
        return false
}

func (w *platformWrapper) CreateDefaultInterfaceMonitor(logger logger.Logger) tun.DefaultInterfaceMonitor {
        return nil
}

func (w *platformWrapper) UsePlatformNetworkInterfaces() bool {
        return false
}

func (w *platformWrapper) NetworkInterfaces() ([]adapter.NetworkInterface, error) {
        return nil, nil
}

func (w *platformWrapper) UnderNetworkExtension() bool {
        return false
}

func (w *platformWrapper) NetworkExtensionIncludeAllNetworks() bool {
        return false
}

func (w *platformWrapper) ClearDNSCache() {}

func (w *platformWrapper) RequestPermissionForWIFIState() error {
        return nil
}

func (w *platformWrapper) ReadWIFIState(ctx context.Context) adapter.WIFIState {
        return adapter.WIFIState{}
}

func (w *platformWrapper) UsePlatformConnectionOwnerFinder() bool {
        return false
}

func (w *platformWrapper) FindConnectionOwner(request *adapter.FindConnectionOwnerRequest) (*adapter.ConnectionOwner, error) {
        return nil, E.New("unsupported")
}

func (w *platformWrapper) UsePlatformWIFIMonitor() bool {
        return false
}

func (w *platformWrapper) UsePlatformNotification() bool {
        return false
}

func (w *platformWrapper) SendNotification(notification *adapter.Notification) error {
        return nil
}

func (w *platformWrapper) CancelNotification(identifier string, typeID int32) error {
        return nil
}

func (w *platformWrapper) MyInterfaceAddress() []netip.Addr {
        return nil
}

func (w *platformWrapper) UsePlatformNeighborResolver() bool {
        return false
}

func (w *platformWrapper) StartNeighborMonitor(listener adapter.NeighborUpdateListener) error {
        return E.New("unsupported")
}

func (w *platformWrapper) CloseNeighborMonitor(listener adapter.NeighborUpdateListener) error {
        return nil
}

func (w *platformWrapper) UsePlatformShell() bool {
        return false
}

func (w *platformWrapper) CheckPlatformShell() error {
        return E.New("unsupported")
}

func (w *platformWrapper) OpenShellSession(user *adapter.PlatformUser, command string, env []string, term string, rows int32, cols int32) (adapter.ShellSession, error) {
        return nil, E.New("unsupported")
}

func (w *platformWrapper) LookupUser(username string) (*adapter.PlatformUser, error) {
        return nil, E.New("unsupported")
}

func (w *platformWrapper) LookupSFTPServer() (string, error) {
        return "", E.New("unsupported")
}

func (w *platformWrapper) ReadSystemSSHHostKey() ([]byte, error) {
        return nil, E.New("unsupported")
}

func (w *platformWrapper) TailscaleHostname() string {
        return ""
}

func (w *platformWrapper) UsePlatformBridge() bool {
        return false
}

func (w *platformWrapper) CreateBridge(options adapter.BridgeOptions) (adapter.BridgeSession, error) {
        return nil, E.New("unsupported")
}

func prefixStrings(prefixes []netip.Prefix) []string {
        out := make([]string, 0, len(prefixes))
        for _, p := range prefixes {
                out = append(out, p.String())
        }
        return out
}

func filterPrefixes(prefixes []netip.Prefix, is4 bool) []netip.Prefix {
        var out []netip.Prefix
        for _, p := range prefixes {
                if p.Addr().Is4() == is4 {
                        out = append(out, p)
                }
        }
        return out
}
