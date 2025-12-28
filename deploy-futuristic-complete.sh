#!/bin/bash
#
# Deploy Complete Futuristic UI to Wodoo Server
#

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Deploying Complete Futuristic UI..."
echo "📂 Working from: $SCRIPT_DIR"
echo ""

# Deploy the futuristic HTML
echo "📄 Deploying HTML file..."
sudo cp "$SCRIPT_DIR/frontend/index.html" /opt/wodoo/frontend/index.html

# Update database name from 'welpakco' to 'prod'
echo "🗄️  Updating database name to 'prod'..."
sudo sed -i 's/ODOO_DB=welpakco/ODOO_DB=prod/' /opt/wodoo/.env
sudo sed -i 's/ODOO_DB=.*/ODOO_DB=prod/' /opt/wodoo/.env

# Show the current .env file
echo ""
echo "📋 Current .env configuration:"
sudo cat /opt/wodoo/.env
echo ""

# Restart the service
echo "♻️  Restarting Wodoo service..."
sudo systemctl restart wodoo

# Wait a moment
sleep 2

# Check status
echo ""
echo "📊 Service status:"
sudo systemctl status wodoo --no-pager | head -10

echo ""
echo "✨ Deployment complete!"
echo ""
echo "🌐 Access your futuristic dashboard at:"
echo "   http://192.168.0.11"
echo ""
echo "The dashboard includes:"
echo "  ✅ 3D animated background with particles and wireframe spheres"
echo "  ✅ Glassmorphism design with neon cyan/magenta colors"
echo "  ✅ All 4 functional tabs (Move, Adjust, Locations, Stock)"
echo "  ✅ Smooth animations and transitions"
echo "  ✅ Space Grotesk and Inter fonts"
echo ""
