package buckets

import (
	"sync"
	"time"
)

// TokenBucket implements a token bucket rate limiter
type TokenBucket struct {
	mu sync.RWMutex

	// Configuration
	rate     float64 // tokens per second
	capacity float64 // maximum tokens

	// State
	tokens     float64   // current tokens
	lastRefill time.Time // last time tokens were refilled
}

// NewTokenBucket creates a new token bucket with the given rate and capacity
func NewTokenBucket(rate, capacity float64) *TokenBucket {
	return &TokenBucket{
		rate:       rate,
		capacity:   capacity,
		tokens:     capacity,
		lastRefill: time.Now(),
	}
}

// Take attempts to take n tokens from the bucket
// Returns true if successful, false if not enough tokens
func (tb *TokenBucket) Take(n float64) bool {
	tb.mu.Lock()
	defer tb.mu.Unlock()

	// 🔧 PERFORMANCE FIX: Optimize refill calculation
	tb.refill()

	if tb.tokens >= n {
		tb.tokens -= n
		return true
	}
	return false
}

// TakeMax attempts to take up to n tokens from the bucket
// Returns the number of tokens actually taken
func (tb *TokenBucket) TakeMax(n float64) float64 {
	tb.mu.Lock()
	defer tb.mu.Unlock()

	// Refill tokens based on time elapsed
	tb.refill()

	taken := min(tb.tokens, n)
	tb.tokens -= taken
	return taken
}

// Available returns the number of tokens currently available
func (tb *TokenBucket) Available() float64 {
	tb.mu.RLock()
	defer tb.mu.RUnlock()

	// Refill tokens based on time elapsed
	tb.refill()
	return tb.tokens
}

// refill refills the bucket based on time elapsed since last refill
func (tb *TokenBucket) refill() {
	now := time.Now()
	elapsed := now.Sub(tb.lastRefill).Seconds()

	// 🔧 PERFORMANCE FIX: Skip refill if no time has passed
	if elapsed <= 0 {
		return
	}

	// Calculate tokens to add
	tokensToAdd := elapsed * tb.rate

	// Add tokens, but don't exceed capacity
	tb.tokens = min(tb.capacity, tb.tokens+tokensToAdd)
	tb.lastRefill = now
}

// Reset resets the bucket to full capacity
func (tb *TokenBucket) Reset() {
	tb.mu.Lock()
	defer tb.mu.Unlock()

	tb.tokens = tb.capacity
	tb.lastRefill = time.Now()
}

// GetRate returns the current rate
func (tb *TokenBucket) GetRate() float64 {
	tb.mu.RLock()
	defer tb.mu.RUnlock()
	return tb.rate
}

// GetCapacity returns the current capacity
func (tb *TokenBucket) GetCapacity() float64 {
	tb.mu.RLock()
	defer tb.mu.RUnlock()
	return tb.capacity
}

// SetRate updates the rate of the token bucket
func (tb *TokenBucket) SetRate(rate float64) {
	tb.mu.Lock()
	defer tb.mu.Unlock()

	// Refill before changing rate to maintain consistency
	tb.refill()
	tb.rate = rate
}

// SetCapacity updates the capacity of the token bucket
func (tb *TokenBucket) SetCapacity(capacity float64) {
	tb.mu.Lock()
	defer tb.mu.Unlock()

	// Refill before changing capacity
	tb.refill()
	tb.capacity = capacity

	// Adjust tokens if new capacity is smaller
	if tb.tokens > capacity {
		tb.tokens = capacity
	}
}

// min returns the minimum of two float64 values
func min(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}
