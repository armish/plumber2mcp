# Example: Running a Plumber API with MCP stdio transport and resources
#
# This script demonstrates running an MCP server with resources that AI assistants
# can read to better understand your R environment and data.

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

# Add custom resources
pr <- pr %>%
  # Add built-in R help resources (includes help for common functions)
  pr_mcp_help_resources() %>%

  # Add a custom resource with current dataset information
  pr_mcp_resource(
    uri = "/data/mtcars-info",
    func = function() {
      paste(
        "Dataset: mtcars",
        paste("Dimensions:", paste(dim(mtcars), collapse = " x ")),
        paste("Columns:", paste(names(mtcars), collapse = ", ")),
        paste("Sample data:"),
        capture.output(head(mtcars, 3)),
        sep = "\n"
      )
    },
    name = "mtcars Dataset Information",
    description = "Information about the built-in mtcars dataset"
  ) %>%

  # Add a resource with R environment information
  pr_mcp_resource(
    uri = "/r/search-path",
    func = function() {
      paste(
        "R Search Path:",
        paste(search(), collapse = "\n"),
        sep = "\n"
      )
    },
    name = "R Search Path",
    description = "Current R search path showing attached packages and environments"
  ) %>%

  # Add a resource with available datasets
  pr_mcp_resource(
    uri = "/data/available",
    func = function() {
      datasets <- data()$results
      if (is.null(datasets)) {
        return("No datasets information available")
      }

      # Format dataset information
      paste(
        "Available R Datasets:",
        paste(
          paste(datasets[, "Item"], "-", datasets[, "Title"]),
          collapse = "\n"
        ),
        sep = "\n"
      )
    },
    name = "Available R Datasets",
    description = "List of available datasets in loaded packages"
  )

# Run as stdio MCP server with resources
# This will block and handle stdio messages until interrupted
message("Starting MCP stdio server with resources...")
message("Available resources:")
message("- R help topics: /help/{topic}")
message("- R session info: /r/session-info")
message("- Installed packages: /r/packages")
message("- mtcars info: /data/mtcars-info")
message("- Search path: /r/search-path")
message("- Available datasets: /data/available")
message("")
message("Connect with: mcp-cli --config-file stdio_config.json")

pr_mcp_stdio(pr, debug = TRUE)
