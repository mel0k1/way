package main

import (
	"context"
	"fmt"
	"os"

	"github.com/sagernet/sing-box/experimental/deprecated"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"
	singjson "github.com/sagernet/sing/common/json"
	"github.com/sagernet/sing/service"
)

func main() {
	cfg := `{
  "log": {"level": "warn"},
  "dns": {
    "servers": [
      {"type": "udp", "tag": "dns-direct", "server": "8.8.8.8"},
      {"type": "https", "tag": "dns-proxy", "server": "1.1.1.1", "detour": "proxy"}
    ],
    "final": "dns-proxy",
    "strategy": "prefer_ipv4",
    "independent_cache": true
  },
  "inbounds": [
    {"type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 2080}
  ],
  "endpoints": [
    {
      "type": "wireguard",
      "tag": "proxy",
      "address": ["172.16.0.2/32"],
      "private_key": "QKuKZKXb3ZmLBv4YUwM9pIQKZ3XnYOq3oa7OwlBfI2k=",
      "mtu": 1280,
      "peers": [
        {
          "address": "engage.cloudflareclient.com",
          "port": 2408,
          "public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
          "allowed_ips": ["0.0.0.0/0", "::/0"],
          "reserved": [1, 2, 3]
        }
      ]
    }
  ],
  "outbounds": [
    {"type": "direct", "tag": "direct"}
  ],
  "route": {
    "final": "proxy",
    "default_domain_resolver": {"server": "dns-direct"}
  }
}`
	ctx := service.ContextWith(context.Background(), deprecated.NewStderrManager(log.StdLogger()))
	ctx = include.Context(ctx)
	if _, err := singjson.UnmarshalExtendedContext[option.Options](ctx, []byte(cfg)); err != nil {
		fmt.Println("ENDPOINTS_FAIL:", err)
		os.Exit(1)
	}
	fmt.Println("ENDPOINTS_OK")

	cfg2 := `{
  "log": {"level": "warn"},
  "inbounds": [
    {"type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 2080}
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy",
      "server": "example.com",
      "server_port": 443,
      "uuid": "11111111-2222-3333-4444-555555555555",
      "tls": {
        "enabled": true,
        "server_name": "example.com",
        "fragment": true,
        
        "utls": {"enabled": true, "fingerprint": "chrome"}
      },
      "multiplex": {
        "enabled": true,
        "protocol": "smux",
        "max_connections": 4,
        "min_streams": 4,
        "padding": true
      }
    },
    {"type": "direct", "tag": "direct"}
  ],
  "route": {"final": "proxy"}
}`
	if _, err := singjson.UnmarshalExtendedContext[option.Options](ctx, []byte(cfg2)); err != nil {
		fmt.Println("FRAGMUX_FAIL:", err)
		os.Exit(1)
	}
	fmt.Println("FRAGMUX_OK")
}
