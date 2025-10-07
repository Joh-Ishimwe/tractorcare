"""
Authentication and authorization for TractorCare
Handles user registration, login, JWT tokens, password hashing
"""
from datetime import datetime, timedelta
from typing import Optional
from passlib.context import CryptContext
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from pydantic import BaseModel

from database import get_db
import models
# ============================================================================
# CONFIGURATION
# ============================================================================

SECRET_KEY = "your-secret-key-change-in-production"  # Use environment variable in production
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

# ============================================================================
# SCHEMAS
# ============================================================================

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    user_id: Optional[int] = None
    username: Optional[str] = None
    role: Optional[str] = None
    coop_id: Optional[str] = None

class UserLogin(BaseModel):
    username: str
    password: str

class UserCreate(BaseModel):
    username: str
    email: str
    password: str
    full_name: str
    phone_number: Optional[str]
    coop_id: Optional[str]
    role: str = "operator"  # admin, manager, operator

class UserResponse(BaseModel):
    user_id: int
    username: str
    email: str
    full_name: str
    role: str
    coop_id: Optional[str]
    is_active: bool
    
    class Config:
        orm_mode = True

# ============================================================================
# PASSWORD HASHING
# ============================================================================

def hash_password(password: str) -> str:
    """Hash a password"""
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash"""
    return pwd_context.verify(plain_password, hashed_password)

# ============================================================================
# JWT TOKEN OPERATIONS
# ============================================================================

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create JWT access token"""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_token(token: str) -> TokenData:
    """Decode and validate JWT token"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("user_id")
        username: str = payload.get("sub")
        role: str = payload.get("role")
        coop_id: str = payload.get("coop_id")
        
        if username is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token"
            )
        
        return TokenData(
            user_id=user_id,
            username=username,
            role=role,
            coop_id=coop_id
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials"
        )

# ============================================================================
# USER OPERATIONS
# ============================================================================

def create_user(db: Session, user: UserCreate):
    """Create new user with hashed password"""
    # Check if username exists
    existing = db.query(models.User).filter(
        models.User.username == user.username
    ).first()
    if existing:
        raise HTTPException(
            status_code=400,
            detail="Username already registered"
        )
    
    # Check if email exists
    existing_email = db.query(models.User).filter(
        models.User.email == user.email
    ).first()
    if existing_email:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )
    
    # Create user
    hashed_pw = hash_password(user.password)
    db_user = models.User(
        username=user.username,
        email=user.email,
        hashed_password=hashed_pw,
        full_name=user.full_name,
        phone_number=user.phone_number,
        coop_id=user.coop_id,
        role=user.role
    )
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def authenticate_user(db: Session, username: str, password: str):
    """Authenticate user credentials"""
    user = db.query(models.User).filter(
        models.User.username == username
    ).first()
    
    if not user:
        return False
    if not verify_password(password, user.hashed_password):
        return False
    if not user.is_active:
        raise HTTPException(
            status_code=403,
            detail="User account is inactive"
        )
    
    return user

def get_user_by_id(db: Session, user_id: int):
    """Get user by ID"""
    return db.query(models.User).filter(
        models.User.user_id == user_id
    ).first()

def update_last_login(db: Session, user_id: int):
    """Update last login timestamp"""
    db.query(models.User).filter(
        models.User.user_id == user_id
    ).update({"last_login": datetime.now()})
    db.commit()

# ============================================================================
# DEPENDENCIES FOR ROUTE PROTECTION
# ============================================================================

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    """
    Dependency to get current authenticated user
    Use in routes: current_user = Depends(get_current_user)
    """
    token = credentials.credentials
    token_data = decode_token(token)
    
    user = get_user_by_id(db, token_data.user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    return user

async def get_current_active_user(
    current_user: models.User = Depends(get_current_user)
):
    """Ensure user is active"""
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

# ============================================================================
# ROLE-BASED ACCESS CONTROL
# ============================================================================

class RoleChecker:
    """Check if user has required role"""
    def __init__(self, allowed_roles: list):
        self.allowed_roles = allowed_roles
    
    def __call__(self, current_user: models.User = Depends(get_current_active_user)):
        if current_user.role not in self.allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Operation requires one of these roles: {self.allowed_roles}"
            )
        return current_user

# Usage examples:
# require_admin = RoleChecker(["admin"])
# require_manager = RoleChecker(["admin", "manager"])
# require_operator = RoleChecker(["admin", "manager", "operator"])

def check_cooperative_access(user: models.User, coop_id: str):
    """Verify user has access to cooperative data"""
    if user.role == "admin":
        return True  # Admins can access all cooperatives
    
    if user.coop_id != coop_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied to this cooperative's data"
        )
    return True