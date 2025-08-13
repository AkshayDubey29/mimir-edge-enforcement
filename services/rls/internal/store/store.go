package store

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/AkshayDubey29/mimir-edge-enforcement/services/rls/internal/limits"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog"
)

// Store defines the interface for tenant data storage
type Store interface {
	// Tenant operations
	GetTenant(ctx context.Context, tenantID string) (*TenantData, error)
	SetTenant(ctx context.Context, tenantID string, data *TenantData) error
	DeleteTenant(ctx context.Context, tenantID string) error
	ListTenants(ctx context.Context) ([]string, error)

	// 🔧 NEW: Global series tracking operations
	GetGlobalSeriesCount(ctx context.Context, tenantID string) (int64, error)
	SetGlobalSeriesCount(ctx context.Context, tenantID string, count int64) error
	IncrementGlobalSeriesCount(ctx context.Context, tenantID string, increment int64) error

	// 🔧 NEW: Per-metric series tracking operations
	GetMetricSeriesCount(ctx context.Context, tenantID, metricName string) (int64, error)
	SetMetricSeriesCount(ctx context.Context, tenantID, metricName string, count int64) error
	IncrementMetricSeriesCount(ctx context.Context, tenantID, metricName string, increment int64) error
	GetAllMetricSeriesCounts(ctx context.Context, tenantID string) (map[string]int64, error)

	// 🔧 NEW: Series deduplication operations
	AddSeriesHash(ctx context.Context, tenantID, metricName, seriesHash string) error
	IsSeriesHashExists(ctx context.Context, tenantID, metricName, seriesHash string) (bool, error)
	GetSeriesHashes(ctx context.Context, tenantID, metricName string) ([]string, error)

	// Health check
	Ping(ctx context.Context) error

	// Close the store
	Close() error
}

// TenantData represents the data stored for each tenant
type TenantData struct {
	ID          string                   `json:"id"`
	Name        string                   `json:"name"`
	Limits      limits.TenantLimits      `json:"limits"`
	Enforcement limits.EnforcementConfig `json:"enforcement"`
	CreatedAt   time.Time                `json:"created_at"`
	UpdatedAt   time.Time                `json:"updated_at"`
}

// MemoryStore implements Store interface using in-memory storage
type MemoryStore struct {
	tenants map[string]*TenantData
	logger  zerolog.Logger
}

// NewMemoryStore creates a new in-memory store
func NewMemoryStore(logger zerolog.Logger) *MemoryStore {
	return &MemoryStore{
		tenants: make(map[string]*TenantData),
		logger:  logger,
	}
}

func (m *MemoryStore) GetTenant(ctx context.Context, tenantID string) (*TenantData, error) {
	if tenant, exists := m.tenants[tenantID]; exists {
		return tenant, nil
	}
	return nil, fmt.Errorf("tenant %s not found", tenantID)
}

func (m *MemoryStore) SetTenant(ctx context.Context, tenantID string, data *TenantData) error {
	data.UpdatedAt = time.Now()
	if data.CreatedAt.IsZero() {
		data.CreatedAt = time.Now()
	}
	m.tenants[tenantID] = data
	m.logger.Debug().Str("tenant_id", tenantID).Msg("stored tenant in memory")
	return nil
}

func (m *MemoryStore) DeleteTenant(ctx context.Context, tenantID string) error {
	delete(m.tenants, tenantID)
	m.logger.Debug().Str("tenant_id", tenantID).Msg("deleted tenant from memory")
	return nil
}

func (m *MemoryStore) ListTenants(ctx context.Context) ([]string, error) {
	tenants := make([]string, 0, len(m.tenants))
	for tenantID := range m.tenants {
		tenants = append(tenants, tenantID)
	}
	return tenants, nil
}

func (m *MemoryStore) Ping(ctx context.Context) error {
	return nil // Memory store is always available
}

func (m *MemoryStore) Close() error {
	return nil
}

// 🔧 NEW: Global series tracking methods for MemoryStore
func (m *MemoryStore) GetGlobalSeriesCount(ctx context.Context, tenantID string) (int64, error) {
	// For memory store, we'll use a simple map to track series counts
	// In production, this should be replaced with Redis for persistence
	return 0, nil // Placeholder - will be implemented with Redis
}

func (m *MemoryStore) SetGlobalSeriesCount(ctx context.Context, tenantID string, count int64) error {
	// Placeholder implementation
	return nil
}

func (m *MemoryStore) IncrementGlobalSeriesCount(ctx context.Context, tenantID string, increment int64) error {
	// Placeholder implementation
	return nil
}

// 🔧 NEW: Per-metric series tracking methods for MemoryStore
func (m *MemoryStore) GetMetricSeriesCount(ctx context.Context, tenantID, metricName string) (int64, error) {
	return 0, nil // Placeholder
}

func (m *MemoryStore) SetMetricSeriesCount(ctx context.Context, tenantID, metricName string, count int64) error {
	return nil // Placeholder
}

