# Example: Running a Plumber API with MCP stdio transport
#
# This script demonstrates running an MCP server using stdio transport.
# This is the standard transport for MCP clients like mcp-cli, Claude Desktop, etc.

# Load the package from source if in development
if (file.exists("../../DESCRIPTION")) {
  devtools::load_all("../..")
} else {
  library(plumber2mcp)
}
library(plumber)

# Create and configure the API
# Get the path to the example plumber.R file
plumber_file <- system.file("examples", "plumber.R", package = "plumber2mcp")
if (plumber_file == "") {
  # If package not installed, use relative path
  plumber_file <- "plumber.R"
}

# Load the plumber API
pr <- plumb(plumber_file)

# Run as stdio MCP server
# This will block and handle stdio messages until interrupted
message("Starting MCP stdio server...")
message("Connect with: mcp-cli --command 'Rscript run_mcp_server_stdio.R'")

pr_mcp_stdio(pr, debug = TRUE)
