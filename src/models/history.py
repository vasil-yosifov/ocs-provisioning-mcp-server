from typing import Any, Dict, Optional
from pydantic import BaseModel
from src.models.common import EntityType

class AccountHistory(BaseModel):
    interactionId: str
    entityId: str
    entityType: EntityType
    creationDate: str
    description: Optional[str] = None
    direction: Optional[str] = None
    reason: Optional[str] = None
    status: Optional[str] = None
    statusChangeDate: Optional[str] = None
    attachment: Optional[Dict[str, Any]] = None
    channel: Optional[str] = None
    interactionDate: Optional[Dict[str, str]] = None
