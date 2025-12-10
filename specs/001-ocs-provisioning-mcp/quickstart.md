# Quickstart

## Prerequisites
- Python 3.11+
- `uv` (recommended) or `pip`

## Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   uv sync
   ```

## Configuration

Create a `.env` file in the root directory:

```bash
OCS_API_BASE_URL=https://provisioning.telco.com/ocs/prov/v1
OCS_API_KEY=your-api-key  # If required
LOG_LEVEL=INFO
```

## Running the Server

### Development Mode
```bash
uv run mcp-server-ocs-provisioning
```

### MCP Inspector
To test the tools interactively:
```bash
npx @modelcontextprotocol/inspector uv run mcp-server-ocs-provisioning
```

## Usage with Claude Desktop

Add the following to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "ocs-provisioning": {
      "command": "uv",
      "args": [
        "--directory",
        "/path/to/ocs-provisioning-mcp-server",
        "run",
        "mcp-server-ocs-provisioning"
      ],
      "env": {
        "OCS_API_BASE_URL": "https://provisioning.telco.com/ocs/prov/v1"
      }
    }
  }
}
```
