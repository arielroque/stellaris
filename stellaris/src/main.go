package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"sync"
	"time"

	"github.com/spiffe/go-spiffe/v2/spiffeid"
	"github.com/spiffe/go-spiffe/v2/spiffetls/tlsconfig"
	"github.com/spiffe/go-spiffe/v2/workloadapi"
)

const (
	port       = 8090
	socketPath = "unix:///run/spire/sockets/agent.sock"
)

var (
	dataList = []*Data{
		{Sensor: "Inertial Measurement Unit (IMU)"},
		{Sensor: "Thermocouple"},
		{Sensor: "Pressure Sensor"},
		{Sensor: "Altitude Sensor"},
		{Sensor: "Power Monitoring"},
		{Sensor: "Environmental Sensor"},
		{Sensor: "Communication System"},
		{Sensor: "Fault Detection"},
		{Sensor: "Emergency Systems"},
		{Sensor: "Structural Integrity Sensor"},
		{Sensor: "Gas Sensor"},
	}
	dataMtx        = sync.RWMutex{}
	brokerSpiffeID = spiffeid.RequireFromString("spiffe://example.org/client-wl")
)

func main() {

	log.Println("Service waiting for an X.509 SVID...")

	ctx := context.Background()
	x509Src, err := workloadapi.NewX509Source(ctx,
		workloadapi.WithClientOptions(
			workloadapi.WithAddr(socketPath),
			//workloadapi.WithLogger(logger.Std),
		),
	)
	if err != nil {
		log.Fatal(err)
	}

	log.Print("Service waiting for a trust bundle...")

	bundleSrc, err := workloadapi.NewBundleSource(ctx,
		workloadapi.WithClientOptions(
			workloadapi.WithAddr(socketPath),
		),
	)
	if err != nil {
		log.Fatal(err)
	}

	server := &http.Server{
		Addr:      fmt.Sprintf(":%d", port),
		TLSConfig: tlsconfig.MTLSServerConfig(x509Src, bundleSrc, tlsconfig.AuthorizeID(brokerSpiffeID)),
	}

	http.HandleFunc("/dashboard", dataHandler)

	log.Printf("Stellaris service listening on port %d...", port)

	err = server.ListenAndServeTLS("", "")
	if err != nil {
		log.Fatal(err)
	}

}

// Data represent a quote for a specific Sensor in a specific time.
type Data struct {
	Sensor string
	Status float64
	Time   *time.Time
}

func dataHandler(resp http.ResponseWriter, req *http.Request) {
	randomizedata()

	encoder := json.NewEncoder(resp)
	dataMtx.RLock()
	err := encoder.Encode(dataList)
	dataMtx.RUnlock()
	if err != nil {
		log.Printf("Error encoding data: %v", err)
		resp.WriteHeader(http.StatusInternalServerError)
		return
	}
}

func randomizedata() {
	dataMtx.Lock()
	for _, data := range dataList {
		if rand.Int()%4 == 0 {
			priceDelta := rand.NormFloat64() * 1.5
			now := time.Now()
			if data.Time == nil {
				data.Status = priceDelta + 10 + 100*rand.Float64()
			} else {
				data.Status += priceDelta
			}
			data.Time = &now
		}
	}
	dataMtx.Unlock()
}
