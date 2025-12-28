# Wodoo Utility Scripts

This directory contains utility scripts for managing and extracting data from your Odoo instance.

## Prerequisites

Make sure the backend dependencies are installed:

```bash
cd ../backend
pip3 install -r requirements.txt
```

## Available Scripts

### 1. Fetch All Products

**Script:** `fetch_all_products.py`

Fetches all products from your Odoo instance and exports them to JSON and CSV formats.

**Usage:**
```bash
cd scripts
python3 fetch_all_products.py
```

**What it does:**
- Connects to your Odoo instance
- Fetches ALL products (handles pagination automatically)
- Shows a summary with product counts by type
- Exports to both JSON and CSV files with timestamps

**Output files:**
- `products_YYYYMMDD_HHMMSS.json` - Full product data in JSON format
- `products_YYYYMMDD_HHMMSS.csv` - Product data in CSV format (Excel-compatible)

**Fields included:**
- ID, Name, Code, Barcode
- Type (product/consumable/service)
- Category
- List Price, Cost Price
- Available Quantity
- And more...

---

### 2. Fetch All Locations

**Script:** `fetch_all_locations.py`

Fetches all stock locations from your Odoo instance.

**Usage:**
```bash
cd scripts
python3 fetch_all_locations.py
```

**What it does:**
- Connects to your Odoo instance
- Fetches ALL stock locations
- Shows a summary with location counts by usage type
- Exports to both JSON and CSV files with timestamps

**Output files:**
- `locations_YYYYMMDD_HHMMSS.json` - Full location data in JSON format
- `locations_YYYYMMDD_HHMMSS.csv` - Location data in CSV format

**Fields included:**
- ID, Name, Complete Name
- Barcode
- Usage Type (internal/view/supplier/customer/etc.)
- Parent Location
- Active status
- And more...

---

## Configuration

These scripts use the same configuration as the main Wodoo application:

- **URL:** From `ODOO_URL` environment variable (default: welpakco.com)
- **Database:** From `ODOO_DB` environment variable (default: prod)
- **Credentials:** From `ODOO_USERNAME` and `ODOO_PASSWORD`

Configuration is loaded from `/opt/wodoo/.env` or backend config.

---

## Examples

### View all products in your inventory:
```bash
python3 fetch_all_products.py
```

Sample output:
```
🚀 Odoo Product Fetcher
============================================================
🔌 Connecting to https://welpakco.com...
✅ Authenticated as user ID: 2

📦 Fetching products...
📊 Found 1,234 products
  Fetching batch 1 to 500...
  Fetching batch 501 to 1000...
  Fetching batch 1001 to 1234...
✅ Fetched 1,234 products

============================================================
PRODUCT SUMMARY
============================================================

Total Products: 1,234

By Type:
  consu: 45
  product: 1,150
  service: 39

Sample Products (first 10):
------------------------------------------------------------
  [123] Widget ABC
       Code: WID-001 | Barcode: 1234567890 | Type: product

...
```

### Export locations:
```bash
python3 fetch_all_locations.py
```

### Import CSV into Excel:
The CSV files can be opened directly in Excel, Google Sheets, or any spreadsheet application for further analysis.

---

## Troubleshooting

**Authentication Error:**
- Check your `.env` file has correct credentials
- Verify database name is set to "prod"

**Connection Error:**
- Ensure you can reach welpakco.com from your server
- Check firewall settings

**Import Error:**
- Run from the `scripts` directory
- Ensure backend dependencies are installed

---

## Future Scripts

Coming soon:
- `fetch_stock_levels.py` - Export current stock quantities
- `import_products.py` - Bulk import products from CSV
- `generate_barcodes.py` - Generate and assign barcodes
- `stock_report.py` - Generate stock movement reports

---

**Last Updated:** December 2025
