from fastapi import FastAPI

app = FastAPI(
    title="Mehewara AI Service",
    description="Agentic AI service for the Mehewara municipal works management system",
    version="1.0.0",
)


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "mehewara-ai",
    }