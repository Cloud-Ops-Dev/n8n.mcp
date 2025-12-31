#!/bin/bash
#===============================================================================
# Deploy Message Queue Producer to IBM VPC VSI
#===============================================================================
#
# DESCRIPTION:
#   This script deploys the message producer application to an IBM Cloud
#   Virtual Server Instance (VSI). It creates the necessary scripts and
#   configuration on the remote system, then starts the producer container.
#
# USAGE:
#   ./deploy-producer-to-ibm.sh <IBM_VSI_IP> <REDIS_HOST>
#
# ARGUMENTS:
#   IBM_VSI_IP   - The floating IP address of the IBM VSI
#   REDIS_HOST   - The public IP of the AWS EC2 running Redis
#
# EXAMPLE:
#   ./deploy-producer-to-ibm.sh 169.48.xxx.xxx 3.xxx.xxx.xxx
#
# PREREQUISITES:
#   - SSH key configured at /home/clay/.ssh/id_ed25519
#   - Docker installed on the IBM VSI
#   - Network connectivity between IBM VSI and AWS EC2 on port 6379
#
# WHAT THIS SCRIPT CREATES ON THE REMOTE SYSTEM:
#   /opt/mq-producer/producer.py     - Python producer application
#   /usr/local/bin/start-producer.sh - Script to start the producer
#   /usr/local/bin/stop-producer.sh  - Script to stop the producer
#   /usr/local/bin/status-producer.sh - Script to check producer health
#
# RELATED DOCUMENTATION:
#   See: /docs/message-queue-lab/IBM_SETUP.md
#
#===============================================================================

set -e  # Exit on any error

#-------------------------------------------------------------------------------
# Parse command line arguments
#-------------------------------------------------------------------------------
IBM_IP="${1:?Error: IBM VSI IP address required. Usage: $0 <IBM_VSI_IP> <REDIS_HOST>}"
REDIS_HOST="${2:?Error: Redis host IP required. Usage: $0 <IBM_VSI_IP> <REDIS_HOST>}"

#-------------------------------------------------------------------------------
# Configuration - Modify these if your environment differs
#-------------------------------------------------------------------------------
SSH_KEY="${SSH_KEY:-/home/clay/.ssh/id_ed25519}"
SSH_USER="${SSH_USER:-root}"
QUEUE_NAME="${QUEUE_NAME:-demo-queue}"
MESSAGE_INTERVAL="${MESSAGE_INTERVAL:-5}"

#-------------------------------------------------------------------------------
# Display deployment information
#-------------------------------------------------------------------------------
echo "==============================================================================="
echo "  Message Queue Producer Deployment"
echo "==============================================================================="
echo ""
echo "  Target IBM VSI:     $IBM_IP"
echo "  Redis Broker:       $REDIS_HOST:6379"
echo "  Queue Name:         $QUEUE_NAME"
echo "  Message Interval:   ${MESSAGE_INTERVAL}s"
echo "  SSH Key:            $SSH_KEY"
echo ""
echo "==============================================================================="

#-------------------------------------------------------------------------------
# Deploy scripts to remote system
# This uses a heredoc to send multiple commands over a single SSH connection
#-------------------------------------------------------------------------------
echo "[1/3] Creating producer scripts on remote system..."

ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$IBM_IP" bash << 'REMOTE_SCRIPT'

#-------------------------------------------------------------------------------
# Create the producer application directory
#-------------------------------------------------------------------------------
mkdir -p /opt/mq-producer

