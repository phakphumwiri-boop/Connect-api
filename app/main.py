from fastapi import FastAPI

from app.routes.chat import router as chat
from app.routes.history import (
    router as history
)
from app.routes.github import (
    router as github
)

app = FastAPI(
    title="ISH API",
    version="1.0.0"
)

app.include_router(chat)
app.include_router(history)
app.include_router(github)\napp.include_router(machines)


@app.get("/health")
async def health():
    return {
        "status": "ok"
    }
