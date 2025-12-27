"""Inventory management endpoints"""
from fastapi import APIRouter, HTTPException, Query
from typing import List
from ..models import (
    Product, ProductStock, InventoryMove, InventoryAdjustment,
    SuccessResponse, StockQuant
)
from ..odoo_client import get_odoo_client

router = APIRouter(prefix="/inventory", tags=["Inventory"])


@router.get("/products", response_model=List[Product])
async def search_products(
    search: str = Query(None, description="Search by name, code, or barcode"),
    limit: int = Query(50, le=200, description="Max results")
):
    """Search for products"""
    client = get_odoo_client()

    # Build domain filter
    domain = [['type', '=', 'product']]  # Only stockable products
    if search:
        domain = [
            '&',
            ['type', '=', 'product'],
            '|', '|',
            ['name', 'ilike', search],
            ['default_code', 'ilike', search],
            ['barcode', 'ilike', search]
        ]

    try:
        products = client.search_read(
            'product.product',
            domain,
            fields=['id', 'name', 'default_code', 'barcode', 'type'],
            limit=limit,
            order='name'
        )
        return products
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to search products: {str(e)}")


@router.get("/products/{product_id}", response_model=Product)
async def get_product(product_id: int):
    """Get a specific product by ID"""
    client = get_odoo_client()

    try:
        products = client.read(
            'product.product',
            [product_id],
            fields=['id', 'name', 'default_code', 'barcode', 'type']
        )
        if not products:
            raise HTTPException(status_code=404, detail=f"Product {product_id} not found")
        return products[0]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch product: {str(e)}")


@router.get("/products/barcode/{barcode}", response_model=Product)
async def get_product_by_barcode(barcode: str):
    """Get a product by barcode"""
    client = get_odoo_client()

    try:
        products = client.search_read(
            'product.product',
            [['barcode', '=', barcode]],
            fields=['id', 'name', 'default_code', 'barcode', 'type'],
            limit=1
        )
        if not products:
            raise HTTPException(status_code=404, detail=f"Product with barcode '{barcode}' not found")
        return products[0]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to search product: {str(e)}")


@router.get("/stock", response_model=List[dict])
async def get_stock(
    product_id: int = Query(None, description="Filter by product ID"),
    location_id: int = Query(None, description="Filter by location ID"),
    limit: int = Query(100, le=500, description="Max results")
):
    """Get stock quantities (quants) with filters"""
    client = get_odoo_client()

    # Build domain filter
    domain = [['quantity', '!=', 0]]  # Only show non-zero stock
    if product_id:
        domain.append(['product_id', '=', product_id])
    if location_id:
        domain.append(['location_id', '=', location_id])

    try:
        quants = client.search_read(
            'stock.quant',
            domain,
            fields=['id', 'product_id', 'location_id', 'quantity', 'reserved_quantity'],
            limit=limit,
            order='product_id, location_id'
        )
        return quants
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch stock: {str(e)}")


@router.get("/stock/location/{location_id}", response_model=List[dict])
async def get_location_stock(location_id: int):
    """Get all stock at a specific location"""
    client = get_odoo_client()

    try:
        quants = client.search_read(
            'stock.quant',
            [['location_id', '=', location_id], ['quantity', '!=', 0]],
            fields=['id', 'product_id', 'location_id', 'quantity', 'reserved_quantity'],
            limit=500,
            order='product_id'
        )
        return quants
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch location stock: {str(e)}")


