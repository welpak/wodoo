#!/bin/bash
#
# Wodoo Remote Deployment Script
# Run this script from your LOCAL machine to deploy Wodoo to a remote server
#

set -e  # Exit on any error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

print_header "Wodoo Remote Deployment Script"

echo ""
echo -e "${GREEN}This script will:${NC}"
echo "  1. Copy Wodoo files to your remote server"
echo "  2. SSH into the server"
echo "  3. Run the automated deployment"
echo "  4. Configure the application"
echo ""

# Gather server information
print_step "Enter deployment details:"
echo ""

read -p "$(echo -e ${CYAN}Remote server IP/hostname: ${NC})" SERVER_HOST
if [ -z "$SERVER_HOST" ]; then
    print_error "Server hostname is required"
    exit 1
fi

read -p "$(echo -e ${CYAN}SSH username [default: current user]: ${NC})" SSH_USER
SSH_USER=${SSH_USER:-$USER}

read -p "$(echo -e ${CYAN}SSH port [default: 22]: ${NC})" SSH_PORT
SSH_PORT=${SSH_PORT:-22}

# Ask about Odoo configuration
echo ""
print_step "Odoo Configuration (optional - can configure later):"
echo ""
read -p "$(echo -e ${CYAN}Configure Odoo credentials now? (y/N): ${NC})" -n 1 -r CONFIGURE_NOW
echo ""

ODOO_URL=""
ODOO_DB=""
ODOO_USERNAME=""
ODOO_PASSWORD=""

if [[ $CONFIGURE_NOW =~ ^[Yy]$ ]]; then
    read -p "$(echo -e ${CYAN}Odoo URL [default: https://welpakco.com]: ${NC})" ODOO_URL
    ODOO_URL=${ODOO_URL:-https://welpakco.com}

    read -p "$(echo -e ${CYAN}Odoo Database [default: welpakco]: ${NC})" ODOO_DB
    ODOO_DB=${ODOO_DB:-welpakco}

    read -p "$(echo -e ${CYAN}Odoo Username [default: admin@welpakco.com]: ${NC})" ODOO_USERNAME
    ODOO_USERNAME=${ODOO_USERNAME:-admin@welpakco.com}

    read -s -p "$(echo -e ${CYAN}Odoo Password: ${NC})" ODOO_PASSWORD
    echo ""
fi

# Summary
print_header "Deployment Summary"
echo ""
echo -e "${GREEN}Target Server:${NC}"
echo "  Host: $SSH_USER@$SERVER_HOST:$SSH_PORT"
echo "  Source: $SCRIPT_DIR"
echo ""

if [ -n "$ODOO_URL" ]; then
    echo -e "${GREEN}Odoo Configuration:${NC}"
    echo "  URL: $ODOO_URL"
    echo "  Database: $ODOO_DB"
    echo "  Username: $ODOO_USERNAME"
    echo "  Password: ********"
    echo ""
fi

read -p "$(echo -e ${YELLOW}Continue with deployment? (y/N): ${NC})" -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Deployment cancelled"
    exit 0
fi

# Test SSH connection
print_header "Step 1/5: Testing SSH Connection"
echo ""

print_info "Testing connection to $SSH_USER@$SERVER_HOST:$SSH_PORT..."

if ssh -p $SSH_PORT -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no $SSH_USER@$SERVER_HOST exit 2>/dev/null; then
    print_success "SSH connection successful (using key-based auth)"
elif ssh -p $SSH_PORT -o ConnectTimeout=10 $SSH_USER@$SERVER_HOST exit; then
    print_success "SSH connection successful"
else
    print_error "Cannot connect to server. Please check:"
    echo "  - Server IP/hostname is correct"
    echo "  - SSH is running on the server"
    echo "  - You have network connectivity"
    echo "  - Firewall allows SSH connections"
    exit 1
fi

# Copy files to server
print_header "Step 2/5: Copying Files to Server"
echo ""

print_info "Copying Wodoo to $SSH_USER@$SERVER_HOST:/tmp/wodoo..."

# Use rsync if available, otherwise use scp
if command -v rsync &> /dev/null; then
    rsync -avz --progress -e "ssh -p $SSH_PORT" \
          --exclude '.git' \
          --exclude '__pycache__' \
          --exclude '*.pyc' \
          --exclude '.env' \
          --exclude 'venv' \
          "$SCRIPT_DIR/" "$SSH_USER@$SERVER_HOST:/tmp/wodoo/"
    print_success "Files copied using rsync"
else
    scp -P $SSH_PORT -r "$SCRIPT_DIR" "$SSH_USER@$SERVER_HOST:/tmp/wodoo"
    print_success "Files copied using scp"
fi

# Create .env file if configured
if [ -n "$ODOO_PASSWORD" ]; then
    print_info "Creating .env file with Odoo credentials..."

    ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST "cat > /tmp/wodoo/.env << 'EOFENV'
# Odoo Configuration
ODOO_URL=$ODOO_URL
ODOO_DB=$ODOO_DB
ODOO_USERNAME=$ODOO_USERNAME
ODOO_PASSWORD=$ODOO_PASSWORD

# API Configuration
API_PREFIX=/api/v1
CORS_ORIGINS=[\"*\"]

# Server Configuration
HOST=0.0.0.0
PORT=8000
WORKERS=4
EOFENV
"
    print_success ".env file created on remote server"
fi

# Run deployment script
print_header "Step 3/5: Running Deployment on Remote Server"
echo ""

print_info "Executing deployment script on $SERVER_HOST..."
print_warning "This may take 3-5 minutes..."
echo ""

ssh -p $SSH_PORT -t $SSH_USER@$SERVER_HOST "cd /tmp/wodoo && sudo bash deploy.sh"

if [ $? -eq 0 ]; then
    print_success "Deployment completed successfully"
else
    print_error "Deployment failed. Check the output above for errors."
    exit 1
fi

# Configure if credentials were not provided earlier
if [ -z "$ODOO_PASSWORD" ]; then
    print_header "Step 4/5: Configuration Required"
    echo ""

    print_warning "You need to configure Odoo credentials manually:"
    echo ""
    echo "Run these commands:"
    echo -e "  ${BLUE}ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST${NC}"
    echo -e "  ${BLUE}sudo nano /opt/wodoo/.env${NC}"
    echo ""
    echo "Then restart the service:"
    echo -e "  ${BLUE}sudo systemctl restart wodoo${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}Press Enter to continue after configuration, or 's' to skip: ${NC})" -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Ss]$ ]]; then
        print_warning "Skipping configuration - remember to configure later!"
    else
        print_info "Opening SSH session for configuration..."
        ssh -p $SSH_PORT -t $SSH_USER@$SERVER_HOST "sudo nano /opt/wodoo/.env && sudo systemctl restart wodoo"
    fi
