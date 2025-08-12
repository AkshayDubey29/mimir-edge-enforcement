package store

import (
	"context"
	"encoding/json"
	"fmt"
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
	
	// Health check
	Ping(ctx context.Context) error
	
	// Close the store
	Close() error
}

// TenantData represents the data stored for each tenant
type TenantData struct {
	ID          string                    `json:"id"`
	Name        string                    `json:"name"`
	Limits      limits.TenantLimits       `json:"limits"`
	Enforcement limits.EnforcementConfig  `json:"enforcement"`
	CreatedAt   time.Time                 `json:"created_at"`
	UpdatedAt   time.Time                 `json:"updated_at"`
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