#-------------------------------------------------------------------------------
# Create the Python producer application
#
# This application:
# - Connects to Redis with automatic retry (10 attempts)
# - Sends JSON messages every MESSAGE_INTERVAL seconds
# - Each message contains: sequence number, timestamp, hostname, environment
# - Runs indefinitely until stopped
#-------------------------------------------------------------------------------
cat > /opt/mq-producer/producer.py << 'PYTHON'
#!/usr/bin/env python3
"""
Message Queue Producer Application

This script connects to a Redis server and continuously sends messages
to a specified queue. It is designed to run as part of the multi-cloud
message queue lab demonstration.

Environment Variables:
    REDIS_HOST       - Redis server hostname (default: localhost)
    REDIS_PORT       - Redis server port (default: 6379)
    QUEUE_NAME       - Name of the Redis list to push messages to (default: demo-queue)
    MESSAGE_INTERVAL - Seconds between messages (default: 5)

Message Format:
    {
        "seq": <sequence_number>,
        "ts": "<ISO_timestamp>",
        "src": "<hostname>",
        "env": "IBM-VPC-VSI",
        "msg": "Message #<seq> from producer"
    }
"""

import json
import os
import socket
import time
import sys

# Attempt to import redis, install if not present
try:
    import redis
except ImportError:
    import subprocess
    print("Installing redis-py library...")
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'redis'])
    import redis

# Configuration from environment variables
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
QUEUE_NAME = os.getenv("QUEUE_NAME", "demo-queue")
INTERVAL = int(os.getenv("MESSAGE_INTERVAL", "5"))

def connect_to_redis():
    """
    Establish connection to Redis with retry logic.

    Attempts to connect up to 10 times with 5-second delays between attempts.
    This handles cases where Redis might not be immediately available after
    infrastructure provisioning.

    Returns:
        redis.Redis: Connected Redis client

    Raises:
        SystemExit: If all connection attempts fail
    """
    print(f"Connecting to Redis at {REDIS_HOST}:{REDIS_PORT}")

    for attempt in range(10):
        try:
            client = redis.Redis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                decode_responses=True
            )
            # Test the connection with PING
            client.ping()
            print("Connection successful!")
            return client
        except Exception as e:
            print(f"Attempt {attempt + 1}/10 failed: {e}")
            if attempt < 9:
                print("Retrying in 5 seconds...")
                time.sleep(5)

    print("Failed to connect to Redis after 10 attempts")
    sys.exit(1)

def main():
    """
    Main producer loop.

    Continuously sends messages to the Redis queue until interrupted.
    Each message is a JSON object pushed to the right of the list using RPUSH.
    """
    print("=" * 60)
    print("MESSAGE QUEUE PRODUCER")
    print("=" * 60)
    print(f"  Redis Server:     {REDIS_HOST}:{REDIS_PORT}")
    print(f"  Queue Name:       {QUEUE_NAME}")
    print(f"  Send Interval:    {INTERVAL} seconds")
    print(f"  Local Hostname:   {socket.gethostname()}")
    print("=" * 60)

    client = connect_to_redis()
    sequence = 0
    hostname = socket.gethostname()

    print(f"\nStarting message production...")

    while True:
        sequence += 1

        # Construct the message payload
        message = {
            "seq": sequence,
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "src": hostname,
            "env": "IBM-VPC-VSI",
            "msg": f"Message #{sequence} from producer"
        }

        # Push message to the right of the Redis list
        # This implements FIFO when consumer uses BLPOP (left pop)
        client.rpush(QUEUE_NAME, json.dumps(message))

        print(f"[{time.strftime('%H:%M:%S')}] Sent message #{sequence}")

        # Wait before sending next message
        time.sleep(INTERVAL)

if __name__ == "__main__":
    main()
PYTHON

# Make the producer script executable
chmod +x /opt/mq-producer/producer.py

#-------------------------------------------------------------------------------
# Create the start-producer.sh management script
#
# Usage: /usr/local/bin/start-producer.sh <REDIS_HOST>
#
# This script:
# - Stops and removes any existing producer container
# - Starts a new container with the specified Redis host
# - Mounts the producer script from /opt/mq-producer
# - Configures automatic restart on failure
#-------------------------------------------------------------------------------
cat > /usr/local/bin/start-producer.sh << 'SCRIPT'
#!/bin/bash
#
# Start the Message Queue Producer
#
# Usage: start-producer.sh <REDIS_HOST>
#
# Arguments:
#   REDIS_HOST - IP address or hostname of the Redis server
#

