from typing import List, Dict, Any, Optional
import logging
from src.models.history import AccountHistory
from src.models.common import PatchOperation
from src.client import ocs_client

logger = logging.getLogger(__name__)

async def create_account_history(accountHistory: AccountHistory) -> Dict[str, Any]:
    """
    Create a new account history entry.
    """
    data = accountHistory.model_dump(mode='json', exclude_none=True)
    # Assuming the endpoint is /account-history based on the resource name
    logger.info(f"create_account_history called with data: {data}")
    result = await ocs_client.request(
        method="POST",
        endpoint="/accountHistory",
        json=data
    )
    logger.info(f"create_account_history result: {result}")
    return result

async def list_account_history(
    entityId: str, 
    limit: int = 10, 
    offset: int = 0
) -> List[Dict[str, Any]]:
    """
    List account history by entity ID.
    """
    params = {
        "entityId": entityId,
        "limit": limit,
        "offset": offset
    }
    logger.info(f"list_account_history called with params: {params}")
    result = await ocs_client.request(
        method="GET",
        endpoint="/accountHistory",
        params=params
    )
    logger.info(f"list_account_history result: {result}")
    return result

async def get_account_history(interactionId: str) -> Dict[str, Any]:
    """
    Get account history by interaction ID.
    """
    logger.info(f"get_account_history called for interaction {interactionId}")
    result = await ocs_client.request(
        method="GET",
        endpoint=f"/accountHistory/{interactionId}"
    )
    logger.info(f"get_account_history result: {result}")
    return result

async def update_account_history(interactionId: str, patches: List[PatchOperation]) -> Dict[str, Any]:
    """
    Update account history entry.
    """
    data = [patch.model_dump(mode='json') for patch in patches]
    logger.info(f"update_account_history called for {interactionId} with patches: {data}")
    result = await ocs_client.request(
        method="PATCH",
        endpoint=f"/accountHistory/{interactionId}",
        json=data
    )
    logger.info(f"update_account_history result: {result}")
    return result
