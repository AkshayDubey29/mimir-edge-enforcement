package main

import (
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/golang/snappy"
	"google.golang.org/protobuf/proto"

	prompb "github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus"
)

func main() {
	fmt.Println("Testing Alloy-like data format with basic auth...")

	// Create sample Prometheus data (similar to Alloy's format)
	writeRequest := &prompb.WriteRequest{
		Timeseries: []*prompb.TimeSeries{
			{
				Labels: []*prompb.Label{
					{Name: "__name__", Value: "test_metric"},
					{Name: "job", Value: "alloy"},
					{Name: "instance", Value: "alloy-instance"},
					{Name: "tenant", Value: "seller"},
				},
				Samples: []*prompb.Sample{
					{Value: 42.0, Timestamp: time.Now().UnixMilli()},
					{Value: 43.0, Timestamp: time.Now().UnixMilli()},
				},
			},
		},
	}

	// Marshal to protobuf
	data, err := proto.Marshal(writeRequest)
	if err != nil {
		fmt.Printf("Failed to marshal protobuf: %v\n", err)
		return
	}

	// Test different compression formats that Alloy might use
	testCases := []struct {
		name            string
		compression     string
		contentEncoding string
		username        string
		password        string
	}{
		{
			name:            "Gzip with seller auth",
			compression:     "gzip",
			contentEncoding: "gzip",
			username:        "seller",
			password:        "seller",
		},
		{
			name:            "Snappy with couwatch auth",
			compression:     "snappy",
			contentEncoding: "snappy",
			username:        "couwatch",
			password:        "push",
		},
		{
			name:            "Uncompressed with seller auth",
			compression:     "none",
			contentEncoding: "",
			username:        "seller",
			password:        "seller",
		},
	}

	for _, tc := range testCases {
		fmt.Printf("\n=== Testing: %s ===\n", tc.name)

		// Compress data based on test case
		var compressedData []byte
		switch tc.compression {
		case "gzip":
			var buf bytes.Buffer
			gw := gzip.NewWriter(&buf)
			gw.Write(data)
			gw.Close()
			compressedData = buf.Bytes()
		case "snappy":
			compressedData = snappy.Encode(nil, data)
		case "none":
			compressedData = data
		}

		// Create basic auth header
		auth := base64.StdEncoding.EncodeToString([]byte(fmt.Sprintf("%s:%s", tc.username, tc.password)))

		// Create request
		req, err := http.NewRequest("POST", "http://localhost:8080/api/v1/push", bytes.NewReader(compressedData))
		if err != nil {
			fmt.Printf("Failed to create request: %v\n", err)
			continue
		}

		// Set headers like Alloy would
		req.Header.Set("Authorization", "Basic "+auth)
		req.Header.Set("Content-Type", "application/x-protobuf")
		if tc.contentEncoding != "" {
			req.Header.Set("Content-Encoding", tc.contentEncoding)
		}
		req.Header.Set("X-Prometheus-Remote-Write-Version", "0.1.0")

		// Send request
		client := &http.Client{Timeout: 10 * time.Second}
		resp, err := client.Do(req)
		if err != nil {
			fmt.Printf("Request failed: %v\n", err)
			continue
		}

		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		fmt.Printf("Status: %d\n", resp.StatusCode)
		fmt.Printf("Response: %s\n", string(body))
		fmt.Printf("Data size: %d bytes\n", len(compressedData))
		fmt.Printf("Auth: Basic %s\n", auth)
	}
}
