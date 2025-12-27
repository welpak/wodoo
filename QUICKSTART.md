# Wodoo Quick Start Guide

This guide will help you deploy Wodoo to your sandbox server in minutes.

## Prerequisites

- Ubuntu 20.04+ or Debian 11+ server
- SSH access with sudo privileges
- Internet connection

## Deployment Steps

### Step 1: Copy Files to Server

From your local machine, copy the wodoo directory to your server:

```bash
# Option A: Using rsync (recommended)
rsync -avz wodoo/ user@your-server-ip:/tmp/wodoo/

# Option B: Using scp
scp -r wodoo/ user@your-server-ip:/tmp/wodoo/

# Option C: Using git (if you've pushed to a repository)
ssh user@your-server-ip
git clone <your-repository-url> /tmp/wodoo
```

### Step 2: SSH into Your Server

```bash
ssh user@your-server-ip
```

### Step 3: Run the Deployment Script

```bash
cd /tmp/wodoo
sudo bash deploy.sh
```

The script will:
- ✅ Install all dependencies (Python, Nginx, etc.)
- ✅ Create /opt/wodoo directory
- ✅ Set up Python virtual environment
- ✅ Install application
- ✅ Configure systemd service
- ✅ Configure Nginx reverse proxy
- ✅ Start services
- ✅ Run health checks

**Time to complete:** ~3-5 minutes

### Step 4: Configure Odoo Credentials

After deployment, you MUST configure your Odoo credentials:

```bash
sudo nano /opt/wodoo/.env
```

Edit these values:
```bash
ODOO_URL=https://welpakco.com
ODOO_DB=welpakco
ODOO_USERNAME=admin@welpakco.com
ODOO_PASSWORD=your_actual_password_here
```

Save and exit (Ctrl+X, then Y, then Enter)

### Step 5: Restart the Service

```bash
sudo systemctl restart wodoo
```

### Step 6: Access the Application

Open your browser and navigate to:
```
http://your-server-ip
```

You should see the Wodoo interface!

## Verification Commands

Check if everything is running correctly:

```bash
# Check service status
sudo systemctl status wodoo

# Check if backend is responding
curl http://localhost:8000/api/health

# Check if Nginx is working
curl http://localhost/api/health

# View application logs
sudo journalctl -u wodoo -f

# View Nginx logs
sudo tail -f /var/log/nginx/wodoo-error.log
```

Expected outputs:
```bash
# Service status should show "active (running)"
# Health check should return: {"status":"healthy","service":"wodoo-api"}
# Logs should show: "INFO: Application startup complete"
```

## Testing the Application

Once deployed, you can test these features:

1. **Test Connection to Odoo**
   - Open: http://your-server-ip
   - Check the connection indicator in the header
   - Should show green "Connected" status

2. **Search for Products**
   - Go to "Move Products" tab
   - Type in the product search field
   - Should see autocomplete results from Odoo

3. **Search for Locations**
   - In any tab, use the location search
   - Should see your Odoo stock locations

4. **View Stock**
   - Go to "Stock View" tab
   - Should see current inventory levels

## Uninstalling Wodoo

To completely remove Wodoo from your system:

```bash
sudo bash /opt/wodoo/uninstall.sh
```

This will:
- Stop all services
- Remove all application files
- Remove systemd service
- Remove Nginx configuration
- Clean up logs
- Restore default Nginx site

**Note:** System packages (Python, Nginx, etc.) are NOT removed as they may be used by other applications.

## Troubleshooting

### Service Won't Start

```bash
# Check detailed logs
sudo journalctl -u wodoo -n 100 --no-pager

# Check if port 8000 is already in use
sudo lsof -i :8000

# Try starting manually for debugging
cd /opt/wodoo/backend
sudo -u www-data /opt/wodoo/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Can't Connect to Odoo

```bash
# Verify .env configuration
sudo cat /opt/wodoo/.env

# Test Odoo connection from server
curl https://welpakco.com

# Test XML-RPC endpoint
curl https://welpakco.com/xmlrpc/2/common

# Check application logs for connection errors
sudo journalctl -u wodoo -n 50 | grep -i error
```

### Nginx Issues

```bash
# Test Nginx configuration
sudo nginx -t

# Check Nginx status
sudo systemctl status nginx

# Check Nginx error logs
sudo tail -n 100 /var/log/nginx/error.log

# Restart Nginx
sudo systemctl restart nginx
```

### Frontend Not Loading

```bash
# Check if files exist
ls -la /opt/wodoo/frontend/

# Check Nginx access logs
sudo tail -f /var/log/nginx/wodoo-access.log

# Check permissions
sudo chown -R www-data:www-data /opt/wodoo/frontend
```

### Port Already in Use

If port 8000 is already in use:

```bash
# Find what's using the port
sudo lsof -i :8000

# Kill the process (replace PID)
sudo kill -9 <PID>

# Or change the port in .env
sudo nano /opt/wodoo/.env
# Change PORT=8000 to PORT=8001

# Restart service
sudo systemctl restart wodoo
```

## Useful Commands

### Service Management

```bash
# Start service
sudo systemctl start wodoo

# Stop service
sudo systemctl stop wodoo

# Restart service
sudo systemctl restart wodoo

# Check status
sudo systemctl status wodoo

# Enable on boot
sudo systemctl enable wodoo

# Disable on boot
sudo systemctl disable wodoo
```

### Logs

```bash
# Follow application logs
sudo journalctl -u wodoo -f

# View last 100 lines
sudo journalctl -u wodoo -n 100

# View logs since today
sudo journalctl -u wodoo --since today

# View Nginx access logs
sudo tail -f /var/log/nginx/wodoo-access.log

# View Nginx error logs
sudo tail -f /var/log/nginx/wodoo-error.log
```

### Updating the Application

```bash
# Stop service
sudo systemctl stop wodoo

# Pull latest changes (if using git)
cd /opt/wodoo
sudo git pull

# Update Python dependencies
sudo /opt/wodoo/venv/bin/pip install -r /opt/wodoo/backend/requirements.txt

# Restart service
sudo systemctl start wodoo
```

## Security Checklist for Production

- [ ] Change default Odoo password
- [ ] Configure firewall (UFW)
- [ ] Set up SSL/TLS with Let's Encrypt
- [ ] Restrict .env file permissions (already done by script)
- [ ] Set up fail2ban
- [ ] Configure automated backups
- [ ] Set up monitoring/alerts
- [ ] Review Nginx security headers
- [ ] Keep system updated

## Getting Help

If you encounter issues:

1. Check the logs (see commands above)
2. Review the main README.md
3. Check docs/DEPLOYMENT.md for detailed info
4. Review docs/API.md for API documentation

## Next Steps

Once deployed and working:

1. **Configure SSL/TLS** (for production):
   ```bash
   sudo apt-get install certbot python3-certbot-nginx
   sudo certbot --nginx -d your-domain.com
   ```

2. **Set up firewall**:
   ```bash
   sudo ufw allow ssh
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

3. **Test barcode scanners**: Configure your USB scanner to append Enter key after scanning

4. **Train users**: Share the usage documentation

5. **Monitor performance**: Watch logs and system resources

---

**Deployment Time:** ~5 minutes
**Uninstall Time:** ~1 minute
**Server Requirements:** 512MB RAM minimum (1GB+ recommended)
