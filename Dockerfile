# ---- Build Stage ----
# Use a full-featured Python image to build our dependencies
FROM python:3.10-bullseye AS builder

# Set working directory
WORKDIR /app

# Install build dependencies
RUN pip install --upgrade pip setuptools wheel

# Copy only the files needed to install dependencies
# This leverages Docker cache more effectively
COPY requirements.txt .

# Install runtime dependencies into a "virtual environment"
# We will copy this entire directory to the final image
RUN pip install --no-cache-dir --prefix="/app/venv" \
    -r requirements.txt

# ---- Final Stage ----
# Use a minimal, slim Python image for the final container
FROM python:3.10-slim-bullseye AS final

# Install runtime dependencies (ca-certificates for SSL/TLS)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set a non-root user for security
# Create a system group and user with no home directory
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Set the working directory
WORKDIR /app

# Create logs directory with proper permissions
RUN mkdir -p /app/logs && chown -R appuser:appgroup /app/logs

# Copy the installed Python packages from the builder stage
COPY --from=builder /app/venv /app/venv

# Add venv to PATH so Python can find packages
ENV PATH=/app/venv/bin:$PATH \
    PYTHONPATH=/app/venv/lib/python3.10/site-packages:$PYTHONPATH

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