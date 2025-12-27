#!/bin/bash
#
# Wodoo Complete Uninstall Script
# Removes ALL components installed by the deployment script
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

confirm_uninstall() {
    print_header "Wodoo Complete Uninstall"
    echo ""
    print_warning "This will COMPLETELY remove Wodoo from your system including:"
    echo "  - Application files in $INSTALL_DIR"
    echo "  - Systemd service ($SERVICE_NAME)"
    echo "  - Nginx configuration"
    echo "  - All logs"
    echo ""
    print_error "This action CANNOT be undone!"
    echo ""
    read -p "Are you absolutely sure you want to continue? (type 'yes' to confirm): " -r
    echo
    if [[ ! $REPLY == "yes" ]]; then
        print_info "Uninstall cancelled."
        exit 0
    fi
    echo ""
}

stop_services() {
    print_header "Stopping Services"

    # Stop Wodoo service
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_info "Stopping $SERVICE_NAME service..."
        systemctl stop "$SERVICE_NAME"
        print_success "Service stopped"
    else
        print_info "Service $SERVICE_NAME is not running"
    fi

    # We don't stop Nginx as it might be used by other sites
    print_info "Nginx will be restarted (not stopped)"
}

disable_service() {
    print_header "Disabling Systemd Service"

    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        print_info "Disabling $SERVICE_NAME service..."
        systemctl disable "$SERVICE_NAME"
        print_success "Service disabled"
    else
        print_info "Service $SERVICE_NAME is not enabled"
    fi
}

remove_systemd_service() {
    print_header "Removing Systemd Service File"

    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        print_info "Removing service file..."
        rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        print_success "Service file removed"

        print_info "Reloading systemd daemon..."
        systemctl daemon-reload
        systemctl reset-failed 2>/dev/null || true
        print_success "Systemd daemon reloaded"
    else
        print_info "Service file not found, skipping..."
    fi
}

remove_nginx_config() {
    print_header "Removing Nginx Configuration"

    # Remove enabled site link
    if [ -L "/etc/nginx/sites-enabled/$NGINX_SITE" ]; then
        print_info "Removing enabled site link..."
        rm -f "/etc/nginx/sites-enabled/$NGINX_SITE"
        print_success "Enabled site link removed"
    fi

    # Remove available site config
    if [ -f "/etc/nginx/sites-available/$NGINX_SITE" ]; then
        print_info "Removing site configuration..."
        rm -f "/etc/nginx/sites-available/$NGINX_SITE"
        print_success "Site configuration removed"
    fi

    # Restore default site if backup exists
    if [ -f "/etc/nginx/sites-available/default.backup" ]; then
        print_info "Restoring default Nginx site..."
        mv /etc/nginx/sites-available/default.backup /etc/nginx/sites-available/default
        ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
        print_success "Default site restored"
    fi

    # Test and reload Nginx
    print_info "Testing Nginx configuration..."
    if nginx -t 2>&1 | grep -q "successful"; then
        print_success "Nginx configuration is valid"

        print_info "Reloading Nginx..."
        systemctl reload nginx
        print_success "Nginx reloaded"
    else
        print_warning "Nginx configuration test failed. You may need to fix it manually."
    fi
}

remove_nginx_logs() {
    print_header "Removing Nginx Logs"

    if [ -f "/var/log/nginx/wodoo-access.log" ]; then
        print_info "Removing Nginx access log..."
        rm -f /var/log/nginx/wodoo-access.log*
        print_success "Access log removed"
    fi

    if [ -f "/var/log/nginx/wodoo-error.log" ]; then
        print_info "Removing Nginx error log..."
        rm -f /var/log/nginx/wodoo-error.log*
        print_success "Error log removed"
    fi
}

remove_application_files() {
    print_header "Removing Application Files"

    if [ -d "$INSTALL_DIR" ]; then
        print_info "Removing $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
        print_success "Application directory removed"
    else
        print_info "Application directory not found, skipping..."
    fi
}

remove_systemd_logs() {
    print_header "Cleaning Systemd Journal Logs"

    print_info "Rotating and vacuuming journal logs for $SERVICE_NAME..."
    journalctl --rotate 2>/dev/null || true
    journalctl --vacuum-time=1s --identifier="$SERVICE_NAME" 2>/dev/null || true
    print_success "Systemd logs cleaned"
}

cleanup_package_dependencies() {
    print_header "Checking Package Dependencies"

    print_warning "The following packages were installed during deployment:"
    echo "  - python3, python3-pip, python3-venv"
    echo "  - nginx"
    echo "  - git"
    echo "  - curl"
    echo ""
    print_info "These packages are NOT being removed as they may be used by other applications."
    print_info "If you want to remove them, you can do so manually with:"
    echo -e "  ${BLUE}sudo apt-get remove python3-pip python3-venv nginx git${NC}"
    echo -e "  ${BLUE}sudo apt-get autoremove${NC}"
    echo ""
}

verify_removal() {
    print_header "Verifying Removal"

    ISSUES_FOUND=false

    # Check if service file exists
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        print_error "Service file still exists"
        ISSUES_FOUND=true
    else
        print_success "Service file removed"
    fi

    # Check if Nginx config exists
    if [ -f "/etc/nginx/sites-available/$NGINX_SITE" ] || [ -L "/etc/nginx/sites-enabled/$NGINX_SITE" ]; then
        print_error "Nginx configuration still exists"
        ISSUES_FOUND=true
    else
        print_success "Nginx configuration removed"
    fi

    # Check if install directory exists
    if [ -d "$INSTALL_DIR" ]; then
        print_error "Installation directory still exists"
        ISSUES_FOUND=true
    else
        print_success "Installation directory removed"
    fi

    # Check if service is running
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        print_error "Service is still running"
        ISSUES_FOUND=true
    else
        print_success "Service is not running"
    fi

    if [ "$ISSUES_FOUND" = true ]; then
        echo ""
        print_warning "Some components may not have been removed completely."
        print_info "Please review the errors above."
    fi
}

show_completion_message() {
    print_header "Uninstall Complete!"

    echo ""
    print_success "Wodoo has been completely removed from your system!"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}Removed Components:${NC}"
    echo "  ✓ Application files ($INSTALL_DIR)"
    echo "  ✓ Systemd service ($SERVICE_NAME)"
    echo "  ✓ Nginx configuration"
    echo "  ✓ Application logs"
    echo ""
    echo -e "${YELLOW}Not Removed (may be used by other apps):${NC}"
    echo "  • Python packages (python3, pip, venv)"
    echo "  • Nginx (web server)"
    echo "  • Git"
    echo "  • Curl"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}To remove Python and Nginx (if not needed):${NC}"
    echo -e "  ${BLUE}sudo apt-get remove python3-pip python3-venv nginx git${NC}"
    echo -e "  ${BLUE}sudo apt-get autoremove${NC}"
    echo ""
    echo -e "${GREEN}To reinstall Wodoo:${NC}"
    echo -e "  ${BLUE}git clone <repository-url>${NC}"
    echo -e "  ${BLUE}cd wodoo${NC}"
    echo -e "  ${BLUE}sudo bash deploy.sh${NC}"
    echo ""
}

# Main execution
main() {
    check_root
    confirm_uninstall
    stop_services
    disable_service
    remove_systemd_service
    remove_nginx_config
    remove_nginx_logs
    remove_application_files
    remove_systemd_logs
    cleanup_package_dependencies
    verify_removal
    show_completion_message
}

# Run main function
main "$@"
