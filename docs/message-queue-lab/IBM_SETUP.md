# IBM Cloud VPC Setup Guide

## Overview

This guide covers the IBM Cloud VPC infrastructure for the message queue lab. The Virtual Server Instance (VSI) runs the message producer that sends messages to the Redis broker on AWS.

---

## Architecture

```
IBM Cloud (us-south)
├── VPC: 10.240.0.0/18
│   ├── Public Gateway
│   ├── Subnet: 10.240.0.0/24 (us-south-1)
│   └── Security Group
│       ├── Inbound: TCP 22 (SSH)
│       └── Outbound: All traffic
└── Virtual Server Instance (VSI)
    ├── Profile: cx2-2x4 (2 vCPU, 4GB RAM)
    ├── Image: Custom image with Docker
    └── Floating IP: Attached
```

---

## Prerequisites

### IBM Cloud API Key

1. Log into IBM Cloud Console
2. Navigate to Manage → Access (IAM) → API Keys
3. Create an API key or use existing
4. Store securely (shown only once)

### SSH Key in IBM Cloud

1. Navigate to VPC Infrastructure → SSH Keys
2. Add your public key (or create new)
3. Note the key name (default: `lab-key`)

### Custom Image (Recommended)

A custom image with Docker pre-installed speeds up provisioning:

1. Create a VSI with base Ubuntu image
2. Install Docker and dependencies
3. Create image from the VSI
4. Use image ID in Terraform

---

## Terraform Configuration

### Files

| File | Purpose |
|------|---------|
| `providers.tf` | IBM provider configuration |
| `variables.tf` | Input variables |
| `main.tf` | VPC, subnet, VSI resources |
| `terraform.tfvars.template` | Credential template |

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ibm_region` | us-south | IBM Cloud region |
| `ibm_zone` | us-south-1 | Availability zone |
| `instance_profile` | cx2-2x4 | VSI size |
| `ssh_key_name` | lab-key | SSH key in IBM Cloud |
| `custom_image_id` | (required) | Custom image with Docker |

### Setting Up Credentials

```bash
cd /home/clay/IDE/tools/n8n.mcp/terraform/ibm-vpc-from-image

# Copy template
cp terraform.tfvars.template terraform.tfvars

# Edit with your credentials
vim terraform.tfvars
```

Contents of `terraform.tfvars`:
```hcl
ibm_api_key      = "your-ibm-api-key"
ibm_region       = "us-south"
ssh_key_name     = "lab-key"
ssh_key_path     = "/home/clay/.ssh/id_ed25519"
instance_name    = "n8n-lab-vsi-from-image"
instance_profile = "cx2-2x4"
custom_image_id  = "r006-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

---

## Producer Deployment

### Overview

The producer deployment script creates:
1. Python producer application
2. Start/stop/status management scripts
3. Docker container configuration

### Deployment Process

```bash
# Run deployment script
/scripts/message-queue/deploy-producer-to-ibm.sh <IBM_VSI_IP> <REDIS_HOST>

# Example
/scripts/message-queue/deploy-producer-to-ibm.sh 169.xx.xx.xx 3.xx.xx.xx
```

### What Gets Created

**`/opt/mq-producer/producer.py`**
The main producer application that:
- Connects to Redis with retry logic
- Sends JSON messages every 5 seconds
- Includes sequence number, timestamp, hostname

**`/usr/local/bin/start-producer.sh <REDIS_HOST>`**
```bash
#!/bin/bash
# Starts the producer container with Redis host parameter
# Pre-pulls Python image if not present
docker rm -f mq-producer 2>/dev/null || true
docker run -d \
  --name mq-producer \
  --restart unless-stopped \
  -e REDIS_HOST="$1" \
  -e REDIS_PORT=6379 \
  -e QUEUE_NAME=demo-queue \
  -e MESSAGE_INTERVAL=5 \
  -v /opt/mq-producer:/app \
  python:3.11-slim \
  sh -c "pip install redis && python -u /app/producer.py"
```

**`/usr/local/bin/stop-producer.sh`**
```bash
#!/bin/bash
docker stop mq-producer && docker rm mq-producer
echo "Producer stopped"
```

**`/usr/local/bin/status-producer.sh`**
```bash
#!/bin/bash
# Returns HEALTHY if container is running
# Returns NOT_RUNNING otherwise
if docker ps --filter name=mq-producer --format '{{.Status}}' | grep -q Up; then
  echo "HEALTHY"
else
  echo "NOT_RUNNING"
fi
```

