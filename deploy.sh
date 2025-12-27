#!/bin/bash
#
# Wodoo Deployment Script
# Installs and configures Wodoo on Ubuntu/Debian systems
#

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/wodoo"
SERVICE_USER="www-data"
SERVICE_NAME="wodoo"
NGINX_SITE="wodoo"

# Functions
print_header() {
    echo -e "${BLUE}======================================"
    echo -e "$1"
    echo -e "======================================${NC}"
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

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        print_info "Detected OS: $PRETTY_NAME"
    else
        print_error "Cannot detect OS. This script supports Ubuntu/Debian only."
        exit 1
    fi

    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        print_error "This script supports Ubuntu/Debian only. Detected: $OS"
        exit 1
    fi
}

update_system() {
    print_header "Updating System Packages"
    apt-get update -qq
    print_success "System package list updated"
}

install_dependencies() {
    print_header "Installing Dependencies"

    # List of packages to install
    PACKAGES=(
        "python3"
        "python3-pip"
        "python3-venv"
        "nginx"
        "git"
        "curl"
    )

    print_info "Installing: ${PACKAGES[*]}"

    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${PACKAGES[@]}" > /dev/null 2>&1

    print_success "All dependencies installed"
}

check_python_version() {
    print_header "Checking Python Version"

    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)

    print_info "Python version: $PYTHON_VERSION"

    if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 9 ]); then
        print_warning "Python 3.9+ is recommended. Current: $PYTHON_VERSION"
    else
        print_success "Python version is compatible"
    fi
}

create_install_directory() {
    print_header "Creating Installation Directory"

    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Directory $INSTALL_DIR already exists"
        read -p "Do you want to remove it and continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing existing directory..."
            rm -rf "$INSTALL_DIR"
            print_success "Existing directory removed"
        else
            print_error "Installation cancelled"
            exit 1
        fi
    fi

    mkdir -p "$INSTALL_DIR"
    print_success "Created directory: $INSTALL_DIR"
}

copy_application_files() {
    print_header "Copying Application Files"

    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    print_info "Copying from: $SCRIPT_DIR"
    print_info "Copying to: $INSTALL_DIR"

    # Copy all files
    cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/" 2>/dev/null || true

    # Ensure key directories exist
    mkdir -p "$INSTALL_DIR/backend/app/routers"
    mkdir -p "$INSTALL_DIR/frontend/js"
    mkdir -p "$INSTALL_DIR/deploy"
    mkdir -p "$INSTALL_DIR/docs"

    print_success "Application files copied"
}

setup_python_environment() {
    print_header "Setting Up Python Virtual Environment"

    print_info "Creating virtual environment..."
    python3 -m venv "$INSTALL_DIR/venv"
    print_success "Virtual environment created"

    print_info "Installing Python packages..."
    "$INSTALL_DIR/venv/bin/pip" install --upgrade pip -q
    "$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/backend/requirements.txt" -q
    print_success "Python packages installed"
}

configure_environment() {
    print_header "Configuring Environment"

    if [ ! -f "$INSTALL_DIR/.env" ]; then
        if [ -f "$INSTALL_DIR/.env.example" ]; then
            cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
            print_success "Created .env from .env.example"
            print_warning "⚠️  IMPORTANT: You must edit $INSTALL_DIR/.env with your Odoo credentials!"
            print_warning "⚠️  Run: sudo nano $INSTALL_DIR/.env"
        else
            print_error ".env.example not found. Creating minimal .env..."
            cat > "$INSTALL_DIR/.env" << 'EOF'
# Odoo Configuration
ODOO_URL=https://welpakco.com
ODOO_DB=welpakco
ODOO_USERNAME=admin@welpakco.com
ODOO_PASSWORD=CHANGE_ME

# API Configuration
API_PREFIX=/api/v1
CORS_ORIGINS=["*"]

# Server Configuration
HOST=0.0.0.0
PORT=8000
WORKERS=4
EOF
            print_warning "Created basic .env file - YOU MUST EDIT IT!"
        fi
    else
        print_info ".env file already exists, skipping..."
    fi
}

set_permissions() {
    print_header "Setting Permissions"

    print_info "Setting ownership to $SERVICE_USER:$SERVICE_USER..."
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

    print_info "Securing .env file..."
    chmod 600 "$INSTALL_DIR/.env"

    print_success "Permissions set correctly"
}

install_systemd_service() {
    print_header "Installing Systemd Service"

    if [ -f "$INSTALL_DIR/deploy/wodoo.service" ]; then
        cp "$INSTALL_DIR/deploy/wodoo.service" "/etc/systemd/system/$SERVICE_NAME.service"
        print_success "Service file copied"
    else
        print_warning "Service file not found, creating one..."
        cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=Wodoo - Inventory Location Manager
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/backend
Environment="PATH=$INSTALL_DIR/venv/bin"
EnvironmentFile=$INSTALL_DIR/.env
ExecStart=$INSTALL_DIR/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
Restart=always
RestartSec=10

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF
        print_success "Service file created"
    fi

    print_info "Reloading systemd daemon..."
    systemctl daemon-reload

    print_info "Enabling service..."
    systemctl enable "$SERVICE_NAME"

    print_info "Starting service..."
    systemctl start "$SERVICE_NAME"

    # Wait a moment for service to start
    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service started successfully"
    else
        print_error "Service failed to start. Check logs with: journalctl -u $SERVICE_NAME -n 50"
    fi
}

