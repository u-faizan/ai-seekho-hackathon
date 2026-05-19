# 🏗️ Backend Architecture & File Structure

The backend is built as a highly modular, decoupled **FastAPI** application following professional, enterprise-grade directory structuring. 

By grouping files by their architectural domain (`core`, `database`, `services`), the system is scalable, clean, and extremely easy to read for the hackathon judges.

## 📂 Directory Map
```text
backend/
├── main.py                # API Router & Entry Point
├── core/                  # Core System Logic
│   └── auth.py            # Firebase JWT Middleware & Security
├── database/              # Database Layer
│   ├── database.py        # SQLite Sandbox Connection & SessionMaker
│   └── models.py          # SQLAlchemy ORM Tables (Metrics, Campaigns)
├── services/              # Domain Services & AI Business Logic
│   ├── agents.py          # Google Antigravity Agentic Orchestrator
│   └── preprocessor.py    # Input Cleaning, HTML/PDF extraction
├── static/                # Static Files
│   └── index.html         # Developer Console UI
├── requirements.txt       # Python Dependencies
└── .env                   # Secrets & Configs
```

---

## 📄 Component Responsibilities

### 1. `main.py` (The API Gateway)
* **Role**: Handles all HTTP traffic, routing, and Pydantic validation.
* **Key Endpoints**:
    * `POST /api/v1/analyze`: The main agentic flow.
    * `POST /api/v1/test/upload`: File processing bridge.
* **Rule**: Strictly un-opinionated. Does *not* contain AI logic. Only routes data.

### 2. `services/` (The Business Logic)
* **`preprocessor.py`**: The cleaning layer. Standardizes messy URLs, PDFs, and raw text into clean tokens before hitting the LLM.
* **`agents.py`**: The "Brain" of the operation. Contains the `run_pipeline()` orchestrator that explicitly routes data through:
    1. **IE-Agent**: Insight Extraction.
    2. **IA-Agent**: Impact Analysis.
    3. **DA-Agent**: Decision Action.
    4. **ES-Agent**: Execution Simulation (Deterministic).

### 3. `database/` (The Sandbox)
* **Role**: Manages the local SQLite database to simulate a live business environment.
* **`models.py`**: Defines the `SystemMetrics`, `Campaigns`, and `UserSessions` tables.
* **`database.py`**: Handles connection pooling, thread-safe access, and database initialization.

### 4. `core/` (Security & Core Configs)
* **`auth.py`**: The Bouncer. Intercepts incoming requests to validate Firebase JWT tokens, ensuring only authorized team members can trigger the agentic operations pipeline.

---

## 🔄 The Data Flow Architecture

1. **Ingress**: Client sends an unstructured payload (text/URL/PDF) to `main.py`.
2. **Cleaning**: Payload is passed to `services.preprocessor` to extract raw context.
3. **Reasoning**: Context goes into `services.agents`, kicking off the multi-agent THOUGHT/ACTION flow.
4. **Action**: The DA-Agent selects a mitigation action and passes it to the ES-Agent.
5. **Simulation**: The ES-Agent connects to `database.models` to update the sandbox metrics (e.g. active campaigns, delivery fees).
6. **Egress**: The execution trace and state delta are returned to the client as JSON.
