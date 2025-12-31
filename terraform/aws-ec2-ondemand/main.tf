# AWS EC2 On-Demand Instance
# Purpose: Spin up EC2 for message queue demo (Redis broker)

# VPC
resource "aws_vpc" "ondemand_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "n8n-lab-vpc"
    ManagedBy = "n8n"
    Project   = "message-queue-demo"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "ondemand_igw" {
  vpc_id = aws_vpc.ondemand_vpc.id

  tags = {
    Name      = "n8n-lab-igw"
    ManagedBy = "n8n"
  }
}

# Subnet
resource "aws_subnet" "ondemand_subnet" {
  vpc_id                  = aws_vpc.ondemand_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name      = "n8n-lab-subnet"
    ManagedBy = "n8n"
  }
}

# Route Table
resource "aws_route_table" "ondemand_rt" {
  vpc_id = aws_vpc.ondemand_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ondemand_igw.id
  }

  tags = {
    Name      = "n8n-lab-rt"
    ManagedBy = "n8n"
  }
}

# Route Table Association
resource "aws_route_table_association" "ondemand_rta" {
  subnet_id      = aws_subnet.ondemand_subnet.id
  route_table_id = aws_route_table.ondemand_rt.id
}

# Security Group
resource "aws_security_group" "ondemand_sg" {
  name        = "n8n-lab-sg"
  description = "Security group for n8n lab - Redis and SSH"
  vpc_id      = aws_vpc.ondemand_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Redis port (6379)
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Redis access"
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name      = "n8n-lab-sg"
    ManagedBy = "n8n"
  }
}

# EC2 Instance
resource "aws_instance" "ondemand_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  subnet_id              = aws_subnet.ondemand_subnet.id
  vpc_security_group_ids = [aws_security_group.ondemand_sg.id]

  # Install Docker and prepare Redis via user_data (cloud-init)
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Log to file for debugging
              exec > /var/log/cloud-init-mq.log 2>&1

              echo "=== Starting cloud-init for Message Queue Demo ==="

              # Install Docker
              apt-get update
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu

              # Pre-pull Redis image (saves time on first start)
              docker pull redis:7-alpine

              # Create startup script for Redis
              cat > /usr/local/bin/start-redis.sh << 'SCRIPT'
              #!/bin/bash
              docker rm -f mq-redis 2>/dev/null || true
              docker run -d \
                --name mq-redis \
                --restart unless-stopped \
                -p 6379:6379 \
                redis:7-alpine \
                redis-server --appendonly yes
              echo "Redis started on port 6379"
              SCRIPT
              chmod +x /usr/local/bin/start-redis.sh

              # Create stop script
              cat > /usr/local/bin/stop-redis.sh << 'SCRIPT'
              #!/bin/bash
              docker stop mq-redis && docker rm mq-redis
              echo "Redis stopped"
              SCRIPT
              chmod +x /usr/local/bin/stop-redis.sh

              # Create status script
              cat > /usr/local/bin/status-redis.sh << 'SCRIPT'
              #!/bin/bash
              if docker exec mq-redis redis-cli ping 2>/dev/null | grep -q PONG; then
                echo "HEALTHY"
              else
                echo "NOT_RUNNING"
              fi
              SCRIPT
              chmod +x /usr/local/bin/status-redis.sh

              # Create README
              cat > /home/ubuntu/README.md << 'README'
              # AWS EC2 Redis Broker

              This instance is part of the n8n Message Queue Demo.

              ## Quick Commands

              Start Redis:
                /usr/local/bin/start-redis.sh

              Stop Redis:
                /usr/local/bin/stop-redis.sh

              Check Status:
                /usr/local/bin/status-redis.sh

              View Logs:
                docker logs -f mq-redis

              ## Redis Connection
              - Host: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
              - Port: 6379

              ## Created by n8n automation
              README
              chown ubuntu:ubuntu /home/ubuntu/README.md

              # Auto-start Redis on boot (Option C: Hybrid approach)
              /usr/local/bin/start-redis.sh

              echo "=== Cloud-init complete - Redis is running ==="
              EOF

  tags = {
    Name      = var.instance_name
    ManagedBy = "n8n"
    Project   = "message-queue-demo"
  }
}

# Outputs
output "instance_id" {
  value       = aws_instance.ondemand_ec2.id
  description = "EC2 Instance ID"
}

output "public_ip" {
  value       = aws_instance.ondemand_ec2.public_ip
  description = "Public IP address"
}

output "public_dns" {
  value       = aws_instance.ondemand_ec2.public_dns
  description = "Public DNS hostname"
}

output "private_ip" {
  value       = aws_instance.ondemand_ec2.private_ip
  description = "Private IP address"
}

output "vpc_id" {
  value       = aws_vpc.ondemand_vpc.id
  description = "VPC ID"
}

output "ssh_command" {
  value       = "ssh -i ${var.ssh_key_path} ubuntu@${aws_instance.ondemand_ec2.public_ip}"
  description = "SSH command to connect"
}

output "redis_endpoint" {
  value       = "${aws_instance.ondemand_ec2.public_ip}:6379"
  description = "Redis endpoint for producers/consumers"
}
