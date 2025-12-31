#!/bin/bash
#===============================================================================
# Deploy Message Queue Consumer Locally
#===============================================================================
#
# DESCRIPTION:
#   This script deploys the message consumer application as a Docker container
#   on the local workstation. The consumer connects to a remote Redis server
#   and processes messages from the queue.
#
# USAGE:
#   ./deploy-consumer-local.sh <REDIS_HOST>
#
# ARGUMENTS:
#   REDIS_HOST - The public IP of the AWS EC2 running Redis
#
# EXAMPLE:
#   ./deploy-consumer-local.sh 3.xxx.xxx.xxx
#
# ENVIRONMENT VARIABLES (optional):
#   QUEUE_NAME       - Redis queue name (default: demo-queue)
#   REDIS_PORT       - Redis port (default: 6379)
#
# PREREQUISITES:
#   - Docker installed and running locally
#   - Network connectivity to AWS EC2 on port 6379
#
# WHAT THIS SCRIPT DOES:
#   1. Removes any existing mq-consumer container
#   2. Starts a new Python container with the consumer logic
#   3. Consumer uses BLPOP to wait for messages from Redis
#
# RELATED DOCUMENTATION:
#   See: /docs/message-queue-lab/LAB_GUIDE.md
#
#===============================================================================

set -e  # Exit on any error

#-------------------------------------------------------------------------------
# Parse command line arguments
#-------------------------------------------------------------------------------
REDIS_HOST="${1:?Error: Redis host IP required. Usage: $0 <REDIS_HOST>}"

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
QUEUE_NAME="${QUEUE_NAME:-demo-queue}"
REDIS_PORT="${REDIS_PORT:-6379}"
CONTAINER_NAME="mq-consumer"

#-------------------------------------------------------------------------------
# Display deployment information
#-------------------------------------------------------------------------------
echo "==============================================================================="
echo "  Message Queue Consumer Deployment (Local)"
echo "==============================================================================="
echo ""
echo "  Redis Broker:   $REDIS_HOST:$REDIS_PORT"
echo "  Queue Name:     $QUEUE_NAME"
echo "  Container:      $CONTAINER_NAME"
echo ""
echo "==============================================================================="

#-------------------------------------------------------------------------------
# Stop existing consumer container (if any)
#-------------------------------------------------------------------------------
echo "[1/2] Removing existing consumer container..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

#-------------------------------------------------------------------------------
# Start the consumer container
#
# The consumer application is embedded as a Python one-liner for simplicity.
# It performs the following operations:
#   1. Connects to Redis with retry logic (10 attempts)
#   2. Uses BLPOP to block-wait for messages on the queue
#   3. Parses and displays each received message
#   4. Runs indefinitely until stopped
#-------------------------------------------------------------------------------
echo "[2/2] Starting consumer container..."

docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -e REDIS_HOST="$REDIS_HOST" \
  -e REDIS_PORT="$REDIS_PORT" \
  -e QUEUE_NAME="$QUEUE_NAME" \
  python:3.11-slim \
  sh -c 'pip install redis && python -u -c "
import json
import os
import time
import sys

# Attempt to import redis
try:
    import redis
except ImportError:
    print(\"Error: redis-py not installed\")
    sys.exit(1)

# Configuration from environment
REDIS_HOST = os.getenv(\"REDIS_HOST\", \"localhost\")
REDIS_PORT = int(os.getenv(\"REDIS_PORT\", \"6379\"))
QUEUE_NAME = os.getenv(\"QUEUE_NAME\", \"demo-queue\")

print(\"=\" * 60)
print(\"MESSAGE QUEUE CONSUMER\")
print(\"=\" * 60)
print(f\"  Redis Server:  {REDIS_HOST}:{REDIS_PORT}\")
print(f\"  Queue Name:    {QUEUE_NAME}\")
print(\"=\" * 60)

# Connect to Redis with retry logic
print(f\"\\nConnecting to Redis at {REDIS_HOST}:{REDIS_PORT}\")
client = None

for attempt in range(10):
    try:
        client = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            decode_responses=True
        )
        client.ping()
        print(\"Connection successful!\")
        break
    except Exception as e:
        print(f\"Attempt {attempt + 1}/10 failed: {e}\")
        if attempt < 9:
            print(\"Retrying in 5 seconds...\")
            time.sleep(5)

if client is None:
    print(\"Failed to connect to Redis\")
    sys.exit(1)

# Main consumer loop
print(f\"\\nWaiting for messages on queue: {QUEUE_NAME}\")
print(\"-\" * 60)

messages_received = 0

while True:
    # BLPOP blocks until a message is available
    # Returns tuple: (queue_name, message) or None on timeout
    result = client.blpop(QUEUE_NAME, timeout=30)

    if result:
        messages_received += 1
        _, raw_message = result

        try:
            # Parse JSON message
            message = json.loads(raw_message)

            # Display formatted message
            print(f\"[{time.strftime(\"%H:%M:%S\")}] Message #{messages_received}\")
            print(f\"    Sequence:    {message.get(\"seq\", \"N/A\")}\")
            print(f\"    Source:      {message.get(\"src\", \"unknown\")}\")
            print(f\"    Environment: {message.get(\"env\", \"unknown\")}\")
            print(f\"    Timestamp:   {message.get(\"ts\", \"N/A\")}\")
            print(f\"    Content:     {message.get(\"msg\", \"\")}\")
            print(\"-\" * 60)

        except json.JSONDecodeError:
            # Handle non-JSON messages
            print(f\"[{time.strftime(\"%H:%M:%S\")}] Raw message: {raw_message}\")
"'

#-------------------------------------------------------------------------------
# Display completion information
#-------------------------------------------------------------------------------
echo ""
echo "==============================================================================="
echo "  Consumer Started Successfully"
echo "==============================================================================="
echo ""
echo "  View logs (follow mode):"
echo "    docker logs -f $CONTAINER_NAME"
echo ""
echo "  Management commands:"
echo "    Stop:   docker stop $CONTAINER_NAME"
echo "    Remove: docker rm $CONTAINER_NAME"
echo "    Status: docker ps --filter name=$CONTAINER_NAME"
echo ""
echo "==============================================================================="
