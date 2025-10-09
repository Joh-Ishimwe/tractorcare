"""
TractorCare API - Complete Backend
"""
from fastapi import FastAPI, HTTPException, Depends, status, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import List, Dict
from datetime import datetime
import logging
import os

# Conditional import for rate limiting
try:
    from fastapi_limiter import FastAPILimiter
    from fastapi_limiter.depends import RateLimiter
    import redis.asyncio as redis
    RATE_LIMITING_ENABLED = True
except ImportError:
    RATE_LIMITING_ENABLED = False
    logging.warning("Rate limiting is disabled due to missing dependencies (fastapi-limiter, redis). Install them for rate limiting.")

from database import get_db
from auth import create_access_token, authenticate_user, update_last_login, get_current_user, RoleChecker, create_user
from schemas import *
from rule_based_maintenance import Tractor as RuleTractor, MaintenancePredictor, AlertSystem  # Integrate rule-based

app = FastAPI(title="TractorCare API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production to specific domains
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
    expose_headers=["*"]
)
# Rate limiting setup (Render-compatible)
if RATE_LIMITING_ENABLED:
    @app.on_event("startup")
    async def startup():
        redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")
        redis_client = await redis.from_url(redis_url, encoding="utf-8", decode_responses=True)
        await FastAPILimiter.init(redis_client)
        logger.info(f"Connected to Redis at {redis_url}")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

require_admin = RoleChecker(["admin"])

@app.get("/")
def root():
    return {"app": "TractorCare API", "version": "1.0.0"}

@app.post("/auth/register", dependencies=[Depends(RateLimiter(times=5, seconds=60)) if RATE_LIMITING_ENABLED else []])
def register(user: UserCreate, db=Depends(get_db)):
    try:
        return create_user(db, user)
    except HTTPException as e:
        logger.warning(f"Registration failed for {user.username}: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error during registration: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/auth/login", response_model=Token, dependencies=[Depends(RateLimiter(times=5, seconds=60)) if RATE_LIMITING_ENABLED else []])
def login(credentials: UserLogin, db=Depends(get_db)):
    try:
        user = authenticate_user(db, credentials.username, credentials.password)
        if not user:
            raise HTTPException(401, "Invalid credentials")
        access_token = create_access_token({
            "sub": user["username"],
            "user_id": user["_id"],
            "role": user["role"],
            "coop_id": user.get("coop_id")
        })
        update_last_login(db, user["_id"])
        return {"access_token": access_token, "token_type": "bearer"}
    except HTTPException as e:
        logger.warning(f"Login failed for {credentials.username}: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error during login: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/auth/me")
def get_me(current_user=Depends(get_current_user)):
    return current_user

@app.post("/cooperatives", dependencies=[Depends(RateLimiter(times=10, seconds=60)) if RATE_LIMITING_ENABLED else []])
def create_cooperative(coop: CooperativeCreate, db=Depends(get_db), _=Depends(require_admin)):
    try:
        coop_dict = coop.dict()
        if db.cooperatives.find_one({"coop_id": coop.coop_id}):
            raise HTTPException(400, "Coop ID exists")
        db.cooperatives.insert_one(coop_dict)
        return coop_dict
    except HTTPException as e:
        logger.warning(f"Cooperative creation failed: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error creating cooperative: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/cooperatives/{coop_id}")
def get_cooperative(coop_id: str, db=Depends(get_db), current_user=Depends(get_current_user)):
    try:
        coop = db.cooperatives.find_one({"coop_id": coop_id})
        if not coop:
            raise HTTPException(404, "Not found")
        return coop
    except HTTPException as e:
        logger.warning(f"Get cooperative failed: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error getting cooperative: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/cooperatives")
def list_cooperatives(db=Depends(get_db), current_user=Depends(get_current_user)):
    try:
        return list(db.cooperatives.find())
    except Exception as e:
        logger.error(f"Unexpected error listing cooperatives: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/tractors", dependencies=[Depends(RateLimiter(times=10, seconds=60)) if RATE_LIMITING_ENABLED else []])
def create_tractor(tractor: TractorCreate, db=Depends(get_db), current_user=Depends(get_current_user)):
    try:
        tractor_dict = tractor.dict()
        tractor_dict["purchase_date"] = datetime.strptime(tractor.purchase_date, "%Y-%m-%d")
        tractor_dict["current_status"] = "available"
        tractor_dict["created_at"] = datetime.now()
        if db.tractors.find_one({"tractor_id": tractor.tractor_id}):
            raise HTTPException(400, "Tractor ID exists")
        db.tractors.insert_one(tractor_dict)
        return tractor_dict
    except HTTPException as e:
        logger.warning(f"Tractor creation failed: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error creating tractor: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/tractors/{tractor_id}")
def get_tractor(tractor_id: str, db=Depends(get_db), current_user=Depends(get_current_user)):
    try:
        tractor = db.tractors.find_one({"tractor_id": tractor_id})
        if not tractor:
            raise HTTPException(404, "Not found")
        return tractor
    except HTTPException as e:
        logger.warning(f"Get tractor failed: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error getting tractor: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/cooperatives/{coop_id}/tractors")
def list_coop_tractors(coop_id: str, db=Depends(get_db), current_user=Depends(get_current_user)):
    try:
        return list(db.tractors.find({"coop_id": coop_id}))
    except Exception as e:
        logger.error(f"Unexpected error listing coop tractors: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/tractors")
