# Wodoo Deployment Guide

Complete deployment guide for Ubuntu/Debian Linux servers.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Deployment Methods](#deployment-methods)
- [Docker Deployment](#docker-deployment)
- [Native Linux Deployment](#native-linux-deployment)
- [Reverse Proxy Configuration](#reverse-proxy-configuration)
- [SSL/TLS Setup](#ssltls-setup)
- [Security Hardening](#security-hardening)
- [Monitoring](#monitoring)
- [Backup & Recovery](#backup--recovery)

## Prerequisites

### System Requirements

- **OS**: Ubuntu 20.04+ or Debian 11+
- **RAM**: Minimum 512MB (1GB+ recommended)
- **CPU**: 1 core minimum (2+ recommended)
- **Disk**: 2GB free space
- **Network**: Internet access for package installation

### Software Requirements

- Python 3.11+
- Nginx (for reverse proxy)
- Docker & Docker Compose (for Docker deployment)
- Git

## Deployment Methods

### Method 1: Docker (Recommended for Production)

**Pros:**
- Isolated environment
- Easy to update
- Portable
- Consistent across environments

**Cons:**
- Requires Docker installation
- Slightly more resource usage

### Method 2: Native Installation

**Pros:**
- Direct system integration
- Lower resource overhead
- Full control

**Cons:**
- More manual configuration
- System-dependent

## Docker Deployment

### Step 1: Install Docker

```bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt-get install docker-compose -y

# Add user to docker group (optional)
sudo usermod -aG docker $USER
newgrp docker
```

### Step 2: Clone and Configure

```bash
# Clone repository
git clone https://github.com/yourusername/wodoo.git
cd wodoo

# Create environment file
cp .env.example .env
nano .env
```

Edit `.env` with your Odoo credentials:
```bash
ODOO_URL=https://welpakco.com
ODOO_DB=welpakco
ODOO_USERNAME=admin@welpakco.com
ODOO_PASSWORD=your_secure_password
```

### Step 3: Deploy

```bash
# Start the application
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

### Step 4: Test

```bash
# Test connection
curl http://localhost:8000/api/test-connection

# Access application
# Visit http://your-server-ip:8000
```

### Docker Management Commands

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# Restart
docker-compose restart

# Update (pull latest changes)
git pull
docker-compose up -d --build

# View logs
docker-compose logs -f wodoo

# Execute commands in container
docker-compose exec wodoo bash
```

## Native Linux Deployment

### Step 1: Install System Dependencies

```bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install dependencies
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    nginx \
    git \
    curl
```

### Step 2: Automated Installation

```bash
# Clone to temporary location
git clone https://github.com/yourusername/wodoo.git /tmp/wodoo

# Run installation script
sudo bash /tmp/wodoo/deploy/install.sh
```

The script will:
1. Install system dependencies
2. Create `/opt/wodoo` directory
3. Set up Python virtual environment
4. Install Python packages
5. Configure systemd service
6. Configure Nginx
7. Start services

### Step 3: Configure

```bash
# Edit configuration
sudo nano /opt/wodoo/.env

# Restart service
sudo systemctl restart wodoo
```

### Step 4: Verify

```bash
# Check service status
sudo systemctl status wodoo

# Check Nginx status
sudo systemctl status nginx

# View logs
sudo journalctl -u wodoo -f

# Test connection
curl http://localhost:8000/api/test-connection
```

### Manual Installation Steps

If you prefer manual installation:

```bash
# Create directory
sudo mkdir -p /opt/wodoo
cd /opt/wodoo

# Clone repository
sudo git clone https://github.com/yourusername/wodoo.git .

# Create virtual environment
sudo python3 -m venv venv

# Install dependencies
sudo /opt/wodoo/venv/bin/pip install -r backend/requirements.txt

# Create .env file
sudo cp .env.example .env
sudo nano .env

# Set permissions
sudo chown -R www-data:www-data /opt/wodoo
sudo chmod 600 /opt/wodoo/.env

# Install systemd service
sudo cp deploy/wodoo.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable wodoo
sudo systemctl start wodoo

# Configure Nginx
sudo cp deploy/nginx.conf /etc/nginx/sites-available/wodoo
sudo ln -s /etc/nginx/sites-available/wodoo /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

## Reverse Proxy Configuration

### Nginx as Reverse Proxy

The provided `nginx.conf` configures Nginx to:
- Serve static frontend files
- Proxy API requests to FastAPI backend
- Add security headers
- Handle caching

**Custom Domain Setup:**

```bash
# Edit Nginx config
sudo nano /etc/nginx/sites-available/wodoo
```

Change `server_name _;` to `server_name your-domain.com;`

```bash
# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

### Apache as Reverse Proxy (Alternative)

```apache
<VirtualHost *:80>
    ServerName your-domain.com

    ProxyPreserveHost On
    ProxyPass /api/ http://localhost:8000/api/
    ProxyPassReverse /api/ http://localhost:8000/api/

    DocumentRoot /opt/wodoo/frontend
    <Directory /opt/wodoo/frontend>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

## SSL/TLS Setup

### Using Let's Encrypt (Recommended)

```bash
# Install Certbot
sudo apt-get install certbot python3-certbot-nginx -y

# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal is configured automatically
# Test renewal
sudo certbot renew --dry-run
```

### Manual SSL Certificate

If you have your own SSL certificate:

```bash
# Copy certificates
sudo cp your-cert.crt /etc/ssl/certs/
sudo cp your-key.key /etc/ssl/private/

# Update Nginx config
sudo nano /etc/nginx/sites-available/wodoo
```

Add SSL configuration:
```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/ssl/certs/your-cert.crt;
    ssl_certificate_key /etc/ssl/private/your-key.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # ... rest of configuration
}

server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
```

## Security Hardening

### Firewall Configuration

```bash
# Install UFW
sudo apt-get install ufw -y

# Configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable
sudo ufw status
```

### Secure Environment File

```bash
# Restrict .env permissions
sudo chmod 600 /opt/wodoo/.env
sudo chown www-data:www-data /opt/wodoo/.env
```

### Fail2ban Setup

Protect against brute force attacks:

```bash
# Install fail2ban
sudo apt-get install fail2ban -y

# Create Nginx filter
sudo nano /etc/fail2ban/filter.d/nginx-wodoo.conf
```

Add:
```ini
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" (4|5)\d\d
ignoreregex =
```

Configure jail:
```bash
sudo nano /etc/fail2ban/jail.local
```

Add:
```ini
[nginx-wodoo]
enabled = true
port = http,https
filter = nginx-wodoo
logpath = /var/log/nginx/wodoo-error.log
maxretry = 5
bantime = 3600
```

Restart:
```bash
sudo systemctl restart fail2ban
```

## Monitoring

### System Monitoring

```bash
# Install monitoring tools
sudo apt-get install htop iotop nethogs -y
```

### Application Logs

```bash
# View service logs
sudo journalctl -u wodoo -f

# Nginx access logs
sudo tail -f /var/log/nginx/wodoo-access.log

# Nginx error logs
sudo tail -f /var/log/nginx/wodoo-error.log
```

### Health Checks

Create monitoring script:

```bash
sudo nano /usr/local/bin/wodoo-healthcheck.sh
```

```bash
#!/bin/bash
HEALTH_URL="http://localhost:8000/api/health"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL)

if [ $RESPONSE -ne 200 ]; then
    echo "Wodoo health check failed (HTTP $RESPONSE)"
    systemctl restart wodoo
    echo "$(date): Service restarted" >> /var/log/wodoo-health.log
fi
```

```bash
sudo chmod +x /usr/local/bin/wodoo-healthcheck.sh
```

Add to crontab:
```bash
sudo crontab -e
```

Add:
```
*/5 * * * * /usr/local/bin/wodoo-healthcheck.sh
```

### Performance Monitoring

Install and configure monitoring:

```bash
# Install Prometheus node exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-*.tar.gz
sudo cp node_exporter-*/node_exporter /usr/local/bin/
sudo useradd -rs /bin/false node_exporter

# Create systemd service
sudo nano /etc/systemd/system/node_exporter.service
```

```ini
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
```

## Backup & Recovery

### Automated Backup Script

```bash
sudo nano /usr/local/bin/wodoo-backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/wodoo"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup application
tar -czf $BACKUP_DIR/wodoo-app-$DATE.tar.gz /opt/wodoo

# Backup Nginx config
cp /etc/nginx/sites-available/wodoo $BACKUP_DIR/nginx-$DATE.conf

# Keep only last 7 days
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.conf" -mtime +7 -delete

echo "$(date): Backup completed" >> /var/log/wodoo-backup.log
```

```bash
sudo chmod +x /usr/local/bin/wodoo-backup.sh
```

Schedule daily backup:
```bash
sudo crontab -e
```

Add:
```
0 2 * * * /usr/local/bin/wodoo-backup.sh
```

### Recovery Procedure

```bash
# Stop service
sudo systemctl stop wodoo
sudo systemctl stop nginx

# Restore from backup
sudo tar -xzf /var/backups/wodoo/wodoo-app-YYYYMMDD_HHMMSS.tar.gz -C /

# Restore Nginx config
sudo cp /var/backups/wodoo/nginx-YYYYMMDD_HHMMSS.conf /etc/nginx/sites-available/wodoo

# Restart services
sudo systemctl start wodoo
sudo systemctl start nginx
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs
sudo journalctl -u wodoo -n 100 --no-pager

# Test manually
sudo -u www-data /opt/wodoo/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000

# Check permissions
ls -la /opt/wodoo

# Verify Python environment
/opt/wodoo/venv/bin/python --version
/opt/wodoo/venv/bin/pip list
```

### Nginx Issues

```bash
# Test configuration
sudo nginx -t

# Check error logs
sudo tail -n 100 /var/log/nginx/error.log

# Verify backend is running
curl http://localhost:8000/api/health
```

### Connection to Odoo Fails

```bash
# Test from server
curl https://welpakco.com

# Check .env configuration
sudo cat /opt/wodoo/.env

# Test XML-RPC connection manually
python3 -c "
import xmlrpc.client
common = xmlrpc.client.ServerProxy('https://welpakco.com/xmlrpc/2/common')
print(common.version())
"
```

## Updates and Maintenance

### Updating Wodoo

**Docker:**
```bash
cd /path/to/wodoo
git pull
docker-compose up -d --build
```

**Native:**
```bash
sudo systemctl stop wodoo
cd /opt/wodoo
sudo git pull
sudo /opt/wodoo/venv/bin/pip install -r backend/requirements.txt
sudo systemctl start wodoo
```

### System Updates

```bash
# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Restart services if needed
sudo systemctl restart wodoo
sudo systemctl restart nginx
```

## Production Checklist

- [ ] SSL/TLS configured and working
- [ ] Firewall configured (only 80, 443, 22 open)
- [ ] Strong Odoo password in `.env`
- [ ] `.env` file permissions set to 600
- [ ] Fail2ban configured
- [ ] Automated backups configured
- [ ] Health checks configured
- [ ] Monitoring set up
- [ ] Log rotation configured
- [ ] DNS configured correctly
- [ ] Tested barcode scanners
- [ ] Load tested with expected traffic

---

For additional support, refer to the main README.md or contact support@welpakco.com
