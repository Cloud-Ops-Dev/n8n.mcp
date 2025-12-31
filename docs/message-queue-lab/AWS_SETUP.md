# AWS EC2 Setup Guide

## Overview

This guide covers the AWS EC2 infrastructure for the message queue lab. The EC2 instance serves as the Redis message broker, accepting connections from both the IBM Cloud producer and the local consumer.

---

## Architecture

```
AWS Cloud (us-east-2)
├── VPC: 10.0.0.0/16
│   ├── Internet Gateway
│   ├── Public Subnet: 10.0.1.0/24
│   ├── Route Table → Internet Gateway
│   └── Security Group
│       ├── Inbound: TCP 22 (SSH)
│       ├── Inbound: TCP 6379 (Redis)
│       └── Outbound: All traffic
└── EC2 Instance
    ├── Type: t2.micro (Free tier)
    ├── AMI: Ubuntu 22.04 LTS
    ├── Storage: 8GB gp2
    └── cloud-init: Docker + Redis
```

---

## Prerequisites

### AWS Credentials

You need an AWS Access Key and Secret Key with permissions to:
- Create/delete VPCs, subnets, internet gateways
- Create/delete security groups
- Launch/terminate EC2 instances

### SSH Key Pair

1. Create or use existing key pair in AWS Console
2. Download the `.pem` file
3. Store at: `/home/clay/.ssh/R_Smurf_001.pem`
4. Set permissions: `chmod 400 ~/.ssh/R_Smurf_001.pem`

---

## Terraform Configuration

### Files

| File | Purpose |
|------|---------|
| `providers.tf` | AWS provider and version constraints |
| `variables.tf` | Input variables with defaults |
| `main.tf` | Resource definitions |
| `terraform.tfvars.template` | Template for credentials |

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | us-east-2 | AWS region |
| `instance_type` | t2.micro | Instance size (free tier) |
| `ami_id` | ami-0ea3c35c5c3284d82 | Ubuntu 22.04 LTS |
| `ssh_key_name` | R_Smurf_001 | AWS key pair name |
| `instance_name` | n8n-lab-ec2-redis | Instance tag name |

### Setting Up Credentials

```bash
cd /home/clay/IDE/tools/n8n.mcp/terraform/aws-ec2-ondemand

# Copy template
cp terraform.tfvars.template terraform.tfvars

# Edit with your credentials
vim terraform.tfvars
```

Contents of `terraform.tfvars`:
```hcl
aws_access_key = "AKIAIOSFODNN7EXAMPLE"
aws_secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
aws_region     = "us-east-2"
ssh_key_name   = "R_Smurf_001"
ssh_key_path   = "/home/clay/.ssh/R_Smurf_001.pem"
instance_name  = "n8n-lab-ec2-redis"
instance_type  = "t2.micro"
ami_id         = "ami-0ea3c35c5c3284d82"
```

---

## Cloud-Init Script

The EC2 instance uses cloud-init to automatically configure the system on first boot:

### What Gets Installed

1. **Docker** - Container runtime
2. **Redis Image** - Pre-pulled for faster startup
3. **Management Scripts** - start/stop/status for Redis

### Scripts Created

**`/usr/local/bin/start-redis.sh`**
```bash
#!/bin/bash
# Removes any existing Redis container and starts fresh
# Redis data persists in Docker volume with appendonly enabled
docker rm -f mq-redis 2>/dev/null || true
docker run -d \
  --name mq-redis \
  --restart unless-stopped \
  -p 6379:6379 \
  redis:7-alpine \
  redis-server --appendonly yes
echo "Redis started on port 6379"
```

**`/usr/local/bin/stop-redis.sh`**
```bash
#!/bin/bash
docker stop mq-redis && docker rm mq-redis
echo "Redis stopped"
```

**`/usr/local/bin/status-redis.sh`**
```bash
#!/bin/bash
# Returns HEALTHY if Redis responds to PING
# Returns NOT_RUNNING otherwise
if docker exec mq-redis redis-cli ping 2>/dev/null | grep -q PONG; then
  echo "HEALTHY"
else
  echo "NOT_RUNNING"
fi
```

### Cloud-Init Log

