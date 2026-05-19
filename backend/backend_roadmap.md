# 🗺️ Backend Implementation Roadmap & Development Guide
## Autonomous Business Operations Agent (Insight ➔ Action System)

This document is your step-by-step developer blueprint. Hand these individual milestones to your coding assistant (such as Gemini 3.1 High or Claude 3.5 Sonnet) to build and assemble the production-ready FastAPI backend.

---

## 📅 Milestone 1: Environment & Package Initialization

Your first step is to establish an isolated environment and define all core packages.

### 📋 Checklist & Tasks
* [ ] **1. Create Python Virtual Environment (`venv`)**:
  * Run: `python -m venv venv` inside the `backend/` directory.
  * Activate it: `.\venv\Scripts\Activate.ps1` (Windows PowerShell).
* [ ] **2. Create `requirements.txt`**:
  Create the file containing these explicit libraries:
  ```text
  fastapi>=0.110.0
  uvicorn[standard]>=0.28.0
  pydantic>=2.6.0
  sqlalchemy>=2.0.0
  python-dotenv>=1.0.0
  firebase-admin>=6.5.0
  google-generativeai>=0.4.0
  jinja2>=3.1.0
  httpx>=0.27.0
  ```
* [ ] **3. Install dependencies**:
  * Run: `pip install -r requirements.txt`

