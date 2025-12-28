# Quick Deployment Guide

Choose your deployment method:

## Method 1: One-Command Remote Deployment (Easiest) ⭐

Run this **from your local machine** to automatically deploy to a remote server:

```bash
cd wodoo
bash remote-deploy.sh
```

The script will:
1. ✅ Ask for server details (IP, username, SSH port)
2. ✅ Optionally configure Odoo credentials
3. ✅ Test SSH connection
4. ✅ Copy files to server
5. ✅ Run deployment automatically
6. ✅ Test the installation
7. ✅ Give you the access URL

**Time: ~5 minutes** (mostly automated)

---

## Method 2: Manual Deployment

### Option A: Clone from GitHub on Server

```bash
# SSH into your server
ssh user@your-server-ip

# Clone repository
git clone https://github.com/welpak/wodoo.git /tmp/wodoo

# Run deployment
cd /tmp/wodoo
sudo bash deploy.sh

# Configure
sudo nano /opt/wodoo/.env
sudo systemctl restart wodoo
```

### Option B: Copy Files from Local Machine

```bash
# From local machine - copy files
rsync -avz wodoo/ user@your-server-ip:/tmp/wodoo/

# SSH into server
ssh user@your-server-ip

# Run deployment
cd /tmp/wodoo
sudo bash deploy.sh

# Configure
sudo nano /opt/wodoo/.env
sudo systemctl restart wodoo
```

---

## Complete Uninstall

Remove everything that was installed:

```bash
# On the server
sudo bash /opt/wodoo/uninstall.sh
```

Or remotely from your local machine:

```bash
ssh user@your-server-ip 'sudo bash /opt/wodoo/uninstall.sh'
```

---

## Quick Commands Reference

### Check Status
```bash
sudo systemctl status wodoo
curl http://localhost/api/health
```

### View Logs
```bash
sudo journalctl -u wodoo -f
sudo tail -f /var/log/nginx/wodoo-error.log
```

### Restart Service
```bash
sudo systemctl restart wodoo
```

### Edit Configuration
```bash
sudo nano /opt/wodoo/.env
sudo systemctl restart wodoo
```

---

## What Gets Installed

- ✅ Python virtual environment at `/opt/wodoo/venv`
- ✅ FastAPI application at `/opt/wodoo/backend`
- ✅ Web interface at `/opt/wodoo/frontend`
- ✅ Systemd service: `wodoo.service`
- ✅ Nginx configuration: `/etc/nginx/sites-available/wodoo`
- ✅ System packages: `python3-pip`, `python3-venv`, `nginx`, `git`, `curl`

---

## Troubleshooting

### Service won't start
```bash
sudo journalctl -u wodoo -n 100
```

### Can't connect to Odoo
```bash
sudo nano /opt/wodoo/.env  # Check credentials
sudo systemctl restart wodoo
curl http://localhost/api/test-connection
```

### Port already in use
```bash
sudo lsof -i :8000
sudo kill -9 <PID>
sudo systemctl restart wodoo
```

---

## Documentation

- **QUICKSTART.md** - Detailed deployment guide
- **README.md** - Full documentation
- **docs/API.md** - API reference
- **docs/DEPLOYMENT.md** - Advanced deployment options

---

## Support

- GitHub: https://github.com/welpak/wodoo
- Issues: https://github.com/welpak/wodoo/issues
- Email: support@welpakco.com
