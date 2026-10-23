//go:build !windows

package waycore

func killSwitchArm(tunLuid uint64) error {
	return nil
}

func killSwitchDisarm() {}

func tunLUID() (uint64, error) {
	return 0, nil
}
