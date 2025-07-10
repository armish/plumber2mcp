#!/usr/bin/env Rscript
# Simple test of stdio transport

library(plumber)
library(plumber2mcp)

# Create test script
test_script <- '
library(plumber)
library(plumber2mcp)

pr <- plumber::pr()
pr$handle("GET", "/test", function() { list(msg = "hello from stdio") })

# Run stdio server
plumber2mcp::pr_mcp_stdio(pr, debug = FALSE)
'

# Write script to file
script_file <- tempfile(fileext = ".R")
writeLines(test_script, script_file)

# Create test input
input_file <- tempfile()
writeLines(c(
  '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}',
  '{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}',
  '{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "GET__test", "arguments": {}}}'
), input_file)

# Run the test
message("Testing stdio transport...")
output <- system2("Rscript", 
                  args = script_file,
                  stdin = input_file,
                  stdout = TRUE,
                  stderr = TRUE)

# Display output
message("\nOutput from stdio server:")
for (line in output) {
  message(line)
  # Parse and pretty print
  tryCatch({
    json <- jsonlite::fromJSON(line)
    message("  Parsed: ", names(json), " = ", 
            paste(unlist(json), collapse = ", "))
  }, error = function(e) {})
}

# Cleanup
unlink(script_file)
unlink(input_file)