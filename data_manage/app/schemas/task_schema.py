from pydantic import BaseModel
from datetime import datetime

class TaskRecordSchema(BaseModel):

    year: int
    time: datetime
    batch_name: str
    sample_name: str
    data_path: str

    class Config:
        orm_mode = True