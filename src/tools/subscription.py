from typing import List, Dict, Any, Optional
import logging
from src.models.subscription import Subscription
from src.models.common import PatchOperation
from src.client import ocs_client

logger = logging.getLogger(__name__)

async def create_subscription(subscriberId: str, subscription: Subscription) -> Dict[str, Any]:
    """
    Create a subscription for a subscriber.
    """
    # The API likely expects the subscription data in the body
    # and the subscriberId in the path or body.
    # Based on standard REST patterns for sub-resources: POST /subscribers/{id}/subscriptions
    # Or if it's a top level resource: POST /subscriptions with subscriberId in body.
    
    # Looking at contracts/tools.json, it takes subscriberId and subscription object.
    # Let's assume the OCS API endpoint is /subscribers/{subscriberId}/subscriptions
    
    # We need to convert the Pydantic model to a dict
    data = subscription.model_dump(mode='json', exclude_none=True)
    
    # If the API expects subscriberId in the body as well, we can add it.
    # But usually it's in the path.
    
    logger.info(f"create_subscription called for subscriber {subscriberId} with data: {data}")
    result = await ocs_client.request(
        method="POST",
        endpoint=f"/subscribers/{subscriberId}/subscriptions",
        json=data
    )
    logger.info(f"create_subscription result: {result}")
    return result

async def list_subscriptions(subscriberId: str) -> List[Dict[str, Any]]:
    """
    List subscriptions for a subscriber.
    """
    logger.info(f"list_subscriptions called for subscriber {subscriberId}")
    result = await ocs_client.request(
        method="GET",
        endpoint=f"/subscribers/{subscriberId}/subscriptions"
    )
    logger.info(f"list_subscriptions result: {result}")
    return result

async def get_subscription(subscriptionId: str) -> Dict[str, Any]:
    """
    Get subscription by ID.
    """
    logger.info(f"get_subscription called for subscription {subscriptionId}")
    result = await ocs_client.request(
        method="GET",
        endpoint=f"/subscriptions/{subscriptionId}"
    )
    logger.info(f"get_subscription result: {result}")
    return result

async def update_subscription(subscriptionId: str, patches: List[PatchOperation]) -> Dict[str, Any]:
    """
    Update subscription fields.
    """
    data = [patch.model_dump(mode='json') for patch in patches]
    logger.info(f"update_subscription called for {subscriptionId} with patches: {data}")
    result = await ocs_client.request(
        method="PATCH",
        endpoint=f"/subscriptions/{subscriptionId}",
        json=data
    )
    logger.info(f"update_subscription result: {result}")
    return result

async def delete_subscription(subscriptionId: str) -> Optional[Dict[str, Any]]:
    """
    Delete subscription.
    """
    logger.info(f"delete_subscription called for {subscriptionId}")
    result = await ocs_client.request(
        method="DELETE",
        endpoint=f"/subscriptions/{subscriptionId}"
    )
    logger.info(f"delete_subscription result: {result}")
    return result
