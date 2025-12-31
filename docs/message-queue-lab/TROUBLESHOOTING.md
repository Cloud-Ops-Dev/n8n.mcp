# Troubleshooting Guide

## Quick Diagnostics

### Health Check Commands

```bash
# Check all components quickly
echo "=== AWS Redis ===" && \
ssh -o ConnectTimeout=5 ubuntu@<aws-ip> /usr/local/bin/status-redis.sh && \
echo "=== IBM Producer ===" && \
ssh -o ConnectTimeout=5 root@<ibm-ip> /usr/local/bin/status-producer.sh && \
echo "=== Local Consumer ===" && \
docker ps --filter name=mq-consumer --format "{{.Status}}" || echo "NOT_RUNNING"
```

### Check Queue Depth

```bash
ssh ubuntu@<aws-ip> 'docker exec mq-redis redis-cli llen demo-queue'
```

If queue depth keeps growing → Consumer not receiving
If queue depth is 0 → Producer not sending or consumer is caught up

---

## Connection Issues

### Problem: Cannot SSH to AWS EC2

**Symptoms:**
- Connection timeout
- Connection refused

**Solutions:**

1. **Verify instance is running**
   ```bash
   aws ec2 describe-instances \
     --filters "Name=tag:Name,Values=n8n-lab-ec2-redis" \
     --query 'Reservations[].Instances[].{State:State.Name,IP:PublicIpAddress}'
   ```

2. **Check security group**
   ```bash
   aws ec2 describe-security-groups \
     --filters "Name=group-name,Values=n8n-lab-sg" \
     --query 'SecurityGroups[].IpPermissions'
   ```

3. **Verify SSH key permissions**
   ```bash
   ls -la ~/.ssh/R_Smurf_001.pem
   # Should be: -r--------
   chmod 400 ~/.ssh/R_Smurf_001.pem
   ```

4. **Test with verbose SSH**
   ```bash
   ssh -vvv -i ~/.ssh/R_Smurf_001.pem ubuntu@<ip>
   ```

### Problem: Cannot SSH to IBM VSI

**Symptoms:**
- Connection timeout
- Permission denied

**Solutions:**

1. **Check floating IP assigned**
   ```bash
   ibmcloud is instance <instance-id> --output json | jq '.network_interfaces[].floating_ips'
   ```

2. **Verify SSH key**
   ```bash
   # List keys in IBM Cloud
   ibmcloud is keys

   # Verify local key
   ssh-keygen -l -f ~/.ssh/id_ed25519.pub
   ```

3. **Test connectivity**
   ```bash
   ping -c 3 <floating-ip>
   nc -zv <floating-ip> 22
   ```

---

## Redis Issues

### Problem: Redis Container Not Running

**Symptoms:**
- `status-redis.sh` returns NOT_RUNNING
- Connection refused on port 6379

**Solutions:**

1. **SSH and check Docker**
   ```bash
   ssh ubuntu@<aws-ip>
   docker ps -a
   docker logs mq-redis
   ```

2. **Restart Redis**
   ```bash
   /usr/local/bin/start-redis.sh
   ```

3. **Check Docker service**
   ```bash
   systemctl status docker
   # If not running:
   sudo systemctl start docker
   ```

4. **Verify cloud-init completed**
   ```bash
   cat /var/log/cloud-init-mq.log
   cloud-init status
   ```

### Problem: Cannot Connect to Redis from External

**Symptoms:**
- Redis works locally on EC2
- Connection timeout from IBM/local

**Solutions:**

1. **Test Redis locally**
   ```bash
   # On EC2 instance
   docker exec mq-redis redis-cli ping
   # Should return: PONG
   ```

2. **Check Redis is listening on all interfaces**
   ```bash
   docker exec mq-redis redis-cli config get bind
   # Should return: *
   ```

3. **Verify security group**
   - Port 6379 must be open
   - Source should be 0.0.0.0/0 (or specific IPs)

4. **Test from producer host**
   ```bash
   # On IBM VSI
   nc -zv <aws-ip> 6379
   # Should return: Connection succeeded
   ```

---

## Producer Issues

### Problem: Producer Container Not Starting

**Symptoms:**
- Container exits immediately
- Status shows NOT_RUNNING

**Solutions:**

1. **Check container logs**
   ```bash
   ssh root@<ibm-ip> 'docker logs mq-producer'
   ```

2. **Common errors:**
   - "redis.exceptions.ConnectionError" → Check REDIS_HOST
   - "No module named redis" → Image pull failed

3. **Verify environment variables**
   ```bash
   ssh root@<ibm-ip> 'docker inspect mq-producer | grep -A 20 "Env"'
   ```

4. **Test Redis connectivity manually**
   ```bash
   ssh root@<ibm-ip>
   python3 -c "import socket; s=socket.socket(); s.settimeout(5); s.connect(('<aws-ip>', 6379)); print('OK')"
   ```

### Problem: Producer Sending But Consumer Not Receiving

**Symptoms:**
- Producer logs show "Sent #X"
- Consumer shows nothing
- Queue depth increasing

**Solutions:**

1. **Verify queue name matches**
   ```bash
   # On producer
   docker inspect mq-producer | grep QUEUE_NAME

   # On consumer
   docker inspect mq-consumer | grep QUEUE_NAME
   ```

