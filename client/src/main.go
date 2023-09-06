package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"stellaris-client/dashboard"
	"time"

	"github.com/spiffe/go-spiffe/v2/spiffeid"
	"github.com/spiffe/go-spiffe/v2/spiffetls/tlsconfig"
	"github.com/spiffe/go-spiffe/v2/workloadapi"
)

const (
	port       = 8080
	dataURL    = "https://stellaris-api.server:8090/dashboard"
	socketPath = "unix:///run/spire/sockets/agent.sock"
)

var (
	latestData   = []*dashboard.Data(nil)
	latestUpdate = time.Now()
	// Stellaris quotes provider SPIFFE ID
	dataProviderSpiffeID = spiffeid.RequireFromString("spiffe://example.org/stellaris-wl")
	x509Src              *workloadapi.X509Source
	bundleSrc            *workloadapi.BundleSource
)

func main() {
	log.Print("Service waiting for an X.509 SVID...")

	ctx := context.Background()

	var err error
	x509Src, err = workloadapi.NewX509Source(ctx,
		workloadapi.WithClientOptions(
			workloadapi.WithAddr(socketPath),
			//workloadapi.WithLogger(logger.Std),
		),
	)
	if err != nil {
		log.Fatal(err)
	}

	log.Print("Service waiting for a trust bundle...")

	bundleSrc, err = workloadapi.NewBundleSource(ctx,
		workloadapi.WithClientOptions(
			workloadapi.WithAddr(socketPath),
		),
	)
	if err != nil {
		log.Fatal(err)
	}

	server := &http.Server{
		Addr: fmt.Sprintf(":%d", port),
	}
	http.HandleFunc("/dashboard", dashboardHandler)

	log.Printf("Client listening on port %d...", port)

	err = server.ListenAndServe()
	if err != nil {
		log.Fatal(err)
	}
}

func dashboardHandler(resp http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		resp.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	data, err := getDashboardData()

	if data != nil {
		latestData = data
		latestUpdate = time.Now()
	} else {
		data = latestData
	}

	dashboard.Page.Execute(resp, map[string]interface{}{
		"Data":        data,
		"Err":         err,
		"LastUpdated": latestUpdate,
	})
}

func getDashboardData() ([]*dashboard.Data, error) {
	client := http.Client{
		Transport: &http.Transport{
			TLSClientConfig: tlsconfig.MTLSClientConfig(x509Src, bundleSrc, tlsconfig.AuthorizeID(dataProviderSpiffeID)),
		},
	}

	resp, err := client.Get(dataURL)
	if err != nil {
		log.Printf("Error getting data: %v", err)
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		log.Printf("Dashboard data unavailable: %s", resp.Status)
		return nil, err
	}

	jsonData, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Printf("Error reading response body: %v", err)
		return nil, err
	}

	data := []*dashboard.Data{}
	err = json.Unmarshal(jsonData, &data)
	if err != nil {
		log.Printf("Error unmarshaling json quotes: %v", err)
		return nil, err
	}

	return data, nil
}
