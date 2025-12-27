# Wodoo API Documentation

Complete API reference for the Wodoo Inventory Location Manager.

## Base URL

```
http://your-server/api/v1
```

## Authentication

Currently uses Odoo credentials configured in backend. API endpoints do not require separate authentication.

## Endpoints

### Health & Status

#### GET /api/health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "service": "wodoo-api"
}
```

#### GET /api/test-connection

Test connection to Odoo server.

**Response:**
```json
{
  "success": true,
  "version": {...},
  "uid": 2,
  "message": "Successfully connected to Odoo"
}
```

---

### Locations

#### GET /api/v1/locations/

Get all stock locations with optional filters.

**Query Parameters:**
- `search` (string): Search by name
- `parent_id` (integer): Filter by parent location
- `usage` (string): Filter by usage type (internal, view, etc.)
- `limit` (integer): Max results (default: 100, max: 500)

**Example Request:**
```bash
curl "http://localhost:8000/api/v1/locations/?search=warehouse&limit=20"
```

**Response:**
```json
[
  {
    "id": 8,
    "name": "WH/Stock",
    "complete_name": "WH/Stock",
    "barcode": "LOC-001",
    "location_id": [7, "WH"],
    "usage": "internal"
  }
]
```

#### GET /api/v1/locations/{location_id}

Get a specific location by ID.

**Response:**
```json
{
  "id": 8,
  "name": "WH/Stock",
  "complete_name": "WH/Stock",
  "barcode": "LOC-001",
  "location_id": [7, "WH"],
  "usage": "internal"
}
```

#### GET /api/v1/locations/barcode/{barcode}

Search for a location by barcode.

**Response:** Same as get location by ID

#### POST /api/v1/locations/

Create a new stock location.

**Request Body:**
```json
{
  "name": "New Location",
  "barcode": "LOC-123",
  "location_id": 8,
  "usage": "internal"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Location created successfully",
  "data": {
    "id": 15
  }
}
```

#### PUT /api/v1/locations/{location_id}

Update an existing location.

**Request Body:**
```json
{
  "name": "Updated Name",
  "barcode": "NEW-BARCODE"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Location 15 updated successfully"
}
```

#### DELETE /api/v1/locations/{location_id}

Delete a location.

**Response:**
```json
{
  "success": true,
  "message": "Location 15 deleted successfully"
}
```

---

### Inventory

#### GET /api/v1/inventory/products

Search for products.

**Query Parameters:**
- `search` (string): Search by name, code, or barcode
- `limit` (integer): Max results (default: 50, max: 200)

**Example Request:**
```bash
curl "http://localhost:8000/api/v1/inventory/products?search=laptop&limit=10"
```

**Response:**
```json
[
  {
    "id": 25,
    "name": "Laptop Dell XPS 13",
    "default_code": "DELL-XPS13",
    "barcode": "1234567890",
    "type": "product"
  }
]
```

#### GET /api/v1/inventory/products/{product_id}

Get a specific product by ID.

**Response:** Same as search products

#### GET /api/v1/inventory/products/barcode/{barcode}

Get a product by barcode.

**Response:** Same as search products

#### GET /api/v1/inventory/stock

Get stock quantities (quants) with filters.

**Query Parameters:**
- `product_id` (integer): Filter by product ID
- `location_id` (integer): Filter by location ID
- `limit` (integer): Max results (default: 100, max: 500)

**Example Request:**
```bash
curl "http://localhost:8000/api/v1/inventory/stock?location_id=8&limit=50"
```

**Response:**
```json
[
  {
    "id": 123,
    "product_id": [25, "Laptop Dell XPS 13"],
    "location_id": [8, "WH/Stock"],
    "quantity": 15.0,
    "reserved_quantity": 2.0
  }
]
```

#### GET /api/v1/inventory/stock/location/{location_id}

Get all stock at a specific location.

**Response:** Same as get stock

#### POST /api/v1/inventory/move

Move products between locations.

**Request Body:**
```json
{
  "product_id": 25,
  "from_location_id": 8,
  "to_location_id": 12,
  "quantity": 5.0,
  "note": "Transfer to shipping area"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Moved 5.0 units successfully",
  "data": {
    "picking_id": 45,
    "move_id": 156
  }
}
```

#### POST /api/v1/inventory/adjust

Add or remove products at a location (inventory adjustment).

**Request Body:**
```json
{
  "product_id": 25,
  "location_id": 8,
  "quantity": 10.0,
  "note": "Inventory count adjustment"
}
```

Note: Use positive quantity to add stock, negative to remove.

**Response:**
```json
{
  "success": true,
  "message": "Added 10.0 units successfully",
  "data": {
    "quant_id": 123
  }
}
```

#### GET /api/v1/inventory/history

Get stock move history.

**Query Parameters:**
- `product_id` (integer): Filter by product ID
- `location_id` (integer): Filter by location ID (source or destination)
- `limit` (integer): Max results (default: 50, max: 200)

**Response:**
```json
[
  {
    "id": 156,
    "name": "Product Move",
    "product_id": [25, "Laptop Dell XPS 13"],
    "product_uom_qty": 5.0,
    "location_id": [8, "WH/Stock"],
    "location_dest_id": [12, "WH/Shipping"],
    "date": "2025-01-15 10:30:00",
    "state": "done",
    "reference": "INT/00045"
  }
]
```

---

## Error Responses

All endpoints return standard error responses:

**4xx Client Errors:**
```json
{
  "detail": "Location 999 not found"
}
```

**5xx Server Errors:**
```json
{
  "detail": "Failed to connect to Odoo: Connection timeout"
}
```

## Rate Limiting

Currently no rate limiting is implemented. Consider adding nginx rate limiting for production:

```nginx
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

location /api/ {
    limit_req zone=api_limit burst=20 nodelay;
    ...
}
```

## Testing

### cURL Examples

**Search products:**
```bash
curl "http://localhost:8000/api/v1/inventory/products?search=laptop"
```

**Create location:**
```bash
curl -X POST "http://localhost:8000/api/v1/locations/" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Location",
    "barcode": "TEST-001",
    "usage": "internal"
  }'
```

**Move product:**
```bash
curl -X POST "http://localhost:8000/api/v1/inventory/move" \
  -H "Content-Type: application/json" \
  -d '{
    "product_id": 25,
    "from_location_id": 8,
    "to_location_id": 12,
    "quantity": 5.0
  }'
```

### Python Examples

```python
import requests

base_url = "http://localhost:8000/api/v1"

# Search products
response = requests.get(f"{base_url}/inventory/products", params={"search": "laptop"})
products = response.json()

# Move product
move_data = {
    "product_id": 25,
    "from_location_id": 8,
    "to_location_id": 12,
    "quantity": 5.0
}
response = requests.post(f"{base_url}/inventory/move", json=move_data)
result = response.json()
```

## Interactive Documentation

Visit these URLs for interactive API documentation:

- **Swagger UI**: http://localhost:8000/api/docs
- **ReDoc**: http://localhost:8000/api/redoc

These interfaces allow you to:
- Browse all endpoints
- See request/response schemas
- Try out API calls directly
- Download OpenAPI specification
