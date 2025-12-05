#!/bin/bash

# n8n + MCP Lab Setup Script
# This script initializes the development environment

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}n8n + MCP Lab Setup${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

command -v docker >/dev/null 2>&1 || { echo -e "${RED}Error: Docker is not installed${NC}" >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo -e "${RED}Error: Docker Compose is not installed${NC}" >&2; exit 1; }
command -v claude >/dev/null 2>&1 || { echo -e "${RED}Error: Claude Code CLI is not installed${NC}" >&2; exit 1; }

echo -e "${GREEN}✓ Docker installed${NC}"
echo -e "${GREEN}✓ Docker Compose installed${NC}"
echo -e "${GREEN}✓ Claude Code CLI installed${NC}"
echo ""

# Setup environment file
echo -e "${YELLOW}Setting up environment configuration...${NC}"

if [ ! -f "docker/.env" ]; then
    cp docker/.env.example docker/.env
    echo -e "${GREEN}✓ Created docker/.env from template${NC}"
    echo -e "${YELLOW}⚠  Please edit docker/.env with your actual credentials${NC}"
else
    echo -e "${YELLOW}⚠  docker/.env already exists, skipping...${NC}"
fi
echo ""

# Create necessary directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p workflows/templates
mkdir -p workflows/examples
mkdir -p logs
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# Pull Docker images
echo -e "${YELLOW}Pulling Docker images (this may take a few minutes)...${NC}"
cd docker
docker-compose pull
echo -e "${GREEN}✓ Docker images pulled${NC}"
echo ""

# Start services
echo -e "${YELLOW}Starting services...${NC}"
docker-compose up -d
echo -e "${GREEN}✓ Services started${NC}"
echo ""

# Wait for n8n to be ready
echo -e "${YELLOW}Waiting for n8n to be ready...${NC}"
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -f -s http://localhost:5678/healthz > /dev/null 2>&1; then
        echo -e "${GREEN}✓ n8n is ready!${NC}"
        break
    fi
    attempt=$((attempt + 1))
    echo -n "."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}Error: n8n failed to start${NC}"
    exit 1
fi
echo ""

cd ..

# Display next steps
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo -e "1. Edit your credentials:"
echo -e "   ${GREEN}nano docker/.env${NC}"
echo ""
echo -e "2. Access n8n interface:"
echo -e "   ${GREEN}http://localhost:5678${NC}"
echo -e "   Default credentials (change these!):"
echo -e "   Username: admin"
echo -e "   Password: admin"
echo ""
echo -e "3. Configure MCP integration:"
echo -e "   ${GREEN}./scripts/configure-mcp.sh${NC}"
echo ""
echo -e "4. View logs:"
echo -e "   ${GREEN}docker-compose -f docker/docker-compose.yml logs -f${NC}"
echo ""
echo -e "5. Stop services:"
echo -e "   ${GREEN}docker-compose -f docker/docker-compose.yml down${NC}"
echo ""
