from typing import List, Dict, Any
import logging
import json

logger = logging.getLogger(__name__)

async def get_available_offers() -> str:
    """
**Tool Name:** Get Available Offers

**Purpose:** Retrieves the list of all available service offers and packages that can be assigned to subscribers in the OCS system. This tool provides information about data plans, voice bundles, SMS packages, and value-added services available for subscription.

**Parameters:**
- None required

**Returns:**
A JSON-formatted list of available offers, where each offer includes:
- `offerId`: Unique identifier for the offer
- `offerName`: Human-readable name of the offer
- `description`: Detailed description of what the offer includes
- `price`: Monthly or one-time price for the offer
- `type`: Offer type ("PREPAID" or "POSTPAID")
- `recurring`: Whether the offer renews automatically (true/false)
- `paid`: Whether the offer is paid (true/false)
- `groupOffer`: Whether this is a group/shared offer (true/false)
- `maxRecurringCycles`: Maximum number of recurring cycles (null for unlimited)
- `cycleLength`: Length of the billing cycle (integer)
- `cycleUnit`: Unit for the billing cycle ("MONTH", "WEEK", etc.)
- `balances`: Array of balance allocations included in the offer, each containing:
  - `type`: Balance type (e.g., "ALLOWANCE")
  - `amount`: Balance amount in specified units
  - `unit`: Unit of measurement ("SECONDS" for voice, "EVENTS" for SMS, "BYTES" for data)
  - `recurring`: Whether the balance recurs (true/false)
  - `cycleLength`: Balance cycle length
  - `cycleUnit`: Balance cycle unit
  - `rolloverAllowed`: Whether unused balance rolls over (true/false)
  - `maxRolloverAmount`: Maximum amount that can roll over (0 = no limit)
  - `description`: Human-readable description of the balance

**Use Cases:**
- Displaying available packages to customers during onboarding
- Helping customers choose appropriate service plans
- Comparing different offers for upselling/cross-selling
- Providing information for customer service inquiries
- Planning subscription configurations

**Workflow:**
1. Call get_subscriber to verify subscriber type (PREPAID or POSTPAID)
2. Call get_available_offers to retrieve current catalog
3. Filter offers by matching subscriber type (type field must match subscriber type)
4. Present compatible offers to user or filter further based on requirements
5. Use offerId when creating subscriptions for subscribers

**Important Notes:**
- This is a static catalog - offers don't change dynamically during session
- Prices and features are current as of the query time
- **Subscriber type must match offer type**: PREPAID subscribers can only use PREPAID offers, and POSTPAID subscribers can only use POSTPAID offers
- Always verify subscriber type before recommending or assigning offers
- Bundle offers may include multiple services at discounted rates

**Example Usage:**
```
User: "What data plans do you have for my prepaid account?"
Assistant: Calls get_subscriber to check subscriber type (PREPAID) → Calls get_available_offers → Filters by type="PREPAID" and balances containing "BYTES" → Presents matching data plans (1000, 1002, 1003, 1010)

User: "Show me all offers"
Assistant: Calls get_available_offers → Displays complete catalog (both PREPAID and POSTPAID)

User: "What's included in the Premium prepaid plan?"
Assistant: Calls get_available_offers → Finds offerId="1010" → Shows voice (18000 seconds = 5 hours), SMS (5000 events), and data (21474836480 bytes = 20GB) balances with rollover capabilities

User: "I want to add a data bundle to subscriber 123456"
Assistant: Calls get_subscriber("123456") → Checks subscriber type (e.g., PREPAID) → Calls get_available_offers → Filters by type="PREPAID" and data balances → Presents only compatible offers
```

**Response Format:**
Returns a formatted JSON string containing the complete offer catalog with all details for easy reading and comparison.
    """
    logger.info("get_available_offers called")
    
    # List of available offers from OCS provisioning system
    offers = [
        {
            "offerId": "1000",
            "offerName": "Basic prepaid plan",
            "description": "Basic prepaid priceplan, which covers all type of services",
            "price": 7.99,
            "type": "PREPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 0,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 3600,
                    "unit": "SECONDS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": False,
                    "maxRolloverAmount": 0,
                    "description": "Prepaid base balance for voice service"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 1000,
                    "unit": "EVENTS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": False,
                    "maxRolloverAmount": 0,
                    "description": "Prepaid base balance for SMS and MMS service"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 10737418240,
                    "unit": "BYTES",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": False,
                    "maxRolloverAmount": 0,
                    "description": "Prepaid base balance for data service"
                }
            ]
        },
        {
            "offerId": "1001",
            "offerName": "Basic postpaid plan",
            "description": "Basic postpaid priceplan, which covers all type of services",
            "price": 15.99,
            "type": "POSTPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 0,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 86600,
                    "unit": "SECONDS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": False,
                    "maxRolloverAmount": 0,
                    "description": "Postpaid base balance for voice service"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 5000,
                    "unit": "EVENTS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": False,
                    "maxRolloverAmount": 0,
                    "description": "Postpaid base balance for SMS and MMS service"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 10737418240,
                    "unit": "BYTES",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": False,
                    "maxRolloverAmount": 0,
                    "description": "Postpaid base balance for data service"
                }
            ]
        },
        {
            "offerId": "1002",
            "offerName": "Weekly data bundle 5GB",
            "description": "Prepaid weekly data bundle – 5GB",
            "price": 4.99,
            "type": "PREPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 4,
            "cycleUnit": "WEEK",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 5368709120,
                    "unit": "BYTES",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "WEEK",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 5368709120,
                    "description": "Prepaid 5GB weekly balance"
                }
            ]
        },
        {
            "offerId": "1003",
            "offerName": "Monthly data bundle 25GB",
            "description": "Prepaid monthly data bundle – 25GB",
            "price": 12.99,
            "type": "PREPAID",
            "recurring": False,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 1,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 26843545600,
                    "unit": "BYTES",
                    "recurring": False,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 0,
                    "description": "Prepaid 25GB one time monthly balance"
                }
            ]
        },
        {
            "offerId": "1010",
            "offerName": "Premium prepaid plan",
            "description": "Premium prepaid price plan, which contains more free units for all type of services",
            "price": 9.99,
            "type": "PREPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 0,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 18000,
                    "unit": "SECONDS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 7200,
                    "description": "5 hours prepaid balance for voice service with 2 hours rollover"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 5000,
                    "unit": "EVENTS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 2000,
                    "description": "5000 events prepaid balance for SMS and MMS services with 2000 events rollover"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 21474836480,
                    "unit": "BYTES",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 10737418240,
                    "description": "20GB prepaid balance for data service with 10GB rollover"
                }
            ]
        }
    ]
    
    logger.info(f"Returning {len(offers)} available offers")
    return json.dumps(offers, indent=2)

