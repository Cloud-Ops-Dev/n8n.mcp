# AWS EC2 On-Demand Instance

Terraform configuration to spin up an EC2 instance for Redis broker in the message queue demo.

## Purpose

Creates a t2.micro EC2 instance (free tier eligible) with:
- VPC with public subnet
- Security group allowing SSH (22) and Redis (6379)
- Docker pre-installed via cloud-init

## Usage

### 1. Configure Credentials

```bash
cp terraform.tfvars.template terraform.tfvars
# Edit terraform.tfvars with your AWS credentials
```

### 2. Initialize and Apply

```bash
terraform init
terraform plan
terraform apply
```

### 3. Connect via SSH

After apply, use the output:
```bash
ssh -i /home/clay/.ssh/R_Smurf_001.pem ubuntu@<public_ip>
```

### 4. Deploy Redis

```bash
docker run -d --name redis -p 6379:6379 redis:7-alpine
```

### 5. Tear Down

```bash
terraform destroy
```

## Outputs

| Output | Description |
|--------|-------------|
| `instance_id` | EC2 Instance ID |
| `public_ip` | Public IP address |
| `public_dns` | Public DNS hostname |
| `private_ip` | Private IP address |
| `vpc_id` | VPC ID |
| `ssh_command` | Ready-to-use SSH command |
| `redis_endpoint` | Redis connection string |

## Cost

- **t2.micro**: Free tier eligible (750 hrs/month for 12 months)
- **Remember**: Destroy when not in use to avoid charges

## Integration with n8n

This terraform is designed to be called from n8n workflows via Docker:
- `aws-ec2-spin-up-ondemand.json` - Provisions infrastructure
- `aws-ec2-tear-down-ondemand.json` - Destroys infrastructure
