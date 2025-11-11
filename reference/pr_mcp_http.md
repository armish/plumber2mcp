# Add MCP support via HTTP transport

This is the original pr_mcp implementation that adds HTTP endpoints

## Usage

``` r
pr_mcp_http(
  pr,
  path = "/mcp",
  include_endpoints = NULL,
  exclude_endpoints = NULL,
  server_name = "plumber-mcp",
  server_version = "0.3.0"
)
```

## Arguments

- pr:

  A Plumber router

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
