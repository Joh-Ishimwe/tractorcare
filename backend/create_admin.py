"""
Create admin user for TractorCare
"""
from datetime import datetime
from database import users_collection
from auth import hash_password

def create_admin():
    # Check if admin exists
    existing = users_collection.find_one({"username": "admin"})
    
    if existing:
        print("⚠️  Admin user already exists")
        print(f"   Username: {existing['username']}")
        print(f"   Email: {existing['email']}")
        return
    
    # Create admin user
    admin = {
        "username": "admin",
        "email": "admin@tractorcare.rw",
        "hashed_password": hash_password("admin123"),
        "full_name": "Administrator",
        "phone_number": "+250788000000",
        "role": "admin",
        "coop_id": None,
        "is_active": True,
        "created_at": datetime.utcnow(),
        "last_login": None
    }
    
    result = users_collection.insert_one(admin)
    
    print("✅ Admin user created successfully!")
    print(f"   Username: admin")
    print(f"   Password: admin123")
    print(f"   Email: admin@tractorcare.rw")
    print(f"   ID: {result.inserted_id}")
    print("\n⚠️  Please change the password after first login!")

if __name__ == "__main__":
    create_admin()