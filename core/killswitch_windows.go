//go:build windows

package waycore

import (
        "fmt"

        "golang.zx2c4.com/wireguard/windows/tunnel/firewall"
        "golang.zx2c4.com/wireguard/windows/tunnel/winipcfg"
)

const wayTunName = "way_tun"

func killSwitchArm(tunLuid uint64) error {
        firewall.DisableFirewall()
        return firewall.EnableFirewall(tunLuid, false, nil)
}

func killSwitchDisarm() {
        firewall.DisableFirewall()
}

func tunLUID() (uint64, error) {
        adapters, err := winipcfg.GetAdaptersAddresses(0, 0)
        if err != nil {
                return 0, fmt.Errorf("way: enumerate adapters: %w", err)
        }
        for _, a := range adapters {
                if a.FriendlyName() == wayTunName {
                        return uint64(a.LUID), nil
                }
        }
        return 0, fmt.Errorf("way: tun adapter %q not found", wayTunName)
}
