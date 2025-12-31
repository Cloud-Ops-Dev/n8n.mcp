# Packer Template: IBM Cloud Custom Image with Producer
# Purpose: Build custom image with Docker + Producer app for message queue demo
# Option C: Hybrid - Apps baked in, Redis IP passed via user-data at boot

packer {
  required_plugins {
    ibmcloud = {
      version = ">= 3.0.0"
      source  = "github.com/IBM/ibmcloud"
    }
  }
}

variable "ibm_api_key" {
  type      = string
  sensitive = true
}

variable "ibm_region" {
  type    = string
  default = "us-south"
}

variable "image_name" {
  type    = string
  default = "n8n-lab-producer-image"
}

variable "subnet_id" {
  type        = string
  description = "Existing subnet ID for the build instance"
}

variable "resource_group_id" {
  type        = string
  description = "IBM Cloud resource group ID"
}

source "ibmcloud-vpc" "producer" {
  api_key = var.ibm_api_key
  region  = var.ibm_region

  subnet_id         = var.subnet_id
  resource_group_id = var.resource_group_id

  vsi_base_image_name = "ibm-ubuntu-22-04-4-minimal-amd64-1"
  vsi_profile         = "cx2-2x4"
  vsi_interface       = "public"
  vsi_user_data_file  = ""

  image_name = "${var.image_name}-{{timestamp}}"

  communicator = "ssh"
  ssh_username = "root"
  ssh_timeout  = "15m"

  tags = ["n8n-lab", "packer", "message-queue-demo"]
}

build {
  name    = "producer-image"
  sources = ["source.ibmcloud-vpc.producer"]

  # Install Docker
  provisioner "shell" {
    inline = [
      "echo '=== Installing Docker ==='",
      "apt-get update",
      "apt-get install -y docker.io docker-compose",
      "systemctl enable docker",
      "systemctl start docker",
    ]
  }

  # Create producer application directory
  provisioner "shell" {
    inline = [
      "echo '=== Setting up Producer application ==='",
      "mkdir -p /opt/mq-producer",
    ]
  }

  # Upload producer Python script
  provisioner "file" {
    source      = "files/producer.py"
    destination = "/opt/mq-producer/producer.py"
  }

  # Upload docker-compose file
  provisioner "file" {
    source      = "files/docker-compose.yml"
    destination = "/opt/mq-producer/docker-compose.yml"
  }

  # Pre-pull and build producer image
  provisioner "shell" {
    inline = [
      "echo '=== Building producer Docker image ==='",
      "cd /opt/mq-producer",

      # Create Dockerfile inline
      "cat > Dockerfile << 'EOF'\nFROM python:3.11-slim\nWORKDIR /app\nRUN pip install redis\nCOPY producer.py .\nCMD [\"python\", \"-u\", \"producer.py\"]\nEOF",

      # Build the image
      "docker build -t mq-producer:latest .",
    ]
  }

  # Create management scripts
  provisioner "shell" {
    inline = [
      "echo '=== Creating management scripts ==='",

      # Start script (reads from .env file)
      "cat > /usr/local/bin/start-producer.sh << 'EOF'\n#!/bin/bash\nif [ ! -f /opt/mq-producer/.env ]; then\n  echo \"Error: /opt/mq-producer/.env not found\"\n  echo \"Create .env with REDIS_HOST, REDIS_PORT, QUEUE_NAME, MESSAGE_INTERVAL\"\n  exit 1\nfi\ncd /opt/mq-producer\ndocker-compose up -d\necho \"Producer started\"\nEOF",
      "chmod +x /usr/local/bin/start-producer.sh",

      # Stop script
      "cat > /usr/local/bin/stop-producer.sh << 'EOF'\n#!/bin/bash\ncd /opt/mq-producer\ndocker-compose down\necho \"Producer stopped\"\nEOF",
      "chmod +x /usr/local/bin/stop-producer.sh",

      # Status script
      "cat > /usr/local/bin/status-producer.sh << 'EOF'\n#!/bin/bash\nif docker ps --filter name=mq-producer --format '{{.Status}}' | grep -q Up; then\n  echo \"HEALTHY\"\nelse\n  echo \"NOT_RUNNING\"\nfi\nEOF",
      "chmod +x /usr/local/bin/status-producer.sh",
    ]
  }

  # Create systemd service for auto-start (waits for .env from cloud-init)
  provisioner "shell" {
    inline = [
      "echo '=== Creating systemd service ==='",

      "cat > /etc/systemd/system/mq-producer.service << 'EOF'\n[Unit]\nDescription=Message Queue Producer\nAfter=docker.service cloud-final.service\nRequires=docker.service\n\n[Service]\nType=oneshot\nRemainAfterExit=yes\nExecStartPre=/bin/bash -c 'while [ ! -f /opt/mq-producer/.env ]; do sleep 1; done'\nExecStart=/usr/local/bin/start-producer.sh\nExecStop=/usr/local/bin/stop-producer.sh\n\n[Install]\nWantedBy=multi-user.target\nEOF",

      "systemctl daemon-reload",
      "systemctl enable mq-producer.service",
    ]
  }

  # Create README
  provisioner "shell" {
    inline = [
      "echo '=== Creating README ==='",

      "cat > /root/README.md << 'EOF'\n# IBM VSI Producer (Pre-built Image)\n\nThis instance is part of the n8n Message Queue Demo.\nBuilt with Packer - Option C: Hybrid approach.\n\n## How It Works\n1. On boot, cloud-init/user-data creates /opt/mq-producer/.env\n2. systemd waits for .env to appear\n3. Producer starts automatically with Redis config from .env\n\n## Environment File (/opt/mq-producer/.env)\nREDIS_HOST=<aws-ec2-ip>\nREDIS_PORT=6379\nQUEUE_NAME=demo-queue\nMESSAGE_INTERVAL=5\n\n## Quick Commands\n\nStart Producer:\n  /usr/local/bin/start-producer.sh\n\nStop Producer:\n  /usr/local/bin/stop-producer.sh\n\nCheck Status:\n  /usr/local/bin/status-producer.sh\n\nView Logs:\n  docker logs -f mq-producer\n\n## Created by n8n automation\nEOF",
    ]
  }
}
