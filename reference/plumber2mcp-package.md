# plumber2mcp: Add Model Context Protocol Support to Plumber APIs

Extends plumber APIs with Model Context Protocol (MCP) support, enabling
AI assistants to discover and call your API endpoints as tools, read
resources for context, and use prompt templates for guided interactions.
Simply add pr_mcp() to your plumber pipeline to automatically expose all
endpoints via the MCP protocol with rich schema generation and
documentation.

The plumber2mcp package extends Plumber APIs with Model Context Protocol
(MCP) support, enabling AI assistants (like Claude, ChatGPT, etc.) to
discover and interact with your R functions through three key MCP
primitives:

- **Tools**: AI assistants can call your API endpoints directly

- **Resources**: AI assistants can read documentation, data, and
  analysis results

- **Prompts**: AI assistants can use pre-defined templates to guide
  interactions

## Main Functions

**Core MCP Setup:**

- [`pr_mcp`](https://armish.github.io/plumber2mcp/reference/pr_mcp.md):
  Add MCP support to a Plumber router (main function)

- [`pr_mcp_http`](https://armish.github.io/plumber2mcp/reference/pr_mcp_http.md):
  Add MCP support with HTTP transport

- [`pr_mcp_stdio`](https://armish.github.io/plumber2mcp/reference/pr_mcp_stdio.md):
  Add MCP support with stdio transport

**Resources:**

- [`pr_mcp_resource`](https://armish.github.io/plumber2mcp/reference/pr_mcp_resource.md):
  Add a custom resource

- [`pr_mcp_help_resources`](https://armish.github.io/plumber2mcp/reference/pr_mcp_help_resources.md):
  Add built-in R help resources

**Prompts:**

- [`pr_mcp_prompt`](https://armish.github.io/plumber2mcp/reference/pr_mcp_prompt.md):
  Add a prompt template

## Quick Start

**HTTP Transport (for testing):**

    library(plumber)
    library(plumber2mcp)

    pr("plumber.R") %>%
      pr_mcp(transport = "http") %>%
      pr_run(port = 8000)

**Stdio Transport (for MCP clients):**

    library(plumber)
    library(plumber2mcp)

    pr("plumber.R") %>%
      pr_mcp(transport = "stdio")

## Adding Features

**Add a Resource:**

    pr %>%
      pr_mcp(transport = "stdio") %>%
      pr_mcp_resource(
        uri = "/data/summary",
        func = function() summary(mtcars),
        name = "Dataset Summary"
      )

**Add a Prompt:**

    pr %>%
      pr_mcp(transport = "stdio") %>%
      pr_mcp_prompt(
        name = "analyze-data",
        description = "Guide for data analysis",
        arguments = list(
          list(name = "dataset", description = "Dataset name", required = TRUE)
        ),
        func = function(dataset) {
          paste("Please analyze the", dataset, "dataset")
        }
      )

## MCP Protocol

This package implements the Model Context Protocol (MCP) specification
version 2025-06-18. It provides:

- **Automatic endpoint discovery**: Scans your Plumber API and converts
  endpoints to MCP tools

- **Rich schema generation**: Creates detailed JSON schemas from roxygen
  documentation

- **JSON-RPC 2.0**: Handles all MCP communication via JSON-RPC

- **Multiple transports**: HTTP (for testing) and stdio (for MCP
  clients)

- **Enhanced documentation**: Extracts parameter descriptions, types,
  and defaults

## Supported MCP Methods

**Core Protocol:**

- `initialize`: Server initialization and capability negotiation

- `ping`: Health check

**Tools:**

- `tools/list`: List available API endpoints

- `tools/call`: Execute an API endpoint

**Resources:**

- `resources/list`: List available resources

- `resources/read`: Read a specific resource

- `resources/templates/list`: List resource templates

**Prompts:**

- `prompts/list`: List available prompt templates

- `prompts/get`: Get a specific prompt with arguments

## Configuration

Customize your MCP server with:

- `path`: Custom mount path (default: "/mcp")

- `include_endpoints`: Whitelist specific endpoints

- `exclude_endpoints`: Blacklist specific endpoints

- `server_name`: Custom server name

- `server_version`: Custom server version

- `debug`: Enable debug logging (stdio only)

## Learn More

- MCP Specification: <https://modelcontextprotocol.io>

- GitHub Repository: <https://github.com/armish/plumber2mcp>

- Plumber Documentation: <https://www.rplumber.io>

## Author

**Maintainer**: Bulent Arman Aksoy <arman@aksoy.org>

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic HTTP server
library(plumber)
library(plumber2mcp)

pr <- plumber::pr()
pr$handle("GET", "/echo", function(msg = "hello") {
  list(message = msg)
})

pr %>%
  pr_mcp(transport = "http") %>%
  pr_run(port = 8000)

# Full-featured stdio server
pr %>%
  pr_mcp(transport = "stdio") %>%
  pr_mcp_resource(
    uri = "/docs/api",
    func = function() "API Documentation",
    name = "API Docs"
  ) %>%
  pr_mcp_prompt(
    name = "help",
    description = "Get help with the API",
    func = function() "How can I help you use this API?"
  )
} # }
```
