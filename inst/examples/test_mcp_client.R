# Test MCP Client
# This script tests the MCP server functionality

library(httr)
library(jsonlite)

# Base URL for the MCP server
base_url <- "http://localhost:8000"

# Test 1: Get server info
cat("Test 1: Getting MCP server info...\n")
response <- GET(paste0(base_url, "/mcp"))
content <- content(response, "parsed")
cat("Server info:", toJSON(content, pretty = TRUE), "\n\n")

# Test 2: Initialize MCP session
cat("Test 2: Initializing MCP session...\n")
init_request <- list(
  jsonrpc = "2.0",
  id = 1,
  method = "initialize",
  params = list(
    protocolVersion = "2025-06-18",
    capabilities = list()
  )
)

response <- POST(
  paste0(base_url, "/mcp/messages"),
  body = init_request,
  encode = "json"
)
content <- content(response, "parsed")
cat("Initialize response:", toJSON(content, pretty = TRUE), "\n\n")

# Test 3: List available tools
cat("Test 3: Listing available tools...\n")
list_request <- list(
  jsonrpc = "2.0",
  id = 2,
  method = "tools/list"
)

response <- POST(
  paste0(base_url, "/mcp/messages"),
  body = list_request,
  encode = "json"
)
content <- content(response, "parsed")
cat("Available tools:", toJSON(content, pretty = TRUE), "\n\n")

# Test 4: Call a tool (GET_echo)
cat("Test 4: Calling GET_echo tool...\n")
echo_request <- list(
  jsonrpc = "2.0",
  id = 3,
  method = "tools/call",
  params = list(
    name = "GET__echo",
    arguments = list(
      msg = "Hello from MCP!"
    )
  )
)

response <- POST(
  paste0(base_url, "/mcp/messages"),
  body = echo_request,
  encode = "json"
)
content <- content(response, "parsed")
cat("Echo response:", toJSON(content, pretty = TRUE), "\n\n")

# Test 5: Call a tool (POST_add)
cat("Test 5: Calling POST_add tool...\n")
add_request <- list(
  jsonrpc = "2.0",
  id = 4,
  method = "tools/call",
  params = list(
    name = "POST__add",
    arguments = list(
      a = 5,
      b = 3
    )
  )
)

response <- POST(
  paste0(base_url, "/mcp/messages"),
  body = add_request,
  encode = "json"
)
content <- content(response, "parsed")
cat("Add response:", toJSON(content, pretty = TRUE), "\n\n")

# Test 6: Call a tool (GET_time)
cat("Test 6: Calling GET_time tool...\n")
time_request <- list(
  jsonrpc = "2.0",
  id = 5,
  method = "tools/call",
  params = list(
    name = "GET__time",
    arguments = list()
  )
)

response <- POST(
  paste0(base_url, "/mcp/messages"),
  body = time_request,
  encode = "json"
)
content <- content(response, "parsed")
cat("Time response:", toJSON(content, pretty = TRUE), "\n\n")

cat("All tests completed!\n")
