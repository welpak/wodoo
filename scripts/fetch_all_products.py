#!/usr/bin/env python3
"""
Fetch all products from Odoo instance (Standalone version)
Supports export to CSV or JSON
"""

import os
import sys
import json
import csv
import xmlrpc.client
from datetime import datetime
from pathlib import Path


# Configuration from environment or defaults
ODOO_URL = os.getenv('ODOO_URL', 'https://welpakco.com')
ODOO_DB = os.getenv('ODOO_DB', 'prod')
ODOO_USERNAME = os.getenv('ODOO_USERNAME', 'admin@welpakco.com')
ODOO_PASSWORD = os.getenv('ODOO_PASSWORD', 'Nirvana0rff!')


def connect_to_odoo():
    """Connect to Odoo and authenticate"""
    print(f"🔌 Connecting to {ODOO_URL}...")
    print(f"📚 Database: {ODOO_DB}")
    print(f"👤 Username: {ODOO_USERNAME}")

    # Common endpoint
    common = xmlrpc.client.ServerProxy(f'{ODOO_URL}/xmlrpc/2/common')

    # Authenticate
    uid = common.authenticate(
        ODOO_DB,
        ODOO_USERNAME,
        ODOO_PASSWORD,
        {}
    )

    if not uid:
        raise Exception("Authentication failed! Check your credentials.")

    print(f"✅ Authenticated as user ID: {uid}")

    # Models endpoint
    models = xmlrpc.client.ServerProxy(f'{ODOO_URL}/xmlrpc/2/object')

    return uid, models


def fetch_all_products(uid, models, product_type='all'):
    """
    Fetch all products from Odoo

    Args:
        uid: User ID
        models: XML-RPC models proxy
        product_type: 'all', 'product' (stockable), 'consu' (consumable), 'service'
    """
    print(f"\n📦 Fetching products...")

    # Build domain filter
    if product_type == 'all':
        domain = []
    else:
        domain = [['type', '=', product_type]]

    # First, count total products
    count = models.execute_kw(
        ODOO_DB, uid, ODOO_PASSWORD,
        'product.product', 'search_count',
        [domain]
    )

    print(f"📊 Found {count} products")

    # Fetch all products (in batches if needed)
    all_products = []
    batch_size = 500
    offset = 0

    fields = [
        'id', 'name', 'default_code', 'barcode', 'type',
        'categ_id', 'list_price', 'standard_price',
        'qty_available', 'virtual_available', 'uom_id',
        'active', 'create_date', 'write_date'
    ]

    while offset < count:
        print(f"  Fetching batch {offset + 1} to {min(offset + batch_size, count)}...")

        products = models.execute_kw(
            ODOO_DB, uid, ODOO_PASSWORD,
            'product.product', 'search_read',
            [domain],
            {
                'fields': fields,
                'limit': batch_size,
                'offset': offset,
                'order': 'name'
            }
        )

        all_products.extend(products)
        offset += batch_size

    print(f"✅ Fetched {len(all_products)} products\n")
    return all_products


def export_to_json(products, filename=None):
    """Export products to JSON file"""
    if not filename:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f'products_{timestamp}.json'

    filepath = Path(__file__).parent / filename

    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(products, f, indent=2, ensure_ascii=False, default=str)

    print(f"💾 Exported to JSON: {filepath}")
    return filepath


def export_to_csv(products, filename=None):
    """Export products to CSV file"""
    if not filename:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f'products_{timestamp}.csv'

    filepath = Path(__file__).parent / filename

    if not products:
        print("⚠️  No products to export")
        return None

    # Flatten nested fields (like categ_id which is [id, name])
    flattened_products = []
    for p in products:
        flat_p = {}
        for key, value in p.items():
            if isinstance(value, list) and len(value) == 2 and isinstance(value[0], int):
                # This is an Odoo many2one field [id, "name"]
                flat_p[f'{key}_id'] = value[0]
                flat_p[f'{key}_name'] = value[1]
            else:
                flat_p[key] = value
        flattened_products.append(flat_p)

    # Get all unique keys from all products
    fieldnames = set()
    for p in flattened_products:
        fieldnames.update(p.keys())
    fieldnames = sorted(fieldnames)

    with open(filepath, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(flattened_products)

    print(f"💾 Exported to CSV: {filepath}")
    return filepath


def print_summary(products):
    """Print a summary of products"""
    print("\n" + "="*60)
    print("PRODUCT SUMMARY")
    print("="*60)

    # Count by type
    types = {}
    for p in products:
        ptype = p.get('type', 'unknown')
        types[ptype] = types.get(ptype, 0) + 1

    print(f"\nTotal Products: {len(products)}")
    print("\nBy Type:")
    for ptype, count in sorted(types.items()):
        print(f"  {ptype}: {count}")

    # Show sample products
    print(f"\nSample Products (first 10):")
    print("-" * 60)
    for p in products[:10]:
        barcode = p.get('barcode') or 'N/A'
        code = p.get('default_code') or 'N/A'
        print(f"  [{p['id']}] {p['name']}")
        print(f"       Code: {code} | Barcode: {barcode} | Type: {p.get('type', 'N/A')}")
        print()


def main():
    """Main execution"""
    print("🚀 Odoo Product Fetcher")
    print("="*60)

    try:
        # Connect to Odoo
        uid, models = connect_to_odoo()

        # Fetch all products
        # Options: 'all', 'product' (stockable), 'consu' (consumable), 'service'
        products = fetch_all_products(uid, models, product_type='all')

        # Print summary
        print_summary(products)

        # Export to both formats
        print("\n" + "="*60)
        print("EXPORTING DATA")
        print("="*60 + "\n")

        export_to_json(products)
        export_to_csv(products)

        print("\n✨ Done!\n")

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
