"""
TractorCare FastAPI Main Application
Production-ready backend with all routes and ML service initialization
"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from app.core.config import get_settings
from app.core.database import Database
from app.routes import usage_tracking
from app.middleware.security import SecurityHeadersMiddleware

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle management"""
    logger.info("Starting TractorCare API...")
    
    await Database.connect_db()
    await Database.seed_maintenance_schedules()
    
    logger.info("✅ ML Service initialized via routes")
    logger.info("TractorCare API started successfully")
    
    yield
    
    logger.info("Shutting down TractorCare API...")
    await Database.close_db()
    logger.info("TractorCare API shutdown complete")


app = FastAPI(
    title=settings.API_TITLE,
    description=settings.API_DESCRIPTION,
    version=settings.API_VERSION,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json"
)

app.add_middleware(SecurityHeadersMiddleware)

allowed_origins = settings.allowed_origins_list
logger.info(f"🌐 Allowed CORS origins: {allowed_origins}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins if allowed_origins else ["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=[
        "Content-Type",
        "Authorization",
        "Accept",
        "Origin",
        "X-Requested-With",
        "X-CSRF-Token",
    ],
    expose_headers=["Content-Type", "Authorization"],
    max_age=3600,
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler for uncaught errors"""
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "error_code": "INTERNAL_ERROR"
        }
    )


@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring"""
    return {
        "status": "healthy",
        "version": settings.API_VERSION,
        "environment": settings.ENVIRONMENT
    }


@app.get("/")
async def root():
    """Root API endpoint"""
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