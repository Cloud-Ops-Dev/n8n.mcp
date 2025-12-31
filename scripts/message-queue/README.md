# Message Queue Demo Scripts

Scripts for deploying and managing the multi-cloud + on-prem message queue demonstration.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         ON-PREMISES ENVIRONMENT                                   │
│  ┌─────────────────────┐              ┌─────────────────────────────────────┐    │
│  │      Laptop         │              │      Arch Workstation               │    │
│  │   (Control Plane)   │    SSH       │      192.168.1.43                   │    │
│  │                     │─────────────▶│                                     │    │
│  │   n8n Orchestrator  │              │   mq-consumer (Python)              │    │
│  └─────────────────────┘              └─────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────────┘
                                                           │ BLPOP
        ┌─────────────────────┐      ┌─────────────────────┐
        │   IBM Cloud VPC     │      │      AWS EC2        │
        │   (us-south)        │      │    (us-east-2)      │
        │                     │      │                     │
        │   mq-producer       │─────▶│   mq-redis          │
        │   (Python)          │RPUSH │   (Redis 7)         │
        └─────────────────────┘      └─────────────────────┘
```

## Scripts

### deploy-producer-to-ibm.sh
Deploys producer application to IBM VSI via SSH.

```bash
./deploy-producer-to-ibm.sh <IBM_VSI_IP> <AWS_EC2_IP>
```

Creates on IBM VSI:
- `/opt/mq-producer/producer.py` - Python producer script
- `/usr/local/bin/start-producer.sh` - Start script (takes REDIS_HOST arg)
- `/usr/local/bin/stop-producer.sh` - Stop script
- `/usr/local/bin/status-producer.sh` - Status check

### deploy-consumer-to-arch.sh (Recommended)
Deploys consumer container to Arch Workstation (On-Prem) via SSH.

```bash
./deploy-consumer-to-arch.sh <AWS_EC2_IP>
```

Example:
```bash
./deploy-consumer-to-arch.sh 3.138.174.53
```

This SSHes to the Arch Workstation at 192.168.1.43 and starts the consumer container there.

### deploy-consumer-local.sh (Legacy)
Deploys consumer container on the local machine (where script runs).

```bash
./deploy-consumer-local.sh <AWS_EC2_IP>
```

Note: For the multi-cloud + on-prem demo, use `deploy-consumer-to-arch.sh` instead.

## AWS EC2 Scripts (Created by Terraform)

On AWS EC2, cloud-init creates:
- `/usr/local/bin/start-redis.sh` - Start Redis container
- `/usr/local/bin/stop-redis.sh` - Stop Redis container
- `/usr/local/bin/status-redis.sh` - Check Redis status

## Usage with n8n

The n8n workflows orchestrate deployment via SSH:

1. **Spin up AWS EC2** (terraform) - Provisions Redis broker
2. **Spin up IBM VSI** (terraform) - Provisions Producer host
3. **Start Redis**: `ssh ubuntu@<aws-ip> /usr/local/bin/start-redis.sh`
4. **Deploy Producer**: `./deploy-producer-to-ibm.sh <ibm-ip> <aws-ip>`
5. **Start Consumer**: `./deploy-consumer-to-arch.sh <aws-ip>`

## Health Checks

```bash
# Redis (on AWS EC2)
ssh ubuntu@<aws-ip> /usr/local/bin/status-redis.sh

# Producer (on IBM Cloud VSI)
ssh root@<ibm-ip> /usr/local/bin/status-producer.sh

# Consumer (on Arch Workstation - On-Prem)
ssh 192.168.1.43 'docker ps --filter name=mq-consumer --format "{{.Status}}"'
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ARCH_HOST` | 192.168.1.43 | Arch Workstation IP |
| `QUEUE_NAME` | demo-queue | Redis queue name |
| `REDIS_PORT` | 6379 | Redis port |

## Viewing Logs

```bash
# Consumer logs (from laptop)
ssh 192.168.1.43 'docker logs -f mq-consumer'

# Producer logs (from laptop)
ssh root@<ibm-ip> 'docker logs -f mq-producer'

# Redis logs (from laptop)
ssh ubuntu@<aws-ip> 'docker logs -f mq-redis'
```
