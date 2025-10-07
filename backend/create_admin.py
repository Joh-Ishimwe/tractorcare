from database import SessionLocal
from auth import hash_password
import models

db = SessionLocal()

existing = db.query(models.User).filter(models.User.username == "admin").first()
if existing:
    print("Admin already exists")
    print(f"Username: {existing.username}")
    print(f"Email: {existing.email}")
else:
    admin = models.User(
        username="admin",
        email="admin@tractorcare.rw",
        hashed_password=hash_password("admin123"),
        full_name="Administrator",
        role="admin"
    )
    db.add(admin)
    db.commit()
    print("Admin created: admin / admin123")

db.close()