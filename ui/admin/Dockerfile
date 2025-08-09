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

# Set ownership of React app files to nginx user
RUN chown -R nginx:nginx /usr/share/nginx/html

# Create tmp directory for nginx (required for non-root execution)
RUN mkdir -p /tmp/nginx && chown -R nginx:nginx /tmp/nginx

# Expose port
EXPOSE 80

# Switch to non-root user
USER nginx

# Run nginx in foreground
CMD ["nginx", "-g", "daemon off;"]