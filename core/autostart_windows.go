//go:build windows

package waycore

import (
	"os"
	"path/filepath"

	"golang.org/x/sys/windows/registry"
)

const (
	autostartRunKey = `Software\Microsoft\Windows\CurrentVersion\Run`
	autostartValue  = "Way"
)

func autostartCommand() (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", err
	}
	app := filepath.Join(filepath.Dir(exe), "way.exe")
	if _, err := os.Stat(app); err != nil {
		return "", err
	}
	return `"` + app + `"`, nil
}

func autostartEnabled() bool {
	key, err := registry.OpenKey(registry.CURRENT_USER, autostartRunKey, registry.QUERY_VALUE)
	if err != nil {
		return false
	}
	defer key.Close()
	val, _, err := key.GetStringValue(autostartValue)
	if err != nil {
		return false
	}
	want, err := autostartCommand()
	if err != nil {
		return val != ""
	}
	return val == want
}

func setAutostart(enable bool) error {
	key, err := registry.OpenKey(registry.CURRENT_USER, autostartRunKey, registry.QUERY_VALUE|registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer key.Close()
	if !enable {
		if err := key.DeleteValue(autostartValue); err != nil && err != registry.ErrNotExist {
			return err
		}
		return nil
	}
	cmd, err := autostartCommand()
	if err != nil {
		return err
	}
	return key.SetStringValue(autostartValue, cmd)
}
