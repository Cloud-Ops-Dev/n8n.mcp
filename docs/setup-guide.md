# Complete Setup Guide

This guide will walk you through setting up the entire n8n + MCP multi-cloud server management lab.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Configure Cloud Providers](#configure-cloud-providers)
4. [Configure MCP Integration](#configure-mcp-integration)
5. [Import Workflows](#import-workflows)
6. [Testing](#testing)
7. [Next Steps](#next-steps)

---

## Prerequisites

### Required Software

#### On Your Laptop (Control Plane)
- **OS**: Linux (you have Arch Linux 6.17.7)
- **Docker**: Version 20.10 or later
- **Docker Compose**: Version 2.0 or later
- **Claude Code CLI**: Latest version
- **Git**: For version control
- **SSH Client**: OpenSSH

#### Verify installations:
```bash
docker --version
docker-compose --version
claude --version
git --version
ssh -V
```

### Required Accounts
- ✅ IBM Cloud account with API key
- ✅ AWS account with access credentials
- ✅ SSH access to AMD workstation

### System Resources
- **Laptop**: I7 CPU, 32GB RAM ✅
- **Disk Space**: At least 20GB free on Docker partition
- **Network**: Reliable internet connection

---

## Initial Setup

### Step 1: Clone the Repository

```bash
# Navigate to your projects directory
cd /home/clay/Documents/GitHub

# Clone the repository (replace with your GitHub URL after creating it)
git clone https://github.com/YOUR_USERNAME/n8n.mcp.git
cd n8n.mcp
```

### Step 2: Run Setup Script

```bash
# Make scripts executable (should already be done)
chmod +x scripts/*.sh

# Run the main setup script
./scripts/setup.sh
```

This script will:
- ✅ Check all prerequisites
- ✅ Create `docker/.env` from template
- ✅ Pull Docker images
- ✅ Start n8n and PostgreSQL
- ✅ Wait for services to be ready

**Expected Output**:
```
================================
n8n + MCP Lab Setup
================================

Checking prerequisites...
✓ Docker installed
✓ Docker Compose installed
✓ Claude Code CLI installed

Setting up environment configuration...
✓ Created docker/.env from template
⚠  Please edit docker/.env with your actual credentials
...
```

### Step 3: Configure Environment Variables

```bash
# Edit the environment file
nano docker/.env
```

**Critical Settings to Change**:

```bash
# Change default passwords!
POSTGRES_PASSWORD=your_secure_password_here
N8N_BASIC_AUTH_PASSWORD=your_n8n_password_here

# Set your timezone
TZ=America/New_York  # or your local timezone

# We'll add cloud credentials later
```

Save and exit (Ctrl+X, Y, Enter)

### Step 4: Restart Services with New Config

```bash
cd docker
docker-compose down
docker-compose up -d
cd ..
```

### Step 5: Access n8n UI

1. Open browser: http://localhost:5678
2. Login with:
   - Username: `admin`
   - Password: (what you set in `.env`)

3. **Initial n8n Setup**:
   - Set up your profile
   - Skip cloud connection (optional)
   - Explore the interface

---

## Configure Cloud Providers

### AWS Configuration

#### Step 1: Create IAM User
1. Login to AWS Console
2. Navigate to IAM → Users → Add User
3. User name: `n8n-automation`
4. Access type: ✅ Programmatic access
5. Permissions: Attach policies
   - `AmazonEC2FullAccess`
   - `AmazonS3FullAccess`
6. **Save credentials**: Access Key ID and Secret Access Key

#### Step 2: Add to Environment
```bash
nano docker/.env
```

Add:
```bash
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=us-east-1
```

#### Step 3: Configure in n8n
1. Open n8n UI → Credentials
2. Click "+ Add Credential"
3. Search for "AWS"
4. Enter:
   - Access Key ID: (from IAM)
   - Secret Access Key: (from IAM)
   - Region: us-east-1
5. Test connection
6. Save as "AWS Account"

---

### IBM Cloud Configuration

#### Step 1: Generate API Key
1. Login to IBM Cloud Console
2. Navigate to Manage → Access (IAM) → API Keys
3. Click "Create an IBM Cloud API key"
4. Name: `n8n-automation`
5. **Save the API key** (only shown once!)

#### Step 2: Add to Environment
```bash
nano docker/.env
```

Add:
```bash
IBM_CLOUD_API_KEY=your_ibm_api_key_here
IBM_CLOUD_REGION=us-south
```

#### Step 3: Configure in n8n
1. n8n UI → Credentials → "+ Add Credential"
2. Search for "HTTP Header Auth" (IBM uses REST API)
3. Name: `Authorization`
4. Value: `Bearer YOUR_IBM_API_KEY`
5. Save as "IBM Cloud API"

---

### SSH Key Setup

#### Step 1: Generate SSH Keys (if needed)
```bash
# For AMD Workstation
ssh-keygen -t ed25519 -C "n8n-amd" -f ~/.ssh/n8n-amd

# For IBM Cloud
ssh-keygen -t ed25519 -C "n8n-ibm" -f ~/.ssh/n8n-ibm

# For AWS EC2
ssh-keygen -t ed25519 -C "n8n-aws" -f ~/.ssh/n8n-aws
```

#### Step 2: Copy Public Keys to Servers

**AMD Workstation**:
```bash
ssh-copy-id -i ~/.ssh/n8n-amd.pub your_user@192.168.x.x
```

**IBM Cloud**:
```bash
# Add via IBM Cloud console or:
ssh-copy-id -i ~/.ssh/n8n-ibm.pub root@ibm_server_ip
```

**AWS EC2**:
```bash
# Upload to AWS:
aws ec2 import-key-pair --key-name n8n-key \
  --public-key-material fileb://~/.ssh/n8n-aws.pub
```

#### Step 3: Update Environment
```bash
nano docker/.env
```

Add:
```bash
# AMD Workstation
AMD_HOST=192.168.1.100
AMD_SSH_PORT=22
AMD_SSH_USER=your_username
AMD_SSH_KEY_PATH=/home/clay/.ssh/n8n-amd

# IBM Cloud Server
IBM_SERVER_IP=your.ibm.ip.address
IBM_SSH_USER=root
IBM_SSH_KEY_PATH=/home/clay/.ssh/n8n-ibm

# AWS EC2 Instance
AWS_SERVER_IP=your.aws.ip.address
AWS_SSH_USER=ec2-user
AWS_SSH_KEY_PATH=/home/clay/.ssh/n8n-aws
```

---

## Configure MCP Integration

### Step 1: Generate n8n API Key

1. Open n8n UI: http://localhost:5678
2. Navigate to: Settings → API
3. Click "Create an API Key"
4. Copy the generated key

### Step 2: Add API Key to Environment

```bash
nano docker/.env
```

Update:
```bash
N8N_API_KEY=n8n_api_XXXXXXXXXXXXXXXXXXXXX
```

### Step 3: Configure MCP Server

```bash
./scripts/configure-mcp.sh
```

This will:
- ✅ Check n8n is running
- ✅ Create/update `.mcp.json`
- ✅ Configure n8n-MCP with API key

### Step 4: Verify MCP Configuration

Check the `.mcp.json` file:
```bash
cat .mcp.json
```

Should look like:
```json
{
  "mcpServers": {
    "n8n-mcp": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "n8n-mcp"],
      "env": {
        "MCP_MODE": "stdio",
        "LOG_LEVEL": "error",
        "DISABLE_CONSOLE_OUTPUT": "true",
        "N8N_API_URL": "http://localhost:5678",
        "N8N_API_KEY": "your_actual_key"
      }
    }
  }
}
```

### Step 5: Test MCP Integration

**Important**: You may need to restart Claude Code for MCP changes to take effect.

After restart, try:
```
Ask Claude: "What n8n nodes are available for SSH operations?"
```

---

## Import Workflows

### Method 1: Via n8n UI (Recommended for First Time)

1. Open n8n: http://localhost:5678
2. Click Workflows → "Import from File"
3. Navigate to `workflows/templates/`
4. Import `server-health-check.json`
5. Update credentials in the workflow
6. Test manually
7. Activate the workflow

### Method 2: Via File Copy

```bash
# Copy workflow templates to n8n
docker cp workflows/templates/server-health-check.json n8n:/tmp/
docker exec n8n n8n import:workflow --input=/tmp/server-health-check.json
```

### Method 3: Using Claude + MCP

```
Ask Claude: "Import the server health check workflow and configure it for my three servers"
```

---

## Testing

### Test 1: n8n UI Access
```bash
curl http://localhost:5678/healthz
# Expected: OK
```

### Test 2: Database Connection
```bash
docker exec -it n8n-postgres psql -U n8n -c "SELECT 1;"
# Expected: 1
```

### Test 3: SSH Connectivity

**AMD Workstation**:
```bash
ssh -i ~/.ssh/n8n-amd your_user@192.168.x.x "uptime"
```

**IBM Cloud**:
```bash
ssh -i ~/.ssh/n8n-ibm root@ibm_server_ip "uptime"
```

**AWS EC2** (if provisioned):
```bash
ssh -i ~/.ssh/n8n-aws ec2-user@aws_ip "uptime"
```

### Test 4: n8n API
```bash
curl -H "X-N8N-API-KEY: your_api_key" \
  http://localhost:5678/api/v1/workflows
# Expected: JSON array of workflows
```

### Test 5: Execute Test Workflow
1. In n8n UI, create simple workflow:
   - Manual Trigger → Function (return "Hello World")
2. Click "Execute Workflow"
3. Verify output in right panel

### Test 6: MCP Integration
```bash
# In Claude Code
"List available n8n workflow templates"
```

---

## Next Steps

### Phase 1: Basic Operations ✅
- [x] n8n and PostgreSQL running
- [x] MCP integration configured
- [ ] Test workflows imported
- [ ] SSH connectivity verified

### Phase 2: Cloud Integration
- [ ] Provision AWS EC2 instance
- [ ] Configure IBM Cloud server
- [ ] Deploy test application
- [ ] Set up monitoring workflows

### Phase 3: Advanced Automation
- [ ] Automated backup workflows
- [ ] Cost monitoring dashboards
- [ ] Security scanning automation
- [ ] Log aggregation pipeline

---

## Troubleshooting

### n8n won't start
```bash
# Check logs
docker logs n8n

# Common issues:
# - Database not ready: Wait and restart
docker-compose -f docker/docker-compose.yml restart n8n
```

### Can't access n8n UI
```bash
# Check if port is listening
netstat -tulpn | grep 5678

# Check Docker network
docker network ls
docker network inspect docker_n8n-network
```

### MCP not connecting
```bash
# Verify .mcp.json exists
cat .mcp.json

# Check n8n API key is correct
echo $N8N_API_KEY

# Restart Claude Code session
```

### SSH connection refused
```bash
# Test manually first
ssh -i /path/to/key user@host

# Check firewall on target
sudo ufw status

# Verify key permissions
chmod 600 ~/.ssh/n8n-*
```

### Database connection error
```bash
# Check PostgreSQL is running
docker ps | grep postgres

# Test connection
docker exec -it n8n-postgres psql -U n8n

# Reset database (CAUTION: destroys data)
docker-compose -f docker/docker-compose.yml down -v
docker-compose -f docker/docker-compose.yml up -d
```

---

## Security Checklist

- [ ] Changed default n8n password
- [ ] Generated unique PostgreSQL password
- [ ] n8n API key created and secured
- [ ] SSH keys generated (not reusing old keys)
- [ ] AWS IAM user with minimal permissions
- [ ] IBM Cloud API key with minimal scope
- [ ] `.env` file in `.gitignore`
- [ ] Firewall rules configured on all servers
- [ ] Regular backup schedule established

---

## Support Resources

- **n8n Documentation**: https://docs.n8n.io
- **n8n Community**: https://community.n8n.io
- **MCP Documentation**: https://modelcontextprotocol.io
- **Claude Code Docs**: https://code.claude.com/docs
- **Project Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/n8n.mcp/issues)

---

## What You Should Have Now

✅ n8n running on http://localhost:5678
✅ PostgreSQL database for persistence
✅ MCP integration for AI-assisted workflows
✅ Cloud provider credentials configured
✅ SSH access to all target servers
✅ Workflow templates ready to use
✅ Monitoring and alerting capability

**You're ready to start building!** 🚀
