# ---- Final Stage ----
# Use a minimal, slim Python image for the final container
FROM python:3.10-slim-bullseye AS final

# Install runtime dependencies (ca-certificates for SSL/TLS)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install all dependencies directly to system Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Set a non-root user for security
# Create a system group and user with no home directory
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Create logs directory with proper permissions
RUN mkdir -p /app/logs && chown -R appuser:appgroup /app/logs

# Copy the application code
COPY . .

# Change ownership of the app directory to the non-root user
RUN chown -R appuser:appgroup /app

# Switch to the non-root user
USER appuser

# Expose port 8000 (changed from 80 to avoid permission issues)
EXPOSE 8000

# Set the Redis host from an environment variable
ENV REDIS_HOST=redis-db
ENV LOG_LEVEL=INFO

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/')" || exit 1

# Run uvicorn server on port 8000
# Note: No --reload in production!
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]