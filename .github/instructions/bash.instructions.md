---
description: This file describes the Bash scripting best practices for the project.
applyTo: **/*.sh
---
# Bash Script Best Practices

## Script Structure
Always include shebang: `#!/bin/bash`
Use 'set -euo pipefail' for safer scripts
Include script description and usage information
Use functions for reusable code blocks

## Variable Handling
Use '"$VAR"' instead of 'VAR' to handle spaces
Use 'local' for function variables
Use '${VAR:-default}' for default values
Validate required variables exist

## Error Handling
Check exit codes: if ! command; then
Use 'exit 1' for critical operations
Include meaningful error messages
Clean up temporary files on exit

## Security
Avoid 'eval' when possible
Validate input parameters
Use temporary files securely
Don't hardcode sensitive data

## Code Style
Use consistent indentation (2 or 4 spaces)
Keep functions under 50 lines
Use descriptive variable names
Comment complex logic
