# Architecture Overview

## System Architecture

This lab demonstrates an AI-powered, multi-cloud infrastructure orchestration system using n8n automation and Model Context Protocol (MCP) for AI integration.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Control Plane (Laptop)                   │
│                   I7, 32GB RAM, Linux                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              MCP client CLI                         │  │
│  │  - User interface for AI interaction                 │  │
│  │  - MCP client for n8n integration                    │  │
│  └───────────────────┬──────────────────────────────────┘  │
│                      │ MCP Protocol (stdio)                │
│  ┌───────────────────▼──────────────────────────────────┐  │
│  │           n8n-MCP Server (npx)                       │  │
│  │  - Exposes n8n API to MCP                         │  │
│  │  - 543 node types with documentation                 │  │
│  │  - 2,700+ workflow templates                         │  │
│  └───────────────────┬──────────────────────────────────┘  │
│                      │ HTTP API                            │
│  ┌───────────────────▼──────────────────────────────────┐  │
│  │        n8n Automation Engine (Docker)                │  │
│  │  - Workflow execution engine                         │  │
│  │  - Visual workflow designer                          │  │
│  │  - Integration with 300+ services                    │  │
│  │  Port: 5678                                          │  │
│  └───────────────────┬──────────────────────────────────┘  │
│                      │                                     │
│  ┌───────────────────▼──────────────────────────────────┐  │
│  │        PostgreSQL Database (Docker)                  │  │
│  │  - n8n workflow storage                              │  │
│  │  - Execution history                                 │  │
│  │  - Credentials (encrypted)                           │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└────────┬──────────────┬──────────────┬─────────────────────┘
         │              │              │
         │ SSH/API      │ SSH/API      │ SSH/API
         │              │              │
    ┌────▼─────┐  ┌────▼──────┐  ┌───▼──────┐
    │   AMD    │  │   IBM     │  │   AWS    │
    │Workstation│  │   Cloud   │  │   EC2    │
    │          │  │  Server   │  │Instance  │
    │  Docker  │  │           │  │          │
    │ Services │  │  CentOS   │  │  Ubuntu  │
    └──────────┘  └───────────┘  └──────────┘
       Local      Enterprise      Public
       Dev Env     Cloud          Cloud
