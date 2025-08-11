package main

import (
	"fmt"
	"log"

	"google.golang.org/protobuf/proto"

	prompb "github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus"
)

func main() {
	// Create a simple WriteRequest
	writeRequest := &prompb.WriteRequest{
		Timeseries: []*prompb.TimeSeries{
			{
				Labels: []*prompb.Label{
					{Name: "__name__", Value: "test_metric"},
					{Name: "test", Value: "value"},
				},
				Samples: []*prompb.Sample{
					{Value: 1.0, Timestamp: 1234567890},
				},
			},
		},
	}

	// Marshal
	data, err := proto.Marshal(writeRequest)
	if err != nil {
		log.Fatalf("Failed to marshal: %v", err)
	}

	fmt.Printf("Marshaled data size: %d bytes\n", len(data))

	// Unmarshal
	var unmarshaled prompb.WriteRequest
	if err := proto.Unmarshal(data, &unmarshaled); err != nil {
		log.Fatalf("Failed to unmarshal: %v", err)
	}

	fmt.Printf("Unmarshaled successfully: %d timeseries\n", len(unmarshaled.Timeseries))
	fmt.Printf("First timeseries: %d labels, %d samples\n",
		len(unmarshaled.Timeseries[0].Labels),
		len(unmarshaled.Timeseries[0].Samples))
}
