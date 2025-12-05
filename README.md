# n8n + MCP Multi-Cloud Server Management Lab

An AI-powered infrastructure orchestration lab that combines n8n automation with Model Context Protocol (MCP) to build, deploy, and manage servers across multiple cloud providers.

## 🎯 Project Overview

This lab demonstrates how to use AI-assisted automation to manage infrastructure across:
- **Local AMD Workstation** (Docker-based development)
- **IBM Cloud** (Enterprise cloud infrastructure)
- **AWS EC2** (Public cloud compute)

### Architecture

```
┌─────────────────────────────────────────────────┐
│         Laptop (I7, 32GB RAM - Control Plane)   │
├─────────────────────────────────────────────────┤
│  Docker Containers:                             │
│  ┌──────────┐  ┌─────────────┐  ┌────────────┐ │
│  │   n8n    │◄─┤  n8n-MCP    │◄─┤  Claude    │ │
│  │ (5678)   │  │  Server     │  │  Code      │ │
│  └────┬─────┘  └─────────────┘  └────────────┘ │
└───────┼────────────────────────────────────────┘
        │
        │ n8n Workflows Manage:
        ├─► AMD Workstation (SSH, Docker)
        ├─► IBM Cloud Server (API/SSH)
        └─► AWS EC2 Instance (API/SSH)
```

## 🚀 Quick Start

### Prerequisites

- **Laptop**: Docker, Docker Compose, Claude Code CLI
- **Cloud Accounts**: IBM Cloud, AWS (with API credentials)
- **Network**: SSH access to AMD workstation

### Installation

1. **Clone the repository**
   ```bash
   cd /home/clay/Documents/GitHub
   git clone <your-repo-url> n8n.mcp
   cd n8n.mcp
   ```

2. **Configure environment**
   ```bash
   cp docker/.env.example docker/.env
   # Edit docker/.env with your credentials
   ```

3. **Start the stack**
   ```bash
   cd docker
   docker-compose up -d
   ```

4. **Configure MCP with Claude Code**
   ```bash
   ./scripts/configure-mcp.sh
   ```

5. **Access n8n**
   Open http://localhost:5678

## 📚 Documentation

- [Architecture Guide](docs/architecture.md) - System design and components
- [Setup Guide](docs/setup-guide.md) - Detailed installation instructions
- [Workflow Documentation](docs/workflows.md) - n8n workflow templates
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## 🔧 What's Included

### Docker Services
- **n8n**: Workflow automation engine
- **PostgreSQL**: n8n database backend
- **n8n-MCP**: AI integration via Model Context Protocol

### Workflow Templates
- Server provisioning (AWS EC2, IBM Cloud)
- Configuration management
- Health monitoring
- Log aggregation
- Automated backups

### Scripts
- `setup.sh`: Initial environment setup
- `configure-mcp.sh`: MCP server configuration
- `deploy.sh`: Deployment utilities

## 🎓 Learning Objectives

1. **n8n Automation**: Build complex workflows for infrastructure management
2. **MCP Integration**: Use AI to design and modify automation
3. **Multi-Cloud Operations**: Manage resources across providers
4. **Docker Orchestration**: Container-based service deployment
5. **GitOps Practices**: Version-controlled infrastructure automation

## 📋 Project Phases

### Phase 1: Foundation (Current)
- ✅ Docker environment setup
- ✅ n8n + MCP integration
- ⬜ Basic server connectivity tests

### Phase 2: Cloud Integration
- ⬜ AWS EC2 provisioning workflows
- ⬜ IBM Cloud server management
- ⬜ SSH key management
- ⬜ Ansible integration

### Phase 3: Advanced Operations
- ⬜ Monitoring and alerting
- ⬜ Log aggregation
- ⬜ Automated backup/restore
- ⬜ Multi-step orchestrations

## 🛠️ Technology Stack

- **Automation**: n8n, Ansible
- **AI Integration**: Claude Code, MCP
- **Containers**: Docker, Docker Compose
- **Cloud Providers**: AWS, IBM Cloud
- **Languages**: JavaScript (n8n), Bash (scripting)

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details

## 🤝 Contributing

This is a learning lab project. Feel free to fork and experiment!

## 📞 Support

For issues and questions, please open a GitHub issue.
