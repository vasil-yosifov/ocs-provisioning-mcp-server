from typing import Any, Dict, List, Optional
import logging

from src.client import ocs_client
from src.models.subscriber import Subscriber
from src.models.common import PatchOperation

logger = logging.getLogger(__name__)

async def lookup_subscriber(
    msisdn: Optional[str] = None,
    imsi: Optional[str] = None,
    first_name: Optional[str] = None,
    last_name: Optional[str] = None,
    transaction_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Lookup subscriberId by msisdn, imsi or first and last name.
    
    Args:
        msisdn: MSISDN number to lookup
        imsi: IMSI to lookup
        first_name: Subscriber first name (requires last_name)
        last_name: Subscriber last name (requires first_name)
        transaction_id: Optional unique transaction ID
    """
    params = {}
    if msisdn:
        params["msisdn"] = msisdn
    if imsi:
        params["imsi"] = imsi
    if first_name:
        params["firstName"] = first_name
    if last_name:
        params["lastName"] = last_name
        
    logger.info(f"lookup_subscriber called with params: {params}")
    result = await ocs_client.get("/subscribers/lookup", transaction_id=transaction_id, params=params)
    logger.info(f"lookup_subscriber result: {result}")
    return result

async def create_subscriber(
    subscriber_id: str,
    msisdn: Optional[str] = None,
    imsi: Optional[str] = None,
    first_name: Optional[str] = None,
    last_name: Optional[str] = None,
    email: Optional[str] = None,
    subscriber_type: Optional[str] = None,
    language_id: Optional[str] = None,
    notification_addresses: Optional[List[str]] = None,
    personal_info: Optional[Dict[str, Any]] = None,
    billing: Optional[Dict[str, Any]] = None,
    services: Optional[Dict[str, Any]] = None,
    custom_fields: Optional[Dict[str, str]] = None,
    transaction_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Create a new subscriber.
    
    Args:
        subscriber_id: Unique subscriber ID
        msisdn: MSISDN in international format
        imsi: IMSI
        first_name: First name (helper for personalInfo)
        last_name: Last name (helper for personalInfo)
        email: Email address (helper for personalInfo)
        subscriber_type: Type of subscriber
        language_id: Language ID
        notification_addresses: List of notification addresses
        personal_info: Full personal info object (overrides helpers)
        billing: Billing information object
        services: Services configuration object
        custom_fields: Custom fields dictionary
        transaction_id: Optional unique transaction ID
    """
    # Construct the subscriber object
    subscriber_data = {
        "subscriberId": subscriber_id,
    }
    
    if msisdn:
        subscriber_data["msisdn"] = msisdn
    if imsi:
        subscriber_data["imsi"] = imsi
    if subscriber_type:
        subscriber_data["subscriberType"] = subscriber_type
    if language_id:
        subscriber_data["languageId"] = language_id
    if notification_addresses:
        subscriber_data["notificationAddresses"] = notification_addresses
    if billing:
        subscriber_data["billing"] = billing
    if services:
        subscriber_data["services"] = services
    if custom_fields:
        subscriber_data["customFields"] = custom_fields
        
    # Handle personal info helpers
    if personal_info:
        subscriber_data["personalInfo"] = personal_info
    elif first_name or last_name or email:
        subscriber_data["personalInfo"] = {}
        if first_name:
            subscriber_data["personalInfo"]["firstName"] = first_name
        if last_name:
            subscriber_data["personalInfo"]["lastName"] = last_name
        if email:
            subscriber_data["personalInfo"]["email"] = email

    # Validate with Pydantic model (optional but good practice before sending)
    # model = Subscriber(**subscriber_data)
    # payload = model.model_dump(exclude_none=True, mode='json')
    
    # We send the raw constructed dict to allow flexibility, but validation happens at OCS or via Pydantic if we enforced it strictly here.
    # Given the requirement to use Pydantic models for validation (FR-007), let's use it.
    model = Subscriber(**subscriber_data)
    payload = model.model_dump(exclude_none=True, mode='json')

    logger.info(f"create_subscriber called with payload: {payload}")
    result = await ocs_client.post("/subscribers", transaction_id=transaction_id, json=payload)
    logger.info(f"create_subscriber result: {result}")
    return result

async def get_subscriber(
    subscriber_id: str,
    transaction_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Get subscriber by ID.
    
    Args:
        subscriber_id: The subscriber ID
        transaction_id: Optional unique transaction ID
    """
    logger.info(f"get_subscriber called with subscriber_id: {subscriber_id}")
    result = await ocs_client.get(f"/subscribers/{subscriber_id}", transaction_id=transaction_id)
    logger.info(f"get_subscriber result: {result}")
    return result

async def update_subscriber(
    subscriber_id: str,
    patches: List[Dict[str, Any]],
    transaction_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Update subscriber fields using JSON patch operations.
    
    Args:
        subscriber_id: The subscriber ID
        patches: List of patch operations (e.g. [{"fieldName": "email", "fieldValue": "new@example.com"}])
        transaction_id: Optional unique transaction ID
    """
    # Validate patches
    validated_patches = [PatchOperation(**p).model_dump(mode='json') for p in patches]
    
    logger.info(f"update_subscriber called for {subscriber_id} with patches: {validated_patches}")
    result = await ocs_client.patch(
        f"/subscribers/{subscriber_id}", 
        transaction_id=transaction_id, 
        json=validated_patches
    )
    logger.info(f"update_subscriber result: {result}")
    return result

async def delete_subscriber(
    subscriber_id: str,
    transaction_id: Optional[str] = None,
) -> str:
    """
    Delete subscriber.
    
    Args:
        subscriber_id: The subscriber ID
        transaction_id: Optional unique transaction ID
    """
    logger.info(f"delete_subscriber called with subscriber_id: {subscriber_id}")
    await ocs_client.delete(f"/subscribers/{subscriber_id}", transaction_id=transaction_id)
    logger.info(f"delete_subscriber completed for {subscriber_id}")
    return f"Subscriber {subscriber_id} deleted successfully"
