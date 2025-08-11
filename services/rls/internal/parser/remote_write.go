package parser

import (
	"bytes"
	"compress/gzip"
	"fmt"
	"io"

	"github.com/golang/snappy"
	"google.golang.org/protobuf/proto"

	prompb "github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus"
)

// ParseResult contains the parsed information from a remote write request
type ParseResult struct {
	SamplesCount int64
	SeriesCount  int64
	LabelsCount  int64
	Error        error
}

// ParseRemoteWriteRequest parses a Prometheus remote write request and counts samples
func ParseRemoteWriteRequest(body []byte, contentEncoding string) (*ParseResult, error) {
	// 🔧 PERFORMANCE FIX: Early return for empty body
	if len(body) == 0 {
		return &ParseResult{SamplesCount: 0, SeriesCount: 0, LabelsCount: 0}, nil
	}

	// 🔧 FIX: Check for potentially truncated bodies
	if contentEncoding == "snappy" && len(body) < 10 {
		return nil, fmt.Errorf("snappy body too small (%d bytes), likely truncated", len(body))
	}

	// Decompress based on content encoding
	decompressed, err := decompress(body, contentEncoding)
	if err != nil {
		return nil, fmt.Errorf("failed to decompress body: %w", err)
	}

	// Parse protobuf
	var writeRequest prompb.WriteRequest
	if err := proto.Unmarshal(decompressed, &writeRequest); err != nil {
		return nil, fmt.Errorf("failed to unmarshal protobuf: %w", err)
	}

	// 🔧 PERFORMANCE FIX: Pre-allocate result and use efficient counting
	result := &ParseResult{}

	// 🔧 PERFORMANCE FIX: Use range loop for better performance
	for _, ts := range writeRequest.Timeseries {
		result.SeriesCount++
		result.LabelsCount += int64(len(ts.Labels))
		result.SamplesCount += int64(len(ts.Samples))
	}

	return result, nil
}

// decompress decompresses the body based on content encoding
func decompress(body []byte, contentEncoding string) ([]byte, error) {
	switch contentEncoding {
	case "":
		return body, nil
	case "gzip":
		reader, err := gzip.NewReader(bytes.NewReader(body))
		if err != nil {
			return nil, fmt.Errorf("failed to create gzip reader: %w", err)
		}
		defer reader.Close()

		decompressed, err := io.ReadAll(reader)
		if err != nil {
			return nil, fmt.Errorf("failed to read gzip data: %w", err)
		}
		return decompressed, nil

	case "snappy":
		decompressed, err := snappy.Decode(nil, body)
		if err != nil {
			// 🔧 FIX: Provide more detailed error information for debugging
			return nil, fmt.Errorf("failed to decode snappy data (body size: %d bytes): %w", len(body), err)
		}
		return decompressed, nil

	default:
		return nil, fmt.Errorf("unsupported content encoding: %s", contentEncoding)
	}
}

// ValidateRemoteWriteRequest validates if the request is a valid remote write request
func ValidateRemoteWriteRequest(body []byte, contentEncoding string) error {
	_, err := ParseRemoteWriteRequest(body, contentEncoding)
	return err
}
