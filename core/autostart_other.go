//go:build !windows

package waycore

func autostartEnabled() bool {
	return false
}

func setAutostart(enable bool) error {
	_ = enable
	return nil
}