def list_tractors(db=Depends(get_db), current_user=Depends(get_current_user)):
    try:
        return list(db.tractors.find())
    except Exception as e:
        logger.error(f"Unexpected error listing tractors: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/tractors/{tractor_id}/predictions")
def get_predictions(tractor_id: str, db=Depends(get_db), current_user=Depends(get_current_user)):
    try:
        tractor_data = db.tractors.find_one({"tractor_id": tractor_id})
        if not tractor_data:
            raise HTTPException(404, "Tractor not found")
        # Use rule-based
        rule_tractor = RuleTractor(
            tractor_id=tractor_data["tractor_id"],
            model=tractor_data["model"],
            purchase_date=tractor_data["purchase_date"].strftime("%Y-%m-%d"),
            initial_engine_hours=tractor_data["engine_hours"],
            usage_intensity=tractor_data["usage_intensity"]
        )
        predictor = MaintenancePredictor(rule_tractor)
        predictions = predictor.predict_all_maintenance()
        # Save to Mongo (optional)
        for pred in predictions:
            pred["tractor_id"] = tractor_id
            db.maintenance_predictions.insert_one(pred)
        return predictions
    except HTTPException as e:
        logger.warning(f"Predictions failed: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error getting predictions: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/members", dependencies=[Depends(RateLimiter(times=10, seconds=60)) if RATE_LIMITING_ENABLED else []])
def create_member(member: MemberCreate, db=Depends(get_db), current_user=Depends(get_current_user)):
    try:
        member_dict = member.dict()
        member_dict["membership_status"] = "active"
        member_dict["join_date"] = datetime.now()
        db.members.insert_one(member_dict)
        return member_dict
    except HTTPException as e:
        logger.warning(f"Member creation failed: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error creating member: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/bookings", dependencies=[Depends(RateLimiter(times=10, seconds=60)) if RATE_LIMITING_ENABLED else []])
def create_booking(booking: BookingCreate, db=Depends(get_db), current_user=Depends(get_current_user)):
    try:
        booking_dict = booking.dict()
        booking_dict["booking_status"] = "pending"
        booking_dict["payment_status"] = "unpaid"
        booking_dict["created_at"] = datetime.now()
        db.bookings.insert_one(booking_dict)
        return booking_dict
    except HTTPException as e:
        logger.warning(f"Booking creation failed: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error creating booking: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/maintenance-records", dependencies=[Depends(RateLimiter(times=10, seconds=60)) if RATE_LIMITING_ENABLED else []])
def create_maintenance(record: MaintenanceRecordCreate, db=Depends(get_db), current_user=Depends(get_current_user)):
    try:
        record_dict = record.dict()
        record_dict["date"] = datetime.strptime(record.date, "%Y-%m-%d")
        record_dict["created_at"] = datetime.now()
        db.maintenance_records.insert_one(record_dict)
        return record_dict
    except HTTPException as e:
        logger.warning(f"Maintenance record creation failed: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error creating maintenance record: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/predict-ml")  # Placeholder for ML (upload audio)
async def predict_ml(tractor_id: str, audio: UploadFile = File(...), db=Depends(get_db), current_user=Depends(get_current_user)):
    try:
        # TODO: Process audio with ML model from notebook
        # Example: Save file, extract MFCC, predict with CNN, store in ml_predictions
        return {"message": "ML prediction placeholder", "anomaly": "normal"}  # Replace with real logic
    except Exception as e:
        logger.error(f"Unexpected error in ML prediction: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/sync", dependencies=[Depends(RateLimiter(times=5, seconds=300)) if RATE_LIMITING_ENABLED else []])
def sync_data(data: Dict, db=Depends(get_db), current_user=Depends(get_current_user)):
    try:
        # Assume data = {"collection_name": [{"_id": ..., "data": ...}, ...]}
        for collection_name, items in data.items():
            if collection_name not in db.list_collection_names():
                raise HTTPException(400, f"Invalid collection: {collection_name}")
            collection = db[collection_name]
            for item in items:
                # Idempotent upsert with timestamp conflict resolution
                existing = collection.find_one({"_id": item.get("_id")})
                if existing:
                    # Simple conflict resolution: Use newer timestamp
                    if item.get("updated_at", datetime.min) > existing.get("updated_at", datetime.min):
                        collection.replace_one({"_id": item["_id"]}, item)
                    else:
                        logger.info(f"Skipped older sync for {item['_id']} in {collection_name}")
                else:
                    collection.insert_one(item)
        sync_log = {
            "device_id": current_user.get("device_id", "unknown"),
            "sync_timestamp": datetime.now(),
            "status": "success",
            "records_count": sum(len(v) for v in data.values()),
            "user_id": current_user["_id"]
        }
        db.sync_logs.insert_one(sync_log)
        return {"status": "synced", "log_id": sync_log["_id"]}
    except HTTPException as e:
        logger.warning(f"Sync failed: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error during sync: {str(e)}")
        sync_log = {
            "device_id": current_user.get("device_id", "unknown"),
            "sync_timestamp": datetime.now(),
            "status": "failed",
            "error_message": str(e),
            "user_id": current_user["_id"]
        }
        db.sync_logs.insert_one(sync_log)
        raise HTTPException(status_code=500, detail="Sync failed")

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port, reload=True)
