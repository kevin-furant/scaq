from sqlalchemy.orm import Session
from app.models.task_record import TaskRecord

def bulk_insert(db: Session, records):

    objs = [TaskRecord(**r) for r in records]

    db.bulk_save_objects(objs)

    db.commit()