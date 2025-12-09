<!--
SYNC IMPACT REPORT
==================
Version change: 0.0.0 → 1.0.0
Bump rationale: Initial constitution creation (MAJOR - first governance definition)

Modified principles: N/A (initial creation)

Added sections:
  - Core Principles (I-IV)
  - Technology Stack
  - Governance

Removed sections: N/A (initial creation)

Templates requiring updates:
  - .specify/templates/plan-template.md ✅ (compatible - uses Constitution Check section)
  - .specify/templates/spec-template.md ✅ (compatible - requirements align)
  - .specify/templates/tasks-template.md ✅ (compatible - task structure aligns)

Follow-up TODOs: None
-->

# OCS Provisioning MCP Server Constitution

## Core Principles

### I. MCP SDK Compliance (NON-NEGOTIABLE)

All MCP server implementations MUST use the official Anthropic MCP Python SDK (`mcp`).

- Server MUST be instantiated via `mcp.server.Server` or `mcp.server.FastMCP`
- Tool definitions MUST use the SDK's `@server.tool()` decorator pattern
- Request/response handling MUST use SDK-provided types from `mcp.types`
- Transport MUST use SDK-provided stdio or SSE transport handlers
- MUST NOT implement custom JSON-RPC handling outside the SDK

**Rationale**: The SDK ensures protocol compliance, handles versioning, and provides
tested implementations of the MCP specification.

### II. Tool Definition Standards (NON-NEGOTIABLE)

Every MCP tool MUST follow these structural requirements:

- Tool name MUST be lowercase with underscores (e.g., `get_subscriber`, `create_account`)
- Tool MUST have a descriptive docstring explaining purpose and usage
- Input parameters MUST use Pydantic models or typed dictionaries with descriptions
- Tool MUST return structured data (dict/list) that serializes to JSON
- Tool MUST handle its own exceptions and return error information in response

**Rationale**: Consistent tool structure ensures predictable behavior for AI agents
and maintainable code.

### III. Error Handling (NON-NEGOTIABLE)

All tool implementations MUST implement defensive error handling:

- External API calls MUST be wrapped in try/except blocks
- HTTP errors MUST be caught and translated to meaningful error responses
- Tool MUST NOT raise unhandled exceptions to the MCP framework
- Error responses MUST include: error type, message, and relevant context
- Timeout values MUST be explicitly set for all external calls

**Rationale**: Unhandled exceptions break the MCP session; defensive handling ensures
graceful degradation and actionable error messages.

### IV. Configuration & Secrets (NON-NEGOTIABLE)

Configuration and credentials MUST be externalized:

- Credentials MUST NOT be hardcoded in source files
- Configuration MUST be loaded from environment variables or external config files
- Server MUST validate required configuration on startup
- Missing configuration MUST result in clear error message and graceful exit

**Rationale**: Externalized configuration enables secure deployment and environment
portability.

## Technology Stack

The following technology constraints apply to this project:

- **Language**: Python 3.11+
- **MCP SDK**: `mcp` (official Anthropic SDK)
- **Type Checking**: Type hints required; validated with mypy or pyright
- **Formatting**: Black formatter (88 char line length)
- **Linting**: Ruff or flake8 for style compliance
- **HTTP Client**: httpx or requests with explicit timeouts
- **Testing**: pytest for unit and integration tests

## Governance

This constitution defines the non-negotiable rules for the OCS Provisioning MCP Server.

- All code contributions MUST comply with these principles
- Violations MUST be justified in writing and approved before merge
- Constitution amendments require documentation of rationale and impact
- Use `.github/instructions/python.instructions.md` for detailed coding standards

**Version**: 1.0.0 | **Ratified**: 2025-12-09 | **Last Amended**: 2025-12-09