func (m *MemoryStore) IncrementMetricSeriesCount(ctx context.Context, tenantID, metricName string, increment int64) error {
	return nil // Placeholder
}

func (m *MemoryStore) GetAllMetricSeriesCounts(ctx context.Context, tenantID string) (map[string]int64, error) {
	return make(map[string]int64), nil // Placeholder
}

// 🔧 NEW: Series deduplication methods for MemoryStore
func (m *MemoryStore) AddSeriesHash(ctx context.Context, tenantID, metricName, seriesHash string) error {
	return nil // Placeholder
}

func (m *MemoryStore) IsSeriesHashExists(ctx context.Context, tenantID, metricName, seriesHash string) (bool, error) {
	return false, nil // Placeholder
}

func (m *MemoryStore) GetSeriesHashes(ctx context.Context, tenantID, metricName string) ([]string, error) {
	return []string{}, nil // Placeholder
}

// RedisStore implements Store interface using Redis
type RedisStore struct {
	client *redis.Client
	logger zerolog.Logger
	prefix string
}

// NewRedisStore creates a new Redis store
func NewRedisStore(addr string, logger zerolog.Logger) *RedisStore {
	client := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: "", // no password set
		DB:       0,  // use default DB

		// 🔥 ULTRA-FAST PATH: Redis connection optimization
		PoolSize:     100,                    // Large pool for high throughput
		MinIdleConns: 20,                     // More idle connections for faster response
		MaxRetries:   0,                      // No retries for ultra-fast fail
		DialTimeout:  500 * time.Millisecond, // Ultra-fast connection timeout
		ReadTimeout:  1 * time.Second,        // Ultra-fast read timeout
		WriteTimeout: 1 * time.Second,        // Ultra-fast write timeout
		PoolTimeout:  500 * time.Millisecond, // Ultra-fast pool timeout
	})

	return &RedisStore{
		client: client,
		logger: logger,
		prefix: "rls:tenant:",
	}
}

func (r *RedisStore) GetTenant(ctx context.Context, tenantID string) (*TenantData, error) {
	key := r.prefix + tenantID
	data, err := r.client.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, fmt.Errorf("tenant %s not found", tenantID)
		}
		return nil, fmt.Errorf("redis get error: %w", err)
	}

	var tenant TenantData
	if err := json.Unmarshal([]byte(data), &tenant); err != nil {
		return nil, fmt.Errorf("unmarshal error: %w", err)
	}

	r.logger.Debug().Str("tenant_id", tenantID).Msg("retrieved tenant from redis")
	return &tenant, nil
}

func (r *RedisStore) SetTenant(ctx context.Context, tenantID string, data *TenantData) error {
	key := r.prefix + tenantID
	data.UpdatedAt = time.Now()
	if data.CreatedAt.IsZero() {
		data.CreatedAt = time.Now()
	}

	jsonData, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("marshal error: %w", err)
	}

	// Store with 24-hour expiration
	err = r.client.Set(ctx, key, jsonData, 24*time.Hour).Err()
	if err != nil {
		return fmt.Errorf("redis set error: %w", err)
	}

	r.logger.Debug().Str("tenant_id", tenantID).Msg("stored tenant in redis")
	return nil
}

func (r *RedisStore) DeleteTenant(ctx context.Context, tenantID string) error {
	key := r.prefix + tenantID
	err := r.client.Del(ctx, key).Err()
	if err != nil {
		return fmt.Errorf("redis del error: %w", err)
	}

	r.logger.Debug().Str("tenant_id", tenantID).Msg("deleted tenant from redis")
	return nil
}

func (r *RedisStore) ListTenants(ctx context.Context) ([]string, error) {
	pattern := r.prefix + "*"
	keys, err := r.client.Keys(ctx, pattern).Result()
	if err != nil {
		return nil, fmt.Errorf("redis keys error: %w", err)
	}

	tenants := make([]string, 0, len(keys))
	for _, key := range keys {
		tenantID := key[len(r.prefix):] // Remove prefix
		tenants = append(tenants, tenantID)
	}

	return tenants, nil
}

func (r *RedisStore) Ping(ctx context.Context) error {
	_, err := r.client.Ping(ctx).Result()
	if err != nil {
		return fmt.Errorf("redis ping error: %w", err)
	}
	return nil
}

func (r *RedisStore) Close() error {
	return r.client.Close()
}

// 🔧 NEW: Global series tracking methods for RedisStore
func (r *RedisStore) GetGlobalSeriesCount(ctx context.Context, tenantID string) (int64, error) {
	key := fmt.Sprintf("rls:series:global:%s", tenantID)
	count, err := r.client.Get(ctx, key).Int64()
	if err != nil {
		if err == redis.Nil {
			return 0, nil // No series count found, return 0
		}
		return 0, fmt.Errorf("redis get global series count error: %w", err)
	}
	return count, nil
}

