FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_PROJECT_ENVIRONMENT=/opt/venv

WORKDIR /app
RUN pip install --no-cache-dir uv

COPY ai-service/mehewara-ai/pyproject.toml ai-service/mehewara-ai/uv.lock ./
RUN uv sync --frozen --no-dev

COPY ai-service/mehewara-ai/ .
EXPOSE 8000

CMD ["uv", "run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
