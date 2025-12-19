from typing import Any, Dict, List, Optional
import logging
import uuid
import random
from datetime import datetime

from src.client import ocs_client
from src.models.subscriber import Subscriber
from src.models.common import PatchOperation, SubscriberState

logger = logging.getLogger(__name__)

async def lookup_subscriber(
    msisdn: Optional[str] = None,
    imsi: Optional[str] = None,
    first_name: Optional[str] = None,
    last_name: Optional[str] = None,
    transaction_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
**Tool Name:** Lookup Subscriber ID

**Purpose:** Retrieves a subscriber's unique identifier (subscriberId) using one of three lookup methods: phone number (MSISDN), SIM identifier (IMSI), or customer name (first and last name combined).

**Input Parameters:**
- `msisdn` (string, optional): Mobile Station International Subscriber Directory Number (phone number)
- `imsi` (string, optional): International Mobile Subscriber Identity (SIM card identifier)
- `firstName` (string, optional): Customer's first name (must be used with lastName)
- `lastName` (string, optional): Customer's last name (must be used with firstName)

**Requirements:**
- Provide exactly ONE of: msisdn, imsi, OR the firstName+lastName pair
- Name searches require both first AND last name

**Returns:**
- `subscriberId` (string): The unique subscriber identifier when found
Or, if not found:
- `ResultCode` (string): Status code indicating failure

**Error Handling:**
- When subscriber doesn't exist: ResultCode = "Entity not found"
- Invalid input combinations will return appropriate error codes

**Use Cases:**
- Customer service lookup by phone number
- Technical support using SIM card identifier
- Account retrieval by customer name when other identifiers unavailable
    """
    if transaction_id is None:
        transaction_id = str(uuid.uuid4())
    
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
    first_name: str,
    last_name: str,
    email: str,
    subscriber_type: str = "PREPAID",
    language_id: str = "EN",
    street: str = "Attemsgasse",
    city: str = "Vienna",
    country: str = "Austria",
    transaction_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
**Tool Name:** Create OCS Subscriber

**Purpose:** Creates a new subscriber account in the OCS (Online Charging System) with auto-generated unique identifiers. The tool automatically generates and validates MSISDN (phone number) and IMSI (SIM identifier) to ensure uniqueness across the system.

**Required Parameters:**
- `first_name` (string): Subscriber's first name
- `last_name` (string): Subscriber's last name
- `email` (string): Subscriber's email address

**Optional Parameters:**
- `subscriber_type` (string): Account type (default: "PREPAID")
  - Common values: PREPAID, POSTPAID
- `language_id` (string): Preferred language code (default: "EN")
  - Common values: EN, DE, FR, etc.
- `street` (string): Street address (default: "Attemsgasse")
- `city` (string): City name (default: "Vienna")
- `country` (string): Country name (default: "Austria")
- `transaction_id` (string): Custom transaction identifier for tracking/logging purposes

**Automatic Generation:**
- `msisdn`: Randomly generated phone number, validated for uniqueness
- `imsi`: Randomly generated SIM card identifier

**Returns:**
- `subscriberId` (string): **Primary identifier for all future operations** - store this value
- `msisdn` (string): The generated phone number
- `imsi` (string): The generated SIM identifier
- Full subscriber details including all provided and generated fields

**Important Notes:**
- The returned `subscriberId` is required for all subsequent subscriber operations (get, updates, deletions)
- MSISDN uniqueness is automatically enforced - the tool will retry generation if conflicts occur
- All address fields have Vienna, Austria defaults for convenience
- Don't assume values for required fields—they must be explicitly provided. If any are missing, ask the user directly. For example, don't infer an email address from a name.

**Use Cases:**
- Onboarding new customers
- Bulk subscriber provisioning
- Testing and development environments
    """
    if transaction_id is None:
        transaction_id = str(uuid.uuid4())
    
    # Generate a unique MSISDN by checking if it already exists
    max_attempts = 10
    msisdn = None
    
    for attempt in range(max_attempts):
        # Generate random 7-digit number
        random_number = random.randint(1000000, 9999999)
        candidate_msisdn = f"43660{random_number:07d}"
        
        # Check if subscriber with this MSISDN exists
        logger.info(f"Checking if MSISDN {candidate_msisdn} exists (attempt {attempt + 1}/{max_attempts})")
        lookup_result = await ocs_client.get(
            "/subscribers/lookup",
            transaction_id=transaction_id,
            params={"msisdn": candidate_msisdn}
        )
        
        # If ResultCode indicates entity not found, we can use this MSISDN
        if lookup_result.get("ResultCode") == "Entity not found":
            msisdn = candidate_msisdn
            logger.info(f"Found unique MSISDN: {msisdn}")
            break
        else:
            logger.info(f"MSISDN {candidate_msisdn} already exists, trying another")
    
    if msisdn is None:
        raise Exception(f"Failed to generate unique MSISDN after {max_attempts} attempts")
    
    # Use the same random number for IMSI for consistency
    random_number = int(msisdn[-7:])
    
    # Construct the subscriber object with generated values
    subscriber_data = {
        "msisdn": msisdn,
        "imsi": f"23205660{random_number:07d}",
        "subscriberType": subscriber_type,
        "languageId": language_id,
        "carrierId": "MAGENTA",
        "currentState": SubscriberState.ACTIVE,
        "personalInfo": {
            "firstName": first_name,
            "lastName": last_name,
            "email": email,
        },
        "services": {
            "voice": True,
            "sms": True,
            "mms": True,
            "data": True,
            "roaming": False,
            "valueAddedServices": [
                "voicemail",
                "callWaiting",
                "internationalCalls"
            ]
        },
        "billing": {
            "billingAddress": {
                "street": street,
                "city": city,
                "country": country,
            }
        }
    }
    
    # Add billing cycle information only for POSTPAID subscribers
    if subscriber_type == "POSTPAID":
        current_day = datetime.now().day
        billcycle_day = 1 if current_day > 28 else current_day
        
        subscriber_data["billing"]["billcycleDay"] = billcycle_day
        subscriber_data["billing"]["billingCycle"] = "MONTHLY"

    # Validate with Pydantic model
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
**Tool Name:** Get Subscriber Details

**Purpose:** Retrieves complete subscriber information using their unique subscriber identifier. This tool fetches all stored details for an existing subscriber account.

**Required Parameters:**
- `subscriber_id` (string): The unique subscriber identifier
  - **Note:** If you don't have the subscriberId, use the `lookup_subscriber` tool first to find it via MSISDN, IMSI, or name

**Optional Parameters:**
- `transaction_id` (string): Custom transaction identifier for tracking/logging purposes

**Returns:**
When subscriber exists:
- Complete subscriber profile in JSON format including:
  - Personal information (first name, last name, email)
  - Identifiers (subscriberId, msisdn, imsi)
  - Account details (subscriber_type, language_id)
  - Address information (street, city, country)
  - Any additional stored attributes

When subscriber not found:
- `ResultCode`: "Entity not found"

**Workflow:**
1. If you have subscriberId → use this tool directly
2. If you only have MSISDN/IMSI/name → use `lookup_subscriber` first to get subscriberId, then use this tool

**Use Cases:**
- Viewing complete customer profile
- Verifying subscriber information before updates
- Customer service inquiries
- Account auditing and validation

**Error Handling:**
- Invalid or non-existent subscriberId returns "Entity not found" status
- Ensure subscriberId format is correct (typically returned from `create_subscriber` or `lookup_subscriber` tools)
    """
    if transaction_id is None:
        transaction_id = str(uuid.uuid4())
    
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
**Tool Name:** Update Subscriber

**Purpose:** Modifies existing subscriber information using JSON patch operations. Allows selective updates to one or multiple fields without affecting unchanged attributes.

**Required Parameters:**
- `subscriber_id` (string): The unique subscriber identifier
  - **Note:** Use `lookup_subscriber` to find subscriberId if you only have MSISDN, IMSI, or name
- `patches` (array): List of field update operations, each containing:
  - `fieldName` (string): The field to update. Note: must match exact field names in the subscriber schema
  - `fieldValue` (string/number/boolean): The new value for the field

**Optional Parameters:**
- `transaction_id` (string): Custom transaction identifier for tracking/logging purposes

**Patch Operations Format:**
```json
[
  {"fieldName": "email", "fieldValue": "newemail@example.com"},
  {"fieldName": "firstName", "fieldValue": "John"},
  {"fieldName": "subscriberType", "fieldValue": "POSTPAID"}
]
```

**Updatable Fields:**

*Personal Information:*
- `email` (string): Email address
- `contactNumber` (string): Contact/phone number
- `firstName` (string): First name
- `lastName` (string): Last name

*System Fields:*
- `languageId` (string): Language preference (e.g., "EN", "DE", "FR", "IT")
- `state` (string): Subscriber state (e.g., "ACTIVE", "SUSPENDED", "DEACTIVATED")

*Billing Fields:*
- `billingStreet` (string): Billing street address
- `billingCity` (string): Billing city
- `billingCountry` (string): Billing country
- `billcycleDay` (integer): Billing cycle day (e.g., 15)

**Returns:**
- Success confirmation with updated subscriber details
- Or error status if update fails

**Important Notes:**
- Only specified fields are modified; all other fields remain unchanged
- Multiple fields can be updated in a single operation
- Validate field names match exact system schema
- Some fields may have validation rules (e.g., unique MSISDN)

**Use Cases:**
- Updating customer contact information
- Changing account type (prepaid ↔ postpaid)
- Correcting address details
- Bulk field modifications

**Error Handling:**
- Invalid subscriberId returns "Entity not found"
- Invalid fieldName returns schema validation error
- Constraint violations (e.g., duplicate MSISDN) return appropriate error codes
    """
    if transaction_id is None:
        transaction_id = str(uuid.uuid4())
    
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
**Tool Name:** Delete Subscriber

**Purpose:** Permanently removes a subscriber account from the OCS (Online Charging System). This operation deletes all associated subscriber data and cannot be undone.

**Required Parameters:**
- `subscriber_id` (string): The unique subscriber identifier of the account to delete.
  - **Note:** Use `lookup_subscriber` to find subscriberId if you only have MSISDN, IMSI, or name

**Optional Parameters:**
- `transaction_id` (string): Custom transaction identifier for tracking/logging purposes

**Returns:**
- `ResultCode` : "Subscriber successfully deleted" when subscriber is deleted
- `ResultCode`: "Entity not found" if subscriberId doesn't exist

**⚠️ Important Warnings:**
- **This operation is irreversible** - deleted subscriber data cannot be recovered
- Frees up the MSISDN and IMSI for potential reuse
- Any active services or balances associated with the subscriber will be lost
- Consider archiving subscriber data before deletion if audit trails are required

**Pre-Deletion Checklist:**
1. Verify you have the correct subscriberId
2. Check for outstanding balances or active services
3. Ensure regulatory/compliance requirements for data retention are met
4. Confirm deletion intent with appropriate authorization

**Use Cases:**
- Account closure/termination
- GDPR/data privacy deletion requests
- Cleaning up test/development accounts
- Removing duplicate or erroneous entries

**Error Handling:**
- Invalid or non-existent subscriberId returns "Entity not found" result code

**Alternative:** If you need to deactivate without deleting, consider using `update_subscriber` to change the account status instead.
    """
    if transaction_id is None:
        transaction_id = str(uuid.uuid4())
    
    logger.info(f"delete_subscriber called with subscriber_id: {subscriber_id}")
    await ocs_client.delete(f"/subscribers/{subscriber_id}", transaction_id=transaction_id)
    logger.info(f"delete_subscriber completed for {subscriber_id}")
    return f"Subscriber {subscriber_id} deleted successfully"
