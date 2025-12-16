from mcp.server.fastmcp import FastMCP
from src.tools.subscriber import (
    lookup_subscriber,
    create_subscriber,
    get_subscriber,
    update_subscriber,
    delete_subscriber
)
from src.tools.subscription import (
    create_subscription,
    list_subscriptions,
    get_subscription,
    update_subscription,
    delete_subscription
)
from src.tools.balance import (
    create_balance,
    list_balances,
    delete_balances
)
from src.tools.account_history import (
    create_account_history,
    list_account_history,
    get_account_history,
    update_account_history
)
import logging
import os
from pathlib import Path
from src.config import settings

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
    instructions=load_system_instructions()
)

mcp.add_tool(create_subscriber)
mcp.add_tool(get_subscriber)
mcp.add_tool(update_subscriber)
mcp.add_tool(delete_subscriber)
mcp.add_tool(lookup_subscriber)

# Register Subscription Tools
# mcp.add_tool(create_subscription)
# mcp.add_tool(list_subscriptions)
# mcp.add_tool(get_subscription)
# mcp.add_tool(update_subscription)
# mcp.add_tool(delete_subscription)

# Register Balance Tools
# mcp.add_tool(create_balance)
# mcp.add_tool(list_balances)
# mcp.add_tool(delete_balances)

# Register Account History Tools
mcp.add_tool(create_account_history)
mcp.add_tool(get_account_history)

def main():
    """Entry point for the MCP server."""
    logger.info("Starting OCS Provisioning MCP Server...")
    mcp.run()

if __name__ == "__main__":
    main()