REDIS_HOST="${1:-localhost}"

echo "Starting message queue producer..."
echo "  Target Redis: $REDIS_HOST:6379"

# Remove existing container if present (ignore errors)
docker rm -f mq-producer 2>/dev/null || true

# Start the producer container
# -d            : Run detached (background)
# --name        : Container name for easy reference
# --restart     : Automatically restart on failure
# -e            : Environment variables for configuration
# -v            : Mount the producer script
docker run -d \
  --name mq-producer \
  --restart unless-stopped \
  -e REDIS_HOST="$REDIS_HOST" \
  -e REDIS_PORT=6379 \
  -e QUEUE_NAME=demo-queue \
  -e MESSAGE_INTERVAL=5 \
  -v /opt/mq-producer:/app \
  python:3.11-slim \
  sh -c "pip install redis && python -u /app/producer.py"

echo ""
echo "Producer started successfully!"
echo "View logs: docker logs -f mq-producer"
SCRIPT
chmod +x /usr/local/bin/start-producer.sh

#-------------------------------------------------------------------------------
# Create the stop-producer.sh management script
#-------------------------------------------------------------------------------
cat > /usr/local/bin/stop-producer.sh << 'SCRIPT'
#!/bin/bash
#
# Stop the Message Queue Producer
#

echo "Stopping message queue producer..."
docker stop mq-producer && docker rm mq-producer
echo "Producer stopped and removed."
SCRIPT
chmod +x /usr/local/bin/stop-producer.sh

#-------------------------------------------------------------------------------
# Create the status-producer.sh health check script
#
# Returns:
#   "HEALTHY"     - Container is running
#   "NOT_RUNNING" - Container is not running
#-------------------------------------------------------------------------------
cat > /usr/local/bin/status-producer.sh << 'SCRIPT'
#!/bin/bash
#
# Check Message Queue Producer Health
#
# Exit codes:
#   0 - Producer is healthy
#   1 - Producer is not running
#

if docker ps --filter name=mq-producer --format '{{.Status}}' | grep -q Up; then
  echo "HEALTHY"
  exit 0
else
  echo "NOT_RUNNING"
  exit 1
fi
SCRIPT
chmod +x /usr/local/bin/status-producer.sh

#-------------------------------------------------------------------------------
# Pre-pull the Python image to speed up first start
#-------------------------------------------------------------------------------
echo "Pre-pulling Python image..."
docker pull python:3.11-slim

echo ""
echo "Remote deployment complete!"

REMOTE_SCRIPT

#-------------------------------------------------------------------------------
# Start the producer with the specified Redis host
#-------------------------------------------------------------------------------
echo ""
echo "[2/3] Starting producer container..."

ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$IBM_IP" \
  "/usr/local/bin/start-producer.sh $REDIS_HOST"

#-------------------------------------------------------------------------------
# Verify the producer started successfully
#-------------------------------------------------------------------------------
echo ""
echo "[3/3] Verifying producer status..."

sleep 3  # Give container time to start

STATUS=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$IBM_IP" \
  "/usr/local/bin/status-producer.sh" 2>/dev/null || echo "UNKNOWN")

echo ""
echo "==============================================================================="
echo "  Deployment Complete"
echo "==============================================================================="
echo ""
echo "  Producer Status: $STATUS"
echo ""
echo "  Management Commands (run on IBM VSI):"
echo "    Start:  /usr/local/bin/start-producer.sh $REDIS_HOST"
echo "    Stop:   /usr/local/bin/stop-producer.sh"
echo "    Status: /usr/local/bin/status-producer.sh"
echo "    Logs:   docker logs -f mq-producer"
echo ""
echo "==============================================================================="
