from typing import List, Dict, Any, Optional
import logging
from src.models.balance import Balance
from src.client import ocs_client

logger = logging.getLogger(__name__)

async def create_balance(subscriptionId: str, balance: Balance) -> Dict[str, Any]:
    """
    Create a balance for a subscription.
    """
    data = balance.model_dump(mode='json', exclude_none=True)
    logger.info(f"create_balance called for subscription {subscriptionId} with data: {data}")
    result = await ocs_client.request(
        method="POST",
        endpoint=f"/subscriptions/{subscriptionId}/balances",
        json=data
    )
    logger.info(f"create_balance result: {result}")
    return result

async def list_balances(subscriptionId: str) -> List[Dict[str, Any]]:
    """
    Get all balances for a subscription.
    """
    logger.info(f"list_balances called for subscription {subscriptionId}")
    result = await ocs_client.request(
        method="GET",
        endpoint=f"/subscriptions/{subscriptionId}/balances"
    )
    logger.info(f"list_balances result: {result}")
    return result

async def delete_balances(subscriptionId: str) -> Optional[Dict[str, Any]]:
    """
    Delete all balances for a subscription.
    """
    logger.info(f"delete_balances called for subscription {subscriptionId}")
    result = await ocs_client.request(
        method="DELETE",
        endpoint=f"/subscriptions/{subscriptionId}/balances"
    )
    logger.info(f"delete_balances result: {result}")
    return result
