"""
auth.py
Firebase Admin SDK initialization and FastAPI JWT verification dependency.
Every protected endpoint injects `get_current_user` to validate the Bearer token.
"""

import os
import firebase_admin
from firebase_admin import credentials, auth as firebase_auth
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from dotenv import load_dotenv

load_dotenv()

# ── Initialize Firebase Admin SDK (runs once at import time) ──────────────────
_credentials_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")

if not firebase_admin._apps:
    try:
        cred = credentials.Certificate(_credentials_path)
        firebase_admin.initialize_app(cred)
        print(f"[OK] Firebase Admin SDK initialized from: {_credentials_path}")
    except Exception as e:
        print(f"[WARN] Firebase initialization failed: {e}")
        print("   Protected endpoints will reject all requests.")

# ── HTTP Bearer extractor ─────────────────────────────────────────────────────
_security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_security),
) -> dict:
    """
    FastAPI dependency that:
    1. Extracts the Firebase JWT from the Authorization header.
    2. Cryptographically verifies it against Firebase public keys.
    3. Returns a user context dict: { uid, email, role }.

    Raises HTTP 401 if token is missing, expired, or invalid.
    """
    token = credentials.credentials
    try:
        decoded = firebase_auth.verify_id_token(token)
        return {
            "uid": decoded.get("uid"),
            "email": decoded.get("email", "unknown@user.com"),
            # Custom claim: set via Firebase Admin SDK or defaults to analyst
            "role": decoded.get("role", "marketing_analyst"),
        }
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase token has expired. Please re-authenticate.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except firebase_auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token. Authentication failed.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Authentication error: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
