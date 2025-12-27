#!/bin/bash
# Installation script for Wodoo on Ubuntu/Debian

set -e

echo "======================================"
echo "Wodoo Installation Script"
echo "======================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Variables
INSTALL_DIR="/opt/wodoo"
SERVICE_USER="www-data"

# Update system
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install dependencies
echo "Installing dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    nginx \
    git \
    curl

# Create installation directory
echo "Creating installation directory..."
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Copy application files
echo "Copying application files..."
if [ -d "/tmp/wodoo" ]; then
    cp -r /tmp/wodoo/* $INSTALL_DIR/
else
    echo "Please ensure wodoo files are in /tmp/wodoo"
    exit 1
fi

# Create Python virtual environment
echo "Creating Python virtual environment..."
python3 -m venv $INSTALL_DIR/venv

# Activate virtual environment and install dependencies
echo "Installing Python dependencies..."
source $INSTALL_DIR/venv/bin/activate
pip install --upgrade pip
pip install -r $INSTALL_DIR/backend/requirements.txt

# Create .env file if not exists
if [ ! -f "$INSTALL_DIR/.env" ]; then
    echo "Creating .env file..."
    cp $INSTALL_DIR/.env.example $INSTALL_DIR/.env
    echo "⚠️  Please edit $INSTALL_DIR/.env with your Odoo credentials"
fi

# Set permissions
echo "Setting permissions..."
chown -R $SERVICE_USER:$SERVICE_USER $INSTALL_DIR
chmod 600 $INSTALL_DIR/.env

# Install systemd service
echo "Installing systemd service..."
cp $INSTALL_DIR/deploy/wodoo.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable wodoo
systemctl start wodoo

# Configure Nginx
echo "Configuring Nginx..."
cp $INSTALL_DIR/deploy/nginx.conf /etc/nginx/sites-available/wodoo
ln -sf /etc/nginx/sites-available/wodoo /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

# Check service status
echo ""
echo "======================================"
echo "Installation Complete!"
echo "======================================"
echo ""
echo "Service Status:"
systemctl status wodoo --no-pager
echo ""
echo "Next Steps:"
echo "1. Edit the configuration: nano $INSTALL_DIR/.env"
echo "2. Restart the service: systemctl restart wodoo"
echo "3. Access Wodoo at http://YOUR_SERVER_IP"
echo ""
echo "Useful commands:"
echo "  - Check status: systemctl status wodoo"
echo "  - View logs: journalctl -u wodoo -f"
echo "  - Restart service: systemctl restart wodoo"
echo ""
