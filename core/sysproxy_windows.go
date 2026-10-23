//go:build windows

package waycore

import (
        "os"
        "unsafe"

        "golang.org/x/sys/windows"
        "golang.org/x/sys/windows/registry"
)

const (
        internetOptionSettingsChanged = 39
        internetOptionRefresh         = 37
)

var (
        wininet               = windows.NewLazySystemDLL("wininet.dll")
        procInternetSetOption = wininet.NewProc("InternetSetOptionW")
)

func IsAdmin() bool {
        f, err := os.Open("\\\\.\\PHYSICALDRIVE0")
        if err != nil {
                return false
        }
        f.Close()
        return true
}

func setSystemProxy(enable bool, addr string) error {
        key, err := registry.OpenKey(
                registry.CURRENT_USER,
                `Software\Microsoft\Windows\CurrentVersion\Internet Settings`,
                registry.QUERY_VALUE|registry.SET_VALUE,
        )
        if err != nil {
                return err
        }
        defer key.Close()
        if enable {
                if err = key.SetDWordValue("ProxyEnable", 1); err != nil {
                        return err
                }
                if err = key.SetStringValue("ProxyServer", addr); err != nil {
                        return err
                }
                if err = key.SetStringValue("ProxyOverride", "<local>"); err != nil {
                        return err
                }
        } else {
                if err = key.SetDWordValue("ProxyEnable", 0); err != nil {
                        return err
                }
        }
        refreshWininet()
        return nil
}

func refreshWininet() {
        if procInternetSetOption.Find() != nil {
                return
        }
        procInternetSetOption.Call(0, internetOptionSettingsChanged, 0, 0)
        procInternetSetOption.Call(0, internetOptionRefresh, 0, 0)
        _ = unsafe.Sizeof(0)
}
