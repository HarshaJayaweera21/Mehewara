"""
Mehewara AI Service — Centralized LLM Provider & Factory
"""

from __future__ import annotations
import logging
from langchain_google_genai import ChatGoogleGenerativeAI
from app.config import settings

logger = logging.getLogger(__name__)


def is_llm_configured() -> bool:
    """Check if a valid Gemini API key is configured."""
    return (
        bool(settings.gemini_api_key)
        and settings.gemini_api_key not in ("not-set", "your-gemini-api-key-here", "")
    )


def get_llm(
    temperature: float = 0.1,
    model: str | None = None,
    max_retries: int = 3,
) -> ChatGoogleGenerativeAI:
    """
    Factory function providing a configured ChatGoogleGenerativeAI instance.

    Reused across all multi-agent components to ensure consistent model selection,
    temperature defaults, and centralized API key management.

    Args:
        temperature: Sampling temperature (default 0.1 for factual precision).
        model: Optional override for the model name (defaults to settings.gemini_model).
        max_retries: Number of retry attempts on network/rate-limit errors.
    """
    selected_model = model or settings.gemini_model

    return ChatGoogleGenerativeAI(
        model=selected_model,
        google_api_key=settings.gemini_api_key,
        temperature=temperature,
        max_retries=max_retries,
    )
