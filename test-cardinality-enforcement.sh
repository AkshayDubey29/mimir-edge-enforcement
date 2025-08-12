#!/bin/bash

echo "🧪 Testing Cardinality-Only Enforcement"
echo "========================================"

# Test 1: Generate traffic within limits (should pass)
echo -e "\n📊 Test 1: Traffic within limits (should pass)"
cd scripts
./load-remote-write -url="http://localhost:8080/api/v1/push" -tenant=test-cardinality -duration=5s -concurrency=2 -series=5 -labels=3

echo -e "\n⏳ Waiting 3 seconds..."
sleep 3

# Test 2: Generate traffic exceeding series per request limit (should be denied)
echo -e "\n🚫 Test 2: Exceeding series per request limit (should be denied)"
./load-remote-write -url="http://localhost:8080/api/v1/push" -tenant=test-cardinality -duration=5s -concurrency=2 -series=15 -labels=3

echo -e "\n⏳ Waiting 3 seconds..."
sleep 3

# Test 3: Generate traffic exceeding labels per series limit (should be denied)
echo -e "\n🚫 Test 3: Exceeding labels per series limit (should be denied)"
./load-remote-write -url="http://localhost:8080/api/v1/push" -tenant=test-cardinality -duration=5s -concurrency=2 -series=5 -labels=10

echo -e "\n⏳ Waiting 3 seconds..."
sleep 3

# Test 4: Generate high rate traffic (should pass - rate limiting disabled)
echo -e "\n📈 Test 4: High rate traffic (should pass - rate limiting disabled)"
./load-remote-write -url="http://localhost:8080/api/v1/push" -tenant=test-cardinality -duration=5s -concurrency=10 -series=5 -labels=3

echo -e "\n✅ Testing completed!"
