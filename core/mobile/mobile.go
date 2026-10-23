package waycore

import (
        "fmt"

        core "github.com/mel0k1/way/core"
        "github.com/sagernet/sing-box/experimental/libbox"
)

var xrayController = core.NewXrayController()

func Version() string {
        return core.WayVersion
}

func CoreVersions() string {
        return fmt.Sprintf("sing-box %s / xray-core %s", libbox.Version(), core.XrayCoreVersion())
}

func NewCommandServer(handler libbox.CommandServerHandler, platform libbox.PlatformInterface) (*libbox.CommandServer, error) {
        return libbox.NewCommandServer(handler, platform)
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