To verify cloud-init completed successfully:
```bash
ssh -i ~/.ssh/R_Smurf_001.pem ubuntu@<public-ip> \
  'cat /var/log/cloud-init-mq.log'
```

---

## Manual Terraform Deployment

If not using n8n workflow:

```bash
cd /home/clay/IDE/tools/n8n.mcp/terraform/aws-ec2-ondemand

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply (creates all resources)
terraform apply

# Note the outputs
# public_ip = "3.xxx.xxx.xxx"
# ssh_command = "ssh -i /home/clay/.ssh/R_Smurf_001.pem ubuntu@3.xxx.xxx.xxx"
```

---

## Security Group Rules

### Inbound Rules

| Type | Protocol | Port | Source | Purpose |
|------|----------|------|--------|---------|
| SSH | TCP | 22 | 0.0.0.0/0 | Remote administration |
| Custom TCP | TCP | 6379 | 0.0.0.0/0 | Redis connections |

### Outbound Rules

| Type | Protocol | Port | Destination | Purpose |
|------|----------|------|-------------|---------|
| All traffic | All | All | 0.0.0.0/0 | Allow all outbound |

### Security Considerations

For production environments:
- Restrict SSH to your IP only
- Restrict Redis to producer/consumer IPs
- Use VPC peering instead of public IPs
- Enable Redis authentication

---

## Connecting to the Instance

### SSH Access

```bash
ssh -i /home/clay/.ssh/R_Smurf_001.pem ubuntu@<public-ip>
```

### Testing Redis

```bash
# From local machine (if redis-cli installed)
redis-cli -h <public-ip> ping

# From the EC2 instance
docker exec mq-redis redis-cli ping

# Check queue length
docker exec mq-redis redis-cli llen demo-queue

# Monitor commands in real-time
docker exec -it mq-redis redis-cli monitor
```

---

## Terraform Outputs

After `terraform apply`, these outputs are available:

| Output | Description |
|--------|-------------|
| `instance_id` | AWS EC2 instance ID |
| `public_ip` | Public IPv4 address |
| `public_dns` | Public DNS hostname |
| `private_ip` | VPC private IP |
| `vpc_id` | VPC identifier |
| `ssh_command` | Ready-to-use SSH command |
| `redis_endpoint` | Redis connection string |

Access outputs anytime:
```bash
terraform output
terraform output public_ip
```

---

## Cost Optimization

### Free Tier Limits

- **t2.micro**: 750 hours/month (first 12 months)
- **EBS Storage**: 30GB/month
- **Data Transfer**: 1GB/month outbound

### Recommendations

1. **Destroy when not in use**
   ```bash
   terraform destroy
   ```

2. **Check running instances**
   ```bash
   aws ec2 describe-instances \
     --filters "Name=tag:ManagedBy,Values=n8n" \
     --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}'
   ```

3. **Monitor usage in AWS Console**
   - EC2 Dashboard → Running Instances
   - Billing Dashboard → Free Tier Usage

---

## Destroying Resources

### Using n8n

Run workflow: `AWS EC2 - Tear Down On-Demand`

### Manual

```bash
cd /home/clay/IDE/tools/n8n.mcp/terraform/aws-ec2-ondemand
terraform destroy
```

This removes:
- EC2 instance
- Security group
- Route table
- Subnet
- Internet gateway
- VPC

---

## Troubleshooting

### Instance Won't Launch

```bash
# Check AMI exists in region
aws ec2 describe-images --image-ids ami-0ea3c35c5c3284d82 --region us-east-2

# Find latest Ubuntu 22.04 AMI
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId'
```

### Can't Connect via SSH

1. Check security group allows port 22
2. Verify key pair matches
3. Check instance is running
4. Verify public IP is assigned

### Redis Not Starting

```bash
# SSH to instance and check Docker
docker ps -a
docker logs mq-redis

# Check cloud-init completed
cat /var/log/cloud-init-mq.log
cloud-init status

# Manually start Redis
/usr/local/bin/start-redis.sh
```

### Connection Timeout on Port 6379

1. Verify security group has port 6379 open
2. Check Redis is listening: `docker exec mq-redis redis-cli ping`
3. Test connectivity: `nc -zv <public-ip> 6379`
