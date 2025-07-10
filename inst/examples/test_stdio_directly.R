#!/usr/bin/env Rscript
# Test stdio transport directly

library(plumber)
library(plumber2mcp)

# Create a simple test API
pr <- pr() %>%
  pr_get("/test", function() { list(msg = "hello from stdio") })

# Simulate stdio messages
test_messages <- c(
  # Initialize
  '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05"}}',
  # List tools
  '{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}',
  # Call a tool
  '{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "GET__test", "arguments": {}}}'
)

# Create a temporary file with test messages
temp_file <- tempfile()
writeLines(test_messages, temp_file)

# Run the stdio server with input from our test file
message("Testing stdio transport with test messages...")
system2("Rscript", 
        args = c("-e", sprintf('
          library(plumber)
          library(plumber2mcp)
          pr <- plumber::pr()
          pr$handle("GET", "/test", function() { list(msg = "hello from stdio") })
          plumber2mcp::pr_mcp_stdio(pr, debug = FALSE)
        ')),
        stdin = temp_file,
        stdout = TRUE,
        stderr = FALSE
)

unlink(temp_file)