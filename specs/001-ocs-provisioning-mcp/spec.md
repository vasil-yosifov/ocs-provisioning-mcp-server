# Feature Specification: Implement OCS Provisioning MCP Server

**Feature Branch**: `001-ocs-provisioning-mcp`
**Created**: 2025-12-10
**Status**: Draft
**Input**: User description: "The project is building a standalone local MCP server, which wraps the telecom subscribers' profile information API... expose CRUD API operations to the MCP clients."

## Clarifications

### Session 2025-12-10

- Q: How should pagination be handled for list endpoints? → A: Expose `limit` and `offset` arguments to the AI agent.
- Q: How should the `update_subscriber` tool accept patch operations? → A: Accept a raw JSON list of patch operations (e.g., `[{"fieldName": "email", "fieldValue": "..."}]`) to match the API schema directly.
- Q: How should the `create_subscriber` tool accept input parameters? → A: Define explicit individual arguments for each field (e.g., `firstName`, `msisdn`) to aid AI discovery.
- Q: How should `X-Transaction-ID` be handled? → A: Allow an optional `transaction_id` argument in all tools; if omitted, the server MUST auto-generate one.
- Q: How should complex nested objects (e.g., `notificationAddress`) be passed? → A: Accept them as JSON/Dictionary arguments (e.g., `notification_address={"email": "..."}`) to keep tool signatures clean.
- Q: What should tools return upon success? → A: Return the full JSON response body from the OCS API to provide maximum context to the agent.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Subscriber Lifecycle Management (Priority: P1)

As an AI agent, I need to manage the full lifecycle of telecom subscribers so that I can provision new users, update their details, and remove them when they leave.

**Why this priority**: This is the core entity of the system; without subscribers, other operations (subscriptions, balances) are impossible.

**Independent Test**: Can be tested by creating a subscriber, verifying they exist via lookup, updating a field, and then deleting them.

**Acceptance Scenarios**:

1. **Given** a new subscriber payload, **When** the `create_subscriber` tool is called, **Then** a new subscriber is created in the OCS and the ID is returned.
2. **Given** an existing subscriber, **When** `lookup_subscriber` is called with MSISDN or IMSI, **Then** the correct subscriber details are returned.
3. **Given** an existing subscriber, **When** `update_subscriber` is called with a patch payload, **Then** the subscriber's details are updated in the OCS.
4. **Given** an existing subscriber, **When** `delete_subscriber` is called, **Then** the subscriber is removed (or marked terminated) in the OCS.

---

### User Story 2 - Subscription and Balance Management (Priority: P2)

As an AI agent, I need to manage subscriptions and balances for a subscriber so that I can provision specific services and track usage quotas.

**Why this priority**: Essential for defining what services the subscriber actually has access to.

**Independent Test**: Create a subscriber, then add a subscription, add a balance, and verify both appear in list/get calls.

**Acceptance Scenarios**:

1. **Given** a subscriber ID, **When** `create_subscription` is called, **Then** a new subscription is linked to that subscriber.
2. **Given** a subscription ID, **When** `create_balance` is called, **Then** a balance bucket is added to that subscription.
3. **Given** a subscriber ID, **When** `list_subscriptions` is called, **Then** all active subscriptions for that user are returned.

---

### User Story 3 - Account History Tracking (Priority: P3)

As an AI agent, I need to record and retrieve account history events so that I can maintain an audit trail of interactions and state changes.

**Why this priority**: Critical for auditing and debugging, but the system can technically function (provisioning-wise) without it.

**Independent Test**: Create a history entry, then retrieve it by ID and by Entity ID.

**Acceptance Scenarios**:

1. **Given** an interaction event, **When** `create_account_history` is called, **Then** the event is persisted.
2. **Given** an entity ID (e.g., subscriber ID), **When** `list_account_history` is called, **Then** all history events for that entity are returned chronologically.

### Edge Cases

- **Invalid Input**: When a tool is called with parameters that violate the schema (e.g., invalid email format, missing required fields), the system MUST return a clear validation error without crashing.
- **Resource Not Found**: When an operation is performed on a non-existent ID (e.g., `get_subscriber` with invalid ID), the system MUST return a standard "Resource not found" error message.
- **API Unavailable**: If the OCS backend is unreachable or times out, the tool MUST return a "Service Unavailable" error with context, rather than hanging or crashing.
- **Duplicate Creation**: If `create_subscriber` is called with an existing MSISDN/IMSI, the system MUST return a "Conflict" error indicating the resource already exists.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST implement `create_subscriber`, `get_subscriber`, `update_subscriber`, and `delete_subscriber` tools wrapping the corresponding OCS API endpoints. `create_subscriber` MUST accept individual arguments for subscriber fields, but nested objects (like `notificationAddress`) MUST be passed as dictionaries. `update_subscriber` MUST accept a list of patch operations as a JSON structure.
- **FR-002**: System MUST implement a `lookup_subscriber` tool that supports searching by `msisdn`, `imsi`, or `firstName`/`lastName`.
- **FR-003**: System MUST implement `create_subscription`, `get_subscription`, `update_subscription`, `delete_subscription`, and `list_subscriptions` tools. `list_subscriptions` MUST support `limit` and `offset` parameters for pagination.
- **FR-004**: System MUST implement `create_balance`, `get_balances`, and `delete_balances` tools.
- **FR-005**: System MUST implement `create_account_history`, `get_account_history`, `update_account_history`, and `list_account_history` tools. `list_account_history` MUST support `limit` and `offset` parameters for pagination.
- **FR-006**: All tools MUST use the official Anthropic `mcp` Python SDK.
- **FR-007**: All tools MUST validate inputs using Pydantic models that match the OCS API schema.
- **FR-008**: System MUST handle OCS API errors (4xx, 5xx) and return meaningful error messages to the MCP client, not raw stack traces.
- **FR-009**: System MUST be configurable via environment variables (`OCS_API_URL`, `OCS_API_KEY`, `OCS_API_TIMEOUT`).
- **FR-010**: All tools MUST accept an optional `transaction_id` argument. If provided, it MUST be sent in the `X-Transaction-ID` header; if omitted, a UUID MUST be generated and sent.
- **FR-011**: All tools MUST return the full JSON response body from the OCS API upon successful execution.

### Success Criteria

- **SC-001**: 100% of the OCS Provisioning API endpoints defined in `latest-ocs-provisioning-api.yml` are exposed as MCP tools.
- **SC-002**: All tools successfully execute the "happy path" scenarios defined in the `app-spec-docs/usage-scripts/` (when adapted to tool calls).
- **SC-003**: The server starts successfully and connects to the OCS backend (mocked or real) without errors.
- **SC-004**: Tool documentation (docstrings) clearly explains required parameters and expected outputs for the AI agent.

### Key Entities *(include if feature involves data)*

- **Subscriber**: Core user profile (IDs, personal info, state).
- **Subscription**: Service plan attached to a subscriber.
- **Balance**: Quota or credit bucket attached to a subscription.
- **AccountHistory**: Audit record of an interaction.

## Assumptions

- The OCS REST API is running and accessible at the configured URL.
- The API specification in `app-spec-docs/latest-ocs-provisioning-api.yml` is accurate and up-to-date.
- Authentication is not handled in the project as implied by the usage scripts.
