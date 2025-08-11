package main

import (
	"encoding/base64"
	"fmt"
	"log"

	"google.golang.org/protobuf/proto"

	prompb "github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus"
)

func main() {
	// Create the exact same data as the load test
	writeRequest := createWriteRequest(1, 1)

	// Serialize to protobuf
	data, err := proto.Marshal(writeRequest)
	if err != nil {
		log.Fatalf("Failed to marshal protobuf: %v", err)
	}

	fmt.Printf("Original data size: %d bytes\n", len(data))
	fmt.Printf("Original data preview: %q\n", string(data[:minInt(100, len(data))]))

	// Test unmarshaling the original data
	var writeRequest2 prompb.WriteRequest
	if err := proto.Unmarshal(data, &writeRequest2); err != nil {
		log.Fatalf("Failed to unmarshal original data: %v", err)
	}

	fmt.Printf("Original data unmarshaled successfully: %d timeseries\n", len(writeRequest2.Timeseries))

	// Simulate the RLS service's body extraction logic
	// First, let's see what happens if we treat the data as a string and back to bytes
	bodyString := string(data)
	fmt.Printf("Body string length: %d\n", len(bodyString))
	fmt.Printf("Body string preview: %q\n", bodyString[:minInt(100, len(bodyString))])

	// Convert back to bytes (this is what the RLS service does)
	bodyBytes := []byte(bodyString)
	fmt.Printf("Body bytes length: %d\n", len(bodyBytes))
	fmt.Printf("Body bytes preview: %q\n", string(bodyBytes[:minInt(100, len(bodyBytes))]))

	// Test unmarshaling the converted data
	var writeRequest3 prompb.WriteRequest
	if err := proto.Unmarshal(bodyBytes, &writeRequest3); err != nil {
		log.Printf("Failed to unmarshal converted data: %v", err)
	} else {
		fmt.Printf("Converted data unmarshaled successfully: %d timeseries\n", len(writeRequest3.Timeseries))
	}

	// Test base64 encoding/decoding (in case that's the issue)
	base64Data := base64.StdEncoding.EncodeToString(data)
	fmt.Printf("Base64 data length: %d\n", len(base64Data))
	fmt.Printf("Base64 data preview: %s\n", base64Data[:minInt(100, len(base64Data))])

	// Try to decode base64
	decodedData, err := base64.StdEncoding.DecodeString(base64Data)
	if err != nil {
		log.Fatalf("Failed to decode base64: %v", err)
	}

	fmt.Printf("Decoded base64 data length: %d\n", len(decodedData))
	fmt.Printf("Decoded base64 data preview: %q\n", string(decodedData[:minInt(100, len(decodedData))]))

	// Test unmarshaling the base64 decoded data
	var writeRequest4 prompb.WriteRequest
	if err := proto.Unmarshal(decodedData, &writeRequest4); err != nil {
		log.Fatalf("Failed to unmarshal base64 decoded data: %v", err)
	}

	fmt.Printf("Base64 decoded data unmarshaled successfully: %d timeseries\n", len(writeRequest4.Timeseries))
}

// Copy the exact same function from load-remote-write.go
func createWriteRequest(workerID, requestID int) *prompb.WriteRequest {
	writeRequest := &prompb.WriteRequest{
		Timeseries: make([]*prompb.TimeSeries, 10), // series = 10
	}

	now := int64(1733928000000) // Use a fixed timestamp

	for i := 0; i < 10; i++ {
		series := &prompb.TimeSeries{
			Labels: []*prompb.Label{
				{Name: "__name__", Value: "test_metric"},
				{Name: "worker", Value: fmt.Sprintf("worker_%d", workerID)},
				{Name: "series", Value: fmt.Sprintf("series_%d", i)},
				{Name: "tenant", Value: "test-tenant"},
			},
			Samples: make([]*prompb.Sample, 100), // samples = 100
		}

		for j := 0; j < 100; j++ {
			series.Samples[j] = &prompb.Sample{
				Value:     float64(j) + float64(workerID)*0.1,
				Timestamp: now + int64(j*1000), // 1 second intervals
			}
		}

		writeRequest.Timeseries[i] = series
	}

	return writeRequest
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}
