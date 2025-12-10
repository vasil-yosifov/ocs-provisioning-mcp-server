# Implementation Tasks

## Phase 1: Project Setup & Core Infrastructure
- [ ] Initialize Python project with `uv`
- [ ] Create `pyproject.toml` with dependencies (`mcp`, `httpx`, `pydantic`, `pydantic-settings`, `python-dotenv`)
- [ ] Create project structure (`src/`, `tests/`)
- [ ] Implement configuration management (`src/config.py`) using `pydantic-settings`
- [ ] Implement base API client (`src/api.py`) with `httpx` and error handling

## Phase 2: Data Models & Validation
- [ ] Implement Pydantic models in `src/models.py` based on `data-model.md`
    - [ ] Enums (`SubscriberState`, `SubscriptionState`, etc.)
    - [ ] `Subscriber` model
    - [ ] `Subscription` model
    - [ ] `Balance` model
    - [ ] `AccountHistory` model
    - [ ] `PatchOperation` model
    - [ ] `Error` model

## Phase 3: Tool Implementation
- [ ] Implement Subscriber tools in `src/tools/subscriber.py`
    - [ ] `lookup_subscriber`
    - [ ] `create_subscriber`
    - [ ] `get_subscriber`
    - [ ] `update_subscriber`
    - [ ] `delete_subscriber`
- [ ] Implement Subscription tools in `src/tools/subscription.py`
    - [ ] `create_subscription`
    - [ ] `list_subscriptions`
    - [ ] `get_subscription`
    - [ ] `update_subscription`
    - [ ] `delete_subscription`
- [ ] Implement Balance tools in `src/tools/balance.py`
    - [ ] `create_balance`
    - [ ] `list_balances`
    - [ ] `delete_balances`
- [ ] Implement Account History tools in `src/tools/account_history.py`
    - [ ] `create_account_history`
    - [ ] `list_account_history`
    - [ ] `get_account_history`
    - [ ] `update_account_history`
- [ ] Register all tools in `src/server.py`

## Phase 4: Testing & Refinement
- [ ] Create unit tests for models
- [ ] Create integration tests for API client (mocked)
- [ ] Create end-to-end tests for tools
- [ ] Verify error handling and edge cases
- [ ] Update README.md with usage instructions

## Phase 5: Final Review
- [ ] Verify compliance with Constitution
- [ ] Check for any missing features from Spec
- [ ] Final code cleanup and formatting
