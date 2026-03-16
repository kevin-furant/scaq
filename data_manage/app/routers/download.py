from fastapi import APIRouter, Depends
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
from app.models.task_record import TaskRecord
import pandas as pd

router = APIRouter()

def get_db():

    db = SessionLocal()

    try:
        yield db

    finally:
        db.close()


@router.get("/download")
def download(start_time:str,end_time:str,db:Session=Depends(get_db)):

    result = db.query(TaskRecord).filter(
        TaskRecord.time.between(start_time,end_time)
    ).all()

    data = [r.__dict__ for r in result]

    df = pd.DataFrame(data)

    file = "result.xlsx"

    df.to_excel(file,index=False)

    return FileResponse(file,filename="result.xlsx")