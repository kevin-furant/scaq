from fastapi import APIRouter, UploadFile, Depends
from sqlalchemy.orm import Session

from app.db.database import SessionLocal
from app.utils.excel_parser import parse_file
from app.services.task_service import bulk_insert

router = APIRouter()

def get_db():

    db = SessionLocal()

    try:
        yield db

    finally:
        db.close()


@router.post("/upload")
async def upload(file: UploadFile, db: Session = Depends(get_db)):

    records = parse_file(file)

    bulk_insert(db, records)

    return {"msg": "upload success"}