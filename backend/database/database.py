"""
database.py
SQLAlchemy engine, session factory, and database initialization.
"""

import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./sandbox.db")

# connect_args is required for SQLite to allow multi-threaded access
engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False},
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    """FastAPI dependency: yields a database session and closes it after request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Create all tables defined in models.py."""
    from .models import SystemMetrics, Campaigns, UserSessions  # noqa: F401
    Base.metadata.create_all(bind=engine)


def seed_db():
    """Populate the database with initial sandbox values if empty."""
    from .models import SystemMetrics
    db = SessionLocal()
    try:
        existing = db.query(SystemMetrics).first()
        if not existing:
            initial_metrics = SystemMetrics(
                active_campaigns_count=3,
                avg_customer_rating=4.2,
                regional_order_volume_lahore=1200,
                delivery_fee_lahore=150.0,
                pending_incident_tickets=0,
            )
            db.add(initial_metrics)
            db.commit()
            print("[OK] Database seeded with initial sandbox metrics.")
        else:
            print("[INFO] Database already seeded. Skipping.")
    finally:
        db.close()
