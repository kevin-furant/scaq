from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
from app.models.task_record import TaskRecord

router = APIRouter()

def get_db():

    db = SessionLocal()

    try:
        yield db

    finally:
        db.close()


@router.get("/query")
def query(
    start_time: str,
    end_time: str,
    page: int = 1,
    size: int = 50,
    db: Session = Depends(get_db)
):

    q = db.query(TaskRecord).filter(
        TaskRecord.time.between(start_time, end_time)
    )

    total = q.count()

    result = q.offset((page-1)*size).limit(size).all()

    return {
        "total": total,
        "data": result
    }