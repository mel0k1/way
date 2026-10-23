package waycore

import (
	"bytes"
	"sync"

	"github.com/xtls/xray-core/core"
	"github.com/xtls/xray-core/infra/conf/serial"

	_ "github.com/xtls/xray-core/main/distro/all"
)

var xrayVersion = "dev"

func XrayCoreVersion() string {
	return xrayVersion
}

type XrayController struct {
	mu       sync.Mutex
	instance *core.Instance
}

func NewXrayController() *XrayController {
	return &XrayController{}
}

func (c *XrayController) Start(configContent []byte) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.instance != nil {
		return nil
	}
	config, err := serial.LoadJSONConfig(bytes.NewReader(configContent))
	if err != nil {
		return err
	}
	instance, err := core.New(config)
	if err != nil {
		return err
	}
	if err = instance.Start(); err != nil {
		instance.Close()
		return err
	}
	c.instance = instance
	return nil
}

func (c *XrayController) Stop() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.instance == nil {
		return nil
	}
	err := c.instance.Close()
	c.instance = nil
	return err
}

func (c *XrayController) Running() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.instance != nil
}
