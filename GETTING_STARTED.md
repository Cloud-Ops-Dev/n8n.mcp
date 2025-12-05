# Getting Started

Welcome to the n8n + MCP Multi-Cloud Server Management Lab!

## 🚀 Quick Start (5 Minutes)

### 1. Initial Setup
```bash
cd /home/clay/Documents/GitHub/n8n.mcp

# Run automated setup
./scripts/setup.sh

# This will:
# - Check prerequisites
# - Create environment file
# - Start Docker services
# - Wait for n8n to be ready
```

### 2. Configure Credentials
```bash
# Edit environment variables
nano docker/.env

# At minimum, change:
# - POSTGRES_PASSWORD
# - N8N_BASIC_AUTH_PASSWORD
```

### 3. Access n8n
- Open browser: http://localhost:5678
- Login with credentials from `.env`
- Explore the interface!

### 4. Configure MCP (AI Integration)
```bash
# Run MCP configuration script
./scripts/configure-mcp.sh

# Then restart Claude Code session
```

## 📖 What to Read Next

### For Complete Beginners
1. [README.md](README.md) - Project overview
2. [Architecture Guide](docs/architecture.md) - Understand the system
3. [Setup Guide](docs/setup-guide.md) - Detailed installation

### For Hands-On Learners
1. Run `./scripts/setup.sh` immediately
2. Follow [Implementation Guide](docs/implementation-guide.md) Phase 1
3. Import workflow templates from `workflows/templates/`

### For Advanced Users
1. Review [Architecture](docs/architecture.md)
2. Customize `docker-compose.yml` for your needs
3. Jump to [Implementation Guide](docs/implementation-guide.md) Phase 2

## 🎯 Learning Path

```
Week 1-2: Foundation
├── Setup local environment
├── Learn n8n basics
├── Configure MCP integration
└── Create first workflows

Week 3-4: Cloud Integration
├── Connect AWS and IBM Cloud
├── Provision servers
├── Deploy applications
└── Multi-cloud orchestration

Week 5-6: Production Operations
├── Monitoring and alerting
├── Log aggregation
├── Automated backups
└── Security automation
```

## 🛠️ Common Commands

### Docker Operations
```bash
# Start all services
./scripts/deploy.sh start

# Stop all services
./scripts/deploy.sh stop

# View logs
./scripts/deploy.sh logs

# Check status
./scripts/deploy.sh status
```

### n8n Operations
```bash
# Access n8n UI
open http://localhost:5678

# View n8n logs
docker logs -f n8n

# Restart n8n
cd docker && docker-compose restart n8n
```

### Backup & Restore
```bash
# Create backup
./scripts/deploy.sh backup

# View backups
ls -lh backups/
```

## 📁 Project Structure

```
n8n.mcp/
├── docker/
│   ├── docker-compose.yml    # Service definitions
│   ├── .env.example          # Environment template
│   └── .env                  # Your credentials (git-ignored)
│
├── workflows/
│   ├── templates/            # Ready-to-use workflows
│   │   ├── server-health-check.json
│   │   └── aws-ec2-provision.json
│   └── examples/             # Your custom workflows
│
├── scripts/
│   ├── setup.sh              # Initial setup
│   ├── configure-mcp.sh      # MCP configuration
│   └── deploy.sh             # Deployment utilities
│
├── docs/
│   ├── architecture.md       # System design
│   ├── setup-guide.md        # Installation guide
│   ├── implementation-guide.md  # Step-by-step tasks
│   └── troubleshooting.md    # Common issues
│
├── .mcp.json                 # MCP server config
├── .gitignore               # Git ignore rules
├── README.md                # Project overview
└── LICENSE                  # MIT License
```

## ❓ Troubleshooting

### n8n won't start
```bash
# Check logs
docker logs n8n

# Restart services
cd docker && docker-compose restart
```

### Can't access UI
```bash
# Verify services running
docker ps

# Check port availability
netstat -tulpn | grep 5678
```

### MCP not working
```bash
# Verify configuration
cat .mcp.json

# Reconfigure
./scripts/configure-mcp.sh

# Restart Claude Code
```

For more issues, see [Troubleshooting Guide](docs/troubleshooting.md)

## 🎓 Learning Resources

### n8n
- [Official Documentation](https://docs.n8n.io)
- [Community Forum](https://community.n8n.io)
- [Workflow Templates](https://n8n.io/workflows)

### Docker
- [Docker Documentation](https://docs.docker.com)
- [Docker Compose](https://docs.docker.com/compose)

### Cloud Providers
- [AWS Free Tier](https://aws.amazon.com/free)
- [IBM Cloud Docs](https://cloud.ibm.com/docs)

## 🤝 Getting Help

1. **Check Documentation**: Start with [Troubleshooting](docs/troubleshooting.md)
2. **Search Issues**: Look through GitHub issues
3. **Ask Community**: n8n forum or Discord
4. **Create Issue**: Report bugs on GitHub

## ✅ Success Checklist

After setup, you should have:
- [ ] n8n accessible at http://localhost:5678
- [ ] PostgreSQL database running
- [ ] Can login to n8n UI
- [ ] MCP configuration complete
- [ ] At least one workflow imported
- [ ] Understanding of basic n8n concepts

## 🚀 Next Steps

1. **Import First Workflow**
   - Go to n8n UI
   - Import `workflows/templates/server-health-check.json`
   - Customize for your servers

2. **Learn n8n Basics**
   - Create manual trigger workflow
   - Add function node
   - Execute and view output

3. **Configure Cloud Access**
   - Add AWS credentials
   - Add IBM Cloud API key
   - Test connectivity

4. **Build Custom Workflow**
   - Use Claude + MCP to generate
   - Import and test
   - Understand the code

## 📝 Notes

- **Security**: Change default passwords immediately!
- **Backups**: Set up automated backups early
- **Costs**: Monitor cloud spending (AWS/IBM)
- **Updates**: Keep Docker images updated

---

**Ready to start?** Run `./scripts/setup.sh` now! 🎉

Need help? Check the [Setup Guide](docs/setup-guide.md) or [Troubleshooting](docs/troubleshooting.md).
