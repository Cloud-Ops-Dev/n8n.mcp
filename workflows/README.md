# n8n Workflow Templates

This directory contains workflow templates for managing multi-cloud infrastructure.

## Templates

### server-health-check.json
**Purpose**: Monitor health of all servers (AMD workstation, IBM Cloud, AWS)

**Trigger**: Schedule (every 5 minutes)

**Actions**:
- SSH into each server
- Check uptime, disk space, and memory
- Parse results and check for errors
- Send alerts if issues detected

**Configuration Required**:
- SSH credentials in environment variables
- Slack webhook (optional, for alerts)

**Usage**:
1. Import into n8n via UI
2. Update SSH credentials in workflow
3. Configure alert destination
4. Activate workflow

---

### aws-ec2-provision.json
**Purpose**: Provision new AWS EC2 instances with Docker pre-installed

**Trigger**: Manual

**Actions**:
- Create EC2 instance with specified configuration
- Wait for instance to start
- Get public IP address
- SSH in and install Docker
- Send success notification

**Configuration Required**:
- AWS credentials
- SSH key pair name
- Security group IDs
- Subnet ID

**Usage**:
1. Import into n8n
2. Configure AWS credentials
3. Update instance specifications
4. Manually trigger to provision

---

## Importing Workflows

### Method 1: Via n8n UI
1. Open n8n at http://localhost:5678
2. Click "+" → "Import from File"
3. Select the JSON template
4. Configure credentials
5. Activate

### Method 2: Via API (with MCP)
```bash
# Using MCP client with n8n-MCP
# Ask: "Import the server-health-check workflow from workflows/templates/"
```

### Method 3: Copy to n8n Container
```bash
docker cp workflows/templates/server-health-check.json n8n:/home/node/.n8n/
```

## Creating Custom Workflows

### Using MCP client + MCP
The n8n-MCP integration allows you to use AI to build workflows:

```
Ask MCP: "Create an n8n workflow that backs up my AMD workstation to AWS S3 every night at 2am"
```

### Manually
1. Open n8n UI
2. Click "+" → "Add first step"
3. Build workflow using visual editor
4. Export via Settings → "Download"
5. Save to this directory

## Workflow Best Practices

1. **Use Environment Variables**: Store credentials in .env, reference via `$env`
2. **Error Handling**: Add error workflows for failure scenarios
3. **Logging**: Use Function nodes to log execution details
4. **Testing**: Test with manual triggers before scheduling
5. **Monitoring**: Use webhook notifications for critical workflows
6. **Version Control**: Commit workflow JSON to git
7. **Documentation**: Add descriptions to nodes for team clarity

## Available n8n Nodes for Server Management

### Communication
- **SSH**: Execute commands on remote servers
- **HTTP Request**: Call REST APIs
- **Webhook**: Receive external triggers

### Cloud Providers
- **AWS**: EC2, S3, Lambda management
- **HTTP Request**: IBM Cloud API calls

### Logic & Control
- **Schedule**: Cron-like triggers
- **If**: Conditional branching
- **Switch**: Multi-way branching
- **Function**: JavaScript code execution
- **Wait**: Delay execution

### Notifications
- **Slack**: Team notifications
- **Email**: Send alerts
- **Webhook**: Custom integrations

## Example Use Cases

### 1. Automated Backups
- Trigger: Daily at 2 AM
- Action: SSH to servers, run backup scripts, upload to S3

### 2. Cost Monitoring
- Trigger: Hourly
- Action: Query AWS/IBM APIs, check spending, alert if threshold exceeded

### 3. Deployment Pipeline
- Trigger: Webhook from GitHub
- Action: Pull code, run tests, deploy to servers

### 4. Log Aggregation
- Trigger: Every 10 minutes
- Action: Collect logs from all servers, parse, store in database

### 5. Security Scanning
- Trigger: Weekly
- Action: Run security audits, check for updates, generate report

## Troubleshooting

**Workflow won't activate**: Check credentials and SSH keys
**SSH timeouts**: Verify firewall rules and network connectivity
**AWS API errors**: Ensure IAM permissions are correct
**Execution errors**: Check n8n logs: `docker logs n8n`

## Resources

- [n8n Documentation](https://docs.n8n.io)
- [n8n Community](https://community.n8n.io)
- [Workflow Templates](https://n8n.io/workflows)