```

## Component Details

### 1. MCP client CLI
**Purpose**: AI-powered development interface

**Capabilities**:
- Natural language workflow creation
- Interactive debugging
- Code generation for n8n functions
- Documentation lookup

**Technology**:
- MCP AI (Anthropic)
- MCP client integration

---

### 2. n8n-MCP Server
**Purpose**: Bridge between MCP and n8n

**Capabilities**:
- Query n8n node documentation
- Search 543 node types
- Access 2,700+ workflow templates
- Create/modify workflows via AI

**Technology**:
- Node.js package (npx)
- Model Context Protocol (stdio)
- SQLite for node database

**Configuration**:
```json
{
  "mcpServers": {
    "n8n-mcp": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "n8n-mcp"],
      "env": {
        "MCP_MODE": "stdio",
        "N8N_API_URL": "http://localhost:5678",
        "N8N_API_KEY": "your-key"
      }
    }
  }
}
```

---

### 3. n8n Automation Engine
**Purpose**: Workflow orchestration and execution

**Key Features**:
- Visual workflow designer
- 300+ pre-built integrations
- Custom JavaScript functions
- Webhook support
- Scheduled execution
- Error handling and retry logic

**Technology**:
- Node.js application
- Docker container
- PostgreSQL backend

**Exposed Services**:
- Web UI: http://localhost:5678
- Webhook endpoint: http://localhost:5678/webhook/*
- API: http://localhost:5678/api/*

---

### 4. PostgreSQL Database
**Purpose**: Persistent storage for n8n

**Stores**:
- Workflow definitions (JSON)
- Execution history
- Credentials (AES-256 encrypted)
- Webhooks
- Settings

**Technology**:
- PostgreSQL 15 Alpine
- Docker volume for persistence

---

### 5. Managed Infrastructure

#### AMD Workstation
- **Role**: Local development server
- **Access**: SSH (local network)
- **Use Cases**:
  - Docker container deployments
  - Testing workflows
  - Build environments
- **Management**: Direct SSH commands

#### IBM Cloud Server
- **Role**: Enterprise cloud infrastructure
- **Access**: IBM Cloud API + SSH
- **Use Cases**:
  - Production deployments
  - Database hosting
  - Enterprise applications
- **Management**: IBM Cloud SDK, Terraform

#### AWS EC2 Instance
- **Role**: Public cloud compute
- **Access**: AWS API + SSH
- **Use Cases**:
  - Web applications
  - Scalable services
  - S3 backups
- **Management**: AWS SDK, CloudFormation

---

## Data Flow

### Workflow Creation Flow
```
User → MCP client → MCP → n8n-MCP → n8n API → PostgreSQL
```

1. User describes workflow in natural language
2. MCP client interprets intent
3. MCP protocol transmits request
4. n8n-MCP translates to n8n API calls
5. n8n creates/modifies workflow
6. Workflow stored in PostgreSQL

### Workflow Execution Flow
```
Trigger → n8n → Target Server → Response → n8n → Action
```

1. Trigger fires (schedule, webhook, manual)
2. n8n executes workflow nodes sequentially
3. SSH/API calls to target servers
4. Collect responses
5. Process with function nodes
6. Take actions (notify, log, etc.)

---

## Network Architecture

### Ports
- **5678**: n8n web UI and API
- **5432**: PostgreSQL (internal only)
- **22**: SSH to managed servers

### Docker Network
- **n8n-network**: Bridge network for containers
- Internal DNS resolution between containers

### External Connectivity
- **AMD Workstation**: Local network (192.168.x.x)
- **IBM Cloud**: Public IP via IBM network
- **AWS EC2**: Public IP via AWS VPC

---

## Security Architecture

### Credential Management
1. **Environment Variables**: Stored in `.env` (git-ignored)
2. **n8n Credentials**: Encrypted in PostgreSQL
3. **SSH Keys**: Stored securely, referenced by path
4. **API Keys**: Rotated regularly, stored in n8n

### Access Control
- **n8n UI**: Basic auth (change default!)
- **n8n API**: API key authentication
- **SSH**: Key-based only, no passwords
- **Cloud APIs**: IAM roles with least privilege

### Network Security
- **Firewall**: Restrict SSH to known IPs
- **VPN**: Consider for production
- **HTTPS**: Recommended for external n8n access

---

## Scalability Considerations

### Vertical Scaling
- Increase Docker container resources
- Upgrade PostgreSQL for more connections
- Add n8n workers for parallel execution

### Horizontal Scaling
- Multiple n8n instances with load balancer
- Shared PostgreSQL or database cluster
- Redis for queue management

### Cloud Scaling
- Auto-scaling groups for AWS EC2
- Kubernetes for container orchestration
- Multi-region deployments

---

## Disaster Recovery

### Backup Strategy
1. **n8n Data**: Daily volume backups
2. **PostgreSQL**: Automated pg_dump
3. **Workflows**: Git version control
4. **Credentials**: Encrypted backup separate from repo

### Recovery Procedures
1. Restore Docker volumes
2. Import database dump
3. Restart services
4. Verify workflow execution

---

## Monitoring & Observability

### Logs
- **n8n**: `/home/node/.n8n/logs/`
- **PostgreSQL**: Docker logs
- **Workflow Executions**: n8n UI

### Metrics
- Execution success/failure rates
- Execution duration
- API response times
- Resource utilization

### Alerts
- Slack notifications for failures
- Email for critical issues
- Webhook for custom integrations

---

## Technology Stack Summary

| Layer | Technology | Purpose |
|-------|-----------|---------|
| AI Interface | MCP client | User interaction |
| AI Protocol | MCP | AI-to-tool communication |
| Automation | n8n | Workflow orchestration |
| Database | PostgreSQL | Data persistence |
| Container | Docker | Service isolation |
| Orchestration | Docker Compose | Multi-container management |
| Cloud - AWS | EC2, S3 | Compute & storage |
| Cloud - IBM | Virtual Servers | Enterprise hosting |
| Local | AMD Workstation | Development environment |

---

## Design Principles

1. **Infrastructure as Code**: All configs in version control
2. **Automation First**: Minimize manual operations
3. **AI-Assisted**: Leverage MCP for complex tasks
4. **Security by Default**: Credentials encrypted, keys required
5. **Observable**: Comprehensive logging and monitoring
6. **Resilient**: Error handling and retry logic
7. **Scalable**: Design for growth from day one
8. **Documented**: Clear documentation for all components
