# Changelog

## plumber2mcp 0.4.0

### Breaking Changes

- **Protocol Version Update**: Upgraded from MCP protocol version
  2024-11-05 to 2025-06-18
  - This is a breaking change for clients still using the old protocol
    version
  - Clients must support protocol version 2025-06-18 to communicate with
    this version

### Critical Bug Fixes

- **Fixed default parameter value serialization** (#issue-tbd)
  - Default values using [`c()`](https://rdrr.io/r/base/c.html),
    [`list()`](https://rdrr.io/r/base/list.html), and other R
    expressions are now correctly evaluated
  - Previously, `c("a", "b")` was serialized as `["c", "a", "b"]`
    (incorrect)
  - Now correctly serialized as `["a", "b"]` (correct)
  - This fixes Claude Desktop compatibility issues where tools were
    disabled due to invalid schemas
  - Added comprehensive test suite (22 new tests) for default value
    handling
  - Fixes validation errors: “malformed default” in MCP schema
    validators
- **Fixed description field being array instead of string** (#issue-tbd)
  - When endpoints had multiple documentation sources (plumber +
    roxygen), description was an array
  - Previously: `{"description": ["First doc", "Second doc"]}`
    (incorrect - violates MCP spec)
  - Now: `{"description": "First doc"}` (correct - single string as
    required by MCP spec)
  - Prioritizes plumber-specific documentation (#\* comments) over
    roxygen docs (#’ comments)
  - Filters out NA values and empty strings before processing
  - This fixes Claude Desktop showing servers as disabled/grayed out
  - Added comprehensive test suite (17 new tests) for description
    handling
  - Ensures strict MCP schema compliance

### New Features

#### MCP Protocol 2025-06-18 Support

- **HTTP Header Support**: Added MCP-Protocol-Version header for HTTP
  transport (required by new spec)
- **Structured Tool Output**: Re-enabled outputSchema support for tools
  (now standard feature in 2025-06-18)
- **Tool Titles**: Added optional title fields to tools for
  human-friendly display names
  - Automatically extracted from roxygen comments or generated from
    method and path

### Improvements

- Better protocol negotiation during initialization
- Enhanced tool definitions with both machine-readable names and
  human-friendly titles
- Output schemas now provide AI assistants with structured format
  expectations
- All 393 tests passing with new protocol version

### Technical Details

- Updated all protocol version strings throughout codebase
- Modified HTTP handler to set and read MCP-Protocol-Version header
- Updated both HTTP and stdio transports to include new fields
- Enhanced handle_tools_list to include title and outputSchema when
  available
- Package documentation updated to reflect new protocol version

### Migration Guide

For users upgrading from 0.3.0: \* No code changes required - the
package handles the new protocol automatically \* MCP clients must
support protocol version 2025-06-18 \* Tools now include optional title
and outputSchema fields \* HTTP responses include MCP-Protocol-Version
header

## plumber2mcp 0.3.0

### New Features

#### Prompts Support

- Added full MCP Prompts support allowing you to define reusable prompt
  templates that AI assistants can discover and use
- New
  [`pr_mcp_prompt()`](https://armish.github.io/plumber2mcp/reference/pr_mcp_prompt.md)
  function to register prompt templates with your MCP server
- Prompts support optional arguments with required/optional parameters
- Prompts can return simple strings, structured messages, or multi-turn
  conversations
- Both HTTP and stdio transports fully support prompts
- Added `prompts/list` and `prompts/get` JSON-RPC handlers
- Updated `initialize` response to advertise prompts capability

#### Enhanced Testing

- Added comprehensive edge case testing (24 new tests)
- Added integration tests for combined features (10 new tests)
- Added security and validation tests (18 new tests)
- Total test count increased from ~69 to ~121 tests (75% increase)
- Tests now cover error handling, malformed inputs, injection attacks,
  and real-world scenarios

### Improvements

- Enhanced schema generation now includes output schemas
- Better error handling for malformed JSON-RPC requests
- Improved handling of NULL, NA, and empty values
- More robust handling of complex nested data structures
- Added support for functions with req/res parameters

### Documentation

- Comprehensive README updates with prompts examples and use cases
- Added example file demonstrating prompts usage
  (inst/examples/prompts_example.R)
- Detailed documentation of prompt message formats
- Added use cases for workflow guidance, code generation, and
  domain-specific assistance

### Bug Fixes

- Fixed parameter ordering in stdio transport handlers
- Fixed JSON-RPC error responses for unknown methods
- Improved type mapping for plumber parameters

## plumber2mcp 0.2.0

### New Features

#### Resources Support

- Added MCP Resources support for exposing R content to AI assistants
- New
  [`pr_mcp_resource()`](https://armish.github.io/plumber2mcp/reference/pr_mcp_resource.md)
  function to add custom resources
- New
  [`pr_mcp_help_resources()`](https://armish.github.io/plumber2mcp/reference/pr_mcp_help_resources.md)
  convenience function for R help topics
- Resources can provide documentation, data summaries, session info, and
  more
- Added `resources/list` and `resources/read` handlers

#### Stdio Transport

- Added native stdio transport support for standard MCP clients
- New
  [`pr_mcp_stdio()`](https://armish.github.io/plumber2mcp/reference/pr_mcp_stdio.md)
  function for stdio-based servers
- Compatible with mcp-cli, Claude Desktop, and other MCP clients
- Handles JSON-RPC over stdin/stdout

### Improvements

- Enhanced schema generation with rich descriptions from roxygen
  comments
- Automatic detection of required vs optional parameters
- Improved type inference for function parameters and return values
- Better handling of empty properties (serialize as object, not array)

### Documentation

- Comprehensive README with examples for all transport types
- Added resources examples and documentation
- Added MCP Inspector testing instructions

## plumber2mcp 0.1.0

### Initial Release

#### Core Features

- HTTP transport for MCP protocol
- Automatic endpoint discovery from Plumber APIs
- JSON-RPC 2.0 protocol implementation
- Tool schema generation from function signatures
- Support for include/exclude endpoint filters
- Customizable server name, version, and mount path

#### MCP Protocol Support

- `initialize` - Server initialization and capabilities
- `tools/list` - List available API endpoints as tools
- `tools/call` - Execute API endpoints through MCP
- `ping` - Server health check

#### Documentation

- Basic README with installation and usage
- Example Plumber API files
- GitHub Actions CI/CD setup
