# Message Queue Demo

Distributed message queue demo across 3 environments:
- **IBM VPC VSI**: Producer (sends messages)
- **AWS EC2**: Redis Broker (queues messages)
- **Local Arch**: Consumer (receives messages)

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   IBM VPC VSI   │     │    AWS EC2      │     │  Local Arch     │
│   (Producer)    │────▶│    (Redis)      │◀────│   (Consumer)    │
│                 │     │                 │     │                 │
│ Sends messages  │     │ Queues messages │     │ Reads messages  │
│ every 5 seconds │     │ Port 6379       │     │ Displays output │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Quick Start

### 1. Deploy Redis on AWS EC2

```bash
# SSH to AWS EC2 instance
ssh -i ~/.ssh/R_Smurf_001.pem ubuntu@<aws-public-ip>

# Run Redis
docker run -d --name mq-redis -p 6379:6379 redis:7-alpine
```

### 2. Deploy Producer on IBM VPC VSI

```bash
# SSH to IBM VSI
ssh -i ~/.ssh/id_rsa root@<ibm-floating-ip>

# Copy and run producer
cd /tmp
# Copy producer files here
docker build -t mq-producer .
docker run -d --name mq-producer \
  -e REDIS_HOST=<aws-public-ip> \
  mq-producer
```

### 3. Deploy Consumer on Local Arch

```bash
cd consumer
REDIS_HOST=<aws-public-ip> docker-compose up -d

# Watch messages
docker logs -f mq-consumer
```

## Environment Variables

### Producer
| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_HOST` | localhost | Redis server hostname |
| `REDIS_PORT` | 6379 | Redis server port |
| `QUEUE_NAME` | demo-queue | Redis list name |
| `MESSAGE_INTERVAL` | 5 | Seconds between messages |

### Consumer
| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_HOST` | localhost | Redis server hostname |
| `REDIS_PORT` | 6379 | Redis server port |
| `QUEUE_NAME` | demo-queue | Redis list name |
| `BLOCK_TIMEOUT` | 0 | Blocking wait timeout (0=forever) |

## n8n Integration

Use these workflows to orchestrate the demo:
- `message-queue-deploy-apps.json` - Deploy all components
- `message-queue-health-check.json` - Check status
- `message-queue-stop-apps.json` - Stop all containers
- `message-queue-full-demo.json` - Full orchestration
