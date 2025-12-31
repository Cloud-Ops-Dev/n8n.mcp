# Multi-Cloud + On-Prem Message Queue Demonstration

**Presented by Novique.AI**

## Overview

This demonstration showcases a distributed message queue architecture spanning **two cloud providers and an on-premises environment**, orchestrated through n8n workflow automation. It illustrates practical implementations of:

- **Hybrid multi-cloud + on-prem architecture** - Real-world enterprise topology
- **Multi-cloud infrastructure provisioning** using Terraform
- **Container-based microservices** with Docker
- **Event-driven messaging patterns** with Redis
- **Unified workflow automation** using n8n as the control plane

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                  Multi-Cloud + On-Prem Message Queue Architecture                 │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                        ON-PREMISES ENVIRONMENT                               │ │
│  │                                                                              │ │
│  │   ┌─────────────────────┐           ┌─────────────────────────────────┐     │ │
│  │   │       Laptop        │           │      Arch Workstation           │     │ │
│  │   │   (Control Plane)   │  SSH/API  │      192.168.1.43               │     │ │
│  │   │                     │──────────▶│                                 │     │ │
│  │   │   ┌───────────┐     │           │   ┌───────────┐                 │     │ │
│  │   │   │    n8n    │     │           │   │ Consumer  │◀──┐             │     │ │
│  │   │   │ Workflows │     │           │   │   App     │   │             │     │ │
│  │   │   └───────────┘     │           │   └───────────┘   │             │     │ │
│  │   │   Orchestrator      │           │   mq-consumer     │             │     │ │
│  │   └─────────────────────┘           └───────────────────│─────────────┘     │ │
│  └─────────────────────────────────────────────────────────│───────────────────┘ │
│                                                            │ BLPOP               │
│  ┌─────────────────────┐      ┌─────────────────────┐     │                     │
│  │   IBM Cloud VPC     │      │      AWS EC2        │     │                     │
│  │    (us-south)       │      │    (us-east-2)      │     │                     │
│  │                     │      │                     │     │                     │
│  │   ┌───────────┐     │      │   ┌───────────┐     │     │                     │
│  │   │ Producer  │─────┼─────▶│   │   Redis   │◀────┼─────┘                     │
│  │   │   App     │RPUSH│      │   │  Broker   │     │                           │
│  │   └───────────┘     │      │   └───────────┘     │                           │
│  │   mq-producer       │      │   mq-redis:6379     │                           │
│  │   Profile: cx2-2x4  │      │   Type: t2.micro    │                           │
│  │   ~$0.09/hr         │      │   Free tier         │                           │
│  └─────────────────────┘      └─────────────────────┘                           │
│                                                                                   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Environment Summary

| Environment | System | Role | Component |
|-------------|--------|------|-----------|
| **On-Prem** | Laptop | Control Plane | n8n Orchestrator |
| **On-Prem** | Arch Workstation (192.168.1.43) | Data Plane | mq-consumer |
| **IBM Cloud** | VPC VSI (us-south) | Data Plane | mq-producer |
| **AWS** | EC2 (us-east-2) | Data Plane | mq-redis |

---

## Technical Components

### Message Producer (IBM Cloud)

**Deployment:** IBM VPC Virtual Server Instance
**Container:** `mq-producer`
**Runtime:** Python 3.11 with redis-py

The producer component simulates event generation, publishing structured JSON messages to the Redis queue at configurable intervals. Each message includes:

```json
{
  "seq": 1,
  "ts": "2025-12-30T10:15:30",
  "src": "ibm-vsi-hostname",
  "env": "IBM-VPC-VSI",
  "msg": "Message #1 from producer"
}
```

**Management Scripts:**
- `/usr/local/bin/start-producer.sh <REDIS_HOST>` - Initialize producer
- `/usr/local/bin/stop-producer.sh` - Graceful shutdown
- `/usr/local/bin/status-producer.sh` - Health check

### Message Broker (AWS EC2)

**Deployment:** AWS EC2 t2.micro (free tier eligible)
**Container:** `mq-redis`
**Runtime:** Redis 7 Alpine

Redis serves as the central message broker, implementing a reliable queue using Redis Lists. This pattern provides:

- **Persistence** - Append-only file (AOF) for durability
- **FIFO ordering** - RPUSH/BLPOP ensures message ordering
- **Blocking reads** - Efficient resource utilization

**Management Scripts:**
- `/usr/local/bin/start-redis.sh` - Start Redis service
- `/usr/local/bin/stop-redis.sh` - Stop Redis service
- `/usr/local/bin/status-redis.sh` - Health status

