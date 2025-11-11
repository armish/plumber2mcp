# Run MCP server with stdio transport

Creates an MCP server that communicates via standard input/output
(stdio). This is the standard transport for MCP clients like Claude
Desktop, mcp-cli, etc.

## Usage

``` r
pr_mcp_stdio(
  pr,
  include_endpoints = NULL,
  exclude_endpoints = NULL,
  server_name = "plumber-mcp",
  server_version = "0.2.0",
  debug = FALSE
)
```

## Arguments

- pr:

  A Plumber router object

- include_endpoints:

  Character vector of endpoints to include as MCP tools (NULL for all)

- exclude_endpoints:

  Character vector of endpoints to exclude from MCP tools

- server_name:

  Name of the MCP server

- server_version:

  Version of the MCP server

- debug:

  Logical, whether to write debug messages to stderr

## Value

This function runs until interrupted and doesn't return

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a Plumber API and run as MCP stdio server
pr <- plumb("api.R")
pr_mcp_stdio(pr)
} # }
```
