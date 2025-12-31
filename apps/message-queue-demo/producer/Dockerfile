FROM python:3.11-slim

WORKDIR /app

# Install redis-py
RUN pip install --no-cache-dir redis

# Copy application
COPY producer.py .

# Run producer
CMD ["python", "-u", "producer.py"]