### Message Consumer (On-Prem: Arch Workstation)

**Deployment:** Docker container on Arch Workstation (192.168.1.43)
**Container:** `mq-consumer`
**Runtime:** Python 3.11 with redis-py

The consumer runs on an on-premises server, demonstrating hybrid cloud connectivity. It subscribes to the Redis queue using blocking operations, processing messages as they arrive from the cloud-based producer.

### n8n Orchestrator (On-Prem: Laptop)

**Deployment:** Docker Compose stack on laptop
**Container:** `n8n` with PostgreSQL backend
**Access:** http://localhost:5678

The n8n instance serves as the unified control plane, orchestrating:
- Cloud infrastructure provisioning (Terraform via Docker)
- Application deployment across all environments
- Health monitoring and status checks
- Teardown and cleanup operations

---

## Infrastructure as Code

### Terraform Configurations

| Configuration | Cloud Provider | Purpose |
|--------------|----------------|---------|
| `aws-ec2-ondemand/` | AWS | EC2 instance for Redis broker |
| `ibm-vpc-from-image/` | IBM Cloud | VSI from optimized custom image |
| `ibm-vpc-ondemand/` | IBM Cloud | VSI from base Ubuntu image |

### AWS Resource Stack

```
VPC (10.0.0.0/16)
├── Internet Gateway
├── Subnet (10.0.1.0/24)
├── Route Table
├── Security Group (SSH, Redis)
└── EC2 Instance
    └── cloud-init: Docker, Redis, management scripts
```

### IBM Resource Stack

```
VPC (10.240.0.0/18)
├── Public Gateway
├── Subnet (10.240.0.0/24)
├── Security Group (SSH)
└── Virtual Server Instance
    └── Custom image with Docker pre-installed
```

---

## Workflow Automation

### Infrastructure Provisioning

| Workflow | Function |
|----------|----------|
| `aws-ec2-spin-up-ondemand.json` | Provision AWS EC2 infrastructure |
| `aws-ec2-tear-down-ondemand.json` | Deprovision AWS resources |
| `ibm-vpc-vsi-spin-up-from-image-v3.json` | Provision IBM VSI |
| `ibm-vpc-vsi-tear-down-v2.json` | Deprovision IBM resources |

### Application Management

| Workflow | Function |
|----------|----------|
| `message-queue-deploy-apps.json` | Deploy all application components |
| `message-queue-health-check.json` | Monitor component health |
| `message-queue-stop-apps.json` | Stop all containers |
| `message-queue-full-demo.json` | Complete orchestration |

---

## Demonstration Walkthrough

### Prerequisites

**Cloud Accounts:**
- AWS account with configured credentials
- IBM Cloud account with API key
- SSH key pairs for both cloud providers

**On-Premises Infrastructure:**
- **Laptop:** n8n instance running (Docker Compose)
- **Arch Workstation:** Docker runtime installed, SSH accessible from laptop

### Execution Steps

1. **Provision AWS EC2 (Redis Broker)**
   ```
   Workflow: AWS EC2 - Spin Up On-Demand
   Duration: ~3 minutes
   Output: Public IP for Redis endpoint
   ```

2. **Provision IBM VSI (Producer)**
   ```
   Workflow: IBM VPC VSI - Spin Up from Image (v3)
   Duration: ~2 minutes
   Output: Floating IP for SSH access
   ```

3. **Deploy Producer Component**
   ```bash
   /scripts/message-queue/deploy-producer-to-ibm.sh <IBM_IP> <AWS_IP>
   ```

4. **Start Application Stack**
   ```
   Workflow: Message Queue - Deploy Apps
   - Starts Redis on AWS EC2
   - Starts Producer on IBM Cloud VSI
   - Starts Consumer on Arch Workstation (On-Prem)
   ```

5. **Monitor Message Flow**
   ```bash
   # From laptop, SSH to Arch Workstation to view consumer logs
   ssh 192.168.1.43 'docker logs -f mq-consumer'
   ```

6. **Verify Health**
   ```
   Workflow: Message Queue - Health Check
   Output: Status of all three components
   ```

7. **Cleanup**
   ```
   Workflow: Message Queue - Stop Apps
   Workflow: AWS EC2 - Tear Down On-Demand
   Workflow: IBM VPC VSI - Tear Down (v2)
   ```

---

## Cost Management

### AWS (t2.micro)
- Free tier: 750 hours/month (first 12 months)
- Strategy: Provision on-demand, destroy after demonstration

### IBM Cloud (cx2-2x4)
- Rate: ~$0.09/hour
- Strategy: Spin up only during active demonstrations

