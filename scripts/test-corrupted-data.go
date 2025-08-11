package main

import (
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

	// Simulate the corruption that the RLS service is experiencing
	// From the debug output, I can see that the first few bytes are different
	// Let me try to reproduce this corruption

	// Create a corrupted version by modifying the first few bytes
	corruptedData := make([]byte, len(data))
	copy(corruptedData, data)

	// Modify the second byte from 0xe0 to 0x21 (as seen in the debug output)
	if len(corruptedData) > 1 {
		corruptedData[1] = 0x21
	}

	fmt.Printf("Corrupted data size: %d bytes\n", len(corruptedData))
	fmt.Printf("Corrupted data preview: %q\n", string(corruptedData[:minInt(100, len(corruptedData))]))

	// Test unmarshaling the corrupted data
	var writeRequest3 prompb.WriteRequest
	if err := proto.Unmarshal(corruptedData, &writeRequest3); err != nil {
		fmt.Printf("Corrupted data unmarshal failed: %v\n", err)
	} else {
		fmt.Printf("Corrupted data unmarshaled successfully: %d timeseries\n", len(writeRequest3.Timeseries))
	}

	// Let me also try to understand what the corruption means
	fmt.Printf("\nByte comparison:\n")
	fmt.Printf("Original bytes: %02x %02x %02x %02x %02x\n", data[0], data[1], data[2], data[3], data[4])
	fmt.Printf("Corrupted bytes: %02x %02x %02x %02x %02x\n", corruptedData[0], corruptedData[1], corruptedData[2], corruptedData[3], corruptedData[4])
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
