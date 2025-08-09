# Multi-stage build for React app
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build the React app
RUN npm run build

# Runtime stage - minimal nginx image
FROM nginx:alpine

# Copy the built React app from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Remove default nginx config (will be replaced by ConfigMap)
RUN rm /etc/nginx/nginx.conf

# Create nginx user and set permissions
RUN addgroup -g 101 -S nginx && \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx

# Set correct ownership
RUN chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/log/nginx /etc/nginx

# Create required directories
RUN mkdir -p /var/run && chown nginx:nginx /var/run

# Expose port
EXPOSE 80

# Switch to non-root user
USER nginx

# Run nginx in foreground
CMD ["nginx", "-g", "daemon off;"]