2. **Check consumer is using BLPOP**
   ```bash
   docker logs mq-consumer
   # Should show "Waiting for messages..."
   ```

3. **Manual queue check**
   ```bash
   # View messages in queue (without removing)
   ssh ubuntu@<aws-ip> 'docker exec mq-redis redis-cli lrange demo-queue 0 -1'
   ```

---

## Consumer Issues

### Problem: Consumer Not Starting

**Symptoms:**
- Container doesn't appear in `docker ps`
- Script returns error

**Solutions:**

1. **Check script execution**
   ```bash
   /scripts/message-queue/deploy-consumer-local.sh <aws-ip>
   # Watch for errors
   ```

2. **Check existing container**
   ```bash
   docker ps -a --filter name=mq-consumer
   docker logs mq-consumer
   ```

3. **Verify Redis host is reachable**
   ```bash
   nc -zv <aws-ip> 6379
   redis-cli -h <aws-ip> ping
   ```

### Problem: Consumer Shows "Connection Refused"

**Symptoms:**
- Logs show "Connection attempt X/10 failed"
- Eventually exits

**Solutions:**

1. **Verify REDIS_HOST is correct**
   ```bash
   docker inspect mq-consumer | grep REDIS_HOST
   ```

2. **Check network connectivity**
   ```bash
   docker run --rm redis:7-alpine redis-cli -h <aws-ip> ping
   ```

3. **Verify AWS security group**
   - Must allow inbound 6379 from your IP

---

## Terraform Issues

### Problem: Terraform Apply Fails

**Symptoms:**
- Error messages during apply
- Resources partially created

**Solutions:**

1. **Check credentials**
   ```bash
   # AWS
   aws sts get-caller-identity

   # IBM
   ibmcloud login --apikey @~/.ibm_api_key
   ibmcloud target
   ```

2. **Validate configuration**
   ```bash
   terraform validate
   terraform plan
   ```

3. **Clean up partial state**
   ```bash
   terraform destroy
   # Then try again
   terraform apply
   ```

### Problem: Terraform Destroy Hangs

**Symptoms:**
- Destroy takes very long
- Stuck on specific resource

**Solutions:**

1. **Check resource in console**
   - May be in "deleting" state
   - Manual deletion might be needed

2. **Force destroy**
   ```bash
   terraform destroy -auto-approve
   ```

3. **Remove from state if stuck**
   ```bash
   terraform state rm <resource_name>
   # Then manually delete in console
   ```

---

## Workflow Issues

### Problem: n8n Workflow Fails

**Symptoms:**
- Execution shows error
- Red nodes in workflow

**Solutions:**

1. **Check execution log**
   - Open workflow in n8n
   - Click on failed execution
   - Review error message

2. **Common issues:**
   - SSH timeout → Check instance is running
   - Command not found → Cloud-init not complete
   - Permission denied → Wrong SSH key

3. **Test command manually**
   ```bash
   # Copy command from workflow
   # Run in terminal to see full error
   ```

### Problem: Terraform Command Fails in Workflow

**Symptoms:**
- "Error: Failed to install provider"
- "Error: Could not load plugin"

**Solutions:**

1. **Check Docker volume mount**
   - Terraform directory must be mounted
   - Check docker-compose.yml volumes

2. **Reinitialize Terraform**
   ```bash
   docker run --rm -v /path/to/terraform:/workspace \
     -w /workspace hashicorp/terraform:latest init -upgrade
   ```

---

## Performance Issues

### Problem: Messages Delayed

**Symptoms:**
- Large gap between send and receive times
- Queue depth fluctuates

**Solutions:**

1. **Check network latency**
   ```bash
   # From IBM to AWS
   ssh root@<ibm-ip> 'ping -c 5 <aws-ip>'
   ```

2. **Check Redis memory**
   ```bash
   ssh ubuntu@<aws-ip> 'docker exec mq-redis redis-cli info memory'
   ```

3. **Check container resources**
   ```bash
   docker stats mq-producer mq-consumer
   ```

### Problem: High Queue Depth

**Symptoms:**
- Queue keeps growing
- Consumer can't keep up

**Solutions:**

1. **Check consumer is running**
   ```bash
   docker logs -f mq-consumer
   ```

2. **Verify consumer connection**
   ```bash
   # Consumer should show "Connected to..."
   # If reconnecting repeatedly, network issue
   ```

3. **Drain queue manually** (for testing)
   ```bash
   ssh ubuntu@<aws-ip> \
     'docker exec mq-redis redis-cli del demo-queue'
   ```

---

## Log Locations

| Component | Log Command |
|-----------|-------------|
| AWS cloud-init | `cat /var/log/cloud-init-mq.log` |
| Redis container | `docker logs mq-redis` |
| Producer container | `docker logs mq-producer` |
| Consumer container | `docker logs mq-consumer` |
| n8n workflow logs | Check n8n UI executions |
| Terraform | Check console output |

---

## Getting Help

### Information to Gather

When troubleshooting, collect:

1. **Component status**
   ```bash
   docker ps -a
   ```

2. **Recent logs**
   ```bash
   docker logs --tail 50 <container>
   ```

3. **Network connectivity**
   ```bash
   nc -zv <host> <port>
   ```

4. **Terraform state**
   ```bash
   terraform show
   ```

5. **Cloud instance status**
   - AWS: EC2 Console
   - IBM: VPC Infrastructure
