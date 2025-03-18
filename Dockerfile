FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy both app and scripts directories
COPY app/ /app/
COPY scripts/ /scripts/

# Set proper permissions
RUN chmod -R 755 /scripts

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
