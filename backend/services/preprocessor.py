"""
preprocessor.py
Universal input pre-processor — text, URL, and PDF only (no images).

Pipeline:
  plain text → normalize + truncate (3000 chars)
  URL        → trafilatura extracts clean article body → normalize
  PDF bytes  → returned as-is for Gemini File API (or pypdf fallback for Groq)
"""

import re
import io
from dataclasses import dataclass
from typing import Optional

MAX_TEXT_CHARS = 3000   # ~750 tokens — enough for business insight extraction
_URL_RE = re.compile(r'^https?://\S+$', re.IGNORECASE)


# ── Output schema ─────────────────────────────────────────────────────────────
@dataclass
class ProcessedInput:
    text: str              # Clean text for LLM (empty string for native PDF)
    input_type: str        # "text" | "url" | "pdf" | "*_failed"
    source_label: str      # Human-readable label for audit logs
    pdf_bytes: Optional[bytes] = None    # Raw PDF bytes (Gemini File API / pypdf fallback)
    pdf_filename: Optional[str] = None


# ── Text normalizer ───────────────────────────────────────────────────────────
def _normalize(text: str, max_chars: int = MAX_TEXT_CHARS) -> str:
    """Remove noise, collapse whitespace, truncate."""
    # Remove zero-width and non-printable chars
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]', '', text)
    # Collapse whitespace to single spaces
    text = re.sub(r'[ \t]+', ' ', text)
    # Max 2 consecutive newlines
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()[:max_chars]


# ── URL extractor (trafilatura) ───────────────────────────────────────────────
def _process_url(url: str) -> ProcessedInput:
    """
    Uses trafilatura — extracts ONLY the article body from a webpage.
    Ignores navigation, ads, sidebars, footers automatically.
    Result is 5-10x cleaner and more token-efficient than regex HTML stripping.
    """
    try:
        import trafilatura

        downloaded = trafilatura.fetch_url(url)
        if not downloaded:
            raise ValueError("Page could not be fetched (empty response).")

        # extract() returns the main article content as clean plain text
        article_text = trafilatura.extract(
            downloaded,
            include_comments=False,
            include_tables=True,
            no_fallback=False,
        )

        if not article_text or len(article_text.strip()) < 50:
            raise ValueError("Trafilatura could not extract meaningful content.")

        clean = _normalize(article_text)
        return ProcessedInput(
            text=f"[Source: {url}]\n\n{clean}",
            input_type="url",
            source_label=url,
        )

    except Exception as e:
        return ProcessedInput(
            text=f"Failed to extract content from URL: {url}\nError: {e}",
            input_type="url_failed",
            source_label=url,
        )


# ── PDF handler ───────────────────────────────────────────────────────────────
def _process_pdf(file_bytes: bytes, filename: str) -> ProcessedInput:
    """
    Returns raw PDF bytes for the agents layer to handle.
    - Gemini provider: uploads via File API (native understanding)
    - Groq provider:   falls back to pypdf text extraction
    The decision is made in agents.py based on LLM_PROVIDER env var.
    """
    if len(file_bytes) == 0:
        return ProcessedInput(
            text="Uploaded PDF was empty.",
            input_type="pdf_failed",
            source_label=filename,
        )
    return ProcessedInput(
        text="",           # agents.py fills this for Groq fallback
        input_type="pdf",
        source_label=filename,
        pdf_bytes=file_bytes,
        pdf_filename=filename,
    )


# ── Main dispatcher ───────────────────────────────────────────────────────────
def preprocess(
    text_input: Optional[str] = None,
    file_bytes: Optional[bytes] = None,
    file_mime: Optional[str] = None,
    filename: Optional[str] = None,
) -> ProcessedInput:
    """
    Universal entry point. Priority: file upload > URL > plain text.
    Supports: plain text, URLs, PDF files.
    Images are not supported (removed for MVP scope).
    """
    # 1. File upload
    if file_bytes and file_mime:
        if file_mime == "application/pdf":
            return _process_pdf(file_bytes, filename or "document.pdf")
        return ProcessedInput(
            text=f"Unsupported file type '{file_mime}'. Only PDF is supported.",
            input_type="unsupported",
            source_label=filename or "unknown",
        )

    # 2. URL detection
    raw = (text_input or "").strip()
    if _URL_RE.match(raw):
        return _process_url(raw)

    # 3. Plain text — normalize and truncate
    return ProcessedInput(
        text=_normalize(raw),
        input_type="text",
        source_label="manual_input",
    )
