# Build stage
FROM golang:1.22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o overrides-sync cmd/overrides-sync/main.go

# Final stage
FROM gcr.io/distroless/static:nonroot

# Copy the binary from builder stage
COPY --from=builder /app/overrides-sync /usr/local/bin/overrides-sync

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Expose metrics port
EXPOSE 9090

# Set user
USER 65532:65532

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/overrides-sync", "--help"] || exit 1

# Run the application
ENTRYPOINT ["/usr/local/bin/overrides-sync"] 