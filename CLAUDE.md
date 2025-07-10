# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

plumber2mcp is an R package that adds Model Context Protocol (MCP) support to Plumber APIs. It transforms existing Plumber endpoints into MCP tools that AI assistants can discover and call via JSON-RPC.

## Core Architecture

### Main Components

**R/pr_mcp.R** - Core implementation with three key functions:
- `pr_mcp()` - Main user-facing function that adds MCP capabilities to a Plumber router
- `create_mcp_handler()` - Creates JSON-RPC message handlers for MCP protocol
- `extract_plumber_tools()` - Converts Plumber endpoints to MCP tool definitions

**Protocol Implementation**:
- HTTP transport layer (Plumber endpoints at `/mcp` and `/mcp/messages`)
- JSON-RPC 2.0 protocol handlers for `initialize`, `tools/list`, and `tools/call` methods
- Automatic endpoint discovery and schema generation from function signatures

**Transport Bridge**:
- `inst/examples/stdio-wrapper.py` - Python bridge that converts stdio transport (expected by MCP clients) to HTTP calls
- Handles R's jsonlite serialization quirks (single-element arrays, empty objects)

### Key Design Patterns

1. **Endpoint Transformation**: Plumber endpoints become MCP tools with naming pattern `{METHOD}__{path}` (e.g., `GET__echo`, `POST__add`)

2. **Schema Generation**: Function parameters automatically converted to JSON Schema with roxygen comment parsing for descriptions

3. **Transport Abstraction**: Core R implementation uses HTTP; stdio wrapper enables compatibility with standard MCP clients

## Development Workflow

### Testing
```bash
# Run all tests
R -e "devtools::test()"

# Run specific test
R -e "testthat::test_file('tests/testthat/test-pr_mcp.R')"

# Run with coverage
R -e "covr::package_coverage()"
```

### Package Development
```bash
# Install dev version
R -e "devtools::install()"

# Generate documentation
R -e "devtools::document()"

# Check package
R -e "devtools::check()"
```

### Testing MCP Integration
```bash
# Start example server
R -e "source('inst/examples/run_mcp_server.R')"

# Test HTTP endpoints directly
curl -X POST http://localhost:8000/mcp/messages \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}'

# Test with MCP client (requires stdio wrapper)
cd inst/examples
mcp-cli --config-file server_config.json tools
```

## JSON-RPC Protocol Flow

1. **Initialize**: Client sends `initialize` with protocol version, receives server capabilities
2. **Tool Discovery**: Client calls `tools/list`, receives array of available tools with schemas
3. **Tool Execution**: Client calls `tools/call` with tool name and arguments, receives results

## Known Issues & Workarounds

**R Serialization**: jsonlite creates single-element arrays for scalars. The stdio wrapper (`stdio-wrapper.py`) handles these conversions:
- `["2.0"]` → `"2.0"` for protocol fields
- `{}` → `null` for empty id fields
- Ensures `content` is always an array of content items

**Transport Mismatch**: R implementation uses HTTP, but most MCP clients expect stdio. The Python wrapper bridges this gap.

## CI/CD

GitHub Actions workflows:
- `R-CMD-check.yaml` - Multi-platform R package testing
- `test-coverage.yaml` - Code coverage reporting via Codecov