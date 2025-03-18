FROM python:3.9

WORKDIR /app

COPY app/server.py /app/server.py
RUN pip install fastapi uvicorn

# Set execute permission for the scripts folder
RUN mkdir -p /scripts && chmod -R 755 /scripts

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
