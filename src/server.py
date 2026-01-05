import logging
import os
from pathlib import Path

from mcp.server.fastmcp import FastMCP

from src.config import settings
from src.tools.subscriber import (
    lookup_subscriber,
    create_subscriber,
    get_subscriber,
    update_subscriber,
    delete_subscriber,
    change_subscriber_state
)
from src.tools.subscription import (
    create_subscription,
    list_subscriptions,
    get_subscription,
    update_subscription,
    change_subscription_state,
    delete_subscription
)
from src.tools.balance import (
    create_balance,
    list_balances,
    delete_balances
)
from src.tools.account_history import (
    create_account_history,
    get_account_history
)
from src.tools.offers import (
    get_available_offers,
    get_offer_by_id
)
from src.tools.usage import (
    record_usage,
    list_usage_for_subscriber
)
from src.prompts.workflow import create_subscription_from_offer

# Configure logging
logging.basicConfig(level=getattr(logging, settings.log_level.upper(), logging.INFO))
logger = logging.getLogger(__name__)

# Load system instructions from external file
def load_system_instructions():
    """Load MCP system instructions from external markdown file."""
    system_prompt_path = Path(__file__).parent.parent / "system_prompt.md"
    try:
        with open(system_prompt_path, 'r', encoding='utf-8') as f:
            instructions = f.read()
            logger.info(f"Successfully loaded system instructions from {system_prompt_path}")
            return instructions
    except FileNotFoundError:
        logger.warning(f"System prompt file not found at {system_prompt_path}, using default instructions")
        return "OCS Subscriber Management System - Tools for managing telecom subscribers"
    except Exception as e:
        logger.error(f"Error loading system prompt: {e}")
        return "OCS Subscriber Management System - Tools for managing telecom subscribers"

# Initialize FastMCP server with instructions
mcp = FastMCP(
    "ocs-provisioning",
    instructions=load_system_instructions(), 
    log_level="DEBUG"
)

mcp.add_tool(create_subscriber)
mcp.add_tool(get_subscriber)
mcp.add_tool(update_subscriber)
mcp.add_tool(delete_subscriber)
mcp.add_tool(lookup_subscriber)
mcp.add_tool(change_subscriber_state)

# Register Subscription Tools
mcp.add_tool(create_subscription)
mcp.add_tool(list_subscriptions)
mcp.add_tool(get_subscription)
mcp.add_tool(change_subscription_state)
mcp.add_tool(delete_subscription)

# Register Balance Tools
mcp.add_tool(create_balance)
mcp.add_tool(list_balances)
mcp.add_tool(delete_balances)

# Register Account History Tools
mcp.add_tool(create_account_history)
mcp.add_tool(get_account_history)

# Register Offers Tools
mcp.add_tool(get_available_offers)
mcp.add_tool(get_offer_by_id)

# Register Usage Tools
mcp.add_tool(record_usage)
mcp.add_tool(list_usage_for_subscriber)

# Register Prompts
mcp.prompt()(create_subscription_from_offer)

def main():
    """Entry point for the MCP server."""
    logger.info("Starting OCS Provisioning MCP Server...")
    mcp.run()

if __name__ == "__main__":
    main()
