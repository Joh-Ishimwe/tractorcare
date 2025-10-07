"""
TractorCare API - Complete Backend
"""
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from database import get_db, engine
import models
import auth

# Create tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="TractorCare API",
    description="Predictive Maintenance Platform",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBearer()

# ============================================================================
# SCHEMAS
# ============================================================================

class UserLogin(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class CooperativeCreate(BaseModel):
    coop_id: str
    name: str
    location: str
    contact_person: str
    phone_number: str

class TractorCreate(BaseModel):
    tractor_id: str
    coop_id: str
    model: str
    serial_number: str
    purchase_date: str
    engine_hours: float = 0
    usage_intensity: str = "moderate"

# ============================================================================
# AUTH DEPENDENCY
# ============================================================================

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    token = credentials.credentials
    token_data = auth.decode_token(token)
    user = auth.get_user_by_id(db, token_data.user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user

# ============================================================================
# ENDPOINTS
# ============================================================================

@app.get("/", tags=["System"])
def root():
    return {
        "app": "TractorCare API",
        "version": "1.0.0",
        "status": "operational"
    }

@app.post("/auth/login", response_model=Token, tags=["Authentication"])
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    user = auth.authenticate_user(db, credentials.username, credentials.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    access_token = auth.create_access_token(
        data={
            "sub": user.username,
            "user_id": user.user_id,
            "role": user.role,
            "coop_id": user.coop_id
        }
    )
    auth.update_last_login(db, user.user_id)
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/auth/me", tags=["Authentication"])
def get_me(current_user: models.User = Depends(get_current_user)):
    return {
        "user_id": current_user.user_id,
        "username": current_user.username,
        "email": current_user.email,
        "role": current_user.role,
        "coop_id": current_user.coop_id
    }

@app.post("/cooperatives", tags=["Cooperatives"])
def create_cooperative(
    coop: CooperativeCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin only")
    
    db_coop = models.Cooperative(**coop.dict())
    db.add(db_coop)
    db.commit()
    db.refresh(db_coop)
    return db_coop

@app.get("/cooperatives/{coop_id}", tags=["Cooperatives"])
def get_cooperative(
    coop_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    coop = db.query(models.Cooperative).filter(
        models.Cooperative.coop_id == coop_id
    ).first()
    if not coop:
        raise HTTPException(status_code=404, detail="Not found")
    return coop

@app.get("/cooperatives", tags=["Cooperatives"])
def list_cooperatives(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    return db.query(models.Cooperative).all()

@app.post("/tractors", tags=["Tractors"])
def create_tractor(
    tractor: TractorCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    db_tractor = models.Tractor(
        tractor_id=tractor.tractor_id,
        coop_id=tractor.coop_id,
        model=models.TractorModel[tractor.model],
        serial_number=tractor.serial_number,
        purchase_date=datetime.fromisoformat(tractor.purchase_date),
        engine_hours=tractor.engine_hours,
        usage_intensity=models.UsageIntensity[tractor.usage_intensity],
        current_status="available"
    )
    db.add(db_tractor)
    db.commit()
    db.refresh(db_tractor)
    return db_tractor

@app.get("/tractors/{tractor_id}", tags=["Tractors"])
def get_tractor(
    tractor_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    tractor = db.query(models.Tractor).filter(
        models.Tractor.tractor_id == tractor_id
    ).first()
    if not tractor:
        raise HTTPException(status_code=404, detail="Not found")
    return tractor

@app.get("/cooperatives/{coop_id}/tractors", tags=["Tractors"])
def list_cooperative_tractors(
    coop_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    return db.query(models.Tractor).filter(
        models.Tractor.coop_id == coop_id
    ).all()

@app.get("/tractors", tags=["Tractors"])
def list_all_tractors(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    return db.query(models.Tractor).all()

@app.get("/tractors/{tractor_id}/predictions", tags=["Predictions"])
def get_predictions(
    tractor_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    tractor = db.query(models.Tractor).filter(
        models.Tractor.tractor_id == tractor_id
    ).first()
    
    if not tractor:
        raise HTTPException(status_code=404, detail="Tractor not found")
    
    engine_hours = tractor.engine_hours
    predictions = []
    
    # Oil change (every 250 hours)
    if engine_hours % 250 > 200:
        predictions.append({
            "task": "Oil Change",
            "status": "due_soon",
            "hours_remaining": 250 - (engine_hours % 250),
            "estimated_cost_rwf": 50000
        })
    
    # Filter replacement (every 500 hours)
    if engine_hours % 500 > 450:
        predictions.append({
            "task": "Filter Replacement",
            "status": "due_soon",
            "hours_remaining": 500 - (engine_hours % 500),
            "estimated_cost_rwf": 75000
        })
    
    return predictions