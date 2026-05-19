"""
agents.py
Google Antigravity multi-agent pipeline.
Stages: IE+IA (merged, 1 Gemini call) → DA (1 Gemini call) → ES (no LLM)

Optimizations:
  - IE+IA merged → 2 Gemini calls per run (down from 3)
  - gemini-2.0-flash-lite for text/URL (higher free-tier quota)
  - gemini-2.0-flash for PDFs via File API (native understanding)
  - Auto-retry with exponential backoff on 429 rate-limit errors
"""

import io
import os
import json
import uuid
import time
import httpx
from datetime import datetime
from dotenv import load_dotenv, find_dotenv
from google import genai
from google.genai import types  # type: ignore
from google.genai.errors import ClientError  # type: ignore

# Loads .env from backend/ first, then searches parent directories (project root)
load_dotenv(find_dotenv(usecwd=True) or find_dotenv(), override=True)

# ── Provider config ───────────────────────────────────────────────────────────
# Temporary switch: set LLM_PROVIDER=openrouter in .env to use OpenRouter.
# When you have a real Gemini key: set LLM_PROVIDER=gemini (or remove the var).
LLM_PROVIDER = os.getenv("LLM_PROVIDER", "gemini").lower()   # "gemini" | "openrouter"

# Gemini models (used when LLM_PROVIDER=gemini)
LITE_MODEL  = "gemini-2.0-flash-lite"  # text/URL — high free-tier quota
FLASH_MODEL = "gemini-2.0-flash"       # PDFs via Gemini File API

# OpenRouter models — same Gemini models, accessed via OpenRouter proxy
OR_MODEL      = os.getenv("OPENROUTER_MODEL", "google/gemini-2.0-flash-lite-001")
OR_MODEL_FULL = "google/gemini-2.0-flash-001"        # for complex tasks (optional)

MAX_RETRIES = 3
BASE_WAIT   = 20   # seconds (matches Gemini's suggested retry delay)

# Only initialize Gemini client if using Gemini directly
if LLM_PROVIDER == "gemini":
    client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
else:
    client = None   # Not used for OpenRouter

DISCORD_WEBHOOK_URL = os.getenv("MOCK_DISCORD_WEBHOOK_URL", "").strip()


# ── Core: Gemini text call with retry ─────────────────────────────────────────
def _call_gemini(system_prompt: str, user_content: str, model: str = None) -> dict:
    """
    Text-only Gemini call. Uses LITE_MODEL by default.
    Auto-retries up to MAX_RETRIES times on 429 with exponential backoff.
    """
    model = model or LITE_MODEL
    last_error = None

    for attempt in range(MAX_RETRIES):
        try:
            response = client.models.generate_content(
                model=model,
                contents=user_content,
                config=types.GenerateContentConfig(
                    system_instruction=system_prompt,
                    response_mime_type="application/json",
                ),
            )
            return json.loads(response.text)
        except json.JSONDecodeError:
            return {"raw_response": response.text}
        except ClientError as e:
            last_error = e
            if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e):
                wait = BASE_WAIT * (2 ** attempt)   # 20s → 40s → 80s
                print(f"[WARN] Gemini rate limit (attempt {attempt+1}/{MAX_RETRIES}). "
                      f"Waiting {wait}s before retry...")
                time.sleep(wait)
                continue
            raise
        except Exception:
            raise

    raise last_error or RuntimeError("Gemini call failed after all retries.")


