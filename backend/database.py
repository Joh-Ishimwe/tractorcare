"""
Database configuration for TractorCare
MongoDB setup with PyMongo
"""
from pymongo import MongoClient
from pymongo.errors import ServerSelectionTimeoutError
import os
from dotenv import load_dotenv, dotenv_values
from pathlib import Path

# Load .env located in the backend package directory (explicit) so imports work
# Use override=True so the .env values take precedence over existing environment variables
base_dir = Path(__file__).resolve().parent
# Load .env values and ensure the MONGO_URL from backend/.env is used.
load_dotenv(dotenv_path=base_dir / '.env')
env_vals = dotenv_values(dotenv_path=base_dir / '.env')
# Normalize keys (handle BOM or stray whitespace in keys)
normalized = {}
for k, v in env_vals.items():
    if k is None:
        continue
    key = k.lstrip('\ufeff').strip()
    normalized[key] = v

if normalized.get('MONGO_URL'):
    # Force the process to use the Atlas URI from backend/.env
    os.environ['MONGO_URL'] = normalized['MONGO_URL']

# Resolve the MONGO_URL after loading .env (fall back to localhost)
MONGO_URL = os.environ.get("MONGO_URL", "mongodb://localhost:27017")

# Create client with a short server selection timeout so failures are detected quickly
client = MongoClient(MONGO_URL, serverSelectionTimeoutMS=5000)
db = client["tractorcare_db"]

# Collections
users_collection = db["users"]
cooperatives_collection = db["cooperatives"]
tractors_collection = db["tractors"]
members_collection = db["members"]
bookings_collection = db["bookings"]
maintenance_records_collection = db["maintenance_records"]
maintenance_predictions_collection = db["maintenance_predictions"]
ml_predictions_collection = db["ml_predictions"]
alerts_collection = db["alerts"]
sync_logs_collection = db["sync_logs"]

# Create indexes for better query performance
DB_CONNECTED = False
try:
    # Try a quick ping to verify connectivity
    client.admin.command('ping')
    DB_CONNECTED = True
    users_collection.create_index("username", unique=True)
    users_collection.create_index("email", unique=True)
    tractors_collection.create_index("tractor_id", unique=True)
    cooperatives_collection.create_index("coop_id", unique=True)
    members_collection.create_index("member_id", unique=True)
except ServerSelectionTimeoutError as e:
    # Don't crash at import time; surface a friendly message and continue.
    DB_CONNECTED = False
    print("! MongoDB connection failed during startup:", e)
    print("! This usually means the MONGO_URL is unreachable.")
    print("  - Check backend/.env MONGO_URL, network access, and Atlas IP whitelist (if using Mongo Atlas).\n  - Admin creation and DB operations will fail until the DB is reachable.")

def get_db():
    """Dependency for FastAPI"""
    try:
        yield db
    finally:
        pass  # MongoDB doesn't need explicit close like SQL sessions

if DB_CONNECTED:
    print("✓ MongoDB connected successfully")