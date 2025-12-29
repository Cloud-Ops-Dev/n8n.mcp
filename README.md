# n8n + MCP Multi-Cloud Server Management Lab

An infrastructure orchestration lab that combines n8n automation with Model Context Protocol (MCP) to build, deploy, and manage servers across multiple cloud providers.

## 🎯 Project Overview

This lab demonstrates automated infrastructure management across:
- **Local AMD Workstation** (Docker-based development)
- **IBM Cloud** (Enterprise cloud infrastructure)
- **AWS EC2** (Public cloud compute)

### Architecture

```
┌─────────────────────────────────────────────────┐
│         Laptop (I7, 32GB RAM - Control Plane)   │
├─────────────────────────────────────────────────┤
│  Docker Containers:                             │
│  ┌──────────┐  ┌─────────────┐                  │
│  │   n8n    │◄─┤  n8n-MCP    │                  │
│  │ (5678)   │  │  Server     │                  │
│  └────┬─────┘  └─────────────┘                  │
└───────┼────────────────────────────────────────┘
        │
        │ n8n Workflows Manage:
        ├─► AMD Workstation (SSH, Docker)
        ├─► IBM Cloud Server (API/SSH)
        └─► AWS EC2 Instance (API/SSH)
```

## 🚀 Quick Start

### Prerequisites

- **Laptop**: Docker, Docker Compose
- **Cloud Accounts**: IBM Cloud, AWS (with API credentials)
- **Network**: SSH access to AMD workstation

### Installation

1. **Clone the repository**
   ```bash
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

4. **Access n8n**
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
- **n8n-MCP**: MCP integration server

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

## 🎓 Testing Objectives

1. **n8n Automation**: Build complex workflows for infrastructure management
2. **MCP Integration**: Programmatic workflow design and modification
3. **Multi-Cloud Operations**: Manage resources across providers
4. **Docker Orchestration**: Container-based service deployment
5. **GitOps Practices**: Version-controlled infrastructure automation

## 📋 Project Phases

### Phase 1: Foundation ✅
- ✅ Docker environment setup
- ✅ n8n + MCP integration
- ✅ Server connectivity tests

### Phase 2: Cloud Integration ✅
- ✅ AWS EC2 provisioning workflows
- ✅ IBM Cloud server management
- ✅ SSH key management
- ✅ Terraform integration

### Phase 3: Advanced Operations ✅
- ✅ Monitoring and health checks
- ✅ Log aggregation
- ✅ Automated provisioning/teardown
- ✅ Multi-step orchestrations

## 🛠️ Technology Stack

- **Automation**: n8n, Terraform, Ansible
- **Integration**: MCP (Model Context Protocol)
- **Containers**: Docker, Docker Compose
- **Cloud Providers**: AWS, IBM Cloud
- **Languages**: JavaScript (n8n), Bash (scripting), HCL (Terraform)

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details

## 🤝 Contributing

This is a completed test lab for a customer project. Feel free to fork and experiment!

## 📞 Support

For issues and questions, please open a GitHub issue.