# ── OpenRouter call (temporary — remove when switching back to Gemini key) ────
# Uses the same Gemini models via OpenRouter's OpenAI-compatible proxy.
# No new packages needed — uses httpx which is already installed.
def _call_openrouter(system_prompt: str, user_content: str) -> dict:
    key = os.getenv("OPENROUTER_API_KEY", "").strip()
    if not key:
        raise RuntimeError("OPENROUTER_API_KEY not set in .env")

    for attempt in range(MAX_RETRIES):
        try:
            resp = httpx.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {key}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": "http://localhost:8000",
                },
                json={
                    "model": OR_MODEL,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user",   "content": user_content},
                    ],
                    "response_format": {"type": "json_object"},
                    "max_tokens": 800,  # Lowered to 800 to resolve OpenRouter 402 low balance reservation limits
                },
                timeout=60,
            )
            resp.raise_for_status()
            content = resp.json()["choices"][0]["message"]["content"]
            return json.loads(content)
        except json.JSONDecodeError:
            return {"raw_response": content}
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 429:
                wait = BASE_WAIT * (2 ** attempt)
                print(f"[WARN] OpenRouter rate limit (attempt {attempt+1}/{MAX_RETRIES}). "
                      f"Waiting {wait}s...")
                time.sleep(wait)
                continue
            # Print exact error from OpenRouter for debugging 400 Bad Request
            err_msg = f"[ERROR] OpenRouter HTTP {e.response.status_code}: {e.response.text}"
            print(err_msg)
            raise RuntimeError(f"OpenRouter API Error: {err_msg}") from e
        except Exception:
            raise

    raise RuntimeError("OpenRouter call failed after all retries.")


# ── LLM router — swap provider here by changing LLM_PROVIDER in .env ─────────
def _call_llm(system_prompt: str, user_content: str) -> dict:
    """Routes to Gemini or OpenRouter based on LLM_PROVIDER env var."""
    if LLM_PROVIDER == "openrouter":
        return _call_openrouter(system_prompt, user_content)
    return _call_gemini(system_prompt, user_content)


# ── PDF: Gemini File API call ──────────────────────────────────────────────────
def _call_gemini_pdf(system_prompt: str, pdf_bytes: bytes, filename: str) -> dict:
    """
    Uploads PDF to Gemini File API and runs generation with native PDF understanding.
    Uses FLASH_MODEL (File API requires flash, not lite).
    Cleans up the uploaded file after use.
    """
    last_error = None

    # Upload PDF bytes to Gemini File API
    file_ref = client.files.upload(
        file=io.BytesIO(pdf_bytes),
        config=types.UploadFileConfig(
            mime_type="application/pdf",
            display_name=filename[:40],
        ),
    )

    try:
        for attempt in range(MAX_RETRIES):
            try:
                response = client.models.generate_content(
                    model=FLASH_MODEL,
                    contents=[file_ref, f"Analyze this PDF document: {filename}"],
                    config=types.GenerateContentConfig(
                        system_instruction=system_prompt,
                        response_mime_type="application/json",
                    ),
                )
                return json.loads(response.text)
            except json.JSONDecodeError:
                return {"raw_response": response.text}
            except ClientError as e:
                last_error = e
                if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e):
                    wait = BASE_WAIT * (2 ** attempt)
                    print(f"[WARN] Gemini rate limit on PDF call (attempt {attempt+1}/{MAX_RETRIES}). "
                          f"Waiting {wait}s...")
                    time.sleep(wait)
                    continue
                raise
            except Exception:
                raise
    finally:
        # Always clean up — Gemini auto-expires files after 48h anyway
        try:
            client.files.delete(name=file_ref.name)
        except Exception:
            pass

    raise last_error or RuntimeError("Gemini PDF call failed after all retries.")


# ── Merged IE+IA system prompt ────────────────────────────────────────────────
_IE_IA_SYSTEM = """
You are a dual-role Business Intelligence AI performing TWO tasks in one response.

TASK 1 — INSIGHT EXTRACTION:
Extract structured facts from the business input (text, web article, or PDF).
Do NOT summarize. Extract raw, verifiable data signals only. 
CRITICAL: If the text contains specific numbers (e.g., 'dropped from 3 million to 1 million', '25% decrease'), you MUST include those exact numbers in your insight description.

TASK 2 — IMPACT ANALYSIS:
Analyze the extracted facts for business impact on Revenue, Customer Retention,
Brand Reputation, and Supply Chain.

CHART RULE: Set generate_chart=true ONLY when data has clear comparable numbers
(e.g. 25% drop, week-over-week volume). Default to false — only chart when it adds value.

Return a SINGLE valid JSON with BOTH sections:
{
  "insight": {
    "anomaly": "Detailed, executive-level description of the core anomaly or event (2-3 sentences)",
    "affected_area": "region, department, or product",
    "percentage_change": null or float,
    "direction": "decline" or "increase" or "stable",
    "primary_cause": "inferred or stated root cause",
    "urgency": "LOW" or "MEDIUM" or "HIGH" or "CRITICAL",
    "extracted_entities": ["list", "of", "key", "nouns"],
    "input_summary": "one sentence summarizing what the input was about"
  },
  "impact": {
    "severity": "LOW" or "MEDIUM" or "HIGH" or "CRITICAL",
    "affected_metrics": ["list of KPIs impacted"],
    "financial_risk_estimate": "descriptive string e.g. PKR 450,000 weekly",
    "strategic_implication": "Comprehensive analysis of the strategic and operational consequences (2-3 sentences)",
    "time_sensitivity": "how urgently action is needed",
    "chart_suggestion": {
      "generate_chart": true or false,
      "reason": "brief explanation",
      "chart_type": "bar" or "line" or null,
      "metric_name": "metric label" or null,
      "labels": ["label1", "label2"] or null,
      "values": [number, number] or null
    }
  }
}
"""

