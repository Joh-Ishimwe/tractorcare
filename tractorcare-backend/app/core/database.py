"""
Database Connection and Initialization
Using Motor (async MongoDB driver) and Beanie ODM
"""

from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie
import logging
from typing import Optional
from pymongo.errors import OperationFailure
from app.core.config import get_settings
from app.models import get_all_document_models

logger = logging.getLogger(__name__)

class Database:
    """Database connection manager"""
    
    client: Optional[AsyncIOMotorClient] = None
    
    @classmethod
    async def connect_db(cls):
        """Connect to MongoDB and initialize Beanie"""
        settings = get_settings()
        
        # Create MongoDB client
        cls.client = AsyncIOMotorClient(settings.MONGO_URL)
        
        # Test connection
        await cls.client.admin.command('ping')
        logger.info("Successfully connected to MongoDB")
        
        # Get database
        database = cls.client[settings.DATABASE_NAME]
        
        # Get all document models
        document_models = await get_all_document_models()
        
        # Strategy: Try to initialize all at once
        # If it fails, drop problematic indexes and recreate
        try:
            await init_beanie(
                database=database,
                document_models=document_models
            )
            logger.info(f"Beanie initialized with {len(document_models)} document models")
        except OperationFailure as e:
            if e.code == 86:  # IndexKeySpecsConflict
                logger.warning("Index conflict detected - fixing indexes...")
                
                # Drop and recreate indexes for problematic collections
                for model in document_models:
                    collection_name = model.Settings.name if hasattr(model, 'Settings') else model.__name__.lower() + 's'
                    try:
                        collection = database[collection_name]
                        # Drop all indexes except _id
                        indexes = await collection.index_information()
                        for index_name in indexes:
                            if index_name != '_id_':
                                try:
                                    await collection.drop_index(index_name)
                                    logger.info(f"Dropped index {index_name} from {collection_name}")
                                except Exception as drop_error:
                                    logger.warning(f"Could not drop {index_name}: {drop_error}")
                    except Exception as collection_error:
                        logger.warning(f"Error accessing collection {collection_name}: {collection_error}")
                
                # Now initialize Beanie - it will recreate indexes properly
                await init_beanie(
                    database=database,
                    document_models=document_models
                )
                logger.info(f"Beanie initialized with {len(document_models)} document models (indexes recreated)")
            else:
                raise
        
        logger.info("Database ready")
    
    @classmethod
    async def close_db(cls):
        """Close database connection"""
        if cls.client:
            cls.client.close()
            logger.info("Database connection closed")
    
    @classmethod
    async def seed_maintenance_schedules(cls):
        """
        Seed maintenance schedules from config
        Only runs if schedules don't exist
        """
        from app.models import MaintenanceSchedule, MaintenanceTaskInfo
        from app.core.config import MAINTENANCE_SCHEDULES
        
        try:
            for model_key, schedule_data in MAINTENANCE_SCHEDULES.items():
                # Check if schedule already exists
                existing = await MaintenanceSchedule.find_one(
                    {"model": model_key}
                )
                
                if not existing:
                    # Convert task dicts to MaintenanceTaskInfo objects
                    tasks = [
                        MaintenanceTaskInfo(**task)
                        for task in schedule_data["tasks"]
                    ]
                    
                    # Create schedule
                    schedule = MaintenanceSchedule(
                        model=schedule_data["model"],
                        make=schedule_data["make"],
                        source=schedule_data["source"],
                        tasks=tasks
                    )
                    
                    await schedule.insert()
                    logger.info(f"Seeded maintenance schedule for {model_key}")
                else:
                    logger.info(f"Maintenance schedule for {model_key} already exists")
                    
        except Exception as e:
            logger.warning(f"Error seeding: {str(e)}")
            logger.info("Continuing without seeding...")


# Dependency to get database
async def get_database():
    """Dependency for getting database connection"""
    return Database.client

