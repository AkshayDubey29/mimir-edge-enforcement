# Build stage
FROM golang:1.22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata protobuf protobuf-dev

# Set working directory
WORKDIR /app

# Copy go mod files (service) and local proto modules
COPY services/rls/go.mod services/rls/go.sum ./
COPY protos /protos
RUN go mod download || true

# Generate protobuf stubs inside the image (ensures builds don't rely on host)
ENV PATH="/go/bin:${PATH}"
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.31.0 \
    && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.3.0

# Generate stubs for admin and remote_write
RUN protoc --proto_path=/protos --proto_path=/usr/include \
    --go_out=/protos --go_opt=paths=source_relative \
    --go-grpc_out=/protos --go-grpc_opt=paths=source_relative \
    /protos/*.proto

# Copy service source code
COPY services/rls/. .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o rls cmd/rls/main.go

# Final stage
FROM gcr.io/distroless/static:nonroot

# Copy the binary from builder stage
COPY --from=builder /app/rls /usr/local/bin/rls

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Expose ports
EXPOSE 8080 8081 8082 9090

# Set user
USER 65532:65532

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/rls", "--help"] || exit 1

# Run the application
ENTRYPOINT ["/usr/local/bin/rls"] 