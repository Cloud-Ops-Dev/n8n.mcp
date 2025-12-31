#!/usr/bin/env python3
"""
Message Queue Consumer
Reads messages from Redis queue on AWS EC2.
Designed to run on Local Arch workstation.
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
BLOCK_TIMEOUT = int(os.getenv("BLOCK_TIMEOUT", "0"))  # 0 = wait forever

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
    """Main consumer loop."""
    print("=" * 50)
    print("MESSAGE QUEUE CONSUMER")
    print(f"Redis: {REDIS_HOST}:{REDIS_PORT}")
    print(f"Queue: {QUEUE_NAME}")
    print(f"Block timeout: {BLOCK_TIMEOUT}s (0=forever)")
    print("=" * 50)

    client = get_redis_client()
    hostname = socket.gethostname()
    messages_received = 0

    print(f"Waiting for messages on '{QUEUE_NAME}'...")

    while True:
        # BLPOP blocks until a message is available
        result = client.blpop(QUEUE_NAME, timeout=BLOCK_TIMEOUT if BLOCK_TIMEOUT > 0 else 0)

        if result:
            _, json_message = result
            messages_received += 1

            try:
                message = json.loads(json_message)

                print("\n" + "-" * 40)
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Message #{messages_received}")
                print(f"  Source: {message.get('source', 'unknown')}")
                print(f"  Environment: {message.get('environment', 'unknown')}")
                print(f"  Sequence: {message.get('sequence', 'N/A')}")
                print(f"  Timestamp: {message.get('timestamp', 'N/A')}")
                print(f"  Content: {message.get('content', '')}")
                print("-" * 40)

            except json.JSONDecodeError:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Raw message: {json_message}")

if __name__ == "__main__":
    main()
