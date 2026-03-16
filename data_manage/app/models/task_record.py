from sqlalchemy import Column, Integer, String, DateTime
from app.db.database import Base

class TaskRecord(Base):

    __tablename__ = "task_records"

    id = Column(Integer, primary_key=True, index=True)

    year = Column(Integer, index=True)

    time = Column(DateTime, index=True)

    batch_name = Column(String(100), index=True)

    sample_name = Column(String(100))

    data_path = Column(String(255))