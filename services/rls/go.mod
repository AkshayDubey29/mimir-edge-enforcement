module github.com/AkshayDubey29/mimir-edge-enforcement/services/rls

go 1.22

require (
	github.com/AkshayDubey29/mimir-edge-enforcement/protos/admin v0.0.0
	github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus v0.0.0
	github.com/envoyproxy/go-control-plane v0.12.0
	github.com/golang/protobuf v1.5.3
	github.com/google/uuid v1.4.0
	github.com/gorilla/mux v1.8.1
	github.com/lyft/ratelimit v1.4.2
	github.com/prometheus/client_golang v1.17.0
	github.com/redis/go-redis/v9 v9.3.0
	github.com/rs/zerolog v1.31.0
	github.com/stretchr/testify v1.8.4
	go.uber.org/zap v1.26.0
	golang.org/x/net v0.17.0
	google.golang.org/grpc v1.59.0
	google.golang.org/protobuf v1.31.0
)

replace (
	github.com/AkshayDubey29/mimir-edge-enforcement/protos/admin => ../../protos/admin
	github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus => ../../protos/prometheus
)

require (
	github.com/beorn7/perks v1.0.1 // indirect
	github.com/cespare/xxhash/v2 v2.2.0 // indirect
	github.com/cncf/xds/go v0.0.0-20230607035331-e9ce68804cb4 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
	github.com/envoyproxy/protoc-gen-validate v1.0.2 // indirect
	github.com/golang/glog v1.1.2 // indirect
	github.com/golang/snappy v0.0.4 // indirect
	github.com/mattn/go-colorable v0.1.13 // indirect
	github.com/mattn/go-isatty v0.0.19 // indirect
	github.com/matttproud/golang_protobuf_extensions v1.0.4 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/prometheus/client_model v0.4.1-0.20230718164431-9a2bf3000d16 // indirect
	github.com/prometheus/common v0.44.0 // indirect
	github.com/prometheus/procfs v0.11.1 // indirect
	go.uber.org/multierr v1.11.0 // indirect
	golang.org/x/sys v0.13.0 // indirect
	golang.org/x/text v0.13.0 // indirect
	google.golang.org/genproto/googleapis/api v0.0.0-20231016165738-49dd2c1f3d0b // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20231016165738-49dd2c1f3d0b // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
) 