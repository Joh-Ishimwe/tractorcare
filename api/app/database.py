from motor.motor_asyncio import AsyncIOMotorClient
from app.config import settings

class Database:
    client: AsyncIOMotorClient = None

db = Database()

async def connect_to_mongo():
    db.client = AsyncIOMotorClient(settings.MONGODB_URL)
    print("✅ Connected to MongoDB Atlas")

async def close_mongo_connection():
    db.client.close()
    print("❌ Disconnected from MongoDB")

def get_database():
    return db.client[settings.DATABASE_NAME]