module github.com/AkshayDubey29/mimir-edge-enforcement

go 1.22

require (
	github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus v0.0.0
	google.golang.org/protobuf v1.32.0
)

require github.com/google/go-cmp v0.5.9 // indirect

replace (
	github.com/AkshayDubey29/mimir-edge-enforcement/protos/admin => ./protos/admin
	github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus => ./protos/prometheus
)
