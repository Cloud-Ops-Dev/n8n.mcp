# Packer Image Templates

Build custom cloud images for the multi-cloud + on-prem message queue demonstration.

## Overview

These Packer templates implement **Option C: Hybrid** approach:
- Docker and application code are baked into the image
- Dynamic configuration (Redis IP) is passed via cloud-init/user-data at boot
- Applications auto-start on boot

## Directory Structure

```
packer/
├── README.md                    # This file
├── aws-redis/                   # AWS AMI with Redis
│   ├── redis-ami.pkr.hcl        # Packer template
│   ├── variables.pkrvars.hcl.example
│   └── build.sh                 # Build script
└── ibm-producer/                # IBM custom image with Producer
    ├── producer-image.pkr.hcl   # Packer template
    ├── variables.pkrvars.hcl.example
    ├── build.sh                 # Build script
    └── files/
        ├── producer.py          # Producer application
        └── docker-compose.yml   # Compose configuration
```

## Prerequisites

1. **Install Packer**
   ```bash
   # Via package manager (Arch Linux)
   sudo pacman -S packer

   # Or download from https://www.packer.io/downloads
   ```

2. **Cloud Credentials**
   - AWS: Access Key + Secret Key
   - IBM Cloud: API Key + existing VPC/Subnet

## Building Images

### AWS Redis AMI

1. Configure credentials:
   ```bash
   cd packer/aws-redis
   cp variables.pkrvars.hcl.example variables.pkrvars.hcl
   # Edit variables.pkrvars.hcl with your AWS credentials
   ```

2. Build the AMI:
   ```bash
   ./build.sh
   ```

3. Note the AMI ID from output and update terraform:
   ```bash
   # Edit terraform/aws-ec2-ondemand/terraform.tfvars
   ami_id = "ami-xxxxxxxxxxxxxxxxx"
   ```

### IBM Cloud Producer Image

1. Configure credentials:
   ```bash
   cd packer/ibm-producer
   cp variables.pkrvars.hcl.example variables.pkrvars.hcl
   # Edit variables.pkrvars.hcl with your IBM Cloud credentials
   ```

2. Build the custom image:
   ```bash
   ./build.sh
   ```

3. Note the image ID from output and update terraform:
   ```bash
   # Edit terraform/ibm-vpc-from-image/terraform.tfvars
   custom_image_id = "r006-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```

## What Gets Baked In

### AWS Redis AMI
- Ubuntu 22.04 LTS base
- Docker installed and enabled
- Redis 7 Alpine image pre-pulled
- Management scripts: start-redis.sh, stop-redis.sh, status-redis.sh
- systemd service for auto-start on boot

### IBM Cloud Producer Image
- Ubuntu 22.04 Minimal base
- Docker and docker-compose installed
- Producer Docker image pre-built
- Management scripts: start-producer.sh, stop-producer.sh, status-producer.sh
- systemd service that waits for .env file (from cloud-init) before starting

## How Auto-Start Works

### AWS (Redis)
1. EC2 instance boots from AMI
2. systemd starts `mq-redis.service`
3. Redis container starts immediately (no external config needed)

### IBM (Producer)
1. VSI boots from custom image
2. cloud-init runs and creates `/opt/mq-producer/.env` with Redis IP
3. systemd service detects .env file appears
4. Producer container starts with Redis IP from .env

## Build Times

Approximate build times:
- AWS Redis AMI: ~5-7 minutes
- IBM Producer Image: ~8-10 minutes

## Cost Considerations

Building images incurs temporary cloud costs:
- AWS: t2.micro instance for ~5 minutes (free tier eligible)
- IBM: cx2-2x4 instance for ~10 minutes (~$0.015)

The resulting images are stored:
- AWS: AMI stored in your account (minimal EBS snapshot cost)
- IBM: Custom image stored in your account (minimal storage cost)

## Troubleshooting

### Packer Plugin Issues
```bash
# Re-initialize plugins
packer init -upgrade <template>.pkr.hcl
```

### Build Failures
Check the Packer output for SSH connection issues. Common problems:
- Security group doesn't allow SSH (port 22)
- VPC has no internet gateway
- Wrong SSH username

### Image Not Found After Build
- AWS: Check AMI is in the correct region
- IBM: Check image status in VPC > Custom Images

## Related Documentation

- [LAB_GUIDE.md](../docs/message-queue-lab/LAB_GUIDE.md) - Full demonstration guide
- [AWS_SETUP.md](../docs/message-queue-lab/AWS_SETUP.md) - AWS configuration
- [IBM_SETUP.md](../docs/message-queue-lab/IBM_SETUP.md) - IBM Cloud configuration
