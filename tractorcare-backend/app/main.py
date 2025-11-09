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
# Temporarily commented out middleware imports to fix Swagger UI
# from app.middleware.security import SecurityHeadersMiddleware
# from app.middleware.performance import (
#     RateLimitMiddleware, 
#     ResponseCacheMiddleware, 
#     RequestTimingMiddleware
# )

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
    openapi_url="/openapi.json",
    swagger_ui_parameters={
        "deepLinking": True,
        "displayRequestDuration": True,
        "docExpansion": "none",
        "operationsSorter": "method",
        "filter": True,
        "showMutatedRequest": True,
        "tryItOutEnabled": True
    }
)

# Add CORS middleware with proper configuration
allowed_origins = settings.allowed_origins_list
logger.info(f"🌐 Allowed CORS origins: {allowed_origins}")

# More permissive CORS for development, restrictive for production
if settings.ENVIRONMENT == "production":
    cors_origins = allowed_origins
else:
    cors_origins = ["*"]  # Allow all in development

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=[
        "Accept",
        "Accept-Language", 
        "Content-Language",
        "Content-Type",
        "Authorization",
        "X-Requested-With",
        "X-CSRF-Token"
    ],
    expose_headers=[
        "Content-Type", 
        "Authorization",
        "X-Total-Count",
        "X-Request-ID"
    ],
    max_age=86400,  # 24 hours preflight cache
)

# Temporarily removed all other middleware to fix Swagger UI
# TODO: Re-add performance middleware after fixing docs
# app.add_middleware(SecurityHeadersMiddleware)
# app.add_middleware(RequestTimingMiddleware)
# app.add_middleware(RateLimitMiddleware)
# app.add_middleware(ResponseCacheMiddleware)


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
    """Root API endpoint with ML model status"""
    try:
        from app.services.ml_service import ml_service
        model_status = {
            "loaded": ml_service.model is not None,
            "info": "ResNet CNN Transfer Learning" if ml_service.model else "Loading..."
        }
    except Exception as e:
        model_status = {
            "loaded": False,
            "error": str(e)
        }
    
    return {
        "message": "TractorCare API",
        "version": settings.API_VERSION,
        "docs": "/docs",
        "model_status": model_status,
        "features": [
            "Audio Anomaly Detection (ResNet Transfer Learning)",
            "Predictive Maintenance", 
            "Tractor Management",
            "User Authentication"
        ]
    }


from fastapi.responses import HTMLResponse

@app.get("/swagger", response_class=HTMLResponse)
async def custom_swagger_ui():
    """Custom Swagger UI route as backup"""
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>TractorCare API - Swagger UI</title>
        <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@4.15.5/swagger-ui.css" />
        <style>
            html {{
                box-sizing: border-box;
                overflow: -moz-scrollbars-vertical;
                overflow-y: scroll;
            }}
            *, *:before, *:after {{
                box-sizing: inherit;
            }}
            body {{
                margin:0;
                background: #fafafa;
            }}
        </style>
    </head>
    <body>
        <div id="swagger-ui"></div>
        <script src="https://unpkg.com/swagger-ui-dist@4.15.5/swagger-ui-bundle.js"></script>
        <script src="https://unpkg.com/swagger-ui-dist@4.15.5/swagger-ui-standalone-preset.js"></script>
        <script>
            window.onload = function() {{
                const ui = SwaggerUIBundle({{
                    url: '/openapi.json',
                    dom_id: '#swagger-ui',
                    deepLinking: true,
                    presets: [
                        SwaggerUIBundle.presets.apis,
                        SwaggerUIStandalonePreset
                    ],
                    plugins: [
                        SwaggerUIBundle.plugins.DownloadUrl
                    ],
                    layout: "StandaloneLayout"
                }});
            }};
        </script>
    </body>
    </html>
    """


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
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG
    )