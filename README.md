# 🌌 Nexus Ops: Autonomous Business Operations Agent

Nexus Ops is a state-of-the-art, cloud-backed autonomous business operations platform. It orchestrates a multi-agent AI pipeline to ingest business reports (via text, URLs, or raw PDFs), detect revenue/operational anomalies, dynamically formulate optimal mitigation strategies, simulate live executions inside a sandbox database, and push real-time telemetry updates to a premium Flutter-based mobile dashboard.

---

## 🏗️ System Architecture

The ecosystem consists of two core decoupled systems:
1. **Backend (`/backend`)**: A robust FastAPI application executing the native multi-agent pipeline using the `google-genai` SDK and backed by a local SQLite Sandbox Database.
2. **Mobile App (`/Mobile App`)**: A premium, highly animated Flutter application linked to Firebase for real-time history stream, authentication, and secure profile management.

---

## 🧠 The Agentic Pipeline Flow

The AI pipeline is engineered for speed, cost-efficiency, and total predictability:
1. **Ingress Preprocessing**: Accepts raw text, scraped web URLs, or multi-page PDFs (processed natively using the Gemini File API).
2. **IE-Agent (Insight Extraction) & IA-Agent (Impact Analysis)**: A merged single-call agent that identifies business anomalies and analyzes their severity.
3. **DA-Agent (Decision Action)**: Maps anomalies to a structured Action Plan (e.g., launching promotions, lowering delivery fees, or generating tickets).
4. **ES-Agent (Execution Simulation)**: A deterministic worker that writes live state changes to the SQLite database, triggers Discord alerts, and logs complete traces.

---

## 🛠️ Backend Setup & Execution (`/backend`)

The backend is built in **Python 3.10+**. Follow these precise steps to get it running:

### 1. Create and Activate Virtual Environment
Open your terminal and navigate to the backend directory:
```bash
cd backend
```
Create a localized virtual environment:
```bash
python -m venv venv
```
Activate the environment:
* **Windows (PowerShell)**:
  ```powershell
  .\venv\Scripts\activate
  ```
* **Mac/Linux**:
  ```bash
  source venv/bin/activate
  ```

### 2. Install Dependencies
Ensure you are using the active virtual environment (you will see `(venv)` in your terminal prompt) and run:
```bash
pip install -r requirements.txt
```

