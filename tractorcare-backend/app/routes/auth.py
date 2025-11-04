"""
Authentication Routes
User registration, login, and profile management
"""

from fastapi import APIRouter, HTTPException, status, Depends, Response
from datetime import timedelta
from app.schemas import UserCreate, UserLogin, UserResponse, Token
from app.models import User
from app.core.security import AuthService, get_current_user
from app.core.config import get_settings

router = APIRouter()
settings = get_settings()


@router.options("/register")
@router.options("/login") 
@router.options("/me")
async def handle_cors_preflight():
    """Handle CORS preflight requests"""
    return Response(status_code=200)


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate):
    """Register a new user account"""
    existing_user = await User.find_one(User.email == user_data.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    hashed_password = AuthService.get_password_hash(user_data.password)
    
    user = User(
        email=user_data.email,
        full_name=user_data.full_name,
        phone=user_data.phone,
        hashed_password=hashed_password
    )
    
    await user.insert()
    
    return UserResponse(
        id=str(user.id),
        email=user.email,
        full_name=user.full_name,
        phone=user.phone,
        is_active=user.is_active,
        created_at=user.created_at
    )


@router.post("/login", response_model=Token)
async def login(credentials: UserLogin):
    """Authenticate user and return JWT access token"""
    user = await User.find_one(User.email == credentials.email)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    if not AuthService.verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )
    
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = AuthService.create_access_token(
        data={"sub": user.email},
        expires_delta=access_token_expires
    )
    
    return Token(access_token=access_token)


@router.get("/me", response_model=UserResponse)
async def get_current_user_profile(current_user: User = Depends(get_current_user)):
    """Get current authenticated user's profile"""
    return UserResponse(
        id=str(current_user.id),
        email=current_user.email,
        full_name=current_user.full_name,
        phone=current_user.phone,
        is_active=current_user.is_active,
        created_at=current_user.created_at
    )


@router.put("/me", response_model=UserResponse)
async def update_profile(
    update_data: dict,
    current_user: User = Depends(get_current_user)
):
    """Update current user's profile information"""
    if "full_name" in update_data:
        current_user.full_name = update_data["full_name"]
    if "phone" in update_data:
        current_user.phone = update_data["phone"]
    
    await current_user.save()
    
    return UserResponse(
        id=str(current_user.id),
        email=current_user.email,
        full_name=current_user.full_name,
        phone=current_user.phone,
        is_active=current_user.is_active,
        created_at=current_user.created_at
    )