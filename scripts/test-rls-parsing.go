package main

import (
	"fmt"
	"log"

	"google.golang.org/protobuf/proto"

	prompb "github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus"
)

func main() {
	// Use the exact same logic as the load test
	writeRequest := createWriteRequest(1, 1)

	// Serialize to protobuf
	data, err := proto.Marshal(writeRequest)
	if err != nil {
		log.Fatalf("Failed to marshal protobuf: %v", err)
	}

	fmt.Printf("Generated data size: %d bytes\n", len(data))

	// Test unmarshaling with the same logic as RLS
	var writeRequest2 prompb.WriteRequest
	if err := proto.Unmarshal(data, &writeRequest2); err != nil {
		log.Fatalf("Failed to unmarshal protobuf: %v", err)
	}

	fmt.Printf("Unmarshaled successfully: %d timeseries\n", len(writeRequest2.Timeseries))

	// Count samples and labels like RLS does
	var samplesCount, seriesCount, labelsCount int64
	for _, ts := range writeRequest2.Timeseries {
		seriesCount++
		labelsCount += int64(len(ts.Labels))
		samplesCount += int64(len(ts.Samples))
	}

	fmt.Printf("Counts - Series: %d, Labels: %d, Samples: %d\n", seriesCount, labelsCount, samplesCount)
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
