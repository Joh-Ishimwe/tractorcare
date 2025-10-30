"""
TractorCare FastAPI Main Application
Production-ready with all routes + ML Service initialization
"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from app.core.config import get_settings
from app.core.database import Database
from app.routes import usage_tracking

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle events for FastAPI"""
    # Startup
    logger.info("Starting TractorCare API...")
    
    # Initialize database
    await Database.connect_db()
    await Database.seed_maintenance_schedules()
    
    # ML Service is initialized automatically when audio routes are imported
    # (MLService() is called in app/routes/audio.py)
    logger.info("✅ ML Service initialized via routes")
    
    logger.info("TractorCare API started successfully")
    
    yield
    
    # Shutdown
    logger.info("Shutting down TractorCare API...")
    await Database.close_db()
    logger.info("TractorCare API shutdown complete")


# Create FastAPI app
app = FastAPI(
    title=settings.API_TITLE,
    description=settings.API_DESCRIPTION,
    version=settings.API_VERSION,
    lifespan=lifespan,
    docs_url="/docs",          
    redoc_url="/redoc",         
    openapi_url="/openapi.json" 
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handle all uncaught exceptions"""
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "error_code": "INTERNAL_ERROR"
        }
    )


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": settings.API_VERSION,
        "environment": settings.ENVIRONMENT
    }


# Root endpoint
@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "TractorCare API",
        "version": settings.API_VERSION,
        "docs": "/docs",
        "features": [
            "Audio Anomaly Detection (ResNet Transfer Learning)",
            "Predictive Maintenance",
            "Tractor Management",
            "User Authentication"
        ]
    }


# Import and include routers
from app.routes import auth, tractors, maintenance, audio, statistics, baseline, demo

app.include_router(
    auth.router,
    prefix="/auth", 
    tags=["Authentication"]
)
app.include_router(
    demo.router,
    prefix="/demo", 
    tags=["Quick Model test"]
)
app.include_router(
    tractors.router,
    prefix="/tractors", 
    tags=["Tractors"]
)
app.include_router(
    baseline.router, 
    prefix="/baseline", 
    tags=["Baseline"])

app.include_router(
    usage_tracking.router,
    prefix="/usage",
    tags=["Usage Tracking"]
)

app.include_router(
    maintenance.router,
    prefix="/maintenance",  
    tags=["Maintenance"]
)

app.include_router(
    audio.router,
    prefix="/audio",  
    tags=["Audio Analysis"]
)

app.include_router(
    statistics.router,
    prefix="/statistics",  
    tags=["Statistics"]
)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG
    )