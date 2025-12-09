# OCS Provisioning MCP Server

A Model Context Protocol (MCP) server that provides AI agents with tools to interact with the OCS (Online Charging System) provisioning API interface.

## Overview

This MCP server enables AI assistants to perform subscriber management, account operations, balance inquiries, and transaction handling through the OCS provisioning API. It implements the [Model Context Protocol](https://modelcontextprotocol.io/) using the official Anthropic Python SDK.

## Features

- **Subscriber Management**: Create, lookup, update (patch), and delete subscribers
- **Account Operations**: Query account history with state transition tracking
- **Subscription Handling**: Manage subscriber subscriptions
- **Transaction Support**: Handle transaction IDs and tracking

## Architecture

The server follows strict architectural principles defined in the project constitution:

- **MCP SDK Compliance**: Built exclusively on the official Anthropic `mcp` Python SDK
- **Tool Definition Standards**: Consistent naming, typing, and error handling across all tools
- **Defensive Error Handling**: All external API calls wrapped with proper exception handling
- **Externalized Configuration**: Credentials and settings loaded from environment/config files

See [`.specify/memory/constitution.md`](.specify/memory/constitution.md) for complete governance rules.

## Technology Stack

- **Python**: 3.11+
- **MCP SDK**: Official Anthropic `mcp` package
- **HTTP Client**: httpx or requests (with explicit timeouts)
- **Type Checking**: mypy or pyright
- **Formatting**: Black (88 character line length)
- **Linting**: Ruff or flake8
- **Testing**: pytest

## Project Structure

```
ocs-provisioning-mcp-server/
├── app-spec-docs/              # API specifications and usage scripts
│   ├── latest-ocs-provisioning-api.yml
│   └── usage-scripts/          # Test scripts for API endpoints
├── .specify/                   # Project governance and templates
│   ├── memory/                 # Constitution and project memory
│   └── templates/              # Specification and planning templates
├── src/                        # MCP server implementation (TBD)
└── tests/                      # Test suite (TBD)
```

## Installation

```bash
# Clone the repository
git clone https://github.com/vasil-yosifov/ocs-provisioning-mcp-server.git
cd ocs-provisioning-mcp-server

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your OCS API credentials
```

## Configuration

Required environment variables:

- `OCS_API_URL`: Base URL for the OCS provisioning API
- `OCS_API_TIMEOUT`: Request timeout in seconds (default: 30)

Configuration files should be placed in a `config/` directory (not in version control).

## Usage

Start the MCP server:

```bash
python -m src.server
```

The server will communicate via stdio transport, making it compatible with MCP clients like Claude Desktop.

## Development

### Code Style

All code must follow PEP 8 guidelines and project-specific standards:

- Type hints required on all functions
- Maximum line length: 88 characters (Black standard)
- Meaningful variable and function names
- Docstrings on all public functions and classes

See [`.github/instructions/python.instructions.md`](.github/instructions/python.instructions.md) for detailed coding standards.

### Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src tests/

# Run specific test category
pytest tests/unit/
pytest tests/integration/
```

### Constitution Compliance

All contributions must comply with the project constitution. Key requirements:

1. Use official MCP SDK (no custom JSON-RPC)
2. Follow tool naming conventions (lowercase_with_underscores)
3. Implement defensive error handling (no unhandled exceptions)
4. Externalize all credentials and configuration

## API Reference

The OCS provisioning API specification is documented in `app-spec-docs/latest-ocs-provisioning-api.yml`.

Usage examples and test scripts are available in `app-spec-docs/usage-scripts/`:

- `create-subscriber-tests.sh`
- `subscriber-lookup-api-tests.sh`
- `subscriber-patch-api-tests.sh`
- `subscriber-delete-api-tests.sh`
- `balance-api-tests.sh`
- `account-history-api-tests.sh`
- `subscriptions-api-tests.sh`
- `transaction-id-tests.sh`

## Contributing

1. Review the constitution at `.specify/memory/constitution.md`
2. Follow the Python coding standards in `.github/instructions/python.instructions.md`
3. Create feature specifications using `.specify/templates/spec-template.md`
4. Implement with constitution compliance
5. Add tests and verify all pass before submitting

## License

## License

No license information is provided for this project. Use at your own risk.

## Disclaimer

This software is provided "as is" without any warranty or guarantee regarding code quality, functionality, or fitness for any particular purpose. The authors assume no responsibility for any issues arising from the use of this code.

## Support

For issues and questions, please open a GitHub issue in the repository.
