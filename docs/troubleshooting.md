# Troubleshooting Guide

Common issues and their solutions for the n8n + MCP lab environment.

## Table of Contents
1. [Docker Issues](#docker-issues)
2. [n8n Problems](#n8n-problems)
3. [Database Issues](#database-issues)
4. [MCP Integration](#mcp-integration)
5. [SSH Connectivity](#ssh-connectivity)
6. [Cloud Provider Issues](#cloud-provider-issues)
7. [Workflow Execution](#workflow-execution)
8. [Performance Problems](#performance-problems)

---

## Docker Issues

### Docker daemon not running

**Symptoms**:
```
Cannot connect to the Docker daemon
```

**Solution**:
```bash
# Check Docker status
sudo systemctl status docker

# Start Docker
sudo systemctl start docker

# Enable on boot
sudo systemctl enable docker

# Verify
docker ps
```

---

### Port already in use

**Symptoms**:
```
Error: bind: address already in use
```

**Solution**:
```bash
# Find what's using port 5678
sudo netstat -tulpn | grep 5678
# or
sudo lsof -i :5678

# Kill the process
sudo kill <PID>

# Or change port in docker-compose.yml
ports:
  - "5679:5678"  # Use different external port
```

---

### Docker Compose version issues

**Symptoms**:
```
version is obsolete
```

**Solution**:
```bash
# Update docker-compose.yml
version: '3.8'  # Change to compatible version

# Or update Docker Compose
sudo apt update
sudo apt install docker-compose-plugin
```

---

### Permission denied

**Symptoms**:
```
permission denied while trying to connect to the Docker daemon socket
```

**Solution**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or:
newgrp docker

# Verify
docker ps
```

---

## n8n Problems

### n8n not starting

**Symptoms**:
Container exits immediately

**Diagnosis**:
```bash
# Check logs
docker logs n8n

# Common issues:
# - Database connection failed
# - Environment variable missing
# - Volume permission issue
```

**Solutions**:

**Database not ready**:
```bash
# Wait for database
cd docker
docker-compose restart n8n
```

**Environment variable issue**:
```bash
# Check .env file
cat docker/.env

# Ensure required variables are set
docker-compose config
```

**Volume permissions**:
```bash
# Check volume
docker volume inspect docker_n8n-data

# If needed, recreate
docker-compose down -v
docker-compose up -d
```

---

### Can't access n8n UI

**Symptoms**:
Browser can't reach http://localhost:5678

**Diagnosis**:
```bash
# Check if n8n is running
docker ps | grep n8n

# Check if port is listening
netstat -tulpn | grep 5678

# Check from inside container
docker exec n8n wget -O- http://localhost:5678/healthz
```

**Solutions**:

**Container not running**:
```bash
docker-compose -f docker/docker-compose.yml up -d n8n
```

**Firewall blocking**:
```bash
# Check firewall
sudo ufw status

# Allow port
sudo ufw allow 5678/tcp
```

**Wrong host configuration**:
```bash
# In docker/.env
N8N_HOST=0.0.0.0  # Listen on all interfaces
```

---

### Login credentials not working

**Symptoms**:
Can't login with configured credentials

**Solution**:
```bash
# Check environment variables
docker exec n8n printenv | grep N8N_BASIC_AUTH

# Reset password
# Edit docker/.env
N8N_BASIC_AUTH_PASSWORD=newpassword

# Restart
cd docker
docker-compose restart n8n
```

---

### Workflows not saving

**Symptoms**:
Changes disappear after reload

**Diagnosis**:
```bash
# Check database connection
docker logs n8n | grep -i database

# Check PostgreSQL
docker logs n8n-postgres
```

**Solution**:
```bash
# Restart with fresh connection
cd docker
docker-compose restart n8n postgres
```

---

## Database Issues

### PostgreSQL won't start

**Symptoms**:
```
database system was shut down in recovery mode
```

**Diagnosis**:
```bash
# Check logs
docker logs n8n-postgres

# Check disk space
df -h
```

**Solution**:
```bash
# If corrupted, reset (WARNING: destroys data)
cd docker
docker-compose down
docker volume rm docker_postgres-data
docker-compose up -d
```

---

### Connection refused

**Symptoms**:
```
could not connect to server: Connection refused
```

**Diagnosis**:
```bash
# Check if container is running
docker ps | grep postgres

# Check network
docker network inspect docker_n8n-network
```

**Solution**:
```bash
# Ensure containers on same network
cd docker
docker-compose down
docker-compose up -d

# Verify connection
docker exec n8n-postgres psql -U n8n -c "SELECT 1;"
```

---

### Database credentials incorrect

**Symptoms**:
```
FATAL: password authentication failed
```

**Solution**:
```bash
# Check .env file
cat docker/.env | grep POSTGRES

# Ensure n8n uses same credentials
# In .env:
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=same_as_POSTGRES_PASSWORD

# Restart
cd docker
docker-compose restart
```

---

## MCP Integration

### MCP server not found

**Symptoms**:
Claude can't access n8n tools

**Diagnosis**:
```bash
# Check .mcp.json exists
cat .mcp.json

# List MCP servers
claude mcp list
```

**Solution**:
```bash
# Reconfigure MCP
./scripts/configure-mcp.sh

# Verify configuration
cat .mcp.json

# Restart Claude Code session
```

---

### n8n API connection failed

**Symptoms**:
MCP can't connect to n8n API

**Diagnosis**:
```bash
# Check n8n is running
curl http://localhost:5678/healthz

# Check API key
echo $N8N_API_KEY

# Test API manually
curl -H "X-N8N-API-KEY: your_key" \
  http://localhost:5678/api/v1/workflows
```

**Solution**:

**Missing API key**:
```bash
# Generate in n8n UI: Settings → API
# Add to .env
nano docker/.env
N8N_API_KEY=n8n_api_xxxxxxxxxxxxx

# Update .mcp.json
./scripts/configure-mcp.sh
```

**Wrong URL**:
```bash
# Check in .mcp.json
cat .mcp.json | grep N8N_API_URL

# Should be: http://localhost:5678
# NOT: https:// or different port
```

---

### MCP_MODE not set

**Symptoms**:
```
JSON parsing errors in Claude Desktop
```

**Solution**:
```bash
# Check .mcp.json
cat .mcp.json

# Should have:
"env": {
  "MCP_MODE": "stdio",
  ...
}

# If missing, reconfigure
claude mcp remove n8n-mcp
./scripts/configure-mcp.sh
```

---

## SSH Connectivity

### Permission denied (publickey)

**Symptoms**:
```
Permission denied (publickey)
```

**Diagnosis**:
```bash
# Test SSH manually
ssh -v -i /path/to/key user@host

# Check key permissions
ls -la ~/.ssh/n8n-*
```

**Solution**:
```bash
# Fix key permissions
chmod 600 ~/.ssh/n8n-*
chmod 700 ~/.ssh

# Ensure public key on server
ssh-copy-id -i ~/.ssh/n8n-amd.pub user@host

# Test again
ssh -i ~/.ssh/n8n-amd user@host
```

---

### Connection timeout

**Symptoms**:
SSH hangs, then times out

**Diagnosis**:
```bash
# Check server is reachable
ping host_ip

# Check SSH port
nmap -p 22 host_ip

# Check from different network
```

**Solution**:

**Firewall blocking**:
```bash
# On remote server
sudo ufw allow 22/tcp
sudo ufw enable
```

**SSH not running**:
```bash
# On remote server
sudo systemctl status ssh
sudo systemctl start ssh
```

**Wrong IP/port**:
```bash
# Check .env
cat docker/.env | grep HOST
cat docker/.env | grep PORT

# Verify correct values
```

---

### Host key verification failed

**Symptoms**:
```
Host key verification failed
```

**Solution**:
```bash
# Remove old key
ssh-keygen -R host_ip

# Or edit known_hosts
nano ~/.ssh/known_hosts
# Delete the line with the host

# Reconnect (will ask to verify new key)
ssh user@host
```

---

## Cloud Provider Issues

### AWS authentication failed

**Symptoms**:
```
InvalidClientTokenId: The security token included in the request is invalid
```

**Solution**:
```bash
# Verify credentials
aws configure list

# Check in n8n
# Credentials → AWS → Test

# Regenerate if needed
aws iam create-access-key --user-name n8n-automation

# Update in .env and n8n
```

---

### AWS region mismatch

**Symptoms**:
Can't find resources that exist

**Solution**:
```bash
# Check region in .env
cat docker/.env | grep AWS_DEFAULT_REGION

# Verify in n8n workflow
# AWS node → Region parameter

# List resources in region
aws ec2 describe-instances --region us-east-1
```

---

### IBM Cloud API error

**Symptoms**:
```
401 Unauthorized
```

**Solution**:
```bash
# Test API key
curl -X GET \
  https://cloud.ibm.com/v1/users \
  -H "Authorization: Bearer $IBM_CLOUD_API_KEY"

# Regenerate key if needed
# IBM Cloud Console → Access (IAM) → API Keys
```

---

### EC2 instance won't start

**Symptoms**:
Instance state stuck in "pending"

**Diagnosis**:
```bash
# Check instance status
aws ec2 describe-instances --instance-ids i-xxxxx

# Check limits
aws ec2 describe-account-attributes \
  --attribute-names max-instances
```

**Solution**:

**Limit reached**:
```bash
# Terminate old instances
aws ec2 terminate-instances --instance-ids i-oldinstance

# Or request limit increase
```

**Insufficient resources**:
```bash
# Try different availability zone
# Or different instance type
```

---

## Workflow Execution

### Workflow fails silently

**Symptoms**:
No output, no errors

**Diagnosis**:
```bash
# Check execution in n8n UI
# Executions panel

# Look for:
# - Was it triggered?
# - Which node failed?
# - Error message?
```

**Solution**:

**Trigger not firing**:
```bash
# For schedule triggers, check cron syntax
# For webhooks, test with curl
curl -X POST http://localhost:5678/webhook/test
```

**Node error hidden**:
```bash
# Add "On Error" workflow
# Settings → Error Workflow
```

---

### Timeout errors

**Symptoms**:
```
Execution timed out
```

**Solution**:
```bash
# Increase timeout in .env
EXECUTIONS_TIMEOUT=600  # 10 minutes
EXECUTIONS_TIMEOUT_MAX=3600  # 1 hour

# Restart n8n
cd docker
docker-compose restart n8n
```

---

### Data mapping errors

**Symptoms**:
```
Cannot read property 'json' of undefined
```

**Solution**:
```bash
# In n8n workflow:
# 1. Check previous node has output
# 2. Verify expression syntax: {{$json.fieldName}}
# 3. Use the "Expression Editor" for complex expressions

# Debug with Function node:
return items.map(item => {
  console.log(JSON.stringify(item, null, 2));
  return item;
});
```

---

## Performance Problems

### Slow workflow execution

**Symptoms**:
Workflows take unusually long

**Diagnosis**:
```bash
# Check resource usage
docker stats n8n

# Check execution time in n8n UI
```

**Solutions**:

**Increase container resources**:
```yaml
# In docker-compose.yml
services:
  n8n:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
```

**Optimize workflow**:
```
- Use "Split In Batches" for large datasets
- Disable unnecessary executions logging
- Use function nodes for complex logic (faster than multiple nodes)
```

---

### High memory usage

**Symptoms**:
Container using > 1GB RAM

**Diagnosis**:
```bash
docker stats n8n

# Check execution history size
docker exec n8n-postgres psql -U n8n -c \
  "SELECT COUNT(*) FROM execution_entity;"
```

**Solution**:
```bash
# Clear old executions
# n8n UI → Settings → Executions
# Save data of executions: Delete after 7 days

# Or manually
docker exec n8n-postgres psql -U n8n -c \
  "DELETE FROM execution_entity WHERE \"stoppedAt\" < NOW() - INTERVAL '7 days';"
```

---

### Disk space full

**Symptoms**:
```
no space left on device
```

**Diagnosis**:
```bash
# Check disk usage
df -h

# Check Docker space
docker system df
```

**Solution**:
```bash
# Clean Docker
docker system prune -a

# Remove old images
docker image prune -a

# Clean volumes (careful!)
docker volume prune

# Check logs
journalctl --vacuum-time=7d
```

---

## Getting Help

### Collect Diagnostic Info

When asking for help, include:

```bash
# System info
uname -a
docker --version
docker-compose --version

# Service status
docker ps

# Logs
docker logs n8n --tail 50
docker logs n8n-postgres --tail 50

# Configuration (redact secrets!)
docker-compose -f docker/docker-compose.yml config

# Resource usage
docker stats --no-stream
```

---

### Enable Debug Logging

For more detailed logs:

```bash
# In docker/.env
LOG_LEVEL=debug

# Restart
cd docker
docker-compose restart n8n

# Watch logs
docker logs -f n8n
```

---

### Community Resources

- **n8n Community Forum**: https://community.n8n.io
- **n8n GitHub Issues**: https://github.com/n8n-io/n8n/issues
- **n8n Discord**: https://discord.gg/n8n
- **Stack Overflow**: Tag `n8n`

---

## Emergency Recovery

### Complete Reset (Last Resort)

**WARNING**: This deletes all data!

```bash
# Stop everything
cd docker
docker-compose down -v

# Remove all data
docker volume rm docker_postgres-data docker_n8n-data

# Start fresh
docker-compose up -d

# Restore from backup (if available)
./scripts/deploy.sh restore
```

---

### Backup Before Troubleshooting

Always backup first!

```bash
# Quick backup
./scripts/deploy.sh backup

# Verify backup exists
ls -lh backups/
```

---

**Still stuck?** Open an issue on GitHub with diagnostic info!