configure_nginx() {
    print_header "Configuring Nginx"

    # Backup default site if it exists
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        print_info "Backing up and disabling default Nginx site..."
        mv /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default.backup 2>/dev/null || true
    fi

    if [ -f "$INSTALL_DIR/deploy/nginx.conf" ]; then
        cp "$INSTALL_DIR/deploy/nginx.conf" "/etc/nginx/sites-available/$NGINX_SITE"
        print_success "Nginx config copied"
    else
        print_warning "Nginx config not found, creating one..."
        cat > "/etc/nginx/sites-available/$NGINX_SITE" << 'EOF'
server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Frontend static files
    location / {
        root /opt/wodoo/frontend;
        try_files $uri $uri/ /index.html;
        expires 1h;
        add_header Cache-Control "public, must-revalidate, proxy-revalidate";
    }

    # API proxy
    location /api/ {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Logs
    access_log /var/log/nginx/wodoo-access.log;
    error_log /var/log/nginx/wodoo-error.log;
}
EOF
        print_success "Nginx config created"
    fi

    print_info "Enabling Nginx site..."
    ln -sf "/etc/nginx/sites-available/$NGINX_SITE" "/etc/nginx/sites-enabled/$NGINX_SITE"

    print_info "Testing Nginx configuration..."
    if nginx -t 2>&1 | grep -q "successful"; then
        print_success "Nginx configuration is valid"

        print_info "Restarting Nginx..."
        systemctl restart nginx
        print_success "Nginx restarted"
    else
        print_error "Nginx configuration test failed!"
        nginx -t
        exit 1
    fi
}

test_deployment() {
    print_header "Testing Deployment"

    print_info "Waiting for services to stabilize..."
    sleep 3

    # Test backend health
    print_info "Testing backend health endpoint..."
    if curl -s -f http://localhost:8000/api/health > /dev/null; then
        print_success "Backend health check: OK"
    else
        print_error "Backend health check: FAILED"
        print_info "Check logs with: journalctl -u $SERVICE_NAME -n 50"
    fi

    # Test Nginx
    print_info "Testing Nginx proxy..."
    if curl -s -f http://localhost/api/health > /dev/null; then
        print_success "Nginx proxy: OK"
    else
        print_error "Nginx proxy: FAILED"
        print_info "Check logs with: tail -f /var/log/nginx/wodoo-error.log"
    fi

    # Test frontend
    print_info "Testing frontend..."
    if curl -s -f http://localhost/ > /dev/null; then
        print_success "Frontend: OK"
    else
        print_error "Frontend: FAILED"
    fi
}

show_completion_message() {
    print_header "Installation Complete!"

    echo ""
    print_success "Wodoo has been successfully installed!"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}Installation Directory:${NC} $INSTALL_DIR"
    echo -e "${GREEN}Service Name:${NC} $SERVICE_NAME"
    echo -e "${GREEN}Access URL:${NC} http://$(hostname -I | awk '{print $1}')"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT NEXT STEPS:${NC}"
    echo ""
    echo "1. Configure your Odoo credentials:"
    echo -e "   ${BLUE}sudo nano $INSTALL_DIR/.env${NC}"
    echo ""
    echo "2. Restart the service after configuration:"
    echo -e "   ${BLUE}sudo systemctl restart $SERVICE_NAME${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}Useful Commands:${NC}"
    echo ""
    echo "  Check service status:"
    echo -e "    ${BLUE}sudo systemctl status $SERVICE_NAME${NC}"
    echo ""
    echo "  View application logs:"
    echo -e "    ${BLUE}sudo journalctl -u $SERVICE_NAME -f${NC}"
    echo ""
    echo "  View Nginx logs:"
    echo -e "    ${BLUE}sudo tail -f /var/log/nginx/wodoo-error.log${NC}"
    echo ""
    echo "  Restart service:"
    echo -e "    ${BLUE}sudo systemctl restart $SERVICE_NAME${NC}"
    echo ""
    echo "  Restart Nginx:"
    echo -e "    ${BLUE}sudo systemctl restart nginx${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}To uninstall Wodoo completely, run:${NC}"
    echo -e "    ${BLUE}sudo bash $INSTALL_DIR/uninstall.sh${NC}"
    echo ""
}

# Main execution
main() {
    print_header "Wodoo Deployment Script"

    check_root
    detect_os
    update_system
    install_dependencies
    check_python_version
    create_install_directory
    copy_application_files
    setup_python_environment
    configure_environment
    set_permissions
    install_systemd_service
    configure_nginx
    test_deployment
    show_completion_message
}

# Run main function
main "$@"
