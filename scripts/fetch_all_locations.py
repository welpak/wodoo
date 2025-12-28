#!/usr/bin/env python3
"""
Fetch all stock locations from Odoo instance
Supports export to CSV or JSON
"""

import sys
import json
import csv
import xmlrpc.client
from datetime import datetime
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / 'backend'))

from app.config import settings


def connect_to_odoo():
    """Connect to Odoo and authenticate"""
    print(f"🔌 Connecting to {settings.ODOO_URL}...")

    # Common endpoint
    common = xmlrpc.client.ServerProxy(f'{settings.ODOO_URL}/xmlrpc/2/common')

    # Authenticate
    uid = common.authenticate(
        settings.ODOO_DB,
        settings.ODOO_USERNAME,
        settings.ODOO_PASSWORD,
        {}
    )

    if not uid:
        raise Exception("Authentication failed! Check your credentials.")

    print(f"✅ Authenticated as user ID: {uid}")

    # Models endpoint
    models = xmlrpc.client.ServerProxy(f'{settings.ODOO_URL}/xmlrpc/2/object')

    return uid, models


def fetch_all_locations(uid, models):
    """Fetch all stock locations from Odoo"""
    print(f"\n📍 Fetching stock locations...")

    # Count total locations
    count = models.execute_kw(
        settings.ODOO_DB, uid, settings.ODOO_PASSWORD,
        'stock.location', 'search_count',
        [[]]
    )

    print(f"📊 Found {count} locations")

    # Fetch all locations
    fields = [
        'id', 'name', 'complete_name', 'barcode', 'usage',
        'location_id', 'parent_path', 'company_id',
        'active', 'create_date', 'write_date'
    ]

    locations = models.execute_kw(
        settings.ODOO_DB, uid, settings.ODOO_PASSWORD,
        'stock.location', 'search_read',
        [[]],
        {
            'fields': fields,
            'order': 'complete_name'
        }
    )

    print(f"✅ Fetched {len(locations)} locations\n")
    return locations


def export_to_json(locations, filename=None):
    """Export locations to JSON file"""
    if not filename:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f'locations_{timestamp}.json'

    filepath = Path(__file__).parent / filename

    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(locations, f, indent=2, ensure_ascii=False, default=str)

    print(f"💾 Exported to JSON: {filepath}")
    return filepath


def export_to_csv(locations, filename=None):
    """Export locations to CSV file"""
    if not filename:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f'locations_{timestamp}.csv'

    filepath = Path(__file__).parent / filename

    if not locations:
        print("⚠️  No locations to export")
        return None

    # Flatten nested fields
    flattened_locations = []
    for loc in locations:
        flat_loc = {}
        for key, value in loc.items():
            if isinstance(value, list) and len(value) == 2 and isinstance(value[0], int):
                flat_loc[f'{key}_id'] = value[0]
                flat_loc[f'{key}_name'] = value[1]
            else:
                flat_loc[key] = value
        flattened_locations.append(flat_loc)

    # Get all unique keys
    fieldnames = set()
    for loc in flattened_locations:
        fieldnames.update(loc.keys())
    fieldnames = sorted(fieldnames)

    with open(filepath, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(flattened_locations)

    print(f"💾 Exported to CSV: {filepath}")
    return filepath


def print_summary(locations):
    """Print a summary of locations"""
    print("\n" + "="*60)
    print("LOCATION SUMMARY")
    print("="*60)

    # Count by usage type
    usage_types = {}
    for loc in locations:
        usage = loc.get('usage', 'unknown')
        usage_types[usage] = usage_types.get(usage, 0) + 1

    print(f"\nTotal Locations: {len(locations)}")
    print("\nBy Usage Type:")
    for usage, count in sorted(usage_types.items()):
        usage_desc = {
            'internal': 'Internal Location',
            'view': 'View (Parent)',
            'supplier': 'Supplier Location',
            'customer': 'Customer Location',
            'inventory': 'Inventory Loss/Adjustment',
            'production': 'Production',
            'transit': 'Transit Location'
        }.get(usage, usage)
        print(f"  {usage_desc}: {count}")

    # Show sample locations
    print(f"\nSample Locations (first 15):")
    print("-" * 60)
    for loc in locations[:15]:
        barcode = loc.get('barcode') or 'N/A'
        complete_name = loc.get('complete_name') or loc.get('name')
        print(f"  [{loc['id']}] {complete_name}")
        print(f"       Barcode: {barcode} | Usage: {loc.get('usage', 'N/A')}")
        print()


def main():
    """Main execution"""
    print("🚀 Odoo Location Fetcher")
    print("="*60)

    try:
        # Connect to Odoo
        uid, models = connect_to_odoo()

        # Fetch all locations
        locations = fetch_all_locations(uid, models)

        # Print summary
        print_summary(locations)

        # Export to both formats
        print("\n" + "="*60)
        print("EXPORTING DATA")
        print("="*60 + "\n")

        export_to_json(locations)
        export_to_csv(locations)

        print("\n✨ Done!\n")

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
