# 🚀 Antigravity Autonomous Business Operations Backend

This is the core orchestration backend for the Antigravity system, built as a highly modular, decoupled **FastAPI** application. It implements a native multi-agent pipeline using the `google-genai` SDK, bypassing heavy frameworks like LangChain/CrewAI to ensure near-zero latency, total transparency, and perfect logging control.

---

## 🏗️ Architecture & File Structure

The backend follows a professional multi-layer Domain-Driven Design (MVC-like) architecture to keep the AI logic strictly separated from the HTTP routing and database layers.

```text
backend/
├── main.py                # 🚪 API Router & Entry Point
├── core/                  
│   └── auth.py            # 🔒 Firebase Security & Core Configs
├── database/              
│   ├── database.py        # 🗄️ Connection Pooling & Sandbox init
│   └── models.py          # 📊 SQLAlchemy Tables (Metrics, Campaigns)
├── services/              
│   ├── agents.py          # 🧠 The "Brain" (Antigravity Orchestrator)
│   └── preprocessor.py    # 🧹 Input Cleaning & Extraction (PDFs, URLs)
├── static/                
│   └── index.html         # 🖥️ Developer Console UI
├── requirements.txt       # Python Dependencies
└── .env                   # Secrets & Configs
```

---

## 🧠 The Agentic Flow (`services/agents.py`)

The system autonomously ingests business inputs and routes them through a 4-step pipeline:

1. **Ingress & Preprocessing**: `preprocessor.py` accepts text, URLs (via `trafilatura`), and raw PDFs, standardizing them into LLM-ready context.
2. **IE-Agent (Insight Extraction)**: Identifies the core data signals, anomalies, and metrics from the raw context *without summarizing*.
3. **IA-Agent (Impact Analysis)**: Assesses the severity and strategic implications of the extracted anomaly (e.g., *Is this a critical revenue loss?*).
4. **DA-Agent (Decision Action)**: Selects the optimal mitigation strategy from an internal Action Registry (e.g., `LAUNCH_REGIONAL_PROMOTION`, `TRIGGER_INCIDENT_TICKET`).
5. **ES-Agent (Execution Simulation)**: A deterministic worker agent that strictly executes the DA-Agent's plan. It updates the SQLite Sandbox database, pushes mobile dashboard alerts, and triggers simulated Discord webhooks.

> **Note on Efficiency:** The IE-Agent and IA-Agent are merged into a *single* Gemini call using a dual-role prompt, reducing quota consumption and latency by 33%.

---

## 🛠️ Setup Instructions

### 1. Python Environment
Create and activate a virtual environment:
```bash
cd backend
python -m venv venv

# Windows
.\venv\Scripts\activate
# Mac/Linux
source venv/bin/activate
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Environment Variables
Copy the `.env.example` file to `.env`:
```bash
cp .env.example .env
```
Inside `.env`, configure your API Keys:
* **LLM_PROVIDER**: Set to `gemini` (native API) or `openrouter` (temporary proxy).
* **GEMINI_API_KEY**: Your `AIza...` key from Google AI Studio.
* **OPENROUTER_API_KEY**: Your `sk-or-...` key from OpenRouter.

### 4. Run the Server
```bash
uvicorn main:app --reload
```
Once running, the Developer Console will be available at:
👉 **[http://127.0.0.1:8000](http://127.0.0.1:8000)**

---

## 📊 The Sandbox Database (`database/`)

The system comes with a built-in SQLite database (`sandbox.db`) to safely simulate a live business environment. 
* When the ES-Agent executes an action (e.g., launching a campaign), it writes directly to `Campaigns`.
* It updates `SystemMetrics` (e.g., Customer Rating, Active Campaigns).
* The Dev Console UI tracks these live state changes (Before ➔ After) dynamically.
* All agent traces are logged and audited in the `UserSessions` table.
