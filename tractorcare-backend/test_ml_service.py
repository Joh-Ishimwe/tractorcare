#!/usr/bin/env python3
"""
Simple test script to verify ML Service functionality
"""

import asyncio
import logging
import sys
import os
from pathlib import Path

# Add the app directory to Python path
sys.path.append(str(Path(__file__).parent / "app"))

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

async def test_ml_service():
    """Test ML Service initialization and basic functionality"""
    try:
        print("🧪 Testing ML Service...")
        
        # Import ML Service
        from app.services.ml_service import MLService
        
        print("✅ Successfully imported MLService")
        
        # Initialize service
        print("🚀 Initializing ML Service...")
        ml_service = MLService()
        
        print("✅ ML Service initialized successfully")
        
        # Test model info
        model_info = ml_service.get_model_info()
        print(f"📊 Model Info:")
        print(f"   - Model Name: {model_info['model_name']}")
        print(f"   - Model Loaded: {model_info['model_loaded']}")
        print(f"   - Model Type: {model_info['model_type']}")
        
        if not model_info['model_loaded']:
            print("⚠️  ML model not loaded - service running in fallback mode")
        else:
            print("🎉 ML model loaded successfully")
            
        return True
        
    except Exception as e:
        print(f"❌ Error testing ML Service: {e}")
        return False

if __name__ == "__main__":
    success = asyncio.run(test_ml_service())
    if success:
        print("✅ ML Service test completed successfully")
    else:
        print("❌ ML Service test failed")
        sys.exit(1)