@router.post("/move", response_model=SuccessResponse)
async def move_product(move: InventoryMove):
    """Move products between locations"""
    client = get_odoo_client()

    try:
        # In Odoo, we create a stock picking (transfer) to move products
        # For simplicity, we'll create an internal transfer

        # Get picking type for internal transfers
        picking_types = client.search_read(
            'stock.picking.type',
            [['code', '=', 'internal']],
            fields=['id', 'default_location_src_id', 'default_location_dest_id'],
            limit=1
        )

        if not picking_types:
            raise HTTPException(status_code=500, detail="Internal transfer type not found")

        picking_type_id = picking_types[0]['id']

        # Create the picking (transfer)
        picking_vals = {
            'picking_type_id': picking_type_id,
            'location_id': move.from_location_id,
            'location_dest_id': move.to_location_id,
        }
        if move.note:
            picking_vals['note'] = move.note

        picking_id = client.create('stock.picking', picking_vals)

        # Create the move line
        move_vals = {
            'name': 'Product Move',
            'picking_id': picking_id,
            'product_id': move.product_id,
            'product_uom_qty': move.quantity,
            'location_id': move.from_location_id,
            'location_dest_id': move.to_location_id,
            'product_uom': 1,  # Units
        }

        move_id = client.create('stock.move', move_vals)

        # Confirm and validate the picking
        client.execute('stock.picking', 'action_confirm', [picking_id])
        client.execute('stock.picking', 'action_assign', [picking_id])

        # Set quantity done and validate
        move_lines = client.search_read(
            'stock.move.line',
            [['picking_id', '=', picking_id]],
            fields=['id']
        )

        for ml in move_lines:
            client.write('stock.move.line', [ml['id']], {'quantity': move.quantity})

        client.execute('stock.picking', 'button_validate', [picking_id])

        return SuccessResponse(
            message=f"Moved {move.quantity} units successfully",
            data={"picking_id": picking_id, "move_id": move_id}
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to move product: {str(e)}")


@router.post("/adjust", response_model=SuccessResponse)
async def adjust_inventory(adjustment: InventoryAdjustment):
    """Add or remove products at a location (inventory adjustment)"""
    client = get_odoo_client()

    try:
        # Find or create stock quant for this product/location
        quants = client.search_read(
            'stock.quant',
            [['product_id', '=', adjustment.product_id],
             ['location_id', '=', adjustment.location_id]],
            fields=['id', 'quantity', 'inventory_quantity_set'],
            limit=1
        )

        if quants:
            # Update existing quant
            quant_id = quants[0]['id']
            current_qty = quants[0]['quantity']
            new_qty = current_qty + adjustment.quantity

            client.write('stock.quant', [quant_id], {
                'inventory_quantity': new_qty,
                'inventory_quantity_set': True
            })

            # Apply the inventory adjustment
            client.execute('stock.quant', 'action_apply_inventory', [quant_id])

        else:
            # Create new quant if it doesn't exist (for new product at location)
            if adjustment.quantity < 0:
                raise HTTPException(
                    status_code=400,
                    detail="Cannot remove stock that doesn't exist at this location"
                )

            quant_vals = {
                'product_id': adjustment.product_id,
                'location_id': adjustment.location_id,
                'inventory_quantity': adjustment.quantity,
                'inventory_quantity_set': True
            }

            quant_id = client.create('stock.quant', quant_vals)
            client.execute('stock.quant', 'action_apply_inventory', [quant_id])

        action = "Added" if adjustment.quantity > 0 else "Removed"
        return SuccessResponse(
            message=f"{action} {abs(adjustment.quantity)} units successfully",
            data={"quant_id": quant_id}
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to adjust inventory: {str(e)}")


@router.get("/history", response_model=List[dict])
async def get_stock_moves(
    product_id: int = Query(None, description="Filter by product ID"),
    location_id: int = Query(None, description="Filter by location ID"),
    limit: int = Query(50, le=200, description="Max results")
):
    """Get stock move history"""
    client = get_odoo_client()

    # Build domain filter
    domain = [['state', '=', 'done']]  # Only completed moves
    if product_id:
        domain.append(['product_id', '=', product_id])
    if location_id:
        domain = domain + [
            '|',
            ['location_id', '=', location_id],
            ['location_dest_id', '=', location_id]
        ]

    try:
        moves = client.search_read(
            'stock.move',
            domain,
            fields=[
                'id', 'name', 'product_id', 'product_uom_qty',
                'location_id', 'location_dest_id', 'date', 'state', 'reference'
            ],
            limit=limit,
            order='date desc'
        )
        return moves
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch move history: {str(e)}")
