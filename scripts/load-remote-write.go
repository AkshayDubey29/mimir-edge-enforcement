package main

import (
	"bytes"
	"compress/gzip"
	"crypto/rand"
	"encoding/binary"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/golang/snappy"
	"google.golang.org/protobuf/proto"

	prompb "github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus"
)

var (
	url         = flag.String("url", "http://localhost:8080/api/v1/push", "Target URL")
	tenantID    = flag.String("tenant", "test-tenant", "Tenant ID")
	concurrency = flag.Int("concurrency", 10, "Number of concurrent requests")
	duration    = flag.Duration("duration", 60*time.Second, "Test duration")
	samples     = flag.Int("samples", 100, "Number of samples per request")
	series      = flag.Int("series", 10, "Number of series per request")
	compression = flag.String("compression", "gzip", "Compression type (gzip, snappy, none)")
)

func main() {
	flag.Parse()

	log.Printf("Starting load test:")
	log.Printf("  URL: %s", *url)
	log.Printf("  Tenant: %s", *tenantID)
	log.Printf("  Concurrency: %d", *concurrency)
	log.Printf("  Duration: %v", *duration)
	log.Printf("  Samples per request: %d", *samples)
	log.Printf("  Series per request: %d", *series)
	log.Printf("  Compression: %s", *compression)

	// Create HTTP client
	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	// Start workers
	var wg sync.WaitGroup
	start := time.Now()
	end := start.Add(*duration)

	for i := 0; i < *concurrency; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			worker(client, workerID, end)
		}(i)
	}

	wg.Wait()
	log.Printf("Load test completed in %v", time.Since(start))
}

func worker(client *http.Client, workerID int, end time.Time) {
	requestID := 0
	for time.Now().Before(end) {
		requestID++
		sendRequest(client, workerID, requestID)
		time.Sleep(100 * time.Millisecond) // 10 RPS per worker
	}
}

func sendRequest(client *http.Client, workerID, requestID int) {
	// Create sample data
	writeRequest := createWriteRequest(workerID, requestID)

	// Serialize to protobuf
	data, err := proto.Marshal(writeRequest)
	if err != nil {
		log.Printf("Failed to marshal protobuf: %v", err)
		return
	}

	// Compress if needed
	var body bytes.Buffer
	var contentType string
	var contentEncoding string
	switch *compression {
	case "gzip":
		gw := gzip.NewWriter(&body)
		if _, err := gw.Write(data); err != nil {
			log.Printf("Failed to compress data: %v", err)
			return
		}
		gw.Close()
		contentType = "application/x-protobuf"
		contentEncoding = "gzip"
	case "snappy":
		compressed := snappy.Encode(nil, data)
		body.Write(compressed)
		contentType = "application/x-protobuf"
		contentEncoding = "snappy"
	default:
		body.Write(data)
		contentType = "application/x-protobuf"
		contentEncoding = ""
	}

	// Create request
	req, err := http.NewRequest("POST", *url, &body)
	if err != nil {
		log.Printf("Failed to create request: %v", err)
		return
	}

	// Set headers
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("X-Scope-OrgID", *tenantID)
	if contentEncoding != "" {
		req.Header.Set("Content-Encoding", contentEncoding)
	}

	// Send request
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("Request failed: %v", err)
		return
	}
	defer resp.Body.Close()

	// Read response body
	io.Copy(io.Discard, resp.Body)

	// Log response
	if resp.StatusCode != http.StatusOK {
		log.Printf("Request failed with status %d", resp.StatusCode)
	}
}

func createWriteRequest(workerID, requestID int) *prompb.WriteRequest {
	writeRequest := &prompb.WriteRequest{
		Timeseries: make([]*prompb.TimeSeries, *series),
	}

	now := time.Now().UnixMilli()

	for i := 0; i < *series; i++ {
		series := &prompb.TimeSeries{
			Labels: []*prompb.Label{
				{Name: "__name__", Value: "test_metric"},
				{Name: "worker", Value: fmt.Sprintf("worker_%d", workerID)},
				{Name: "series", Value: fmt.Sprintf("series_%d", i)},
				{Name: "tenant", Value: *tenantID},
			},
			Samples: make([]*prompb.Sample, *samples),
		}

		for j := 0; j < *samples; j++ {
			series.Samples[j] = &prompb.Sample{
				Value:     float64(j) + float64(workerID)*0.1,
				Timestamp: now + int64(j*1000), // 1 second intervals
			}
		}

		writeRequest.Timeseries[i] = series
	}

	return writeRequest
}

// Helper function to generate random bytes
func randomBytes(n int) []byte {
	b := make([]byte, n)
	rand.Read(b)
	return b
}

// Helper function to generate random float64
func randomFloat64() float64 {
	b := make([]byte, 8)
	rand.Read(b)
	return float64(binary.LittleEndian.Uint64(b))
}
