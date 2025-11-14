# ---- Build Stage ----
# Use a full-featured Python image to build our dependencies
FROM python:3.10-bullseye AS builder

# Set working directory
WORKDIR /app

# Install build dependencies
RUN pip install --upgrade pip
RUN pip install poetry

# Copy only the files needed to install dependencies
# This leverages Docker cache more effectively
COPY requirements.txt .

# Install runtime dependencies into a "virtual environment"
# We will copy this entire directory to the final image
RUN pip install --no-cache-dir --prefix="/app/venv" -r requirements.txt

# ---- Final Stage ----
# Use a minimal, slim Python image for the final container
FROM python:3.10-slim-bullseye AS final

# Set a non-root user for security
# Create a system group and user with no home directory
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Set the working directory
WORKDIR /app

# Copy the installed Python packages from the builder stage
COPY --from=builder /app/venv /usr/local

# Copy the application code
COPY . .

# Change ownership of the app directory to the non-root user
RUN chown -R appuser:appgroup /app

# Switch to the non-root user
USER appuser

# Expose port 80
EXPOSE 80

# Set the Redis host from an environment variable
ENV REDIS_HOST=redis-db

# Run uvicorn server
# Note: No --reload in production!
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]