"""
Performance Middleware
Implements rate limiting, caching, and request optimization
"""

from fastapi import Request, HTTPException, status
from fastapi.responses import Response
from starlette.middleware.base import BaseHTTPMiddleware
import time
import json
import hashlib
from typing import Dict, Optional, Callable
import logging
from collections import defaultdict
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

class RateLimitMiddleware(BaseHTTPMiddleware):
    """Simple in-memory rate limiting middleware"""
    
    def __init__(
        self,
        app,
        requests_per_minute: int = 60,
        requests_per_hour: int = 1000
    ):
        super().__init__(app)
        self.requests_per_minute = requests_per_minute
        self.requests_per_hour = requests_per_hour
        self.requests: Dict[str, list] = defaultdict(list)
    
    async def dispatch(self, request: Request, call_next: Callable):
        # Get client IP
        client_ip = self._get_client_ip(request)
        
        # Check rate limits
        current_time = datetime.now()
        
        # Clean old requests
        self._clean_old_requests(client_ip, current_time)
        
        # Check limits
        if self._is_rate_limited(client_ip, current_time):
            return Response(
                content='{"detail":"Rate limit exceeded. Please try again later."}',
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                headers={"Retry-After": "60", "Content-Type": "application/json"}
            )
        
        # Add current request
        self.requests[client_ip].append(current_time)
        
        # Process request
        response = await call_next(request)
        
        # Add rate limit headers
        response.headers["X-RateLimit-Limit"] = str(self.requests_per_minute)
        response.headers["X-RateLimit-Remaining"] = str(
            max(0, self.requests_per_minute - len([
                req for req in self.requests[client_ip] 
                if req > current_time - timedelta(minutes=1)
            ]))
        )
        
        return response
    
    def _get_client_ip(self, request: Request) -> str:
        """Extract client IP from request"""
        # Check X-Forwarded-For header (for proxies/load balancers)
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()
        
        # Check X-Real-IP header
        real_ip = request.headers.get("X-Real-IP")
        if real_ip:
            return real_ip
        
        # Fall back to direct connection
        return request.client.host if request.client else "unknown"
    
    def _clean_old_requests(self, client_ip: str, current_time: datetime):
        """Remove requests older than 1 hour"""
        cutoff_time = current_time - timedelta(hours=1)
        self.requests[client_ip] = [
            req for req in self.requests[client_ip] 
            if req > cutoff_time
        ]
    
    def _is_rate_limited(self, client_ip: str, current_time: datetime) -> bool:
        """Check if client has exceeded rate limits"""
        requests_list = self.requests[client_ip]
        
        # Check per-minute limit
        minute_ago = current_time - timedelta(minutes=1)
        requests_last_minute = len([
            req for req in requests_list if req > minute_ago
        ])
        
        if requests_last_minute >= self.requests_per_minute:
            return True
        
        # Check per-hour limit
        hour_ago = current_time - timedelta(hours=1)
        requests_last_hour = len([
            req for req in requests_list if req > hour_ago
        ])
        
        return requests_last_hour >= self.requests_per_hour


class ResponseCacheMiddleware(BaseHTTPMiddleware):
    """Simple in-memory response caching middleware"""
    
    def __init__(self, app, cache_ttl_seconds: int = 300):
        super().__init__(app)
        self.cache_ttl = cache_ttl_seconds
        self.cache: Dict[str, dict] = {}
    
    async def dispatch(self, request: Request, call_next: Callable):
        # Only cache GET requests
        if request.method != "GET":
            return await call_next(request)
        
        # Don't cache authenticated endpoints (for security)
        auth_header = request.headers.get("Authorization")
        if auth_header:
            return await call_next(request)
        
        # Don't cache certain paths
        if request.url.path.startswith(("/docs", "/openapi.json", "/redoc")):
            return await call_next(request)
        
        # Generate cache key
        cache_key = self._generate_cache_key(request)
        
        # Check cache
        cached_response = self._get_cached_response(cache_key)
        if cached_response:
            logger.debug(f"Cache HIT for {request.url}")
            return Response(
                content=cached_response["content"],
                status_code=cached_response["status_code"],
                headers=dict(cached_response["headers"], **{"X-Cache": "HIT"}),
                media_type=cached_response["media_type"]
            )
        
        # Process request
        response = await call_next(request)
        
        # Cache successful responses
        if 200 <= response.status_code < 300:
            await self._cache_response(cache_key, response)
            response.headers["X-Cache"] = "MISS"
        
        return response
    
    def _generate_cache_key(self, request: Request) -> str:
        """Generate unique cache key for request"""
        # Include path and query parameters
        key_string = f"{request.url.path}?{request.url.query}"
        return hashlib.md5(key_string.encode()).hexdigest()
    
    def _get_cached_response(self, cache_key: str) -> Optional[dict]:
        """Retrieve cached response if valid"""
        if cache_key not in self.cache:
            return None
        
        cached = self.cache[cache_key]
        
        # Check if expired
        if time.time() > cached["expires_at"]:
            del self.cache[cache_key]
            return None
        
        return cached
    
    async def _cache_response(self, cache_key: str, response: Response):
        """Cache response data"""
        try:
            # Read response body if it exists
            if hasattr(response, 'body'):
                body = response.body
            else:
                # For streaming responses, we can't easily cache
                return
            
            # Store in cache
            self.cache[cache_key] = {
                "content": body,
                "status_code": response.status_code,
                "headers": dict(response.headers),
                "media_type": response.media_type,
                "expires_at": time.time() + self.cache_ttl
            }
            
            # Cleanup old cache entries (keep cache size manageable)
            self._cleanup_cache()
            
        except Exception as e:
            logger.warning(f"Failed to cache response: {str(e)}")
    
    def _cleanup_cache(self):
        """Remove expired cache entries"""
        current_time = time.time()
        expired_keys = [
            key for key, value in self.cache.items()
            if current_time > value["expires_at"]
        ]
        
        for key in expired_keys:
            del self.cache[key]
        
        # Also limit cache size (remove oldest if too large)
        if len(self.cache) > 1000:  # Max 1000 cached responses
            # Remove 100 oldest entries
            oldest_keys = sorted(
                self.cache.keys(), 
                key=lambda k: self.cache[k]["expires_at"]
            )[:100]
            
            for key in oldest_keys:
                del self.cache[key]


class RequestTimingMiddleware(BaseHTTPMiddleware):
    """Middleware to add request timing headers"""
    
    async def dispatch(self, request: Request, call_next: Callable):
        start_time = time.time()
        
        response = await call_next(request)
        
        process_time = time.time() - start_time
        response.headers["X-Process-Time"] = str(round(process_time, 4))
        
        return response