else
    print_header "Step 4/5: Verifying Configuration"
    echo ""
    print_success "Odoo credentials already configured"
fi

# Test deployment
print_header "Step 5/5: Testing Deployment"
echo ""

print_info "Running health checks..."

# Test health endpoint
HEALTH_CHECK=$(ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST "curl -s http://localhost/api/health" 2>/dev/null)

if echo "$HEALTH_CHECK" | grep -q "healthy"; then
    print_success "Backend health check: PASSED"
else
    print_warning "Backend health check: FAILED (may need configuration)"
fi

# Test Odoo connection if configured
if [ -n "$ODOO_PASSWORD" ]; then
    print_info "Testing Odoo connection..."
    CONNECTION_TEST=$(ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST "curl -s http://localhost/api/test-connection" 2>/dev/null)

    if echo "$CONNECTION_TEST" | grep -q '"success":true'; then
        print_success "Odoo connection: PASSED"
    else
        print_warning "Odoo connection: FAILED (check credentials)"
    fi
fi

# Get server IP
SERVER_IP=$(ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST "hostname -I | awk '{print \$1}'" 2>/dev/null)

# Completion message
print_header "🎉 Deployment Complete!"

echo ""
echo -e "${GREEN}Wodoo has been successfully deployed!${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Access your application:${NC}"
if [ -n "$SERVER_IP" ]; then
    echo -e "  ${CYAN}http://$SERVER_IP${NC}"
fi
echo -e "  ${CYAN}http://$SERVER_HOST${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Useful SSH Commands:${NC}"
echo ""
echo "  Connect to server:"
echo -e "    ${BLUE}ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST${NC}"
echo ""
echo "  Check service status:"
echo -e "    ${BLUE}ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST 'sudo systemctl status wodoo'${NC}"
echo ""
echo "  View logs:"
echo -e "    ${BLUE}ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST 'sudo journalctl -u wodoo -f'${NC}"
echo ""
echo "  Restart service:"
echo -e "    ${BLUE}ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST 'sudo systemctl restart wodoo'${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}To uninstall:${NC}"
echo -e "    ${BLUE}ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST 'sudo bash /opt/wodoo/uninstall.sh'${NC}"
echo ""
echo -e "${GREEN}Documentation:${NC}"
echo "  - README.md - Full documentation"
echo "  - QUICKSTART.md - Quick start guide"
echo "  - docs/API.md - API reference"
echo "  - docs/DEPLOYMENT.md - Deployment guide"
echo ""

# Save connection info
CONNECTION_FILE="$SCRIPT_DIR/wodoo-connection.txt"
cat > "$CONNECTION_FILE" << EOF
# Wodoo Deployment Connection Info
# Deployed on: $(date)

Server: $SERVER_HOST
SSH User: $SSH_USER
SSH Port: $SSH_PORT
Access URL: http://$SERVER_IP

# Connect to server
ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST

# View logs
ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST 'sudo journalctl -u wodoo -f'

# Restart service
ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST 'sudo systemctl restart wodoo'

# Edit configuration
ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST 'sudo nano /opt/wodoo/.env'

# Uninstall
ssh -p $SSH_PORT $SSH_USER@$SERVER_HOST 'sudo bash /opt/wodoo/uninstall.sh'
EOF

print_success "Connection info saved to: $CONNECTION_FILE"
echo ""
