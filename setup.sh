#!/bin/bash
#
# Quick setup script to checkout the Wodoo branch and deploy
#

set -e  # Exit on any error

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Wodoo Quick Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if we're already in the wodoo directory
if [ -d ".git" ] && [ -f "README.md" ]; then
    echo -e "${GREEN}✓ Already in wodoo directory${NC}"
else
    # Check if wodoo directory exists
    if [ -d "wodoo" ]; then
        echo -e "${GREEN}✓ Found wodoo directory${NC}"
        cd wodoo
    else
        echo -e "${YELLOW}Cloning wodoo repository...${NC}"
        git clone https://github.com/welpak/wodoo.git
        cd wodoo
        echo -e "${GREEN}✓ Repository cloned${NC}"
    fi
fi

# Checkout the correct branch
echo ""
echo -e "${YELLOW}Checking out branch: claude/inventory-location-module-cNvqY${NC}"
git checkout claude/inventory-location-module-cNvqY
echo -e "${GREEN}✓ Branch checked out${NC}"

# Show files
echo ""
echo -e "${BLUE}Files in directory:${NC}"
ls -lh --color=auto

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "You now have access to:"
echo "  • deploy.sh - Deploy locally on this machine"
echo "  • remote-deploy.sh - Deploy to a remote server"
echo "  • uninstall.sh - Remove everything"
echo ""
echo -e "${BLUE}Choose your deployment option:${NC}"
echo ""
echo "1. Deploy locally (on this machine):"
echo -e "   ${YELLOW}sudo bash deploy.sh${NC}"
echo ""
echo "2. Deploy to a remote server:"
echo -e "   ${YELLOW}bash remote-deploy.sh${NC}"
echo ""
read -p "Would you like to deploy now? (1=local, 2=remote, N=skip): " DEPLOY_CHOICE

case $DEPLOY_CHOICE in
    1)
        echo ""
        echo -e "${GREEN}Starting local deployment...${NC}"
        sudo bash deploy.sh
        ;;
    2)
        echo ""
        echo -e "${GREEN}Starting remote deployment...${NC}"
        bash remote-deploy.sh
        ;;
    *)
        echo ""
        echo -e "${YELLOW}Skipping deployment. Run manually when ready:${NC}"
        echo -e "  ${BLUE}sudo bash deploy.sh${NC} (local)"
        echo -e "  ${BLUE}bash remote-deploy.sh${NC} (remote)"
        ;;
esac

echo ""
echo -e "${GREEN}Done!${NC}"
