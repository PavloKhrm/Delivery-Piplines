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

# Production stage
FROM node:22-bookworm-slim AS production

# Create app user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Install only production dependencies
COPY package*.json ./
RUN npm install --omit=dev && npm cache clean --force

# Copy built application from builder stage
COPY --from=builder /app/dist ./dist

# Copy necessary files
COPY --from=builder /app/node_modules ./node_modules

# Change ownership to app user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start the application
CMD ["npm", "run", "start:prod"]
