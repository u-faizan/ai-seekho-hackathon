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
