---
description: This file describes the Python coding standards for the project.
applyTo: **/*.py
---
# Python Standards for AT Tools

## Code Style
Follow PEP 8 guidelines
Use type hints where appropriate
Maximum line length: 88 characters (Black formatter standard)
Use meaningful variable and function names

## API Integration Best Practices
Always handle HTTP exceptions
Use session objects for multiple requests
Implement proper authentication
Add request timeouts
Log requests and responses for debugging

# Configuration Management
Store credentials in external files (like keyfile)
Use environment variables for configuration
Validate configuration on startup
Provide clear error messages for missing config

# Error Handling
Use specific exception types
Log errors with context
Implement retry logic for API calls
Graceful degradation when possible

## Documentation
Include docstrings for all functions
Document API endpoints and parameters
Provide usage examples
Keep README updated

# Python Standards for AT Tools

## Code Style
Follow PEP 8 guidelines
Use type hints where appropriate
Maximum line length: 88 characters (Black formatter standard)
Use meaningful variable and function names

## API Integration Best Practices
Always handle HTTP exceptions
Use session objects for multiple requests
Implement proper authentication
Add request timeouts
Log requests and responses for debugging

## Configuration Management
Store credentials in external files (like keyfile)
Use environment variables for configuration
Validate configuration on startup
Provide clear error messages for missing config

## Error Handling
Use specific exception types
Log errors with context
Implement retry logic for API calls
Graceful degradation when possible

# Documentation
Include docstrings for all functions
Document API endpoints and parameters
Provide usage examples
Keep README updated