_DA_SYSTEM = """
You are a strategic Decision-Making Agent for an Autonomous Business Operations system.
Based on the impact report, choose the best action to take. You can select a predefined operational action (like 'LAUNCH_REGIONAL_PROMOTION', 'UPDATE_LOGISTICS_PRICING', 'TRIGGER_INCIDENT_TICKET') OR completely invent a custom strategic action (e.g., 'HIRE_MORE_DRIVERS', 'PAUSE_MARKETING_SPEND', 'AUDIT_SUPPLY_CHAIN').

Return valid JSON:
{
  "action_type": "A short, UPPERCASE string identifying the action (invent a new one if needed)",
  "action_title": "A short, punchy title for the action (MAX 4-5 words, e.g., 'Halt Karachi Logistics' or 'Launch Regional Promo')",
  "target_region": "exact region name mentioned, or 'global'",
  "parameters": {
    "discount_percentage": null or integer,
    "promo_code": null or string,
    "valid_days": null or integer,
    "new_fee": null or float,
    "reimbursement_amount": null or float,
    "ticket_priority": null or "LOW"/"MEDIUM"/"HIGH"
  },
  "decision_reasoning": "A concise explanation of WHY this specific action was chosen.",
  "projected_outcomes": [
    {
      "metric": "A specific operational KPI or status that will change (e.g., 'Karachi Shipments', 'Brand Risk', 'Active Campaigns')",
      "before_state": "The state BEFORE the action is executed (e.g., 'Blocked / Flooded', 'CRITICAL', '3')",
      "after_state": "The projected state AFTER the action is executed (e.g., 'Rerouted via Hyderabad', 'LOW (Mitigated)', '4')"
    }
  ]
}
"""


# ── Merged IE+IA Agent ─────────────────────────────────────────────────────────
def ie_ia_agent(text: str = None, pdf_bytes: bytes = None, pdf_filename: str = None):
    """
    Single call covering Insight Extraction + Impact Analysis.
    - PDF (Gemini direct): uses Gemini File API.
    - PDF (OpenRouter): uses pypdf text fallback.
    - Text: uses standard text call.
    Returns (insight_dict, impact_dict).
    """
    if pdf_bytes:
        if LLM_PROVIDER == "openrouter":
            # OpenRouter doesn't support Gemini File API, fallback to text extraction
            import pypdf  # type: ignore
            reader = pypdf.PdfReader(io.BytesIO(pdf_bytes))
            extracted_text = "\n".join(page.extract_text() or "" for page in reader.pages)
            user_msg = f"Analyze this PDF text ({pdf_filename}):\n\n{extracted_text[:4000]}"
            result = _call_llm(_IE_IA_SYSTEM, user_msg)
        else:
            result = _call_gemini_pdf(_IE_IA_SYSTEM, pdf_bytes, pdf_filename or "document.pdf")
    else:
        user_msg = f"Analyze the following business input:\n\n{text}"
        result = _call_llm(_IE_IA_SYSTEM, user_msg)

    insight = result.get("insight", result)
    impact  = result.get("impact", {
        "severity": "MEDIUM",
        "strategic_implication": "See insight.",
        "chart_suggestion": {"generate_chart": False},
    })
    return insight, impact


