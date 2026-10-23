package waycore

import (
        "encoding/json"
        "io"
        "net/http"

        "github.com/sagernet/sing-box/constant"
)

var WayVersion = "1.0.0"

func SingBoxVersion() string {
        return constant.Version
}

func writeJSON(w http.ResponseWriter, v any) {
        w.Header().Set("Content-Type", "application/json")
        _ = json.NewEncoder(w).Encode(v)
}

func jsonDecode(r *http.Request, v any) error {
        body, err := io.ReadAll(io.LimitReader(r.Body, 4<<20))
        if err != nil {
                return err
        }
        defer r.Body.Close()
        return json.Unmarshal(body, v)
}
