FROM python:3.11-slim

WORKDIR /app

# Install redis-py
RUN pip install --no-cache-dir redis

# Copy application
COPY consumer.py .

# Run consumer
CMD ["python", "-u", "consumer.py"]
