# Mimir Edge Enforcement Makefile

# Variables
VERSION ?= $(shell git describe --tags --always --dirty)
REGISTRY ?= ghcr.io/AkshayDubey29
GO_VERSION ?= 1.22
NODE_VERSION ?= 20

# Image names
RLS_IMAGE = $(REGISTRY)/mimir-rls
OVERRIDES_SYNC_IMAGE = $(REGISTRY)/overrides-sync
ENVOY_IMAGE = $(REGISTRY)/mimir-envoy
ADMIN_IMAGE = $(REGISTRY)/mimir-edge-admin

# Build targets
.PHONY: all clean build-rls build-sync build-envoy build-ui build-charts test lint proto

# Default target
all: build-rls build-sync build-envoy build-ui build-charts

# Clean build artifacts
clean:
	rm -rf dist/
	rm -rf services/*/dist/
	rm -rf ui/admin/dist/
	rm -rf charts/*/charts/
	rm -rf charts/*/requirements.lock

# Build RLS service
build-rls:
	@echo "Building RLS service..."
	cd services/rls && go build -o dist/rls cmd/rls/main.go

# Build overrides-sync service
build-sync:
	@echo "Building overrides-sync service..."
	cd services/overrides-sync && go build -o dist/overrides-sync cmd/overrides-sync/main.go

# Build Envoy image
build-envoy:
	@echo "Building Envoy image..."
	docker build -t $(ENVOY_IMAGE):$(VERSION) -f Dockerfile.envoy .
	docker tag $(ENVOY_IMAGE):$(VERSION) $(ENVOY_IMAGE):latest

# Build RLS image
build-rls-image:
	@echo "Building RLS image..."
	docker build -t $(RLS_IMAGE):$(VERSION) -f services/rls/Dockerfile services/rls/
	docker tag $(RLS_IMAGE):$(VERSION) $(RLS_IMAGE):latest

# Build overrides-sync image
build-sync-image:
	@echo "Building overrides-sync image..."
	docker build -t $(OVERRIDES_SYNC_IMAGE):$(VERSION) -f services/overrides-sync/Dockerfile services/overrides-sync/
	docker tag $(OVERRIDES_SYNC_IMAGE):$(VERSION) $(OVERRIDES_SYNC_IMAGE):latest

# Build UI
build-ui:
	@echo "Building Admin UI..."
	cd ui/admin && npm install && npm run build

# Build Admin UI image
build-admin-image:
	@echo "Building Admin UI image..."
	docker build -t $(ADMIN_IMAGE):$(VERSION) -f ui/admin/Dockerfile ui/admin/
	docker tag $(ADMIN_IMAGE):$(VERSION) $(ADMIN_IMAGE):latest

# Build all images
build-images: build-rls-image build-sync-image build-envoy build-admin-image

# Build Helm charts
build-charts:
	@echo "Building Helm charts..."
	helm package charts/envoy -d charts/envoy/
	helm package charts/mimir-rls -d charts/mimir-rls/
	helm package charts/overrides-sync -d charts/overrides-sync/

# Test Go services
test:
	@echo "Running Go tests..."
	cd services/rls && go test ./...
	cd services/overrides-sync && go test ./...

# Lint Go code
lint:
	@echo "Linting Go code..."
	golangci-lint run services/rls/...
	golangci-lint run services/overrides-sync/...

# Generate protobuf
proto:
	@echo "Generating protobuf..."
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		protos/*.proto

# Push images
push-images:
	@echo "Pushing images..."
	docker push $(RLS_IMAGE):$(VERSION)
	docker push $(RLS_IMAGE):latest
	docker push $(OVERRIDES_SYNC_IMAGE):$(VERSION)
	docker push $(OVERRIDES_SYNC_IMAGE):latest
	docker push $(ENVOY_IMAGE):$(VERSION)
	docker push $(ENVOY_IMAGE):latest
	docker push $(ADMIN_IMAGE):$(VERSION)
	docker push $(ADMIN_IMAGE):latest

# Development helpers
dev-setup:
	@echo "Setting up development environment..."
	kind create cluster --name mimir-edge --config scripts/kind-config.yaml
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

dev-deploy:
	@echo "Deploying to development cluster..."
	helm install mimir-edge-enforcement charts/mimir-rls/ -f examples/values/dev.yaml
	helm install mimir-envoy charts/envoy/ -f examples/values/dev.yaml
	helm install overrides-sync charts/overrides-sync/ -f examples/values/dev.yaml

dev-cleanup:
	@echo "Cleaning up development environment..."
	kind delete cluster --name mimir-edge

# Load testing
load-test:
	@echo "Running load tests..."
	go run scripts/load-remote-write.go

# Help
help:
	@echo "Available targets:"
	@echo "  all              - Build all components"
	@echo "  build-rls        - Build RLS service"
	@echo "  build-sync       - Build overrides-sync service"
	@echo "  build-ui         - Build Admin UI"
	@echo "  build-images     - Build all Docker images"
	@echo "  build-charts     - Build Helm charts"
	@echo "  test             - Run tests"
	@echo "  lint             - Lint code"
	@echo "  proto            - Generate protobuf"
	@echo "  push-images      - Push Docker images"
	@echo "  dev-setup        - Setup development environment"
	@echo "  dev-deploy       - Deploy to development cluster"
	@echo "  dev-cleanup      - Cleanup development environment"
	@echo "  load-test        - Run load tests"
	@echo "  clean            - Clean build artifacts" 