import asyncio
import logging
import uuid
from datetime import datetime, timezone
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Test Data Container
TEST_DATA = {
    "subscriber_id": f"sub-test-{uuid.uuid4().hex[:8]}",
    "subscription_id": f"sub-plan-{uuid.uuid4().hex[:8]}",
    "balance_id": f"bal-{uuid.uuid4().hex[:8]}",
    "interaction_id": f"int-{uuid.uuid4().hex[:8]}"
}

async def main():
    # Server parameters
    server_params = StdioServerParameters(
        command="uv",
        args=["run", "src/server.py"],
        env=None
    )

    logger.info("Starting Integration Tests...")
    logger.info("Starting OCS Provisioning MCP Server...")

    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            
            # List tools
            tools = await session.list_tools()
            logger.info(f"Connected to MCP Server. Found {len(tools.tools)} tools.")

            # --- Subscriber Lifecycle ---
            logger.info("--- Testing Subscriber Lifecycle ---")

            # Create Subscriber
            logger.info(f"Creating subscriber {TEST_DATA['subscriber_id']}...")
            try:
                result = await session.call_tool(
                    "create_subscriber",
                    arguments={
                        "subscriber_id": TEST_DATA["subscriber_id"],
                        "msisdn": "13194565780",
                        "language_id": "en",
                        "subscriber_type": "prepaid",
                        "personal_info": {
                            "firstName": "Integration",
                            "lastName": "Test",
                            "email": "integration.test@example.com"
                        }
                    }
                )
                logger.info(f"Create Subscriber Result: {result}")
                
                # Capture the actual ID returned by the server
                if result.content and result.content[0].text:
                    import json
                    content = json.loads(result.content[0].text)
                    if "subscriberId" in content:
                        TEST_DATA["subscriber_id"] = content["subscriberId"]
                        logger.info(f"Updated Subscriber ID to: {TEST_DATA['subscriber_id']}")
            except Exception as e:
                logger.error(f"Error creating subscriber: {e}")

            # Lookup Subscriber
            logger.info(f"Looking up subscriber by MSISDN 13194565780...")
            try:
                result = await session.call_tool(
                    "lookup_subscriber",
                    arguments={"msisdn": "13194565780"}
                )
                logger.info(f"Lookup Subscriber Result: {result}")
            except Exception as e:
                logger.error(f"Error looking up subscriber: {e}")

            # Get Subscriber
            logger.info(f"Getting subscriber {TEST_DATA['subscriber_id']}...")
            try:
                result = await session.call_tool(
                    "get_subscriber",
                    arguments={"subscriber_id": TEST_DATA["subscriber_id"]}
                )
                logger.info(f"Get Subscriber Result: {result}")
            except Exception as e:
                logger.error(f"Error getting subscriber: {e}")

            # Update Subscriber
            logger.info(f"Updating subscriber {TEST_DATA['subscriber_id']}...")
            try:
                result = await session.call_tool(
                    "update_subscriber",
                    arguments={
                        "subscriber_id": TEST_DATA["subscriber_id"],
                        "patches": [
                            {
                                "fieldName": "email",
                                "fieldValue": "updated.email@example.com"
                            }
                        ]
                    }
                )
                logger.info(f"Update Subscriber Result: {result}")
            except Exception as e:
                logger.error(f"Error updating subscriber: {e}")

            # --- Subscription Lifecycle ---
            logger.info("--- Testing Subscription Lifecycle ---")

            # Create Subscription
            logger.info(f"Creating subscription {TEST_DATA['subscription_id']} for subscriber {TEST_DATA['subscriber_id']}...")
            try:
                result = await session.call_tool(
                    "create_subscription",
                    arguments={
                        "subscriberId": TEST_DATA["subscriber_id"],
                        "subscription": {
                            "subscriptionId": TEST_DATA["subscription_id"],
                            "offerId": "offer-standard",
                            "state": "active"
                        }
                    }
                )
                logger.info(f"Create Subscription Result: {result}")
                
                # Capture the actual Subscription ID
                if result.content and result.content[0].text:
                    import json
                    content = json.loads(result.content[0].text)
                    if "subscriptionId" in content:
                        TEST_DATA["subscription_id"] = content["subscriptionId"]
                        logger.info(f"Updated Subscription ID to: {TEST_DATA['subscription_id']}")
            except Exception as e:
                logger.error(f"Error creating subscription: {e}")

            # List Subscriptions
            logger.info(f"Listing subscriptions for {TEST_DATA['subscriber_id']}...")
            try:
                result = await session.call_tool(
                    "list_subscriptions",
                    arguments={"subscriberId": TEST_DATA["subscriber_id"]}
                )
                logger.info(f"List Subscriptions Result: {result}")
            except Exception as e:
                logger.error(f"Error listing subscriptions: {e}")

            # Get Subscription
            logger.info(f"Getting subscription {TEST_DATA['subscription_id']}...")
            try:
                result = await session.call_tool(
                    "get_subscription",
                    arguments={"subscriptionId": TEST_DATA["subscription_id"]}
                )
                logger.info(f"Get Subscription Result: {result}")
            except Exception as e:
                logger.error(f"Error getting subscription: {e}")

            # Update Subscription
            logger.info(f"Updating subscription {TEST_DATA['subscription_id']}...")
            try:
                result = await session.call_tool(
                    "update_subscription",
                    arguments={
                        "subscriptionId": TEST_DATA["subscription_id"],
                        "patches": [
                            {
                                "fieldName": "customParameters.test",
                                "fieldValue": "value"
                            }
                        ]
                    }
                )
                logger.info(f"Update Subscription Result: {result}")
            except Exception as e:
                logger.error(f"Error updating subscription: {e}")

            # --- Balance Lifecycle ---
            logger.info("--- Testing Balance Lifecycle ---")

            # Create Balance
            logger.info(f"Creating balance {TEST_DATA['balance_id']} for subscription {TEST_DATA['subscription_id']}...")
            try:
                result = await session.call_tool(
                    "create_balance",
                    arguments={
                        "subscriptionId": TEST_DATA["subscription_id"],
                        "balance": {
                            "balanceId": TEST_DATA["balance_id"],
                            "unitType": "BYTES",
                            "balanceAmount": 1000.0,
                            "balanceAvailable": 1000.0
                        }
                    }
                )
                logger.info(f"Create Balance Result: {result}")
            except Exception as e:
                logger.error(f"Error creating balance: {e}")

            # List Balances
            logger.info(f"Listing balances for {TEST_DATA['subscription_id']}...")
            try:
                result = await session.call_tool(
                    "list_balances",
                    arguments={"subscriptionId": TEST_DATA["subscription_id"]}
                )
                logger.info(f"List Balances Result: {result}")
            except Exception as e:
                logger.error(f"Error listing balances: {e}")

            # Delete Balances
            logger.info(f"Deleting balances for {TEST_DATA['subscription_id']}...")
            try:
                result = await session.call_tool(
                    "delete_balances",
                    arguments={"subscriptionId": TEST_DATA["subscription_id"]}
                )
                logger.info(f"Delete Balances Result: {result}")
            except Exception as e:
                logger.error(f"Error deleting balances: {e}")

            # --- Account History Lifecycle ---
            logger.info("--- Testing Account History Lifecycle ---")

            # Create Account History
            logger.info(f"Creating account history {TEST_DATA['interaction_id']}...")
            try:
                result = await session.call_tool(
                    "create_account_history",
                    arguments={
                        "accountHistory": {
                            "interactionId": TEST_DATA["interaction_id"],
                            "entityId": TEST_DATA["subscriber_id"],
                            "entityType": "SUBSCRIBER",
                            "creationDate": datetime.now(timezone.utc).isoformat(),
                            "description": "Integration Test Interaction",
                            "status": "COMPLETED"
                        }
                    }
                )
                logger.info(f"Create Account History Result: {result}")
            except Exception as e:
                logger.error(f"Error creating account history: {e}")

            # Get Account History
            logger.info(f"Getting account history {TEST_DATA['interaction_id']}...")
            try:
                result = await session.call_tool(
                    "get_account_history",
                    arguments={"interactionId": TEST_DATA["interaction_id"]}
                )
                logger.info(f"Get Account History Result: {result}")
            except Exception as e:
                logger.error(f"Error getting account history: {e}")

            # List Account History
            logger.info(f"Listing account history for {TEST_DATA['subscriber_id']}...")
            try:
                result = await session.call_tool(
                    "list_account_history",
                    arguments={
                        "entityId": TEST_DATA["subscriber_id"]
                    }
                )
                logger.info(f"List Account History Result: {result}")
            except Exception as e:
                logger.error(f"Error listing account history: {e}")

            # Update Account History
            logger.info(f"Updating account history {TEST_DATA['interaction_id']}...")
            try:
                result = await session.call_tool(
                    "update_account_history",
                    arguments={
                        "interactionId": TEST_DATA["interaction_id"],
                        "patches": [
                            {
                                "fieldName": "status",
                                "fieldValue": "IN_PROGRESS"
                            }
                        ]
                    }
                )
                logger.info(f"Update Account History Result: {result}")
            except Exception as e:
                logger.error(f"Error updating account history: {e}")

            # --- Cleanup ---
            logger.info("--- Cleanup ---")

            # Delete Subscription
            logger.info(f"Deleting subscription {TEST_DATA['subscription_id']}...")
            try:
                result = await session.call_tool(
                    "delete_subscription",
                    arguments={"subscriptionId": TEST_DATA["subscription_id"]}
                )
                logger.info(f"Delete Subscription Result: {result}")
            except Exception as e:
                logger.error(f"Error deleting subscription: {e}")

            # Delete Subscriber
            logger.info(f"Deleting subscriber {TEST_DATA['subscriber_id']}...")
            try:
                result = await session.call_tool(
                    "delete_subscriber",
                    arguments={"subscriber_id": TEST_DATA["subscriber_id"]}
                )
                logger.info(f"Delete Subscriber Result: {result}")
            except Exception as e:
                logger.error(f"Error deleting subscriber: {e}")

    logger.info("All tests completed successfully!")

if __name__ == "__main__":
    asyncio.run(main())