### 3. Environment Variables Configuration
Copy the sample environment file to create your active `.env`:
```bash
cp .env.example .env
```
Open the `.env` file and configure your keys:
* **LLM_PROVIDER**: Set to `gemini` to use your native Google Key, or `openrouter` to use the OpenRouter proxy.
* **GEMINI_API_KEY**: **Must be a valid key starting with `AIzaSy...`** obtained from [Google AI Studio](https://aistudio.google.com/).
* **OPENROUTER_API_KEY**: Your `sk-or-v1-...` key if using OpenRouter.
* **MOCK_DISCORD_WEBHOOK_URL**: Your active Discord channel webhook to receive live alert simulation broadcasts.

### 4. Run the Backend Server
```bash
uvicorn main:app --reload
```
👉 The Developer Console will boot up at **[http://127.0.0.1:8000](http://127.0.0.1:8000)**.

---

## 📱 Mobile App Setup & Execution (`/Mobile App`)

The frontend console is built using **Flutter**. Follow these steps to build and run the client:

### 1. Prerequisite Checklist
* Ensure you have [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
* Make sure a mobile emulator is running, or Google Chrome is available for web debug testing.

### 2. Firebase Console Prerequisites
Before running, you must configure your Firebase project console to support the app's features:
1. **Authentication**:
   * Go to your **Firebase Console ➔ Authentication ➔ Sign-in method**.
   * Click **Add new provider** ➔ select **Email/Password** ➔ Enable it and click **Save**.
2. **Cloud Firestore Database**:
   * Go to **Firebase Console ➔ Firestore Database**.
   * Click **Create Database** and select **Test Mode** (or start in production mode and update rules).
   * Navigate to the **Rules** tab and publish the following configuration to allow development access:
     ```javascript
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /{document=**} {
           allow read, write: if true;
         }
       }
     }
     ```

### 3. Install Packages & Run
Navigate to the mobile directory:
```bash
cd "Mobile App"
```
Install all Flutter pub packages:
```bash
flutter pub get
```
Run the application in Chrome:
```bash
flutter run -d chrome
```

---

## 📁 Repository Directory Structure

```text
Google AI Seekho/
├── backend/                  # 🐍 Python FastAPI Core
│   ├── main.py               # API Routes & App Entrypoint
│   ├── core/                 # Security, Configs & Firebase Auth
│   ├── database/             # SQLite Sandbox Database & Models
│   ├── services/             # AI Multi-Agent & PDF Ingress Pipeline
│   └── requirements.txt      # Python Dependencies
├── Mobile App/               # 📱 Flutter Operations Dashboard
│   ├── lib/
│   │   ├── main.dart         # Flutter App Ingress
│   │   └── screens/          # Auth, Profile, History & Ops Dashboard
│   └── pubspec.yaml          # Flutter Configs & Assets
└── README.md                 # 🌌 This Documentation
```

---

## 🚀 Key Features Implemented
* **Native PDF Processing**: Bypasses heavy local OCR. Uploaded PDFs are piped directly into Gemini's Native File API with custom content-type signaling for zero-latency analysis.
* **Stream-Based Telemetry**: Flutter uses Firestore streams to deliver real-time, zero-refresh history states.
* **Premium Theme & Brand**: Complete bespoke visual identity featuring custom assets, sleek dark mode aesthetics, dynamic glassmorphism indicators, and high-performance micro-animations.

---

## 🧩 Solution Design Overview

Nexus Ops solves a critical operational challenge: **How can businesses react autonomously to unstructured reports, alerts, and documents — without human bottlenecks?**

The system ingests raw business data (plain text, URLs, or PDF reports), feeds it through a chain of specialized AI agents, and produces actionable operational decisions that are **simulated against a live sandbox database** — complete with before/after state tracking and real-time Discord alerting.

### Why This Matters
Traditional business intelligence requires analysts to manually read reports, identify issues, formulate responses, and coordinate execution. Nexus Ops compresses this entire cycle into **a single API call** powered by a multi-agent AI pipeline.

---

## 🤖 Agents Developed

The pipeline uses **4 specialized agents** that execute sequentially. The IE+IA agents are merged into a single Gemini call for cost efficiency (2 LLM calls per run instead of 3).

| # | Agent | Role | LLM Model | Description |
|---|-------|------|-----------|-------------|
| 1 | **IE-Agent** (Insight Extraction) | Data Digestor | `gemini-2.0-flash-lite` | Extracts raw, verifiable data signals and anomalies from unstructured input. No summarization — only structured facts with exact numbers, regions, and severity. |
| 2 | **IA-Agent** (Impact Analysis) | Risk Evaluator | `gemini-2.0-flash-lite` | Assesses business impact across Revenue, Customer Retention, Brand Reputation, and Supply Chain. Assigns severity (LOW → CRITICAL) and estimates financial risk. |
| 3 | **DA-Agent** (Decision Action) | Strategist | `gemini-2.0-flash-lite` | Maps the impact profile to optimal mitigation actions. Can select predefined actions (promotions, pricing changes) OR invent custom strategic actions autonomously. |
| 4 | **ES-Agent** (Execution Simulation) | Sandbox Executor | **No LLM** (Deterministic) | Executes the chosen action against the SQLite sandbox database. Writes live state changes, generates mock emails, triggers Discord webhooks, and logs complete execution traces. |

### Agent Optimization Strategy
- **IE + IA agents are merged** into a single Gemini call to reduce latency and API costs
- `gemini-2.0-flash-lite` is used for text/URL inputs (higher free-tier quota)
- `gemini-2.0-flash` is used for PDF inputs via the Gemini File API (native PDF understanding)
- Auto-retry with exponential backoff (20s → 40s → 80s) on rate-limit errors

---

## 🔌 Real & Mock APIs Used

### Real APIs (Production Services)
| Service | Usage | Details |
|---------|-------|---------|
| **Google Gemini API** (`google-genai` SDK) | Core LLM inference for all agents | Uses `gemini-2.0-flash-lite` for text and `gemini-2.0-flash` for PDF processing via the Gemini File API |
| **Firebase Authentication** | User login/signup & JWT token verification | Email/Password auth with `firebase-admin` SDK for backend token verification |
| **Cloud Firestore** | Real-time session history streaming | Flutter app uses Firestore streams for zero-refresh live history updates |
| **Discord Webhooks** | Live alert broadcasting | ES-Agent posts rich embed notifications to a Discord channel when incident tickets or actions are triggered |
| **OpenRouter API** (fallback) | Alternative LLM proxy | Routes to the same Gemini models via OpenRouter's OpenAI-compatible API when direct Gemini access is unavailable |

### Mock / Simulated APIs
| Mock System | Real-World Equivalent | Simulation Strategy |
|-------------|----------------------|---------------------|
| **Campaign Engine** | Shopify / Stripe | Inserts promo campaigns into SQLite `campaigns` table, increments campaign counters, adjusts customer ratings |
| **Logistics Pricing Engine** | Internal Pricing Backend | Modifies `delivery_fee` in the `system_metrics` table with full transaction logging |
| **SMTP Notification System** | SendGrid / Mailgun | Generates personalized `.html` email files in `sandbox/outbox/` directory |
| **Incident Ticket System** | Jira / Zendesk | Creates incident ticket IDs, updates pending ticket counts, and posts alerts to Discord webhooks |
| **CRM Reimbursement** | Salesforce / HubSpot | Simulates credit triggers and generates customer notification emails |

---

## 🔗 Integrations Implemented

### Backend ↔ Mobile App Integration
- **Firebase Auth**: Flutter app authenticates users → sends JWT token → FastAPI verifies using `firebase-admin` SDK
- **REST API**: Flutter communicates with FastAPI via HTTP POST/GET for pipeline execution, history retrieval, and dashboard state
- **Firestore Streams**: Real-time session history synced between backend writes and Flutter's live UI

### Backend ↔ External Services
- **Gemini File API**: PDFs are uploaded directly to Gemini's File API for native understanding (no local OCR/text extraction needed)
- **Discord Webhook Integration**: ES-Agent posts structured embed alerts with insight, impact, decision reasoning, and projected state changes

### Pipeline Data Flow
```
User Input (Text/URL/PDF)
    → Preprocessor (URL scraping / PDF upload / text passthrough)
    → IE+IA Agent (1 Gemini call → Insight + Impact JSON)
    → DA Agent (1 Gemini call → Action Plan JSON)
    → ES Agent (Deterministic → SQLite writes + Discord alerts + Email mocks)
    → Unified Response (session_id, insight, impact, action, logs, state_change)
```

---

## 📐 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER MOBILE APP                            │
│   Auth Screen → Dashboard → Analysis → History → Profile        │
│   (Firebase Auth + Firestore Streams + HTTP Client)             │
└──────────────────────┬──────────────────────────────────────────┘
                       │ HTTP + Firebase JWT
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│                    FASTAPI BACKEND SERVER                         │
│  ┌──────────────┐  ┌──────────────────┐  ┌───────────────────┐  │
│  │ Firebase Auth │  │ SQLite Sandbox   │  │ Action Registry   │  │
│  │ Middleware    │  │ (Metrics/Camps)  │  │ (Mock Simulators) │  │
│  └──────┬───────┘  └────────▲─────────┘  └────────▲──────────┘  │
│         │                   │                      │             │
│         ▼                   │                      │             │
│  ┌──────────────────────────┴──────────────────────┴──────────┐  │
│  │         AGENTIC PIPELINE (agents.py)                       │  │
│  │  IE+IA Agent → DA Agent → ES Agent (deterministic)        │  │
│  └──────────────────────────┬────────────────────────────────┘  │
└─────────────────────────────┼────────────────────────────────────┘
                              │ API Calls
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│              GOOGLE GEMINI API + DISCORD WEBHOOKS                │
│    gemini-2.0-flash-lite (text) │ gemini-2.0-flash (PDFs)       │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🛡️ Security Model
* **Firebase JWT Authentication** protects all production API routes
* **Service Account**: Backend uses `firebase-service-account.json` for server-side token verification
* **CORS Middleware**: Configured for cross-origin Flutter ↔ FastAPI communication
* **Dev-only test endpoints** (`/api/v1/test/*`) are provided for local development without auth

---

## 🏆 Built With
* **Google Gemini API** (gemini-2.0-flash, gemini-2.0-flash-lite)
* **Google Antigravity** (AI-assisted development & orchestration)
* **FastAPI** (Python 3.10+ backend)
* **Flutter** (Cross-platform mobile app)
* **Firebase** (Auth + Cloud Firestore)
* **SQLite** (Sandbox simulation database)
* **SQLAlchemy** (ORM for database operations)
* **Discord Webhooks** (Real-time alert broadcasting)
