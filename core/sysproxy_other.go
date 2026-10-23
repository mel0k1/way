//go:build !windows

package waycore

import "os"

func IsAdmin() bool {
	return os.Geteuid() == 0
}

func setSystemProxy(enable bool, addr string) error {
	return nil
}
