# OCS Provisioning MCP Server

A Model Context Protocol (MCP) server that provides AI agents with tools to interact with the OCS (Online Charging System) provisioning API interface.

## Overview

This MCP server enables AI assistants to perform subscriber management, account operations, balance inquiries, and transaction handling through the OCS provisioning API. It implements the [Model Context Protocol](https://modelcontextprotocol.io/) using the official Anthropic Python SDK.

## Features

- **Subscriber Management**: Create, lookup, update (patch), and delete subscribers.
- **Subscription Management**: Create, list, get, update, delete, and manage state transitions for subscriptions.
- **Offers Management**: Browse available offers and retrieve specific offer details.
- **Balance Management**: Create, list, and delete balances.
- **Account History**: Create, list, get, and update account history entries.
- **Transaction Support**: Automatic `X-Transaction-ID` generation and tracking.

## Tools Available

### Subscriber Tools
- `lookup_subscriber`: Lookup subscriber by MSISDN, IMSI, or name.
- `create_subscriber`: Create a new subscriber.
- `get_subscriber`: Get subscriber details by ID.
- `update_subscriber`: Update subscriber fields using patch operations.
- `delete_subscriber`: Delete a subscriber.

### Subscription Tools
- `create_subscription`: Create a subscription for a subscriber based on an offer.
- `list_subscriptions`: List all subscriptions for a subscriber.
- `get_subscription`: Get detailed subscription information by ID.
- `update_subscription`: Update subscription fields using patch operations.
- `change_subscription_state`: Activate, suspend, cancel, or renew a subscription.
- `delete_subscription`: Permanently delete a subscription.

### Offers Tools
- `get_available_offers`: Retrieve the complete catalog of available offers with balance details.
- `get_offer_by_id`: Get detailed information about a specific offer by its ID.

### Balance Tools
- `create_balance`: Create a balance for a subscription.
- `list_balances`: List balances for a subscription.
- `delete_balances`: Delete all balances for a subscription.

### Account History Tools
- `create_account_history`: Create a new account history entry.
- `list_account_history`: List account history by entity ID.
- `get_account_history`: Get account history by interaction ID.
- `update_account_history`: Update account history entry.

## Configuration

The server requires the following environment variables to be set. You can create a `.env` file in the root directory:

```env
OCS_API_BASE_URL=https://api.ocs.example.com/v1
OCS_API_KEY=your-api-key-here
OCS_API_TIMEOUT=30.0
LOG_LEVEL=INFO
```

## Running the Server

This project uses `uv` for dependency management.

### Prerequisites
- Python 3.11+
- `uv` installed

### Installation

```bash
uv sync
```

### Running

To run the MCP server:

```bash
uv run python src/server.py
```

## Project Structure

```
ocs-provisioning-mcp-server/
├── src/
│   ├── models/                 # Pydantic data models
│   │   ├── common.py           # Shared models
│   │   ├── subscriber.py       # Subscriber models
│   │   ├── subscription.py     # Subscription models
│   │   ├── offers.py           # Offers tools
│   │   ├── balance.py          # Balance tools
│   │   └── account_history.py  # Account history tools
│   ├── client.py               # HTTP client wrapper
│   ├── config.py               # Configuration management
│   └── server.py               # Main server entry point
├── tests/                      # Test suite
├── specs/                      # Project specifications
├── app-spec-docs/              # API history tools
│   ├── client.py               # HTTP client wrapper
│   ├── config.py               # Configuration management
│   └── server.py               # Main server entry point
├── tests/                      # Test suite
├── specs/                      # Project specifications
├── pyproject.toml              # Project configuration
└── README.md                   # This file
```

## Development

### Adding New Tools

1.  Define Pydantic models in `src/models/`.
2.  Implement tool logic in `src/tools/`.
3.  Register the tool in `src/server.py`.

### Error Handling

The server implements standardized error handling:
- `OCSAPIError`: Wraps upstream API errors with status codes and details.
- All tools return descriptive error messages to the LLM.
