package main

import (
    "fmt"
    "os"
    
    "github.com/golang/protobuf/proto"
    prompb "github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus"
)

func main() {
    // Create a simple WriteRequest with multiple series
    var writeRequest prompb.WriteRequest
    
    // Create 50 series (should trigger limits)
    for i := 0; i < 50; i++ {
        timeseries := &prompb.TimeSeries{}
        
        // Add metric name
        timeseries.Labels = append(timeseries.Labels, &prompb.Label{
            Name:  "__name__",
            Value: fmt.Sprintf("test_metric_%d", i%5), // 5 different metrics
        })
        
        // Add some labels
        timeseries.Labels = append(timeseries.Labels, &prompb.Label{
            Name:  "instance",
            Value: fmt.Sprintf("server-%d", i%3),
        })
        
        timeseries.Labels = append(timeseries.Labels, &prompb.Label{
            Name:  "job",
            Value: "test-job",
        })
        
        // Add sample
        timeseries.Samples = append(timeseries.Samples, &prompb.Sample{
            Value:     float64(i),
            Timestamp: 1640995200000 + int64(i*1000),
        })
        
        writeRequest.Timeseries = append(writeRequest.Timeseries, timeseries)
    }
    
    // Serialize to protobuf
    protobufData, err := proto.Marshal(&writeRequest)
    if err != nil {
        panic(err)
    }
    
    // Write to file
    if err := os.WriteFile("simple_test_data.pb", protobufData, 0644); err != nil {
        panic(err)
    }
    
    fmt.Printf("Generated simple test data: %d bytes, %d series\n", len(protobufData), len(writeRequest.Timeseries))
}
