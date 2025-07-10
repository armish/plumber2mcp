# plumber2mcp

<!-- badges: start -->
[![R-CMD-check](https://github.com/armish/plumber2mcp/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/armish/plumber2mcp/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/armish/plumber2mcp/branch/main/graph/badge.svg)](https://app.codecov.io/gh/armish/plumber2mcp?branch=main)
<!-- badges: end -->

Add Model Context Protocol (MCP) support to your Plumber APIs with a single function call.

## What is MCP?

The Model Context Protocol (MCP) is a standard protocol that enables AI assistants (like Claude, ChatGPT, etc.) to interact with external tools and services. By adding MCP support to your Plumber API, you make your R functions available as tools that AI assistants can call directly.

## Installation

```r
# Install from GitHub
remotes::install_github("armish/plumber2mcp")
```

### Dependencies

This package requires:
- R (>= 4.0.0)
- plumber (>= 1.0.0)
- jsonlite
- httr

## Quick Start

```r
library(plumber)
library(plumber2mcp)

# Create and run a Plumber API with MCP support
pr <- pr("plumber.R") %>%
  pr_mcp() %>%
  pr_run(port = 8000)
```

Your API now has:
- Regular HTTP endpoints at `http://localhost:8000/`
- MCP server at `http://localhost:8000/mcp`

## How It Works

The `pr_mcp()` function automatically:

1. **Discovers your endpoints**: Scans all endpoints in your Plumber API
2. **Creates MCP tools**: Converts each endpoint into an MCP tool with proper schema
3. **Adds MCP endpoints**: Adds the necessary MCP protocol endpoints
4. **Handles JSON-RPC**: Manages all MCP communication via JSON-RPC

## MCP Endpoints

Once `pr_mcp()` is applied, your API exposes:

- `GET /mcp` - Server information and capabilities
- `POST /mcp/messages` - JSON-RPC message handler for MCP protocol

## Example

Given a simple Plumber API:

```r
#* Echo back the input
#* @param msg The message to echo
#* @get /echo
function(msg = "") {
  list(message = paste("Echo:", msg))
}

#* Add two numbers
#* @param a First number
#* @param b Second number
#* @post /add
function(a, b) {
  list(result = as.numeric(a) + as.numeric(b))
}
```

These endpoints become MCP tools:
- `GET__echo` - Echo back a message
- `POST__add` - Add two numbers

## Advanced Usage

### Customizing MCP Path

```r
pr %>% pr_mcp(path = "/my-mcp-server")
```

### Filtering Endpoints

```r
# Include only specific endpoints
pr %>% pr_mcp(include_endpoints = c("GET__echo", "POST__add"))

# Exclude specific endpoints
pr %>% pr_mcp(exclude_endpoints = c("POST__internal"))
```

### Custom Server Info

```r
pr %>% pr_mcp(
  server_name = "my-api-mcp",
  server_version = "1.0.0"
)
```

## Complete Example

Here's a step-by-step example of creating an MCP-enabled API:

1. Create a Plumber API file (`my_api.R`):

```r
#* @apiTitle My MCP-Enabled API
#* @apiDescription API with MCP support for AI assistants

#* Get current time
#* @get /time
function() {
  list(time = Sys.time())
}

#* Calculate factorial
#* @param n Integer to calculate factorial
#* @post /factorial
function(n) {
  n <- as.integer(n)
  if (n < 0) stop("n must be non-negative")
  list(result = factorial(n))
}
```

2. Create and run the server:

```r
library(plumber)
library(plumber2mcp)

pr <- pr("my_api.R") %>%
  pr_mcp() %>%
  pr_run(port = 8000)
```

3. Your API is now accessible:
   - HTTP API: `http://localhost:8000/`
   - MCP endpoint: `http://localhost:8000/mcp`
   - API documentation: `http://localhost:8000/__docs__/`

## Testing

Run the example server:

```r
source(system.file("examples/run_mcp_server.R", package = "plumber2mcp"))
```

Test with the MCP client:

```r
source(system.file("examples/test_mcp_client.R", package = "plumber2mcp"))
```

## Using with AI Assistants

Once your MCP server is running, you can configure AI assistants to use it:

### Claude Desktop

Add to your Claude configuration file:

```json
{
  "mcpServers": {
    "my-r-api": {
      "url": "http://localhost:8000/mcp"
    }
  }
}
```

### Other AI Assistants

Check your AI assistant's documentation for MCP configuration instructions.

## MCP Protocol Details

This package implements the [Model Context Protocol](https://modelcontextprotocol.io/) specification. The MCP endpoints handle:

- **Tool Discovery**: Lists all available Plumber endpoints as MCP tools
- **Tool Execution**: Converts MCP tool calls to Plumber endpoint requests
- **Error Handling**: Properly formats errors in MCP response format

## Troubleshooting

### Common Issues

1. **Port already in use**: Change the port number in `pr_run(port = 8001)`
2. **MCP endpoint not found**: Ensure you called `pr_mcp()` before `pr_run()`
3. **Tools not showing up**: Check that your Plumber endpoints have proper annotations

### Debug Mode

Enable verbose logging:

```r
pr %>% pr_mcp(debug = TRUE) %>% pr_run(port = 8000)
```

## Contributing

Contributions are welcome! Please file issues and pull requests on GitHub.

## License

MIT
