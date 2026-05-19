"""
models.py
SQLAlchemy ORM table definitions for the sandbox database.
"""

import uuid
from datetime import datetime
from sqlalchemy import Column, Integer, Float, String, DateTime, Text
from .database import Base


class SystemMetrics(Base):
    """Tracks live operational KPIs of the simulated business."""
    __tablename__ = "system_metrics"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
    active_campaigns_count = Column(Integer, default=0)
    avg_customer_rating = Column(Float, default=4.0)
    regional_order_volume_lahore = Column(Integer, default=0)
    delivery_fee_lahore = Column(Float, default=150.0)
    pending_incident_tickets = Column(Integer, default=0)


class Campaigns(Base):
    """Stores all simulated promotional campaigns created by the agent."""
    __tablename__ = "campaigns"

    id = Column(Integer, primary_key=True, index=True)
    promo_code = Column(String, unique=True, index=True)
    discount_percentage = Column(Integer, default=0)
    target_region = Column(String)
    status = Column(String, default="Active")   # "Active" or "Ended"
    projected_reach = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)


class UserSessions(Base):
    """Audit trail: stores every agentic run per user for the History Log."""
    __tablename__ = "user_sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, index=True)          # Firebase UID
    user_email = Column(String, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
    input_text = Column(Text)                     # Original unstructured input
    insight = Column(Text)                        # IE-Agent JSON (stored as string)
    action_taken = Column(String)                 # DA-Agent decision type
    logs = Column(Text)                           # ES-Agent trace logs (JSON string)
    before_state = Column(Text)                   # Metrics snapshot before action
    after_state = Column(Text)                    # Metrics snapshot after action
