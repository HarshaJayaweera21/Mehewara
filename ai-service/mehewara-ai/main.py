"""
Mehewara AI Service — FastAPI Application Entry Point

This is the main application module that configures:
- CORS middleware (allowing the React frontend & .NET backend)
- API router registration
- Startup/shutdown lifecycle events
- Structured logging
"""

from __future__ import annotations
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routes import router as ai_router
from app.config import settings

# ────────────────────────────────────────────────────────────────
# Logging setup
# ────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.DEBUG if settings.is_development else logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("mehewara-ai")


# ────────────────────────────────────────────────────────────────
# Application lifespan (startup / shutdown hooks)
# ────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle manager."""
    # --- Startup ---
    logger.info("=" * 60)
    logger.info("  Mehewara AI Service starting up")
    logger.info("  Environment : %s", settings.environment)
    logger.info("  LLM Model   : %s", settings.gemini_model)
    logger.info("  LLM Ready   : %s", settings.gemini_api_key != "not-set")
    logger.info("  .NET Backend : %s", settings.dotnet_api_base_url)
    logger.info("  CORS Origins : %s", settings.cors_origin_list)
    logger.info("=" * 60)

    yield  # App is running

    # --- Shutdown ---
    logger.info("Mehewara AI Service shutting down")


# ────────────────────────────────────────────────────────────────
# FastAPI application factory
# ────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Mehewara AI Service",
    description=(
        "Agentic AI microservice for the Mehewara municipal works management system. "
        "Provides intelligent report analysis and structuring via Agent 1."
    ),
    version="0.1.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.is_development else None,
    redoc_url="/redoc" if settings.is_development else None,
)

# --- CORS Middleware ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Register Routers ---
app.include_router(ai_router)


# ────────────────────────────────────────────────────────────────
# Root redirect (convenience)
# ────────────────────────────────────────────────────────────────

@app.get("/", include_in_schema=False)
async def root():
    """Root endpoint — redirects to the healthcheck."""
    return {
        "service": "mehewara-ai",
        "docs": "/docs",
        "health": "/internal/ai/health",
    }