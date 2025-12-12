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
from src.config import settings

# Configure logging
logging.basicConfig(level=getattr(logging, settings.log_level.upper(), logging.INFO))
logger = logging.getLogger(__name__)

# Initialize FastMCP server
mcp = FastMCP("ocs-provisioning")

# Register Subscriber Tools
mcp.add_tool(lookup_subscriber)
mcp.add_tool(create_subscriber)
mcp.add_tool(get_subscriber)
mcp.add_tool(update_subscriber)
mcp.add_tool(delete_subscriber)

# Register Subscription Tools
mcp.add_tool(create_subscription)
mcp.add_tool(list_subscriptions)
mcp.add_tool(get_subscription)
mcp.add_tool(update_subscription)
mcp.add_tool(delete_subscription)

# Register Balance Tools
mcp.add_tool(create_balance)
mcp.add_tool(list_balances)
mcp.add_tool(delete_balances)

# Register Account History Tools
mcp.add_tool(create_account_history)
mcp.add_tool(list_account_history)
mcp.add_tool(get_account_history)
mcp.add_tool(update_account_history)

def main():
    """Entry point for the MCP server."""
    logger.info("Starting OCS Provisioning MCP Server...")
    mcp.run()

if __name__ == "__main__":
    main()
