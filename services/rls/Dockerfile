# Runtime stage - minimal distroless image
FROM gcr.io/distroless/static:nonroot

# Add labels for ultra-fast version
LABEL org.opencontainers.image.version="latest-ultra-fast"
LABEL org.opencontainers.image.description="Ultra-fast RLS service with aggressive performance optimizations"

# Architecture-aware binary copy
ARG TARGETARCH
COPY rls-ultra-fast /usr/local/bin/rls

# Expose ports
EXPOSE 8080 8081 8082 9090

# Set user
USER 65532:65532

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/rls", "--help"] || exit 1

# Run the application
ENTRYPOINT ["/usr/local/bin/rls"]