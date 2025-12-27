"""Main FastAPI application for Wodoo"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
import os

from .config import get_settings
from .odoo_client import get_odoo_client
from .routers import locations, inventory

# Get settings
settings = get_settings()

# Create FastAPI app
app = FastAPI(
    title="Wodoo - Welpak Odoo Inventory",
    description="Fast inventory location management for Odoo 16",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(locations.router, prefix=settings.api_prefix)
app.include_router(inventory.router, prefix=settings.api_prefix)


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "name": "Wodoo - Welpak Odoo Inventory",
        "version": "1.0.0",
        "status": "running",
        "docs": "/api/docs"
    }


@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "wodoo-api"
    }


@app.get("/api/test-connection")
async def test_odoo_connection():
    """Test connection to Odoo"""
    try:
        client = get_odoo_client()
        result = client.test_connection()
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Connection test failed: {str(e)}")


# Serve frontend static files (if frontend directory exists)
frontend_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "frontend")
if os.path.exists(frontend_path):
    app.mount("/", StaticFiles(directory=frontend_path, html=True), name="frontend")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=True
    )
