# Mehewara AI service

Updated 2026-09-26. Python 3.12+ FastAPI service using LangGraph and LangChain's Gemini integration. See the [root guide](../../README.md) and [API reference](<../../Mehewara_API_Contract (1).md>).

## Current pipeline

Agent 1 (report analysis) - Agent 2 (single-Problem consolidation) - Agent 3 (priority/crew recommendation) - end. Agent 3 is skipped for UNCERTAIN consolidation. There is no Agent 4 node or generated/saved task plan.

Tools inspect context supplied by ASP.NET and a local asset catalogue. They do not call separate backend tool endpoints. Agent 1 receives text, location information, and the number of photos; it does not inspect photo contents. Agents 1/2 require Gemini configuration. Agent 3 can use rule-based fallback after missing configuration or a failed model call, but that does not make the whole pipeline independent of Gemini.

## Setup

From this directory, with Python 3.12+ and uv installed:

```powershell
uv sync --extra dev
Copy-Item .env.example .env
```

Copy the example only when creating a new local environment file; keep existing values if already configured. Set `GEMINI_API_KEY` in this service's `.env`. `GEMINI_MODEL` overrides the model setting. The code's current model default is `gemini-3.5-flash-lite`; this is a statement about configuration, not verification of provider availability.

Other settings in `app/config.py`: `DOTNET_API_BASE_URL` (default `http://localhost:5153`), `PORT` (8000), `ENVIRONMENT` (development), and `CORS_ORIGINS`. The default backend URL differs from the actual .NET http profile (5194); current tools use supplied data rather than that URL for fetching context. `docker/.env` is not this service's environment file.

```powershell
uv run uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

The explicit command chooses the server port; changing the Settings.PORT field alone does not change this command.

## Routes

| Route | Result |
| --- | --- |
| GET / | JSON containing service and route links |
| GET /internal/ai/health | Health metadata and whether an LLM key appears configured |
| GET /internal/ai/workflows/diagram | Mermaid graph text |
| POST /internal/ai/workflows | Workflow execution and returned analysis |

Development docs are at `/docs`. These routes are intended for ASP.NET, but the router currently has no service-authentication check. Binding locally in the command above limits that development listener; the code itself does not enforce an internal network boundary.

## Input and output

Request: `workflowId`, `report`, and optional `context` arrays `candidateProblems`, `relatedReports`, `availableCrews`. Photo entries require non-null filename and MIME type, unlike the public report request. Output includes `status`, `workflowId`, `message`, `reportAnalysis`, `problemAnalysis`, `priorityAnalysis`, `recommendations`, and the compatibility `analysis` field.

Agent 2 returns LINK_EXISTING, CREATE_NEW, or UNCERTAIN as a single decision. Its output is not the old `problemLinks[]` format. Agent 3 permits `NEW_PROBLEM`/`NONE` strings; these conflict with the .NET recommendation ID types. Unknown Agent 1 categories become ENVIRONMENT. The recent-job tool returns only one active reference and assumes IN_PROGRESS. These are known limits, not guaranteed correct behavior.

No durable per-step checkpoint or saved workflow queue exists. Later-stage errors can be reported as completed. ASP.NET owns result persistence and currently assigns VALID to Agent 3 results without Agent 4.

## Tests

```powershell
uv run pytest
```

Checked-in modules cover Problem consolidation, priority/crew recommendation, and workflow behavior. Test presence does not establish a fully validated end-to-end application. Tests were not executed during this documentation update. Model-call retries are configured in `app/llm.py`; they do not provide durable whole-workflow recovery.