# ── DA-Agent ──────────────────────────────────────────────────────────────────
def da_agent(impact_report: dict) -> dict:
    return _call_llm(_DA_SYSTEM, json.dumps(impact_report))


# ── ES-Agent (deterministic — no Gemini call) ─────────────────────────────────
def es_agent(action_plan: dict, db_session, logs: list = None, insight: dict = None, impact: dict = None) -> dict:
    from database.models import SystemMetrics, Campaigns

    if logs is None:
        logs = []

    action_type = action_plan.get("action_type", "UNKNOWN")
    params  = action_plan.get("parameters", {})
    region  = action_plan.get("target_region", "unknown")
    ts      = lambda: datetime.utcnow().strftime("%H:%M:%S.%f")[:-3]

    logs.append(f"[{ts()}] ES-Agent initialized. Simulating action: {action_type}")

    metrics = db_session.query(SystemMetrics).first()
    before_state = {
        "active_campaigns_count": metrics.active_campaigns_count,
        "avg_customer_rating":    metrics.avg_customer_rating,
        "regional_order_volume":  metrics.regional_order_volume_lahore,
        "delivery_fee_lahore":    metrics.delivery_fee_lahore,
        "pending_incident_tickets": metrics.pending_incident_tickets,
    }

    if action_type == "LAUNCH_REGIONAL_PROMOTION":
        promo_code = params.get("promo_code") or \
                     f"{region.upper()[:3]}{params.get('discount_percentage', 10)}"
        reach = 5000
        logs.append(f"[{ts()}] ActionRegistry: Connecting to Mock Campaign Database...")
        existing = db_session.query(Campaigns).filter_by(promo_code=promo_code).first()
        if not existing:
            db_session.add(Campaigns(
                promo_code=promo_code,
                discount_percentage=params.get("discount_percentage", 10),
                target_region=region, status="Active", projected_reach=reach,
            ))
            metrics.active_campaigns_count += 1
            metrics.avg_customer_rating = round(min(5.0, metrics.avg_customer_rating + 0.3), 1)
            db_session.commit()
            logs.append(f"[{ts()}] MockDB: Campaign inserted — {promo_code} ({region})")
        else:
            logs.append(f"[{ts()}] MockDB: {promo_code} already exists. Skipping.")
        logs.append(f"[{ts()}] NotificationEngine: Mock alerts queued for {reach:,} users.")
        logs.append(f"[{ts()}] MobileOps: Pushed campaign alert to Mobile Dashboard.")

    elif action_type == "UPDATE_LOGISTICS_PRICING":
        new_fee = params.get("new_fee") or round(metrics.delivery_fee_lahore * 1.15, 2)
        old_fee = metrics.delivery_fee_lahore
        logs.append(f"[{ts()}] ActionRegistry: Connecting to Logistics Pricing Engine...")
        metrics.delivery_fee_lahore = new_fee
        db_session.commit()
        logs.append(f"[{ts()}] MockDB: delivery_fee {old_fee} → {new_fee} PKR")
        logs.append(f"[{ts()}] NotificationEngine: Fee-change notification drafted.")
        logs.append(f"[{ts()}] MobileOps: Pushed pricing update to Mobile Dashboard.")

    elif action_type == "DISPATCH_CUSTOMER_REIMBURSEMENT":
        amount   = params.get("reimbursement_amount", 500)
        outbox   = os.path.join(os.path.dirname(__file__), "sandbox", "outbox")
        os.makedirs(outbox, exist_ok=True)
        email_id = str(uuid.uuid4())[:8]
        with open(os.path.join(outbox, f"email_{email_id}.html"), "w") as f:
            f.write(f"<html><body><h2>Reimbursement Notice</h2>"
                    f"<p>PKR {amount} credit for disruptions in {region}.</p>"
                    f"<p>– Autonomous Operations Agent</p></body></html>")
        logs.append(f"[{ts()}] SMTP Mock: email_{email_id}.html → sandbox/outbox/")
        metrics.avg_customer_rating = round(min(5.0, metrics.avg_customer_rating + 0.1), 1)
        db_session.commit()

    elif action_type == "TRIGGER_INCIDENT_TICKET":
        priority  = params.get("ticket_priority", "HIGH")
        ticket_id = f"INC-{str(uuid.uuid4())[:6].upper()}"
        metrics.pending_incident_tickets += 1
        db_session.commit()
        logs.append(f"[{ts()}] IncidentEngine: Ticket {ticket_id} (Priority: {priority})")
        logs.append(f"[{ts()}] MobileOps: Sent critical incident alert to Mobile App.")
        if DISCORD_WEBHOOK_URL:
            try:
                _insight_text = insight.get('anomaly', 'N/A') if insight else 'N/A'
                _impact_text = impact.get('strategic_implication', 'N/A') if impact else 'N/A'
                
                custom_title = action_plan.get('action_title', f'Incident Ticket: {ticket_id}')
                
                fields = [
                    {"name": "🧠 Insight", "value": _insight_text},
                    {"name": "💥 Impact", "value": _impact_text},
                    {"name": "🤔 Decision", "value": action_plan.get('decision_reasoning', 'N/A')},
                    {"name": "🎯 Action Executed", "value": f"`{action_type}` (Ticket: {ticket_id})"}
                ]
                
                # Append dynamic outcomes to Discord fields!
                outcomes = action_plan.get('projected_outcomes', [])
                if outcomes:
                    fields.append({"name": "📈 Dynamic State Changes (Simulation Forecast)", "value": "\n".join(
                        f"• **{o.get('metric')}**: {o.get('before_state')} ➔ **{o.get('after_state')}**"
                        for o in outcomes
                    )})
                
                payload = {
                    "embeds": [{
                        "title": f"🚨 {custom_title}",
                        "color": 16711680,
                        "fields": fields,
                        "footer": {"text": f"Priority: {priority} | Region: {region}"}
                    }]
                }
                
                with httpx.Client(timeout=5) as hx:
                    hx.post(DISCORD_WEBHOOK_URL, json=payload)
                logs.append(f"[{ts()}] Discord: Alert posted.")
            except Exception as e:
                logs.append(f"[{ts()}] Discord: Webhook failed ({e}).")
        else:
            logs.append(f"[{ts()}] Discord: Not configured.")
    else:
        # Handle free-form AI suggested actions (Custom Actions)
        logs.append(f"[{ts()}] ActionRegistry: Generated Custom Strategic Recommendation - {action_type}")
        logs.append(f"[{ts()}] MobileOps: Pushed custom recommendation alert to Mobile Dashboard.")
        if DISCORD_WEBHOOK_URL:
            try:
                _insight_text = insight.get('anomaly', 'N/A') if insight else 'N/A'
                _impact_text = impact.get('strategic_implication', 'N/A') if impact else 'N/A'
                custom_title = action_plan.get('action_title', f'Custom: {action_type}')
                
                fields = [
                    {"name": "🧠 Insight", "value": _insight_text},
                    {"name": "💥 Impact", "value": _impact_text},
                    {"name": "🤔 Decision", "value": action_plan.get('decision_reasoning', 'N/A')},
                    {"name": "🎯 Action Suggested", "value": f"`{action_type}`"}
                ]
                
                # Append dynamic outcomes to Discord fields!
                outcomes = action_plan.get('projected_outcomes', [])
                if outcomes:
                    fields.append({"name": "📈 Dynamic State Changes (Simulation Forecast)", "value": "\n".join(
                        f"• **{o.get('metric')}**: {o.get('before_state')} ➔ **{o.get('after_state')}**"
                        for o in outcomes
                    )})
                
                payload = {
                    "embeds": [{
                        "title": f"💡 Suggestion: {custom_title}",
                        "color": 3447003,  # Blue color for suggestions
                        "fields": fields,
                        "footer": {"text": f"Region: {region}"}
                    }]
                }
                with httpx.Client(timeout=5) as hx:
                    hx.post(DISCORD_WEBHOOK_URL, json=payload)
                logs.append(f"[{ts()}] Discord: Suggestion alert posted.")
            except Exception as e:
                logs.append(f"[{ts()}] Discord: Webhook failed ({e}).")

    db_session.refresh(metrics)
    after_state = {
        "active_campaigns_count": metrics.active_campaigns_count,
        "avg_customer_rating":    metrics.avg_customer_rating,
        "regional_order_volume":  metrics.regional_order_volume_lahore,
        "delivery_fee_lahore":    metrics.delivery_fee_lahore,
        "pending_incident_tickets": metrics.pending_incident_tickets,
    }
    logs.append(f"[{ts()}] ES-Agent: Simulation complete. State delta recorded.")
    return {"logs": logs, "before_state": before_state, "after_state": after_state}


