//go:build linux

package waycore

import (
        "os"
        "os/exec"
        "strings"
)

func IsAdmin() bool {
        return os.Geteuid() == 0
}

func setSystemProxy(enable bool, addr string) error {
        if g, err := exec.LookPath("gsettings"); err == nil {
                return gsettingsProxy(g, enable, addr)
        }
        if k, err := exec.LookPath("kwriteconfig6"); err == nil {
                return kdeProxy(k, enable, addr)
        }
        if k, err := exec.LookPath("kwriteconfig5"); err == nil {
                return kdeProxy(k, enable, addr)
        }
        return nil
}

func gsettingsProxy(bin string, enable bool, addr string) error {
        run := func(args ...string) error {
                return exec.Command(bin, args...).Run()
        }
        if !enable {
                return run("set", "org.gnome.system.proxy", "mode", "none")
        }
        host, port := splitProxyAddr(addr)
        if err := run("set", "org.gnome.system.proxy", "mode", "manual"); err != nil {
                return err
        }
        for _, scheme := range []string{"http", "https", "socks"} {
                _ = run("set", "org.gnome.system.proxy."+scheme, "host", host)
                _ = run("set", "org.gnome.system.proxy."+scheme, "port", port)
        }
        return nil
}

func kdeProxy(bin string, enable bool, addr string) error {
        base := []string{"--file", "kioslaverc", "--group", "Proxy Settings"}
        run := func(key, value string) error {
                return exec.Command(bin, append(base, "--key", key, value)...).Run()
        }
        if !enable {
                return run("ProxyType", "0")
        }
        host, port := splitProxyAddr(addr)
        if err := run("ProxyType", "1"); err != nil {
                return err
        }
        _ = run("httpProxy", "http://"+host+" "+port)
        _ = run("httpsProxy", "http://"+host+" "+port)
        _ = run("socksProxy", "socks://"+host+" "+port)
        return nil
}

func splitProxyAddr(addr string) (string, string) {
        i := strings.LastIndex(addr, ":")
        if i < 0 {
                return addr, "8080"
        }
        return addr[:i], addr[i+1:]
}
