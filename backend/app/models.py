"""Pydantic models for request/response validation"""
from pydantic import BaseModel, Field
from typing import Optional, List


# Location Models
class Location(BaseModel):
    """Stock location model"""
    id: int
    name: str
    complete_name: Optional[str] = None
    barcode: Optional[str] = None
    location_id: Optional[int] = None  # Parent location
    usage: Optional[str] = None  # internal, view, etc.


class LocationCreate(BaseModel):
    """Model for creating a new location"""
    name: str = Field(..., min_length=1, description="Location name")
    barcode: Optional[str] = Field(None, description="Location barcode")
    location_id: Optional[int] = Field(None, description="Parent location ID")
    usage: str = Field(default="internal", description="Location usage type")


class LocationUpdate(BaseModel):
    """Model for updating a location"""
    name: Optional[str] = None
    barcode: Optional[str] = None
    location_id: Optional[int] = None


# Product Models
class Product(BaseModel):
    """Product model"""
    id: int
    name: str
    default_code: Optional[str] = None  # Internal reference/SKU
    barcode: Optional[str] = None
    type: Optional[str] = None  # product, consu, service


class ProductStock(BaseModel):
    """Product with stock quantity at location"""
    product_id: int
    product_name: str
    product_code: Optional[str] = None
    location_id: int
    location_name: str
    quantity: float
    reserved_quantity: Optional[float] = 0.0
    available_quantity: Optional[float] = 0.0


# Inventory Operation Models
class InventoryMove(BaseModel):
    """Model for moving products between locations"""
    product_id: int = Field(..., description="Product ID")
    from_location_id: int = Field(..., description="Source location ID")
    to_location_id: int = Field(..., description="Destination location ID")
    quantity: float = Field(..., gt=0, description="Quantity to move")
    note: Optional[str] = Field(None, description="Optional note")


class InventoryAdjustment(BaseModel):
    """Model for adding/removing products at a location"""
    product_id: int = Field(..., description="Product ID")
    location_id: int = Field(..., description="Location ID")
    quantity: float = Field(..., description="Quantity (positive to add, negative to remove)")
    note: Optional[str] = Field(None, description="Optional note")


class StockQuant(BaseModel):
    """Stock quant (actual inventory at location)"""
    id: int
    product_id: int
    location_id: int
    quantity: float
    reserved_quantity: float


# Search Models
class SearchQuery(BaseModel):
    """Generic search query"""
    query: str = Field(..., min_length=1, description="Search query")
    limit: int = Field(default=20, le=100, description="Max results")


# Response Models
class SuccessResponse(BaseModel):
    """Generic success response"""
    success: bool = True
    message: str
    data: Optional[dict] = None


class ErrorResponse(BaseModel):
    """Generic error response"""
    success: bool = False
    error: str
    message: str
