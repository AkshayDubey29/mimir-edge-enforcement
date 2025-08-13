package main

import (
	"fmt"
	"math"
	"strconv"
	"strings"
)

// ScientificNotationInt64 is a custom flag type that can parse scientific notation
type ScientificNotationInt64 int64

func (s *ScientificNotationInt64) String() string {
	return fmt.Sprintf("%d", *s)
}

func (s *ScientificNotationInt64) Set(value string) error {
	// Handle scientific notation (e.g., "4e6", "1.5e7")
	if strings.Contains(strings.ToLower(value), "e") {
		f, err := strconv.ParseFloat(value, 64)
		if err != nil {
			return fmt.Errorf("invalid scientific notation: %s", value)
		}
		// Check for overflow
		if f > float64(math.MaxInt64) || f < float64(math.MinInt64) {
			return fmt.Errorf("value out of range for int64: %s", value)
		}
		*s = ScientificNotationInt64(int64(f))
		return nil
	}
	
	// Handle regular integer parsing
	i, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return fmt.Errorf("invalid integer: %s", value)
	}
	*s = ScientificNotationInt64(i)
	return nil
}

// parseScientificNotation parses a string value that may contain scientific notation
func parseScientificNotation(value string) (float64, error) {
	// Handle scientific notation (e.g., "4e6", "1.5e7", "4E6")
	value = strings.TrimSpace(value)
	if strings.Contains(strings.ToLower(value), "e") {
		f, err := strconv.ParseFloat(value, 64)
		if err != nil {
			return 0, fmt.Errorf("invalid scientific notation: %s", value)
		}
		return f, nil
	}
	
	// Handle regular float parsing
	f, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid float: %s", value)
	}
	return f, nil
}

// parseScientificNotationInt64 parses a string value that may contain scientific notation and converts to int64
func parseScientificNotationInt64(value string) (int64, error) {
	f, err := parseScientificNotation(value)
	if err != nil {
		return 0, err
	}
	
	// Check for overflow
	if f > float64(math.MaxInt64) || f < float64(math.MinInt64) {
		return 0, fmt.Errorf("value out of range for int64: %s", value)
	}
	
	return int64(f), nil
}

func main() {
	fmt.Println("Testing Scientific Notation Parsing")
	fmt.Println("===================================")

	// Test cases for scientific notation
	testCases := []string{
		"4e6",      // 4MB
		"1.5e7",    // 15MB
		"4E6",      // 4MB (uppercase E)
		"1.5E7",    // 15MB (uppercase E)
		"4194304",  // Regular integer
		"1000",     // Regular integer
		"1e9",      // 1GB
		"2.5e6",    // 2.5MB
	}

	fmt.Println("\nTesting parseScientificNotation (float64):")
	for _, testCase := range testCases {
		result, err := parseScientificNotation(testCase)
		if err != nil {
			fmt.Printf("❌ %s: %v\n", testCase, err)
		} else {
			fmt.Printf("✅ %s -> %f\n", testCase, result)
		}
	}

	fmt.Println("\nTesting parseScientificNotationInt64 (int64):")
	for _, testCase := range testCases {
		result, err := parseScientificNotationInt64(testCase)
		if err != nil {
			fmt.Printf("❌ %s: %v\n", testCase, err)
		} else {
			fmt.Printf("✅ %s -> %d\n", testCase, result)
		}
	}

	fmt.Println("\nTesting ScientificNotationInt64 flag type:")
	for _, testCase := range testCases {
		var flag ScientificNotationInt64
		err := flag.Set(testCase)
		if err != nil {
			fmt.Printf("❌ %s: %v\n", testCase, err)
		} else {
			fmt.Printf("✅ %s -> %d\n", testCase, int64(flag))
		}
	}

	// Test edge cases
	fmt.Println("\nTesting Edge Cases:")
	edgeCases := []string{
		"1e20",     // Too large for int64
		"-1e20",    // Too small for int64
		"invalid",  // Invalid format
		"1.2.3",    // Invalid format
		"",         // Empty string
		"  4e6  ",  // With whitespace
	}

	for _, testCase := range edgeCases {
		result, err := parseScientificNotationInt64(testCase)
		if err != nil {
			fmt.Printf("❌ %s: %v\n", testCase, err)
		} else {
			fmt.Printf("✅ %s -> %d\n", testCase, result)
		}
	}

	fmt.Println("\n✅ Scientific notation parsing test completed!")
}
