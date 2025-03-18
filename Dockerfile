FROM python:3.9-slim

WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create necessary directories
RUN mkdir -p /scripts /app/logs

# Copy application files
COPY app/ /app/
COPY scripts/ /scripts/

# Set proper permissions
RUN chmod -R 755 /scripts && \
    chmod -R 755 /app

# Verify script exists and is executable
RUN ls -la /scripts/server-setup.sh && \
    chmod +x /scripts/server-setup.sh

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
