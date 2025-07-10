# Example: Running a Plumber API with MCP support

library(plumber)
library(plumber2mcp)

# Create and configure the API
# Get the path to the example plumber.R file
plumber_file <- system.file("examples", "plumber.R", package = "plumber2mcp")
if (plumber_file == "") {
  # If package not installed, use relative path
  plumber_file <- "plumber.R"
}

pr <- plumb(plumber_file) %>%
  pr_mcp(transport = "http") %>%
  pr_run(port = 8000)

# The API is now running with:
# - Regular HTTP endpoints at http://localhost:8000/
# - MCP server at http://localhost:8000/mcp
#
# MCP endpoints:
# - GET  /mcp - Server information
# - POST /mcp/messages - JSON-RPC message handler
#
# Available MCP tools will be:
# - GET_echo (from GET /echo)
# - POST_add (from POST /add)
# - GET_time (from GET /time)
# - POST_parse (from POST /parse)