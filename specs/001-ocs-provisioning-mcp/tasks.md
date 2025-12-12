# Implementation Tasks - Implement OCS Provisioning MCP Server

## Phase 1: Project Setup & Core Infrastructure
- [x] T001 Initialize Python project with `uv` and create `pyproject.toml`
- [x] T002 Create project structure (`src/`, `tests/`, `src/models/`, `src/tools/`)
- [x] T003 Implement configuration management in `src/config.py` using `pydantic-settings`
- [x] T004 Implement base API client in `src/client.py` with `httpx`, error handling, and `X-Transaction-ID` logic

## Phase 2: Foundational Tasks (Models)
- [x] T005 [P] Implement common models (Enums, PatchOperation, Error) in `src/models/common.py`
- [x] T006 [P] Implement Subscriber model in `src/models/subscriber.py`
- [x] T007 [P] Implement Subscription model in `src/models/subscription.py`
- [x] T008 [P] Implement Balance model in `src/models/balance.py`
- [x] T009 [P] Implement AccountHistory model in `src/models/history.py`

## Phase 3: User Story 1 - Subscriber Lifecycle Management
- [x] T010 [P] [US1] Implement `lookup_subscriber` tool in `src/tools/subscriber.py`
- [x] T011 [P] [US1] Implement `create_subscriber` tool in `src/tools/subscriber.py`
- [x] T012 [P] [US1] Implement `get_subscriber` tool in `src/tools/subscriber.py`
- [x] T013 [P] [US1] Implement `update_subscriber` tool in `src/tools/subscriber.py`
- [x] T014 [P] [US1] Implement `delete_subscriber` tool in `src/tools/subscriber.py`
- [x] T015 [US1] Register subscriber tools in `src/server.py`

## Phase 4: User Story 2 - Subscription and Balance Management
- [x] T016 [P] [US2] Implement `create_subscription` tool in `src/tools/subscription.py`
- [x] T017 [P] [US2] Implement `list_subscriptions` tool in `src/tools/subscription.py`
- [x] T018 [P] [US2] Implement `get_subscription` tool in `src/tools/subscription.py`
- [x] T019 [P] [US2] Implement `update_subscription` tool in `src/tools/subscription.py`
- [x] T020 [P] [US2] Implement `delete_subscription` tool in `src/tools/subscription.py`
- [x] T021 [P] [US2] Implement `create_balance` tool in `src/tools/balance.py`
- [x] T022 [P] [US2] Implement `list_balances` tool in `src/tools/balance.py`
- [x] T023 [P] [US2] Implement `delete_balances` tool in `src/tools/balance.py`
- [x] T024 [US2] Register subscription and balance tools in `src/server.py`

## Phase 5: User Story 3 - Account History Tracking
- [x] T025 [P] [US3] Implement `create_account_history` tool in `src/tools/account_history.py`
- [x] T026 [P] [US3] Implement `list_account_history` tool in `src/tools/account_history.py`
- [x] T027 [P] [US3] Implement `get_account_history` tool in `src/tools/account_history.py`
- [x] T028 [P] [US3] Implement `update_account_history` tool in `src/tools/account_history.py`
- [x] T029 [US3] Register account history tools in `src/server.py`

## Phase 6: Polish & Cross-Cutting Concerns
- [x] T030 Final code cleanup, formatting, and README update

## Dependencies
- Phase 1 must be completed before Phase 2.
- Phase 2 must be completed before Phase 3, 4, 5.
- Phase 3, 4, 5 can be executed in parallel or sequence, but US1 (Phase 3) is P1.

## Parallel Execution Examples
- **Story 1**: T010, T011, T012, T013, T014 can be implemented in parallel by different developers as they are distinct functions within the same file (or could be split if needed, but here they are in one file).
- **Story 2**: Subscription tools (T016-T020) and Balance tools (T021-T023) are in different files and can be implemented in parallel.

## Implementation Strategy
- **MVP**: Complete Phase 1, 2, and 3 (Subscriber Lifecycle). This provides the core entity management.
- **Incremental**: Add Phase 4 (Subscriptions) then Phase 5 (History).
