from fastapi import FastAPI, Request
from fastapi.templating import Jinja2Templates

from app.routers import upload, query, download
from app.db.init_db import init_db

app = FastAPI(
    title="Task Data Service",
    version="1.0"
)

# 初始化数据库
@app.on_event("startup")
def startup():
    init_db()

# 注册API路由
app.include_router(upload.router)
app.include_router(query.router)
app.include_router(download.router)

# 注册模板目录
templates = Jinja2Templates(directory="app/templates")


# 首页
@app.get("/")
def home(request: Request):
    return templates.TemplateResponse(
        "index.html",
        {"request": request}
    )