### Typical Demonstration Cycle
- Infrastructure provisioning: 5 minutes
- Application deployment: 2 minutes
- Active demonstration: 10-30 minutes
- Teardown: 5 minutes
- **Total billable time: ~20-40 minutes**

---

## Technical Details

### Message Flow

```
Producer                    Redis                       Consumer
   │                          │                            │
   │  RPUSH demo-queue msg    │                            │
   │ ─────────────────────────▶                            │
   │                          │                            │
   │                          │  BLPOP demo-queue 0        │
   │                          │ ◀────────────────────────── │
   │                          │                            │
   │                          │  (queue_name, message)     │
   │                          │ ──────────────────────────▶ │
   │                          │                            │
```

### Network Connectivity

| Source | Destination | Port | Protocol | Purpose |
|--------|-------------|------|----------|---------|
| IBM VSI | AWS EC2 | 6379 | TCP | Producer → Redis (RPUSH) |
| Arch Workstation | AWS EC2 | 6379 | TCP | Consumer → Redis (BLPOP) |
| Laptop | AWS EC2 | 22 | TCP | n8n SSH management |
| Laptop | IBM VSI | 22 | TCP | n8n SSH management |
| Laptop | Arch Workstation | 22 | TCP | n8n SSH management |

---

## File Structure

```
n8n.mcp/
├── terraform/
│   ├── aws-ec2-ondemand/          # AWS infrastructure
│   ├── ibm-vpc-from-image/        # IBM infrastructure (custom image)
│   └── ibm-vpc-ondemand/          # IBM infrastructure (base image)
├── workflows/examples/
│   ├── aws-ec2-*.json             # AWS provisioning workflows
│   ├── ibm-vpc-*.json             # IBM provisioning workflows
│   └── message-queue-*.json       # Application workflows
├── scripts/message-queue/
│   ├── deploy-producer-to-ibm.sh  # Producer deployment
│   ├── deploy-consumer-local.sh   # Consumer deployment
│   └── README.md
├── apps/message-queue-demo/
│   ├── producer/                  # Producer application
│   ├── consumer/                  # Consumer application
│   └── redis/                     # Redis configuration
└── docs/message-queue-lab/
    ├── LAB_GUIDE.md               # This document
    ├── AWS_SETUP.md               # AWS configuration guide
    ├── IBM_SETUP.md               # IBM configuration guide
    └── TROUBLESHOOTING.md         # Diagnostic procedures
```

---

## Key Capabilities Demonstrated

1. **Hybrid Multi-Cloud + On-Prem Architecture** - Workloads spanning AWS, IBM Cloud, and on-premises infrastructure
2. **Unified Control Plane** - n8n orchestrates all environments from a single interface
3. **Infrastructure as Code** - Reproducible cloud deployments with Terraform
4. **Containerization** - Portable applications with Docker across all environments
5. **Message Queuing** - Decoupled, asynchronous communication bridging cloud and on-prem
6. **Workflow Automation** - Orchestrated provisioning, deployment, and teardown
7. **Cost Efficiency** - On-demand cloud provisioning with persistent on-prem resources

---

## Troubleshooting

### Redis Connection Issues

```bash
# Verify Redis is running on AWS
ssh ubuntu@<aws-ip> /usr/local/bin/status-redis.sh

# Test connectivity from producer
ssh root@<ibm-ip> 'nc -zv <aws-ip> 6379'
```

### Producer Issues

```bash
# Check producer status
ssh root@<ibm-ip> /usr/local/bin/status-producer.sh

# View producer logs
ssh root@<ibm-ip> 'docker logs mq-producer'
```

### Consumer Issues (Arch Workstation)

```bash
# Check consumer status on Arch Workstation
ssh 192.168.1.43 'docker ps --filter name=mq-consumer'

# View consumer logs
ssh 192.168.1.43 'docker logs -f mq-consumer'

# Check queue depth on AWS Redis
ssh ubuntu@<aws-ip> 'docker exec mq-redis redis-cli llen demo-queue'
```

---

## Additional Documentation

- [AWS_SETUP.md](AWS_SETUP.md) - AWS EC2 configuration details
- [IBM_SETUP.md](IBM_SETUP.md) - IBM Cloud VPC configuration details
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Comprehensive diagnostic procedures

---

## Extension Possibilities

- Redis monitoring with `redis-cli MONITOR`
- Message persistence configuration
- Message acknowledgment patterns
- Horizontal scaling with multiple producers/consumers
- Observability integration with Prometheus/Grafana
