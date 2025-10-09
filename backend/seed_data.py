"""
Seed sample data for TractorCare
"""
from datetime import datetime
from database import (
    cooperatives_collection, tractors_collection,
    members_collection, bookings_collection, maintenance_records_collection
)

def seed_data():
    print("🌱 Seeding sample data...\n")
    
    # Clear existing data (optional - comment out in production)
    # cooperatives_collection.delete_many({})
    # tractors_collection.delete_many({})
    # members_collection.delete_many({})
    
    # 1. Create Cooperative
    coop = {
        "coop_id": "COOP001",
        "name": "Kayonza Farmers Cooperative",
        "location": "Kayonza",
        "district": "Kayonza",
        "province": "Eastern Province",
        "contact_person": "John Mugisha",
        "phone_number": "+250788123456",
        "email": "kayonza@coop.rw",
        "registration_date": datetime.utcnow(),
        "total_members": 0
    }
    
    if not cooperatives_collection.find_one({"coop_id": "COOP001"}):
        cooperatives_collection.insert_one(coop)
        print("✓ Cooperative created: Kayonza Farmers Cooperative")
    else:
        print("⚠ Cooperative COOP001 already exists")
    
    # 2. Create Tractors
    tractors = [
        {
            "tractor_id": "TR001",
            "coop_id": "COOP001",
            "model": "MF_240",
            "serial_number": "MF240-2023-001",
            "purchase_date": datetime(2023, 1, 15),
            "engine_hours": 1200.0,
            "usage_intensity": "moderate",
            "current_status": "available",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
            "last_maintenance_date": datetime(2024, 6, 15)
        },
        {
            "tractor_id": "TR002",
            "coop_id": "COOP001",
            "model": "MF_375",
            "serial_number": "MF375-2023-002",
            "purchase_date": datetime(2023, 3, 20),
            "engine_hours": 800.0,
            "usage_intensity": "heavy",
            "current_status": "available",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
            "last_maintenance_date": datetime(2024, 7, 10)
        },
        {
            "tractor_id": "TR003",
            "coop_id": "COOP001",
            "model": "JOHN_DEERE_5075E",
            "serial_number": "JD5075-2023-003",
            "purchase_date": datetime(2023, 6, 10),
            "engine_hours": 450.0,
            "usage_intensity": "light",
            "current_status": "maintenance",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
            "last_maintenance_date": datetime(2024, 8, 5)
        }
    ]
    
    for tractor in tractors:
        if not tractors_collection.find_one({"tractor_id": tractor["tractor_id"]}):
            tractors_collection.insert_one(tractor)
            print(f"✓ Tractor created: {tractor['tractor_id']} ({tractor['model']})")
        else:
            print(f"⚠ Tractor {tractor['tractor_id']} already exists")
    
    # 3. Create Members
    members = [
        {
            "member_id": "MEM001",
            "coop_id": "COOP001",
            "name": "Jean Baptiste Mukiza",
            "phone_number": "+250788111222",
            "id_number": "1199780123456789",
            "is_premium": True,
            "membership_status": "active",
            "join_date": datetime(2023, 2, 1)
        },
        {
            "member_id": "MEM002",
            "coop_id": "COOP001",
            "name": "Marie Claire Uwase",
            "phone_number": "+250788222333",
            "id_number": "1198870234567890",
            "is_premium": False,
            "membership_status": "active",
            "join_date": datetime(2023, 3, 15)
        },
        {
            "member_id": "MEM003",
            "coop_id": "COOP001",
            "name": "Emmanuel Nkusi",
            "phone_number": "+250788333444",
            "id_number": "1197760345678901",
            "is_premium": True,
            "membership_status": "active",
            "join_date": datetime(2023, 1, 20)
        }
    ]
    
    for member in members:
        if not members_collection.find_one({"member_id": member["member_id"]}):
            members_collection.insert_one(member)
            print(f"✓ Member created: {member['name']}")
        else:
            print(f"⚠ Member {member['member_id']} already exists")
    
    # Update cooperative member count
    member_count = members_collection.count_documents({"coop_id": "COOP001"})
    cooperatives_collection.update_one(
        {"coop_id": "COOP001"},
        {"$set": {"total_members": member_count}}
    )
    
    # 4. Create sample bookings
    bookings = [
        {
            "tractor_id": "TR001",
            "member_id": "MEM001",
            "coop_id": "COOP001",
            "start_date": datetime(2025, 10, 15),
            "end_date": datetime(2025, 10, 17),
            "booking_status": "confirmed",
            "payment_status": "paid",
            "payment_amount_rwf": 150000,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
    ]
    
    for booking in bookings:
        bookings_collection.insert_one(booking)
        print(f"✓ Booking created: {booking['tractor_id']} for {booking['member_id']}")
    
    # 5. Create sample maintenance records
    maintenance = [
        {
            "tractor_id": "TR001",
            "task_name": "engine_oil_change",
            "description": "Regular engine oil and filter change",
            "date": datetime(2024, 6, 15),
            "engine_hours_at_service": 1050.0,
            "cost_rwf": 25000,
            "performed_by": "Mechanic A",
            "notes": "Used synthetic oil",
            "created_at": datetime.utcnow()
        },
        {
            "tractor_id": "TR001",
            "task_name": "air_filter_check",
            "description": "Air filter inspection and cleaning",
            "date": datetime(2024, 8, 1),
            "engine_hours_at_service": 1150.0,
            "cost_rwf": 5000,
            "performed_by": "Mechanic B",
            "notes": "Filter cleaned, no replacement needed",
            "created_at": datetime.utcnow()
        }
    ]
    
    for record in maintenance:
        maintenance_records_collection.insert_one(record)
        print(f"✓ Maintenance record created: {record['task_name']} for {record['tractor_id']}")
    
    print("\n✅ Sample data seeding complete!")
    print(f"   - 1 Cooperative")
    print(f"   - {len(tractors)} Tractors")
    print(f"   - {len(members)} Members")
    print(f"   - {len(bookings)} Bookings")
    print(f"   - {len(maintenance)} Maintenance records")

if __name__ == "__main__":
    seed_data()