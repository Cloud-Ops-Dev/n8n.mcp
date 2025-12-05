#!/bin/bash

# MCP Server Configuration Script
# Configures n8n-MCP for Claude Code integration

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}MCP Configuration${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if Claude Code CLI is installed
command -v claude >/dev/null 2>&1 || { echo -e "${RED}Error: Claude Code CLI is not installed${NC}" >&2; exit 1; }

# Load environment variables
if [ -f "docker/.env" ]; then
    source docker/.env
else
    echo -e "${RED}Error: docker/.env not found. Run ./scripts/setup.sh first${NC}"
    exit 1
fi

# Check if n8n is running
if ! curl -f -s http://localhost:5678/healthz > /dev/null 2>&1; then
    echo -e "${RED}Error: n8n is not running. Start it with: docker-compose -f docker/docker-compose.yml up -d${NC}"
    exit 1
fi

echo -e "${YELLOW}Configuring n8n-MCP server...${NC}"
echo ""

# Check if .mcp.json exists
if [ -f ".mcp.json" ]; then
    echo -e "${GREEN}✓ .mcp.json already exists${NC}"
    echo -e "${YELLOW}Configuration:${NC}"
    cat .mcp.json
else
    echo -e "${YELLOW}Creating .mcp.json configuration...${NC}"

    # Create MCP configuration
    claude mcp add --scope project --transport stdio n8n-mcp \
        --env MCP_MODE=stdio \
        --env LOG_LEVEL=error \
        --env DISABLE_CONSOLE_OUTPUT=true \
        --env N8N_API_URL=http://localhost:5678 \
        --env N8N_API_KEY="${N8N_API_KEY}" \
        -- npx -y n8n-mcp

    echo -e "${GREEN}✓ MCP server configured${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Configuration Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo ""
echo -e "1. Generate an n8n API key:"
echo -e "   - Open ${GREEN}http://localhost:5678${NC}"
echo -e "   - Go to Settings → API"
echo -e "   - Generate a new API key"
echo -e "   - Add it to ${GREEN}docker/.env${NC} as N8N_API_KEY"
echo ""
echo -e "2. Restart Claude Code to load MCP server:"
echo -e "   - Exit and restart your Claude Code session"
echo ""
echo -e "3. Verify MCP is working:"
echo -e "   - In Claude Code, ask: 'What n8n nodes are available?'"
echo ""
echo -e "4. Update configuration if needed:"
echo -e "   ${GREEN}claude mcp list${NC}   # List configured servers"
echo -e "   ${GREEN}claude mcp remove n8n-mcp${NC}   # Remove if needed"
echo ""
