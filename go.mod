module github.com/AkshayDubey29/mimir-edge-enforcement

go 1.22

require (
	github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus v0.0.0
	github.com/golang/snappy v0.0.4
	github.com/rs/zerolog v1.34.0
	google.golang.org/protobuf v1.36.7
	gopkg.in/yaml.v2 v2.4.0
)

require (
	github.com/google/go-cmp v0.5.9 // indirect
	github.com/mattn/go-colorable v0.1.13 // indirect
	github.com/mattn/go-isatty v0.0.19 // indirect
	golang.org/x/sys v0.12.0 // indirect
)

replace (
	github.com/AkshayDubey29/mimir-edge-enforcement/protos/admin => ./protos/admin
	github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus => ./protos/prometheus
)
