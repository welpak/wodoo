# Wodoo - Welpak Odoo Inventory Location Manager

A fast, lightweight web application for managing inventory locations in Odoo 16 Community Edition. Designed for speed and efficiency with barcode scanner support.

## Features

- **Fast Inventory Operations**
  - Move products between locations
  - Add/remove inventory at locations
  - Barcode scanner support for products and locations
  - Real-time stock visibility

- **Location Management**
  - Create new locations
  - Delete locations
  - Search and filter locations
  - View stock at specific locations

- **Modern Web Interface**
  - Responsive design (mobile-friendly)
  - Real-time search and autocomplete
  - Clean, intuitive UI with Alpine.js
  - Fast page loads with TailwindCSS

- **Production Ready**
  - Docker deployment
  - Systemd service for native Linux
  - Nginx reverse proxy configuration
  - Health checks and monitoring

## Architecture

### Backend
- **Framework**: FastAPI (Python 3.11+)
- **Odoo Integration**: XML-RPC
- **API**: RESTful JSON API
- **Server**: Uvicorn (ASGI)

### Frontend
- **UI Framework**: Alpine.js 3.x
- **Styling**: TailwindCSS 3.x
- **Icons**: Font Awesome 6.x
- **Vanilla JavaScript** (no build step required)

## Quick Start

### Prerequisites
- Linux server (Ubuntu/Debian recommended)
- Python 3.11+
- Nginx (for reverse proxy)
- Access to Odoo 16 API

### Option 1: Docker Deployment (Recommended)

1. Clone the repository:
```bash
git clone https://github.com/welpak/wodoo.git
cd wodoo
```

2. Create `.env` file:
```bash
cp .env.example .env
nano .env  # Edit with your Odoo credentials
```

3. Start with Docker Compose:
```bash
docker-compose up -d
```

4. Access the application:
```
http://your-server-ip:8000
```

### Option 2: Native Linux Installation

1. Run the installation script:
```bash
sudo cp -r wodoo /tmp/
sudo bash /tmp/wodoo/deploy/install.sh
```

2. Configure environment:
```bash
sudo nano /opt/wodoo/.env
```

3. Restart the service:
```bash
sudo systemctl restart wodoo
```

4. Access the application:
```
http://your-server-ip
```

## Configuration

### Environment Variables

Edit `.env` file with your settings:

```bash
# Odoo Configuration
ODOO_URL=https://welpakco.com
ODOO_DB=welpakco
ODOO_USERNAME=admin@welpakco.com
ODOO_PASSWORD=your_password_here

# API Configuration
API_PREFIX=/api/v1
CORS_ORIGINS=["*"]

# Server Configuration
HOST=0.0.0.0
PORT=8000
WORKERS=4
```

## Usage

### Move Products Between Locations

1. Navigate to **Move Products** tab
2. Scan or search for the product
3. Scan or search for source location
4. Scan or search for destination location
5. Enter quantity
6. Click **Move Product**

### Adjust Inventory

1. Navigate to **Adjust Inventory** tab
2. Scan or search for the product
3. Scan or search for the location
4. Enter quantity (positive to add, negative to remove)
5. Click **Adjust Inventory**

### Manage Locations

1. Navigate to **Locations** tab
2. Click **Add Location** to create new locations
3. Use the search bar to find locations
4. Click **View Stock** to see inventory at a location
5. Click **Delete** to remove a location

### View Stock

1. Navigate to **Stock View** tab
2. See all stock quantities across locations
3. Use filters to narrow results

## API Documentation

### Interactive API Docs

Access the auto-generated API documentation:
- **Swagger UI**: http://your-server/api/docs
- **ReDoc**: http://your-server/api/redoc

### Key Endpoints

#### Inventory Operations
- `POST /api/v1/inventory/move` - Move products between locations
- `POST /api/v1/inventory/adjust` - Add/remove inventory
- `GET /api/v1/inventory/products` - Search products
- `GET /api/v1/inventory/stock` - View stock levels

#### Location Management
- `GET /api/v1/locations/` - List locations
- `POST /api/v1/locations/` - Create location
- `GET /api/v1/locations/{id}` - Get location details
- `DELETE /api/v1/locations/{id}` - Delete location

## Deployment

### Systemd Service Management

```bash
# Start service
sudo systemctl start wodoo

# Stop service
sudo systemctl stop wodoo

# Restart service
sudo systemctl restart wodoo

# Check status
sudo systemctl status wodoo

# View logs
sudo journalctl -u wodoo -f
```

### Nginx Configuration

The installation script automatically configures Nginx as a reverse proxy. The configuration:
- Serves frontend static files
- Proxies `/api/` requests to the FastAPI backend
- Includes security headers
- Handles caching appropriately

### Docker Management

```bash
# Start containers
docker-compose up -d

# Stop containers
docker-compose down

# View logs
docker-compose logs -f

# Rebuild after changes
docker-compose up -d --build
```

## Performance Optimization

### For High-Traffic Environments

1. **Increase Workers**: Edit `.env` and increase `WORKERS=8`
2. **Enable Caching**: Add Redis for API response caching
3. **Database Connection Pool**: Configure connection pooling in Odoo
4. **CDN**: Serve static assets from CDN

### Barcode Scanner Optimization

- Use USB barcode scanners configured as keyboard input
- Scanner should append Enter key after barcode
- Test scanner with both product and location barcodes

## Troubleshooting

### Connection Issues

```bash
# Test Odoo connection
curl http://localhost:8000/api/test-connection
```

### Service Not Starting

```bash
# Check logs
journalctl -u wodoo -n 50

# Verify Python environment
/opt/wodoo/venv/bin/python --version

# Test manually
cd /opt/wodoo/backend
/opt/wodoo/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Nginx Issues

```bash
# Test Nginx configuration
sudo nginx -t

# Check Nginx logs
sudo tail -f /var/log/nginx/wodoo-error.log
```

## Security

### Best Practices

1. **Change Default Credentials**: Update Odoo password in `.env`
2. **Use HTTPS**: Configure SSL/TLS with Let's Encrypt
3. **Firewall**: Only expose port 80/443, block port 8000
4. **Regular Updates**: Keep system and dependencies updated
5. **Secure .env**: Ensure `.env` file has restricted permissions (600)

### SSL/TLS Configuration

Use Certbot for Let's Encrypt:

```bash
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

## Development

### Local Development Setup

```bash
# Create virtual environment
cd backend
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Project Structure

```
wodoo/
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py              # FastAPI application
│   │   ├── config.py            # Configuration management
│   │   ├── odoo_client.py       # Odoo XML-RPC client
│   │   ├── models.py            # Pydantic models
│   │   └── routers/
│   │       ├── locations.py     # Location endpoints
│   │       └── inventory.py     # Inventory endpoints
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/
│   ├── index.html               # Main UI
│   └── js/
│       └── app.js               # Alpine.js application
├── deploy/
│   ├── install.sh               # Installation script
│   ├── wodoo.service            # Systemd service
│   └── nginx.conf               # Nginx configuration
├── docker-compose.yml
├── .env.example
└── README.md
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:
- GitHub Issues: https://github.com/welpak/wodoo/issues
- Email: support@welpakco.com

## Acknowledgments

- FastAPI framework
- Alpine.js for reactive UI
- TailwindCSS for styling
- Odoo community

---

**Wodoo** - Making inventory management fast and simple.
