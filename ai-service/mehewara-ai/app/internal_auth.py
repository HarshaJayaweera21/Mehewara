"""Shared-secret authentication for service-to-service AI requests."""
import secrets
from fastapi import Header, HTTPException
from app.config import settings


def require_internal_key(x_internal_api_key: str = Header(default="")) -> None:
    expected = settings.internal_ai_api_key
    if not expected or not secrets.compare_digest(x_internal_api_key.encode(), expected.encode()):
        raise HTTPException(status_code=401, detail="Invalid internal service credentials")
