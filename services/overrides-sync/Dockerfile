# Runtime stage - minimal distroless image
FROM gcr.io/distroless/static:nonroot

# Architecture-aware binary copy
ARG TARGETARCH
COPY overrides-sync-${TARGETARCH} /usr/local/bin/overrides-sync

# Set user
USER 65532:65532

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/overrides-sync", "--help"] || exit 1

# Run the application
ENTRYPOINT ["/usr/local/bin/overrides-sync"]