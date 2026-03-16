from app.db.database import engine
from app.models.task_record import TaskRecord
from app.db.database import Base

def init_db():

    Base.metadata.create_all(bind=engine)