package main

import (
        "flag"
        "fmt"
        "os"
        "os/signal"
        "syscall"

        core "github.com/mel0k1/way/core"
)

func main() {
        addr := flag.String("addr", "127.0.0.1:20717", "control api listen address")
        version := flag.Bool("version", false, "print version")
        flag.Parse()

        if *version {
                fmt.Println("waycore " + core.WayVersion + " (xray " + core.XrayCoreVersion() + ")")
                return
        }

        go func() {
                if err := core.Serve(*addr); err != nil {
                        fmt.Fprintln(os.Stderr, "waycore:", err)
                        os.Exit(1)
                }
        }()

        fmt.Println("waycore listening on " + *addr)
        sig := make(chan os.Signal, 1)
        signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
        <-sig
}
