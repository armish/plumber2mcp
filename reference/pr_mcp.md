# Add MCP (Model Context Protocol) support to a Plumber router

Add MCP (Model Context Protocol) support to a Plumber router

## Usage

``` r
pr_mcp(
  pr,
  transport,
  path = "/mcp",
  include_endpoints = NULL,
  exclude_endpoints = NULL,
  server_name = "plumber-mcp",
  server_version = "0.3.0",
  debug = FALSE
)
```

## Arguments

- pr:

  A Plumber router

- transport:

  Transport method: "http" or "stdio" (required)

- path:

  The path to mount the MCP server (default: "/mcp") - only used for
  HTTP transport

- include_endpoints:

  Endpoints to include as MCP tools (NULL for all)

- exclude_endpoints:

  Endpoints to exclude from MCP tools

- server_name:

  Name of the MCP server

- server_version:

  Version of the MCP server

- debug:

  Logical, whether to write debug messages (stdio transport only)
