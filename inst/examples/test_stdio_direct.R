#!/usr/bin/env Rscript
# Direct test of stdio transport

# Load development version
devtools::load_all()

library(plumber)

# Create a simple API
pr <- pr() %>%
  pr_get("/test", function() { list(msg = "hello from stdio") }) %>%
  pr_post("/echo", function(text = "") { list(echo = text) })

# Create a subprocess for testing
library(processx)

# Write a simple test harness
test_harness <- '
devtools::load_all()
library(plumber)

pr <- plumber::pr()
pr$handle("GET", "/test", function() { list(msg = "hello from stdio") })
pr$handle("POST", "/echo", function(text = "") { list(echo = text) })

plumber2mcp::pr_mcp_stdio(pr, debug = FALSE)
'

harness_file <- tempfile(fileext = ".R")
writeLines(test_harness, harness_file)

# Create process
proc <- process$new(
  command = "Rscript",
  args = harness_file,
  stdin = "|",
  stdout = "|",
  stderr = "|"
)

# Helper to send and receive
send_receive <- function(proc, message) {
  proc$write_input(paste0(message, "\n"))
  Sys.sleep(0.1)  # Give it time to process
  output <- proc$read_output_lines(n = 1)
  if (length(output) > 0) {
    return(jsonlite::fromJSON(output[1], simplifyVector = FALSE))
  }
  return(NULL)
}

# Test sequence
message("Testing stdio MCP server...")

# 1. Initialize
message("\n1. Testing initialize...")
init_resp <- send_receive(proc, \'{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}\')
message("Response: ", jsonlite::toJSON(init_resp, auto_unbox = TRUE, pretty = TRUE))

# 2. List tools  
message("\n2. Testing tools/list...")
tools_resp <- send_receive(proc, \'{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}\')
message("Response: ", jsonlite::toJSON(tools_resp, auto_unbox = TRUE, pretty = TRUE))
message("Found ", length(tools_resp$result$tools), " tools")

# 3. Call a tool
message("\n3. Testing tools/call...")
call_resp <- send_receive(proc, \'{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "GET__test", "arguments": {}}}\')
message("Response: ", jsonlite::toJSON(call_resp, auto_unbox = TRUE, pretty = TRUE))

# Check for errors
errors <- proc$read_error_lines()
if (length(errors) > 0) {
  message("\nErrors from server:")
  for (err in errors) message("  ", err)
}

# Cleanup
proc$kill()
unlink(harness_file)

message("\nTest complete!")