> [!WARNING]
> **Discord Webhook Guard (Gap Fix #2):** In your `.env`, `MOCK_DISCORD_WEBHOOK_URL` is currently empty. The backend **must** include a guard: *"If `MOCK_DISCORD_WEBHOOK_URL` is empty or unset, skip the Discord POST and only log the alert to the terminal and SQLite logs."* This prevents the server from crashing during demo if no webhook is configured.

---

## 🗄️ Milestone 2: SQLite Database Sandbox & Schema

We will build the local sandbox database state using **SQLAlchemy** to store operational metrics, campaigns, and user history logs.

### 📋 Schema Blueprint (Pydantic & DB Models)
Create `database.py` and `models.py` with these three critical tables:

1. **`SystemMetrics` Table**:
   * `id`: Integer (Primary Key)
   * `timestamp`: DateTime (Default now)
   * `active_campaigns_count`: Integer
   * `avg_customer_rating`: Float
   * `regional_order_volume_lahore`: Integer
   * `delivery_fee_lahore`: Float
2. **`Campaigns` Table**:
   * `id`: Integer (Primary Key)
   * `promo_code`: String (Unique)
   * `discount_percentage`: Integer
   * `target_region`: String
   * `status`: String ("Active" or "Ended")
   * `projected_reach`: Integer
3. **`UserSessions` Table (Operational History)**:
   * `id`: String (UUID, Primary Key)
   * `user_id`: String (Firebase UID)
   * `timestamp`: DateTime
   * `input_text`: String (Unstructured feed)
   * `insight`: JSON String (Facts extracted)
   * `action_taken`: String
   * `logs`: JSON String (Agent execution traces)
   * `before_state`: JSON String
   * `after_state`: JSON String

### 🧪 Database Seeding script
Write a seed function to populate the database with initial values on server startup:
* `active_campaigns_count`: 3
* `avg_customer_rating`: 4.2
* `regional_order_volume_lahore`: 1200
* `delivery_fee_lahore`: 150.0

---

## 🔒 Milestone 3: Firebase Auth Verification Dependency

Create `auth.py` to establish the FastAPI backend gatekeeper middleware using the `firebase-admin` SDK.

### 📋 Checklist & Tasks
* [ ] **Initialize SDK**: Load credentials from `firebase-service-account.json`.
* [ ] **Create Security Dependency `get_current_user`**:
  * Use FastAPI’s `HTTPBearer` to extract the ID Token from the header.
  * Verify the token using `auth.verify_id_token(token)`.
  * Return a Python dict containing the user's `uid`, `email`, and `role` (Operations Admin, Logistics Manager, etc.).
  * Raise `HTTPException(status_code=401)` if verification fails.

---

## 🤖 Milestone 4: Google Antigravity Agent workflows

Create `agents.py` to organize the multi-agent pipeline using Google Antigravity.

### 📋 Checklist & Tasks
* [ ] **Configure Gemini Clients**: Load `GEMINI_API_KEY` from `.env`.
* [ ] **Define Agent Prompting & Outputs**:
  * **IE-Agent (Insight Extraction)**: Prompt Gemini 2.5 Flash to extract raw values, targets, and percentage drops. Enforce a clean JSON schema output.
  * **IA-Agent (Impact Analysis)**: Prompt Gemini 2.5 Pro to evaluate implications on revenue, customer churn, and operational latency. Return JSON.
  * **DA-Agent (Decision Agent)**: Prompt Gemini 2.5 Pro to match impacts against the Available Action Registry and formulate execution parameters.
* [ ] **Define ES-Agent (Execution Simulation Engine)**:
  * Creates a record in the `Campaigns` table if the action is `LAUNCH_REGIONAL_PROMOTION`.
  * Updates `delivery_fee_lahore` in `SystemMetrics` if the action is `UPDATE_LOGISTICS_PRICING`.
  * Writes simulated execution logs.
  * Saves an `.html` email draft under `sandbox/outbox/` if email triggers occur.
  * If `MOCK_DISCORD_WEBHOOK_URL` is set, POST a formatted alert message to the Discord channel. **Otherwise, skip silently and log to terminal only.**
* [ ] **Final Pipeline Step — Session History Write (Gap Fix #3)**:
  * After the ES-Agent completes successfully, write the **entire session record** to the `UserSessions` table:
    * `user_id` (from Firebase JWT)
    * `input_text` (original unstructured input)
    * `insight` (IE-Agent JSON output)
    * `action_taken` (DA-Agent decision)
    * `logs` (ES-Agent execution trace)
    * `before_state` and `after_state` (SQLite metrics snapshot delta)
  * This is what powers the dashboard **History Log** tab and enables per-user audit trail viewing.

---

## 🔌 Milestone 5: FastAPI Routes & Main Gateway

Assemble the REST API inside `main.py` using FastAPI routers.

### 📋 Required Endpoints
1. **`POST /api/v1/analyze`** *(Protected)*:
   * Accepts raw unstructured operational text.
   * Runs the Google Antigravity agent pipeline.
   * Reads metrics "Before", mutates database (Action Simulation), reads metrics "After".
   * Saves the full session record to the `UserSessions` audit history table.
   * Returns unified JSON output (Insight, Impact, Action, Logs, Before vs. After).
2. **`GET /api/v1/dashboard-state`** *(Protected)*:
   * Returns current active metrics, active campaigns list, and recent session history logs.
3. **`POST /api/v1/reset-state`** *(Protected)*:
   * Deletes and re-seeds the SQLite database back to its initial mock settings for fresh demo pitches.
4. **`GET /api/v1/history`** *(Protected — Gap Fix #1)*:
   * Returns all past `UserSessions` records filtered by the **logged-in user's Firebase UID**.
   * Each record includes: timestamp, input_text, action_taken, before/after state.
   * Powers the **"History Log"** tab on the dashboard — allows judges to click any past run and replay the full agent reasoning chain.
5. **`DELETE /api/v1/history/{session_id}`** *(Protected — Gap Fix #1)*:
   * Deletes a specific session record by its UUID.
   * Allows users to clean up old or test runs before a live demo submission.

---

## 🌐 Milestone 6: Live Test Webpage (Static Sandbox Console)

We will serve a single-page HTML application straight from our backend to visual-test the system instantly.

### 📋 Checklist & Tasks
* [ ] **Create `backend/static/index.html`**:
  * Build a clean Tailwind-styled webpage containing:
    * A text box to paste unstructured operational inputs.
    * A **"Run Agentic Flow"** button.
    * An **Interactive Terminal Log timeline** that displays agent traces in real time (e.g., green checkmarks for completed agents).
    * A **Before vs. After comparative dashboard panel** showing metrics delta.
    * A **Simulated Database Inspector** table displaying active campaigns.
* [ ] **Mount Static Files in `main.py`**:
  ```python
  from fastapi.staticfiles import StaticFiles
  app.mount("/", StaticFiles(directory="static", html=True), name="static")
  ```
