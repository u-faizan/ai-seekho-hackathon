"""
main.py
FastAPI application entry point.
Mounts all API routes and serves the static test dashboard.
"""

import json
import os
from contextlib import asynccontextmanager
from datetime import datetime

from fastapi import FastAPI, Depends, HTTPException, status, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import Optional

from database.database import get_db, init_db, seed_db
from core.auth import get_current_user
from services.agents import run_pipeline
from database.models import SystemMetrics, Campaigns, UserSessions

# ── Lifespan: initialize DB tables and seed defaults ─────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Runs once on startup
    init_db()
    seed_db()
    print("[OK] Server ready at http://127.0.0.1:8000")
    yield
    # Runs on shutdown (add cleanup here if needed)


# ── App Setup ─────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Autonomous Business Operations Agent",
    description="Insight → Action System | Google AI Seekho Hackathon",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Restrict to your domains in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Pydantic Request Schemas ──────────────────────────────────────────────────
class AnalysisRequest(BaseModel):
    source: str = "manual_input"
    data_type: str = "text/plain"
    content: str


class ActionExecutionRequest(BaseModel):
    action_type: str
    target_region: str = "global"
    parameters: dict = {}


class ChatRequest(BaseModel):
    message: str


# ── ROUTE 1: Full Agentic Pipeline (Protected) ────────────────────────────────
@app.post("/api/v1/analyze")
async def analyze(
    request: AnalysisRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Protected endpoint for React/Flutter frontends.
    Requires a valid Firebase JWT token in the Authorization header.
    """
    if not request.content.strip():
        raise HTTPException(status_code=400, detail="Content field cannot be empty.")

    result = run_pipeline(
        raw_input=request.content,
        user=current_user,
        db_session=db,
    )
    return result


# ── ROUTE 1b: DEV-ONLY Test Endpoint (No Auth Required) ───────────────────────
@app.post("/api/v1/test/analyze")
async def test_analyze(
    request: AnalysisRequest,
    db: Session = Depends(get_db),
):
    """
    Unprotected endpoint exclusively for the static test console.
    NO Firebase token required. Used during development only.
    DO NOT expose this in production without auth.
    """
    if not request.content.strip():
        raise HTTPException(status_code=400, detail="Content field cannot be empty.")

    # Use a mock dev user so session history still gets written correctly
    dev_user = {"uid": "dev-test-user", "email": "dev@test.local", "role": "operations_admin"}

    try:
        result = run_pipeline(
            raw_input=request.content,
            user=dev_user,
            db_session=db,
        )
        return result
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Pipeline error: {str(e)}"
        )


# ── ROUTE 1c: DEV-ONLY Dashboard State (No Auth Required) ─────────────────────
@app.get("/api/v1/test/dashboard-state")
async def test_dashboard_state(db: Session = Depends(get_db)):
    """Unprotected dashboard state fetch for the static test console."""
    metrics   = db.query(SystemMetrics).first()
    campaigns = db.query(Campaigns).filter_by(status="Active").all()

    return {
        "metrics": {
            "active_campaigns_count": metrics.active_campaigns_count if metrics else 0,
            "avg_customer_rating": metrics.avg_customer_rating if metrics else 0,
            "regional_order_volume_lahore": metrics.regional_order_volume_lahore if metrics else 0,
            "delivery_fee_lahore": metrics.delivery_fee_lahore if metrics else 0,
        },
        "active_campaigns": [
            {
                "promo_code": c.promo_code,
                "discount_percentage": c.discount_percentage,
                "target_region": c.target_region,
                "projected_reach": c.projected_reach,
                "created_at": c.created_at.isoformat(),
            }
            for c in campaigns
        ],
    }


# ── ROUTE 1d: DEV-ONLY Reset (No Auth Required) ───────────────────────────────
@app.post("/api/v1/test/reset-state")
async def test_reset_state(db: Session = Depends(get_db)):
    """Unprotected reset for the static test console."""
    db.query(Campaigns).delete()
    db.query(UserSessions).delete()
    db.query(SystemMetrics).delete()
    db.commit()
    seed_db()
    return {"detail": "Sandbox reset to initial defaults."}


# ── ROUTE 1e: DEV-ONLY File Upload (No Auth Required) ─────────────────────────
@app.post("/api/v1/test/upload")
async def test_upload(
    file: UploadFile = File(...),
    text: Optional[str] = Form(default=""),
    db: Session = Depends(get_db),
):
    """
    Accepts a PDF file + optional extra text context.
    Gemini reads the PDF natively via File API (no text extraction needed).
    No auth required (dev only).
    """
    if file.content_type != "application/pdf":
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported type '{file.content_type}'. Only PDF is accepted."
        )

    file_bytes = await file.read()
    if len(file_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded PDF is empty.")

    dev_user = {"uid": "dev-test-user", "email": "dev@test.local", "role": "operations_admin"}

    try:
        result = run_pipeline(
            raw_input=text or "",
            user=dev_user,
            db_session=db,
            file_bytes=file_bytes,
            file_mime=file.content_type,
            filename=file.filename,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Pipeline error: {str(e)}")


# ── ROUTE 2: Direct Action Execution Override ─────────────────────────────────
@app.post("/api/v1/execute-action")
async def execute_action(
    request: ActionExecutionRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Manually trigger a specific action simulation without running all agents."""
    from services.agents import es_agent

    action_plan = {
        "action_type": request.action_type,
        "target_region": request.target_region,
        "parameters": request.parameters,
        "rationale": "Manually triggered via /execute-action endpoint.",
    }
    simulation = es_agent(action_plan, db)
    return {
        "action_executed": request.action_type,
        "execution_logs": simulation["logs"],
        "state_change": {
            "before": simulation["before_state"],
            "after": simulation["after_state"],
        },
    }


# ── ROUTE 3: Dashboard State ───────────────────────────────────────────────────
@app.get("/api/v1/dashboard-state")
async def dashboard_state(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Returns live sandbox metrics, active campaigns, and recent session history."""
    metrics   = db.query(SystemMetrics).first()
    campaigns = db.query(Campaigns).filter_by(status="Active").all()
    sessions  = db.query(UserSessions).order_by(UserSessions.timestamp.desc()).limit(10).all()

    return {
        "metrics": {
            "active_campaigns_count": metrics.active_campaigns_count if metrics else 0,
            "avg_customer_rating": metrics.avg_customer_rating if metrics else 0,
            "regional_order_volume_lahore": metrics.regional_order_volume_lahore if metrics else 0,
            "delivery_fee_lahore": metrics.delivery_fee_lahore if metrics else 0,
        },
        "active_campaigns": [
            {
                "promo_code": c.promo_code,
                "discount_percentage": c.discount_percentage,
                "target_region": c.target_region,
                "projected_reach": c.projected_reach,
                "created_at": c.created_at.isoformat(),
            }
            for c in campaigns
        ],
        "recent_sessions": [
            {
                "session_id": s.id,
                "user_email": s.user_email,
                "action_taken": s.action_taken,
                "timestamp": s.timestamp.isoformat(),
            }
            for s in sessions
        ],
    }


# ── ROUTE 4: History Log (Gap Fix #1) ─────────────────────────────────────────
@app.get("/api/v1/history")
async def get_history(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Returns all past session records for the logged-in user (filtered by Firebase UID)."""
    sessions = (
        db.query(UserSessions)
        .filter(UserSessions.user_id == current_user["uid"])
        .order_by(UserSessions.timestamp.desc())
        .all()
    )
    return [
        {
            "session_id": s.id,
            "timestamp": s.timestamp.isoformat(),
            "input_text": s.input_text,
            "insight": json.loads(s.insight) if s.insight else {},
            "action_taken": s.action_taken,
            "logs": json.loads(s.logs) if s.logs else [],
            "before_state": json.loads(s.before_state) if s.before_state else {},
            "after_state": json.loads(s.after_state) if s.after_state else {},
        }
        for s in sessions
    ]


# ── ROUTE 5: Delete History Entry (Gap Fix #1) ────────────────────────────────
@app.delete("/api/v1/history/{session_id}")
async def delete_history(
    session_id: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Deletes a specific session record. Only the owning user can delete their runs."""
    session = db.query(UserSessions).filter(
        UserSessions.id == session_id,
        UserSessions.user_id == current_user["uid"],
    ).first()

    if not session:
        raise HTTPException(status_code=404, detail="Session not found or access denied.")

    db.delete(session)
    db.commit()
    return {"detail": f"Session {session_id} deleted successfully."}


# ── ROUTE 6: Reset Sandbox Database ───────────────────────────────────────────
@app.post("/api/v1/reset-state")
async def reset_state(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Wipes all sandbox data and re-seeds to initial default values."""
    db.query(Campaigns).delete()
    db.query(UserSessions).delete()
    db.query(SystemMetrics).delete()
    db.commit()
    seed_db()
    return {"detail": "Sandbox database has been reset to initial defaults."}


# ── ROUTE: Health Check ───────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat() + "Z"}


# ── ROUTE: Gemini API Test (ping + simple chat) ────────────────────────────────
@app.post("/api/v1/test/gemini-chat")
async def gemini_chat(request: ChatRequest):
    """
    Minimal Gemini call — verify API key and quota status.
    Accepts: {"message": "your text"}
    """
    from google import genai as _genai
    from google.genai.errors import ClientError as _ClientError  # type: ignore

    message = request.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="message field is required.")

    try:
        _client = _genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
        response = _client.models.generate_content(
            model="gemini-2.0-flash-lite",
            contents=message,
        )
        return {
            "status": "ok",
            "model": "gemini-2.0-flash-lite",
            "reply": response.text,
        }
    except _ClientError as e:
        err = str(e)
        if "429" in err or "RESOURCE_EXHAUSTED" in err:
            raise HTTPException(status_code=429, detail=f"Gemini quota exhausted. {err[:300]}")
        raise HTTPException(status_code=500, detail=f"Gemini API error: {err[:300]}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error: {str(e)[:300]}")


# ── Serve Static Test Dashboard ───────────────────────────────────────────────
static_dir = os.path.join(os.path.dirname(__file__), "static")
os.makedirs(static_dir, exist_ok=True)
app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")
