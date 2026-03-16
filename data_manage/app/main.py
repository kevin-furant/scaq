from fastapi import FastAPI, Request
from fastapi.templating import Jinja2Templates

from app.routers import upload, query, download
from app.db.init_db import init_db

app = FastAPI(title="Task Data Service")

templates = Jinja2Templates(directory="app/templates")

@app.on_event("startup")
def startup():
    init_db()

app.include_router(upload.router)
app.include_router(query.router)
app.include_router(download.router)

@app.get("/")
def index(request: Request):
    return templates.TemplateResponse(
        "index.html",
        {"request": request}
    )