#!/usr/bin/env python3
"""
Message Queue Producer
Sends messages to Redis queue on AWS EC2.
Designed to run on IBM VPC VSI.
"""

import json
import os
import socket
import time
from datetime import datetime

import redis

# Configuration from environment
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
QUEUE_NAME = os.getenv("QUEUE_NAME", "demo-queue")
MESSAGE_INTERVAL = int(os.getenv("MESSAGE_INTERVAL", "5"))

def get_redis_client():
    """Create Redis client with retry logic."""
    max_retries = 10
    retry_delay = 5

    for attempt in range(max_retries):
        try:
            client = redis.Redis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                decode_responses=True
            )
            client.ping()
            print(f"Connected to Redis at {REDIS_HOST}:{REDIS_PORT}")
            return client
        except redis.ConnectionError as e:
            print(f"Connection attempt {attempt + 1}/{max_retries} failed: {e}")
            if attempt < max_retries - 1:
                print(f"Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                raise

def main():
    """Main producer loop."""
    print("=" * 50)
    print("MESSAGE QUEUE PRODUCER")
    print(f"Redis: {REDIS_HOST}:{REDIS_PORT}")
    print(f"Queue: {QUEUE_NAME}")
    print(f"Interval: {MESSAGE_INTERVAL}s")
    print("=" * 50)

    client = get_redis_client()
    sequence = 0
    hostname = socket.gethostname()

    while True:
        sequence += 1
        message = {
            "sequence": sequence,
            "timestamp": datetime.utcnow().isoformat(),
            "source": hostname,
            "environment": "IBM-VPC-VSI",
            "content": f"Hello from producer #{sequence}"
        }

        json_message = json.dumps(message)
        client.rpush(QUEUE_NAME, json_message)

        print(f"[{datetime.now().strftime('%H:%M:%S')}] Sent message #{sequence}")

        time.sleep(MESSAGE_INTERVAL)

if __name__ == "__main__":
    main()
