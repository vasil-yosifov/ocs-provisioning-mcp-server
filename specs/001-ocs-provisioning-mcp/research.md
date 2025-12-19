# Research: OCS Provisioning MCP Server

**Feature**: Implement OCS Provisioning MCP Server
**Date**: 2025-12-10

## Technology Decisions

### 1. MCP SDK
- **Decision**: Use official `mcp` Python SDK.
- **Rationale**: Mandated by project constitution. Provides type-safe abstractions for the MCP protocol, handling JSON-RPC communication and tool registration automatically.
- **Alternatives**: Custom JSON-RPC implementation (Rejected: High maintenance, violates constitution).

### 2. HTTP Client
- **Decision**: `httpx` (Async).
- **Rationale**: The `mcp` SDK is async-native. `httpx` provides a modern, fully async HTTP client with excellent support for timeouts and connection pooling.
- **Alternatives**: `requests` (Rejected: Synchronous, would block the MCP server event loop).

### 3. Data Validation
- **Decision**: `pydantic` v2.
- **Rationale**: The `mcp` SDK uses type hints to generate tool schemas. `pydantic` models are the standard way to define complex structures (like Subscriber objects) and ensure runtime validation of inputs before they reach business logic.
- **Alternatives**: `dataclasses` (Rejected: Less robust validation features).

### 4. Configuration
- **Decision**: `python-dotenv` + `pydantic-settings`.
- **Rationale**: Follows 12-factor app principles. `pydantic-settings` allows validating environment variables (e.g., ensuring `OCS_API_URL` is a valid URL) at startup.

## API Mapping Strategy

The OCS API (`latest-ocs-provisioning-api.yml`) maps to MCP tools as follows:

| OCS Endpoint | MCP Tool | Notes |
|--------------|----------|-------|
| `POST /subscribers` | `create_subscriber` | Maps fields to args |
| `GET /subscribers/lookup` | `lookup_subscriber` | Handles query params |
| `GET /subscribers/{id}` | `get_subscriber` | Direct mapping |
| `PATCH /subscribers/{id}` | `update_subscriber` | Takes patch list |
| `DELETE /subscribers/{id}` | `delete_subscriber` | Direct mapping |
| `POST /subscribers/{id}/subscriptions` | `create_subscription` | |
| `GET /subscribers/{id}/subscriptions` | `list_subscriptions` | Pagination support |
| `GET /subscriptions/{id}` | `get_subscription` | |
| `PATCH /subscriptions/{id}` | `update_subscription` | |
| `DELETE /subscriptions/{id}` | `delete_subscription` | |
| `POST /subscriptions/{id}/balances` | `create_balance` | |
| `GET /subscriptions/{id}/balances` | `get_balances` | |
| `DELETE /subscriptions/{id}/balances` | `delete_balances` | |
| `POST /accountHistory` | `create_account_history` | |
| `GET /accountHistory` | `list_account_history` | Pagination support |
| `GET /accountHistory/{id}` | `get_account_history` | |
| `PATCH /accountHistory/{id}` | `update_account_history` | |

## Open Questions Resolved

- **Pagination**: Will use `limit`/`offset` args.
- **Patching**: Will use raw JSON list for flexibility.
- **Transactions**: Auto-generated UUID if missing.