# ── Master Pipeline Orchestrator ──────────────────────────────────────────────
def run_pipeline(
    raw_input:  str,
    user:       dict,
    db_session,
    file_bytes: bytes = None,
    file_mime:  str   = None,
    filename:   str   = None,
) -> dict:
    """
    Full Antigravity pipeline:
    preprocess → IE+IA (1 Gemini call) → DA (1 Gemini call) → ES → audit log
    Total Gemini calls: 2 per run.
    """
    from database.models import UserSessions
    from .preprocessor import preprocess

    session_id = str(uuid.uuid4())

    # Pipeline Execution Logs (to show reasoning in console)
    logs = []
    ts = lambda: datetime.utcnow().strftime("%H:%M:%S.%f")[:-3]

    # Step 0: Pre-process input
    processed = preprocess(
        text_input=raw_input,
        file_bytes=file_bytes,
        file_mime=file_mime,
        filename=filename,
    )
    logs.append(f"[{ts()}] System: Ingested unstructured input from source: {processed.source_label}")
    logs.append(f"[{ts()}] Orchestrator: Activating IE-Agent (Insight Extraction)...")
    logs.append(f"[{ts()}] IE-Agent [THOUGHT]: I need to extract verifiable data signals and anomalies without summarizing.")

    # Step A+B: IE+IA merged
    insight, impact = ie_ia_agent(
        text=processed.text or None,
        pdf_bytes=processed.pdf_bytes,
        pdf_filename=processed.pdf_filename,
    )
    logs.append(f"[{ts()}] IE-Agent [ACTION]: Extract business context.")
    logs.append(f"[{ts()}] IE-Agent [OBSERVATION]: {insight.get('anomaly', 'Anomaly detected')}")
    
    logs.append(f"[{ts()}] IA-Agent [THOUGHT]: I must determine the severity and business implication of this anomaly.")
    logs.append(f"[{ts()}] IA-Agent [OBSERVATION]: Severity assessed as {impact.get('severity', 'UNKNOWN')}. {impact.get('strategic_implication', '')}")

    logs.append(f"[{ts()}] Orchestrator: Activating DA-Agent (Decision Making)...")
    logs.append(f"[{ts()}] DA-Agent [THOUGHT]: Based on the impact, I must select the optimal mitigation strategy from the Action Registry.")

    # Step C: DA
    action_plan = da_agent(impact)
    act_type = action_plan.get('action_type', 'UNKNOWN')
    act_rat  = action_plan.get('decision_reasoning', 'No rationale provided')
    
    logs.append(f"[{ts()}] DA-Agent [PLAN]: {act_rat}")
    logs.append(f"[{ts()}] DA-Agent [ACTION]: Selected {act_type} for execution.")
    
    logs.append(f"[{ts()}] Orchestrator: Handoff to ES-Agent for simulation...")
    simulation = es_agent(action_plan, db_session, logs=logs, insight=insight, impact=impact)

    # Step E: Audit log
    db_session.add(UserSessions(
        id=session_id,
        user_id=user.get("uid", "anonymous"),
        user_email=user.get("email", ""),
        input_text=processed.source_label,
        insight=json.dumps(insight),
        action_taken=action_plan.get("action_type", "UNKNOWN"),
        logs=json.dumps(simulation["logs"]),
        before_state=json.dumps(simulation["before_state"]),
        after_state=json.dumps(simulation["after_state"]),
    ))
    db_session.commit()

    return {
        "session_id":         session_id,
        "timestamp":          datetime.utcnow().isoformat() + "Z",
        "input_type":         processed.input_type,
        "source_label":       processed.source_label,
        "insight":            insight,
        "impact":             impact,
        "recommended_action": action_plan,
        "execution_logs":     simulation["logs"],
        "state_change": {
            "before": simulation["before_state"],
            "after":  simulation["after_state"],
        },
    }
