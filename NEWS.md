# plumber2mcp 0.3.0

## New Features

### Prompts Support
* Added full MCP Prompts support allowing you to define reusable prompt templates that AI assistants can discover and use
* New `pr_mcp_prompt()` function to register prompt templates with your MCP server
* Prompts support optional arguments with required/optional parameters
* Prompts can return simple strings, structured messages, or multi-turn conversations
* Both HTTP and stdio transports fully support prompts
* Added `prompts/list` and `prompts/get` JSON-RPC handlers
* Updated `initialize` response to advertise prompts capability

### Enhanced Testing
* Added comprehensive edge case testing (24 new tests)
* Added integration tests for combined features (10 new tests)
* Added security and validation tests (18 new tests)
* Total test count increased from ~69 to ~121 tests (75% increase)
* Tests now cover error handling, malformed inputs, injection attacks, and real-world scenarios

## Improvements

* Enhanced schema generation now includes output schemas
* Better error handling for malformed JSON-RPC requests
* Improved handling of NULL, NA, and empty values
* More robust handling of complex nested data structures
* Added support for functions with req/res parameters

## Documentation

* Comprehensive README updates with prompts examples and use cases
* Added example file demonstrating prompts usage (inst/examples/prompts_example.R)
* Detailed documentation of prompt message formats
* Added use cases for workflow guidance, code generation, and domain-specific assistance

## Bug Fixes

* Fixed parameter ordering in stdio transport handlers
* Fixed JSON-RPC error responses for unknown methods
* Improved type mapping for plumber parameters

# plumber2mcp 0.2.0

## New Features

### Resources Support
* Added MCP Resources support for exposing R content to AI assistants
* New `pr_mcp_resource()` function to add custom resources
* New `pr_mcp_help_resources()` convenience function for R help topics
* Resources can provide documentation, data summaries, session info, and more
* Added `resources/list` and `resources/read` handlers

### Stdio Transport
* Added native stdio transport support for standard MCP clients
* New `pr_mcp_stdio()` function for stdio-based servers
* Compatible with mcp-cli, Claude Desktop, and other MCP clients
* Handles JSON-RPC over stdin/stdout

## Improvements

* Enhanced schema generation with rich descriptions from roxygen comments
* Automatic detection of required vs optional parameters
* Improved type inference for function parameters and return values
* Better handling of empty properties (serialize as object, not array)

## Documentation

* Comprehensive README with examples for all transport types
* Added resources examples and documentation
* Added MCP Inspector testing instructions

# plumber2mcp 0.1.0

## Initial Release

### Core Features
* HTTP transport for MCP protocol
* Automatic endpoint discovery from Plumber APIs
* JSON-RPC 2.0 protocol implementation
* Tool schema generation from function signatures
* Support for include/exclude endpoint filters
* Customizable server name, version, and mount path

### MCP Protocol Support
* `initialize` - Server initialization and capabilities
* `tools/list` - List available API endpoints as tools
* `tools/call` - Execute API endpoints through MCP
* `ping` - Server health check

### Documentation
* Basic README with installation and usage
* Example Plumber API files
* GitHub Actions CI/CD setup
