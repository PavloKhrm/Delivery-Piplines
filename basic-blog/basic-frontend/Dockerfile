# Multi-stage build for production
FROM node:22-bookworm-slim AS builder

# Set working directory
WORKDIR /app

# Install dependencies first (better caching)
COPY package*.json ./
RUN npm install && npm cache clean --force

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage with Nginx
FROM nginx:1.25-alpine AS production

# Copy custom nginx configuration template
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# Copy built application from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Create startup script to substitute environment variables
RUN echo '#!/bin/sh' > /docker-entrypoint-custom.sh && \
    echo 'set -e' >> /docker-entrypoint-custom.sh && \
    echo 'rm -f /etc/nginx/nginx.conf' >> /docker-entrypoint-custom.sh && \
    echo 'envsubst "\$BACKEND_SERVICE \$CLIENT_NAME" < /etc/nginx/nginx.conf.template > /tmp/nginx.conf' >> /docker-entrypoint-custom.sh && \
    echo 'cp /tmp/nginx.conf /etc/nginx/nginx.conf' >> /docker-entrypoint-custom.sh && \
    echo 'exec nginx -g "daemon off;"' >> /docker-entrypoint-custom.sh && \
    chmod +x /docker-entrypoint-custom.sh

# Create nginx user and set permissions
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    mkdir -p /var/cache/nginx /var/run && \
    chown -R nginx:nginx /var/cache/nginx /var/run

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1

# Start nginx with environment substitution (run as root to write config)
CMD ["/docker-entrypoint-custom.sh"]
