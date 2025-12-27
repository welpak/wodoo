"""Location management endpoints"""
from fastapi import APIRouter, HTTPException, Query
from typing import List
from ..models import Location, LocationCreate, LocationUpdate, SuccessResponse
from ..odoo_client import get_odoo_client

router = APIRouter(prefix="/locations", tags=["Locations"])


@router.get("/", response_model=List[Location])
async def get_locations(
    search: str = Query(None, description="Search by name"),
    parent_id: int = Query(None, description="Filter by parent location"),
    usage: str = Query(None, description="Filter by usage type"),
    limit: int = Query(100, le=500, description="Max results")
):
    """Get all stock locations with optional filters"""
    client = get_odoo_client()

    # Build domain filter
    domain = []
    if search:
        domain.append(['name', 'ilike', search])
    if parent_id is not None:
        domain.append(['location_id', '=', parent_id])
    if usage:
        domain.append(['usage', '=', usage])

    try:
        locations = client.search_read(
            'stock.location',
            domain,
            fields=['id', 'name', 'complete_name', 'barcode', 'location_id', 'usage'],
            limit=limit,
            order='complete_name'
        )
        return locations
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch locations: {str(e)}")


@router.get("/{location_id}", response_model=Location)
async def get_location(location_id: int):
    """Get a specific location by ID"""
    client = get_odoo_client()

    try:
        locations = client.read(
            'stock.location',
            [location_id],
            fields=['id', 'name', 'complete_name', 'barcode', 'location_id', 'usage']
        )
        if not locations:
            raise HTTPException(status_code=404, detail=f"Location {location_id} not found")
        return locations[0]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch location: {str(e)}")


@router.post("/", response_model=SuccessResponse)
async def create_location(location: LocationCreate):
    """Create a new stock location"""
    client = get_odoo_client()

    try:
        values = {
            'name': location.name,
            'usage': location.usage
        }
        if location.barcode:
            values['barcode'] = location.barcode
        if location.location_id:
            values['location_id'] = location.location_id

        location_id = client.create('stock.location', values)
        return SuccessResponse(
            message=f"Location created successfully",
            data={"id": location_id}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create location: {str(e)}")


@router.put("/{location_id}", response_model=SuccessResponse)
async def update_location(location_id: int, location: LocationUpdate):
    """Update an existing location"""
    client = get_odoo_client()

    try:
        values = {}
        if location.name:
            values['name'] = location.name
        if location.barcode:
            values['barcode'] = location.barcode
        if location.location_id is not None:
            values['location_id'] = location.location_id

        if not values:
            raise HTTPException(status_code=400, detail="No fields to update")

        success = client.write('stock.location', [location_id], values)
        if not success:
            raise HTTPException(status_code=404, detail=f"Location {location_id} not found")

        return SuccessResponse(message=f"Location {location_id} updated successfully")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update location: {str(e)}")


@router.delete("/{location_id}", response_model=SuccessResponse)
async def delete_location(location_id: int):
    """Delete a location"""
    client = get_odoo_client()

    try:
        success = client.unlink('stock.location', [location_id])
        if not success:
            raise HTTPException(status_code=404, detail=f"Location {location_id} not found or cannot be deleted")

        return SuccessResponse(message=f"Location {location_id} deleted successfully")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete location: {str(e)}")


@router.get("/barcode/{barcode}", response_model=Location)
async def get_location_by_barcode(barcode: str):
    """Search for a location by barcode"""
    client = get_odoo_client()

    try:
        locations = client.search_read(
            'stock.location',
            [['barcode', '=', barcode]],
            fields=['id', 'name', 'complete_name', 'barcode', 'location_id', 'usage'],
            limit=1
        )
        if not locations:
            raise HTTPException(status_code=404, detail=f"Location with barcode '{barcode}' not found")
        return locations[0]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to search location: {str(e)}")
