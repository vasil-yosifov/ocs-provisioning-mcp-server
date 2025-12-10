# /speckit.constitution
Define the constitution with the bare minimum non-negotiable rules for implementation of local MCP server implemented in Python using the standard SDK by Anthropic. 

# /speckit.specify
The project is building a standalone local MCP server, which wraps the telecom subscribers' profile information API, provided in `app-spec-docs/latest-ocs-provisioning-api.yml`.
The backend is a REST API microservice, which runs in a docker containerized service. The goal of the MCP server is to expose CRUD API operationd to the MCP clients. Use the scripts in `app-spec-docs/usage-scripts` folders to get additional context about the exposed API. If there are unclear and/or underspecified requirements mark them for clarification.