---

## Manual Terraform Deployment

```bash
cd /home/clay/IDE/tools/n8n.mcp/terraform/ibm-vpc-from-image

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply (creates all resources)
terraform apply

# Note the outputs
# public_ip = "169.xx.xx.xx"
# ssh_command = "ssh -i /home/clay/.ssh/id_ed25519 root@169.xx.xx.xx"
```

---

## Security Group Rules

### Inbound Rules

| Protocol | Port | Source | Purpose |
|----------|------|--------|---------|
| TCP | 22 | Any | SSH access |

### Outbound Rules

| Protocol | Port | Destination | Purpose |
|----------|------|-------------|---------|
| All | All | Any | Allow all outbound |

### Security Considerations

For production:
- Restrict SSH to specific IPs
- Use private endpoints where possible
- Enable IBM Cloud IAM for access control

---

## Connecting to the VSI

### SSH Access

```bash
# Using SSH key
ssh -i /home/clay/.ssh/id_ed25519 root@<floating-ip>
```

### Checking Producer Status

```bash
# Check container status
docker ps --filter name=mq-producer

# View producer logs
docker logs -f mq-producer

# Check Redis connectivity
docker exec mq-producer python -c "import redis; r=redis.Redis(host='<aws-ip>'); print(r.ping())"
```

---

## Custom Image Creation

### Creating a Reusable Image

1. **Provision base VSI**
   ```bash
   # Use ibm-vpc-ondemand terraform
   cd terraform/ibm-vpc-ondemand
   terraform apply
   ```

2. **Install Docker**
   ```bash
   ssh root@<ip>
   apt-get update
   apt-get install -y docker.io
   systemctl enable docker
   systemctl start docker
   ```

3. **Pre-pull images**
   ```bash
   docker pull python:3.11-slim
   ```

4. **Create image from VSI**
   - IBM Cloud Console → VPC Infrastructure → Images
   - Create image from VSI
   - Note the image ID (r006-...)

5. **Update Terraform**
   ```hcl
   custom_image_id = "r006-new-image-id"
   ```

### Benefits of Custom Image

- Faster provisioning (~2 min vs ~5 min)
- Docker already installed
- Python image pre-pulled
- Consistent environment

---

## Terraform Outputs

| Output | Description |
|--------|-------------|
| `vsi_id` | VSI instance ID |
| `public_ip` | Floating IP address |
| `private_ip` | VPC private IP |
| `ssh_command` | Ready-to-use SSH command |
| `image_id_used` | Custom image ID used |

---

## Cost Management

### Instance Pricing (cx2-2x4)

- ~$0.09/hour
- ~$65/month (continuous)
- Billed per second when running

### Cost Optimization

1. **Stop when not in use**
   - VSI still incurs storage costs when stopped
   - Better to destroy and recreate

2. **Destroy resources**
   ```bash
   terraform destroy
   ```

3. **Monitor costs**
   - IBM Cloud → Billing → Usage

---

## Troubleshooting

### VSI Not Starting

```bash
# Check Terraform state
terraform show

# Verify image exists
ibmcloud is images --visibility private
```

### Cannot SSH to VSI

1. Check floating IP is assigned
2. Verify security group allows port 22
3. Check SSH key matches

```bash
# Debug SSH
ssh -vvv -i /home/clay/.ssh/id_ed25519 root@<ip>
```

### Producer Cannot Connect to Redis

```bash
# SSH to VSI
ssh root@<ibm-ip>

# Test Redis connectivity
nc -zv <aws-ip> 6379

# Check producer logs
docker logs mq-producer

# Verify environment variables
docker inspect mq-producer | grep -A 10 Env
```

### Docker Not Running

```bash
# Check Docker status
systemctl status docker

# Start Docker if needed
systemctl start docker

# Check Docker logs
journalctl -u docker
```

---

## Integration with n8n

### Workflows

- `ibm-vpc-vsi-spin-up-from-image-v3.json` - Provision VSI
- `ibm-vpc-vsi-tear-down-v2.json` - Destroy VSI

### Workflow Parameters

Update these in the workflow "Set Configuration" node:
- `image_id` - Custom image ID
- `api_key` - IBM Cloud API key
- `region` - IBM Cloud region
- `ssh_key_name` - SSH key name
- `instance_name` - VSI name
- `instance_profile` - VSI size
