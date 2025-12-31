#!/bin/sh
#===============================================================================
# Deploy Message Queue Consumer to Arch Workstation (On-Prem)
#===============================================================================
#
# DESCRIPTION:
#   This script deploys the message consumer application to the Arch Workstation
#   (192.168.1.43) via SSH. The consumer connects to the AWS-hosted Redis server
#   and processes messages from the queue.
#
# USAGE:
#   ./deploy-consumer-to-arch.sh <REDIS_HOST>
#
# ARGUMENTS:
#   REDIS_HOST - The public IP of the AWS EC2 running Redis
#
# EXAMPLE:
#   ./deploy-consumer-to-arch.sh 3.138.174.53
#
# ENVIRONMENT VARIABLES (optional):
#   ARCH_HOST        - Arch Workstation IP (default: 192.168.1.43)
#   QUEUE_NAME       - Redis queue name (default: demo-queue)
#   REDIS_PORT       - Redis port (default: 6379)
#
# PREREQUISITES:
#   - SSH key access to Arch Workstation
#   - Docker installed on Arch Workstation
#   - Network connectivity from Arch to AWS EC2 on port 6379
#
# WHAT THIS SCRIPT DOES:
#   1. SSHes to the Arch Workstation
#   2. Removes any existing mq-consumer container
#   3. Starts a new Python container with the consumer logic
#   4. Consumer uses BLPOP to wait for messages from Redis
#
# RELATED DOCUMENTATION:
#   See: /docs/message-queue-lab/LAB_GUIDE.md
#
#===============================================================================

set -e  # Exit on any error

#-------------------------------------------------------------------------------
# Parse command line arguments
#-------------------------------------------------------------------------------
if [ -z "$1" ]; then
    echo "Error: Redis host IP required. Usage: $0 <REDIS_HOST>"
    exit 1
fi
REDIS_HOST="$1"

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
ARCH_HOST="${ARCH_HOST:-192.168.1.43}"
ARCH_USER="${ARCH_USER:-clayton}"
SSH_KEY="${SSH_KEY:-/home/clay/.ssh/id_ed25519}"
QUEUE_NAME="${QUEUE_NAME:-demo-queue}"
REDIS_PORT="${REDIS_PORT:-6379}"
CONTAINER_NAME="mq-consumer"

#-------------------------------------------------------------------------------
# Display deployment information
#-------------------------------------------------------------------------------
echo "==============================================================================="
echo "  Message Queue Consumer Deployment (On-Prem: Arch Workstation)"
echo "==============================================================================="
echo ""
echo "  Target Host:    $ARCH_USER@$ARCH_HOST"
echo "  SSH Key:        $SSH_KEY"
echo "  Redis Broker:   $REDIS_HOST:$REDIS_PORT"
echo "  Queue Name:     $QUEUE_NAME"
echo "  Container:      $CONTAINER_NAME"
echo ""
echo "==============================================================================="

#-------------------------------------------------------------------------------
# Consumer Python code (will be passed to container)
#-------------------------------------------------------------------------------
CONSUMER_CODE='
import json
import os
import time
import sys

try:
    import redis
except ImportError:
    print("Error: redis-py not installed")
    sys.exit(1)

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
QUEUE_NAME = os.getenv("QUEUE_NAME", "demo-queue")

print("=" * 60)
print("MESSAGE QUEUE CONSUMER (On-Prem: Arch Workstation)")
print("=" * 60)
print("  Redis Server:  {}:{}".format(REDIS_HOST, REDIS_PORT))
print("  Queue Name:    {}".format(QUEUE_NAME))
print("=" * 60)

print("\nConnecting to Redis at {}:{}".format(REDIS_HOST, REDIS_PORT))
client = None

for attempt in range(10):
    try:
        client = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            decode_responses=True
        )
        client.ping()
        print("Connection successful!")
        break
    except Exception as e:
        print("Attempt {}/10 failed: {}".format(attempt + 1, e))
        if attempt < 9:
            print("Retrying in 5 seconds...")
            time.sleep(5)

if client is None:
    print("Failed to connect to Redis")
    sys.exit(1)

print("\nWaiting for messages on queue: {}".format(QUEUE_NAME))
print("-" * 60)

messages_received = 0

while True:
    result = client.blpop(QUEUE_NAME, timeout=30)

    if result:
        messages_received += 1
        _, raw_message = result

        try:
            message = json.loads(raw_message)
            ts = time.strftime("%H:%M:%S")
            print("[{}] Message #{}".format(ts, messages_received))
            print("    Sequence:    {}".format(message.get("seq", "N/A")))
            print("    Source:      {}".format(message.get("src", "unknown")))
            print("    Environment: {}".format(message.get("env", "unknown")))
            print("    Timestamp:   {}".format(message.get("ts", "N/A")))
            print("    Content:     {}".format(message.get("msg", "")))
            print("-" * 60)
        except json.JSONDecodeError:
            ts = time.strftime("%H:%M:%S")
            print("[{}] Raw message: {}".format(ts, raw_message))
'

#-------------------------------------------------------------------------------
# Deploy to Arch Workstation via SSH
#-------------------------------------------------------------------------------
echo "[1/3] Connecting to Arch Workstation at $ARCH_HOST..."

echo "[2/3] Removing existing consumer container..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ARCH_USER@$ARCH_HOST" "docker rm -f $CONTAINER_NAME 2>/dev/null || true"

echo "[3/3] Starting consumer container on Arch Workstation..."

# Encode the Python code in base64 for safe transmission
ENCODED_CODE=$(echo "$CONSUMER_CODE" | base64 -w 0)

ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ARCH_USER@$ARCH_HOST" "docker run -d \
  --name $CONTAINER_NAME \
  --network host \
  --restart unless-stopped \
  -e REDIS_HOST=$REDIS_HOST \
  -e REDIS_PORT=$REDIS_PORT \
  -e QUEUE_NAME=$QUEUE_NAME \
  python:3.11-slim \
  sh -c 'pip install redis && echo $ENCODED_CODE | base64 -d | python -u'"

#-------------------------------------------------------------------------------
# Display completion information
#-------------------------------------------------------------------------------
echo ""
echo "==============================================================================="
echo "  Consumer Deployed to Arch Workstation Successfully"
echo "==============================================================================="
echo ""
echo "  View logs (from laptop):"
echo "    ssh $ARCH_HOST 'docker logs -f $CONTAINER_NAME'"
echo ""
echo "  Management commands (run via SSH):"
echo "    Stop:   ssh $ARCH_HOST 'docker stop $CONTAINER_NAME'"
echo "    Remove: ssh $ARCH_HOST 'docker rm $CONTAINER_NAME'"
echo "    Status: ssh $ARCH_HOST 'docker ps --filter name=$CONTAINER_NAME'"
echo ""
echo "==============================================================================="
