#!/bin/bash

# Deployment Helper Script
# Utilities for managing the n8n + MCP lab environment

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display help
show_help() {
    echo -e "${GREEN}n8n + MCP Lab Deployment Helper${NC}"
    echo ""
    echo "Usage: ./deploy.sh [command]"
    echo ""
    echo "Commands:"
    echo "  ${BLUE}start${NC}        - Start all services"
    echo "  ${BLUE}stop${NC}         - Stop all services"
    echo "  ${BLUE}restart${NC}      - Restart all services"
    echo "  ${BLUE}status${NC}       - Show service status"
    echo "  ${BLUE}logs${NC}         - Show service logs (follow mode)"
    echo "  ${BLUE}logs-n8n${NC}     - Show only n8n logs"
    echo "  ${BLUE}logs-postgres${NC} - Show only postgres logs"
    echo "  ${BLUE}backup${NC}       - Backup n8n data and database"
    echo "  ${BLUE}restore${NC}      - Restore from backup"
    echo "  ${BLUE}clean${NC}        - Stop and remove all containers and volumes"
    echo "  ${BLUE}update${NC}       - Pull latest images and restart"
    echo "  ${BLUE}shell-n8n${NC}    - Open shell in n8n container"
    echo "  ${BLUE}psql${NC}         - Open PostgreSQL shell"
    echo ""
}

# Function to start services
start_services() {
    echo -e "${YELLOW}Starting services...${NC}"
    cd docker
    docker-compose up -d
    cd ..
    echo -e "${GREEN}✓ Services started${NC}"
    echo -e "${YELLOW}Access n8n at: http://localhost:5678${NC}"
}

# Function to stop services
stop_services() {
    echo -e "${YELLOW}Stopping services...${NC}"
    cd docker
    docker-compose down
    cd ..
    echo -e "${GREEN}✓ Services stopped${NC}"
}

# Function to restart services
restart_services() {
    echo -e "${YELLOW}Restarting services...${NC}"
    cd docker
    docker-compose restart
    cd ..
    echo -e "${GREEN}✓ Services restarted${NC}"
}

# Function to show status
show_status() {
    echo -e "${YELLOW}Service Status:${NC}"
    cd docker
    docker-compose ps
    cd ..
}

# Function to show logs
show_logs() {
    echo -e "${YELLOW}Showing logs (Ctrl+C to exit)...${NC}"
    cd docker
    docker-compose logs -f
}

# Function to show n8n logs only
show_n8n_logs() {
    echo -e "${YELLOW}Showing n8n logs (Ctrl+C to exit)...${NC}"
    cd docker
    docker-compose logs -f n8n
}

# Function to show postgres logs only
show_postgres_logs() {
    echo -e "${YELLOW}Showing postgres logs (Ctrl+C to exit)...${NC}"
    cd docker
    docker-compose logs -f postgres
}

# Function to backup data
backup_data() {
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"

    echo -e "${YELLOW}Creating backup in $BACKUP_DIR...${NC}"

    # Backup n8n data
    docker run --rm -v n8n-data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine tar czf /backup/n8n-data.tar.gz -C /data .

    # Backup database
    cd docker
    docker-compose exec -T postgres pg_dump -U n8n n8n > "../$BACKUP_DIR/n8n-db.sql"
    cd ..

    echo -e "${GREEN}✓ Backup created in $BACKUP_DIR${NC}"
}

# Function to clean everything
clean_all() {
    echo -e "${RED}WARNING: This will remove all containers, volumes, and data!${NC}"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" == "yes" ]; then
        echo -e "${YELLOW}Cleaning up...${NC}"
        cd docker
        docker-compose down -v
        cd ..
        echo -e "${GREEN}✓ Cleanup complete${NC}"
    else
        echo -e "${YELLOW}Cancelled${NC}"
    fi
}

# Function to update
update_services() {
    echo -e "${YELLOW}Updating services...${NC}"
    cd docker
    docker-compose pull
    docker-compose up -d
    cd ..
    echo -e "${GREEN}✓ Services updated${NC}"
}

# Function to open n8n shell
shell_n8n() {
    echo -e "${YELLOW}Opening n8n container shell...${NC}"
    docker exec -it n8n /bin/sh
}

# Function to open postgres shell
psql_shell() {
    echo -e "${YELLOW}Opening PostgreSQL shell...${NC}"
    cd docker
    docker-compose exec postgres psql -U n8n
}

# Main script logic
case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    logs-n8n)
        show_n8n_logs
        ;;
    logs-postgres)
        show_postgres_logs
        ;;
    backup)
        backup_data
        ;;
    clean)
        clean_all
        ;;
    update)
        update_services
        ;;
    shell-n8n)
        shell_n8n
        ;;
    psql)
        psql_shell
        ;;
    *)
        show_help
        ;;
esac
