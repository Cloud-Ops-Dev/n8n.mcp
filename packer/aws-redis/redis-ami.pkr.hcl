# Packer Template: AWS AMI with Redis
# Purpose: Build AMI with Docker + Redis pre-installed for message queue demo
# Option C: Hybrid - Apps baked in, auto-start on boot

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

variable "ami_name" {
  type    = string
  default = "n8n-lab-redis-ami"
}

source "amazon-ebs" "redis" {
  access_key    = var.aws_access_key
  secret_key    = var.aws_secret_key
  region        = var.aws_region

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }

  instance_type = "t2.micro"
  ssh_username  = "ubuntu"
  ami_name      = "${var.ami_name}-{{timestamp}}"

  tags = {
    Name      = var.ami_name
    ManagedBy = "packer"
    Project   = "message-queue-demo"
    Purpose   = "Redis broker for n8n lab"
  }
}

build {
  name    = "redis-ami"
  sources = ["source.amazon-ebs.redis"]

  # Install Docker
  provisioner "shell" {
    inline = [
      "echo '=== Installing Docker ==='",
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker ubuntu",

      "echo '=== Pre-pulling Redis image ==='",
      "sudo docker pull redis:7-alpine",
    ]
  }

  # Create management scripts
  provisioner "shell" {
    inline = [
      "echo '=== Creating Redis management scripts ==='",

      # Start script
      "sudo tee /usr/local/bin/start-redis.sh << 'EOF'\n#!/bin/bash\ndocker rm -f mq-redis 2>/dev/null || true\ndocker run -d \\\n  --name mq-redis \\\n  --restart unless-stopped \\\n  -p 6379:6379 \\\n  redis:7-alpine \\\n  redis-server --appendonly yes\necho \"Redis started on port 6379\"\nEOF",
      "sudo chmod +x /usr/local/bin/start-redis.sh",

      # Stop script
      "sudo tee /usr/local/bin/stop-redis.sh << 'EOF'\n#!/bin/bash\ndocker stop mq-redis && docker rm mq-redis\necho \"Redis stopped\"\nEOF",
      "sudo chmod +x /usr/local/bin/stop-redis.sh",

      # Status script
      "sudo tee /usr/local/bin/status-redis.sh << 'EOF'\n#!/bin/bash\nif docker exec mq-redis redis-cli ping 2>/dev/null | grep -q PONG; then\n  echo \"HEALTHY\"\nelse\n  echo \"NOT_RUNNING\"\nfi\nEOF",
      "sudo chmod +x /usr/local/bin/status-redis.sh",
    ]
  }

  # Create systemd service for auto-start
  provisioner "shell" {
    inline = [
      "echo '=== Creating systemd service for auto-start ==='",

      "sudo tee /etc/systemd/system/mq-redis.service << 'EOF'\n[Unit]\nDescription=Message Queue Redis Broker\nAfter=docker.service\nRequires=docker.service\n\n[Service]\nType=oneshot\nRemainAfterExit=yes\nExecStart=/usr/local/bin/start-redis.sh\nExecStop=/usr/local/bin/stop-redis.sh\n\n[Install]\nWantedBy=multi-user.target\nEOF",

      "sudo systemctl daemon-reload",
      "sudo systemctl enable mq-redis.service",
    ]
  }

  # Create README
  provisioner "shell" {
    inline = [
      "echo '=== Creating README ==='",

      "cat > /home/ubuntu/README.md << 'EOF'\n# AWS EC2 Redis Broker (Pre-built AMI)\n\nThis instance is part of the n8n Message Queue Demo.\nBuilt with Packer - Option C: Hybrid approach.\n\n## Auto-Start\nRedis starts automatically on boot via systemd.\n\n## Quick Commands\n\nStart Redis:\n  /usr/local/bin/start-redis.sh\n\nStop Redis:\n  /usr/local/bin/stop-redis.sh\n\nCheck Status:\n  /usr/local/bin/status-redis.sh\n\nView Logs:\n  docker logs -f mq-redis\n\n## Redis Connection\n- Port: 6379\n- No authentication (demo only)\n\n## Created by n8n automation\nEOF",
    ]
  }
}
