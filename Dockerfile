FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/server.py /app/server.py
RUN mkdir -p /scripts && chmod -R 755 /scripts

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