func (r *RedisStore) SetGlobalSeriesCount(ctx context.Context, tenantID string, count int64) error {
	key := fmt.Sprintf("rls:series:global:%s", tenantID)
	err := r.client.Set(ctx, key, count, 0).Err() // No expiration for series counts
	if err != nil {
		return fmt.Errorf("redis set global series count error: %w", err)
	}
	return nil
}

func (r *RedisStore) IncrementGlobalSeriesCount(ctx context.Context, tenantID string, increment int64) error {
	key := fmt.Sprintf("rls:series:global:%s", tenantID)
	_, err := r.client.IncrBy(ctx, key, increment).Result()
	if err != nil {
		return fmt.Errorf("redis increment global series count error: %w", err)
	}
	return nil
}

// 🔧 NEW: Per-metric series tracking methods for RedisStore
func (r *RedisStore) GetMetricSeriesCount(ctx context.Context, tenantID, metricName string) (int64, error) {
	key := fmt.Sprintf("rls:series:metric:%s:%s", tenantID, metricName)
	count, err := r.client.Get(ctx, key).Int64()
	if err != nil {
		if err == redis.Nil {
			return 0, nil // No metric series count found, return 0
		}
		return 0, fmt.Errorf("redis get metric series count error: %w", err)
	}
	return count, nil
}

func (r *RedisStore) SetMetricSeriesCount(ctx context.Context, tenantID, metricName string, count int64) error {
	key := fmt.Sprintf("rls:series:metric:%s:%s", tenantID, metricName)
	err := r.client.Set(ctx, key, count, 0).Err() // No expiration for series counts
	if err != nil {
		return fmt.Errorf("redis set metric series count error: %w", err)
	}
	return nil
}

func (r *RedisStore) IncrementMetricSeriesCount(ctx context.Context, tenantID, metricName string, increment int64) error {
	key := fmt.Sprintf("rls:series:metric:%s:%s", tenantID, metricName)
	_, err := r.client.IncrBy(ctx, key, increment).Result()
	if err != nil {
		return fmt.Errorf("redis increment metric series count error: %w", err)
	}
	return nil
}

func (r *RedisStore) GetAllMetricSeriesCounts(ctx context.Context, tenantID string) (map[string]int64, error) {
	pattern := fmt.Sprintf("rls:series:metric:%s:*", tenantID)
	keys, err := r.client.Keys(ctx, pattern).Result()
	if err != nil {
		return nil, fmt.Errorf("redis keys error: %w", err)
	}

	metricCounts := make(map[string]int64)
	for _, key := range keys {
		// Extract metric name from key: rls:series:metric:tenantID:metricName
		parts := strings.Split(key, ":")
		if len(parts) >= 5 {
			metricName := parts[4]
			count, err := r.client.Get(ctx, key).Int64()
			if err != nil {
				r.logger.Error().Err(err).Str("key", key).Msg("failed to get metric series count")
				continue
			}
			metricCounts[metricName] = count
		}
	}
	return metricCounts, nil
}

// 🔧 NEW: Series deduplication methods for RedisStore
func (r *RedisStore) AddSeriesHash(ctx context.Context, tenantID, metricName, seriesHash string) error {
	key := fmt.Sprintf("rls:series:hashes:%s:%s", tenantID, metricName)
	// Use Redis SET to store unique series hashes
	err := r.client.SAdd(ctx, key, seriesHash).Err()
	if err != nil {
		return fmt.Errorf("redis add series hash error: %w", err)
	}
	return nil
}

func (r *RedisStore) IsSeriesHashExists(ctx context.Context, tenantID, metricName, seriesHash string) (bool, error) {
	key := fmt.Sprintf("rls:series:hashes:%s:%s", tenantID, metricName)
	exists, err := r.client.SIsMember(ctx, key, seriesHash).Result()
	if err != nil {
		return false, fmt.Errorf("redis check series hash exists error: %w", err)
	}
	return exists, nil
}

func (r *RedisStore) GetSeriesHashes(ctx context.Context, tenantID, metricName string) ([]string, error) {
	key := fmt.Sprintf("rls:series:hashes:%s:%s", tenantID, metricName)
	hashes, err := r.client.SMembers(ctx, key).Result()
	if err != nil {
		return nil, fmt.Errorf("redis get series hashes error: %w", err)
	}
	return hashes, nil
}

// NewStore creates a new store based on the backend type
func NewStore(backend, redisAddr string, logger zerolog.Logger) (Store, error) {
	switch backend {
	case "memory":
		logger.Info().Msg("using memory store backend")
		return NewMemoryStore(logger), nil
	case "redis":
		logger.Info().Str("redis_addr", redisAddr).Msg("using redis store backend")
		store := NewRedisStore(redisAddr, logger)

		// Test Redis connection
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if err := store.Ping(ctx); err != nil {
			return nil, fmt.Errorf("redis connection failed: %w", err)
		}

		return store, nil
	default:
		return nil, fmt.Errorf("unsupported store backend: %s", backend)
	}
}
