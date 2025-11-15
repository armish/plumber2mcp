#' @keywords internal
"_PACKAGE"

#' plumber2mcp: Add Model Context Protocol Support to Plumber APIs
#'
#' @description
#' The plumber2mcp package extends Plumber APIs with Model Context Protocol (MCP)
#' support, enabling AI assistants (like Claude, ChatGPT, etc.) to discover and
#' interact with your R functions through three key MCP primitives:
#'
#' \itemize{
#'   \item \strong{Tools}: AI assistants can call your API endpoints directly
#'   \item \strong{Resources}: AI assistants can read documentation, data, and analysis results
#'   \item \strong{Prompts}: AI assistants can use pre-defined templates to guide interactions
#' }
#'
#' @section Main Functions:
#'
#' \strong{Core MCP Setup:}
#' \itemize{
#'   \item \code{\link{pr_mcp}}: Add MCP support to a Plumber router (main function)
#'   \item \code{\link{pr_mcp_http}}: Add MCP support with HTTP transport
#'   \item \code{\link{pr_mcp_stdio}}: Add MCP support with stdio transport
#' }
#'
#' \strong{Resources:}
#' \itemize{
#'   \item \code{\link{pr_mcp_resource}}: Add a custom resource
#'   \item \code{\link{pr_mcp_help_resources}}: Add built-in R help resources
#' }
#'
#' \strong{Prompts:}
#' \itemize{
#'   \item \code{\link{pr_mcp_prompt}}: Add a prompt template
#' }
#'
#' @section Quick Start:
#'
#' \strong{HTTP Transport (for testing):}
#' \preformatted{
#' library(plumber)
#' library(plumber2mcp)
#'
#' pr("plumber.R") \%>\%
#'   pr_mcp(transport = "http") \%>\%
#'   pr_run(port = 8000)
#' }
#'
#' \strong{Stdio Transport (for MCP clients):}
#' \preformatted{
#' library(plumber)
#' library(plumber2mcp)
#'
#' pr("plumber.R") \%>\%
#'   pr_mcp(transport = "stdio")
#' }
#'
#' @section Adding Features:
#'
#' \strong{Add a Resource:}
#' \preformatted{
#' pr \%>\%
#'   pr_mcp(transport = "stdio") \%>\%
#'   pr_mcp_resource(
#'     uri = "/data/summary",
#'     func = function() summary(mtcars),
#'     name = "Dataset Summary"
#'   )
#' }
#'
#' \strong{Add a Prompt:}
#' \preformatted{
#' pr \%>\%
#'   pr_mcp(transport = "stdio") \%>\%
#'   pr_mcp_prompt(
#'     name = "analyze-data",
#'     description = "Guide for data analysis",
#'     arguments = list(
#'       list(name = "dataset", description = "Dataset name", required = TRUE)
#'     ),
#'     func = function(dataset) {
#'       paste("Please analyze the", dataset, "dataset")
#'     }
#'   )
#' }
#'
#' @section MCP Protocol:
#'
#' This package implements the Model Context Protocol (MCP) specification version
#' 2025-06-18. It provides:
#'
#' \itemize{
#'   \item \strong{Automatic endpoint discovery}: Scans your Plumber API and converts endpoints to MCP tools
#'   \item \strong{Rich schema generation}: Creates detailed JSON schemas from roxygen documentation
#'   \item \strong{JSON-RPC 2.0}: Handles all MCP communication via JSON-RPC
#'   \item \strong{Multiple transports}: HTTP (for testing) and stdio (for MCP clients)
#'   \item \strong{Enhanced documentation}: Extracts parameter descriptions, types, and defaults
#' }
#'
#' @section Supported MCP Methods:
#'
#' \strong{Core Protocol:}
#' \itemize{
#'   \item \code{initialize}: Server initialization and capability negotiation
#'   \item \code{ping}: Health check
#' }
#'
#' \strong{Tools:}
#' \itemize{
#'   \item \code{tools/list}: List available API endpoints
#'   \item \code{tools/call}: Execute an API endpoint
#' }
#'
#' \strong{Resources:}
#' \itemize{
#'   \item \code{resources/list}: List available resources
#'   \item \code{resources/read}: Read a specific resource
#'   \item \code{resources/templates/list}: List resource templates
#' }
#'
#' \strong{Prompts:}
#' \itemize{
#'   \item \code{prompts/list}: List available prompt templates
#'   \item \code{prompts/get}: Get a specific prompt with arguments
#' }
#'
#' @section Configuration:
#'
#' Customize your MCP server with:
#' \itemize{
#'   \item \code{path}: Custom mount path (default: "/mcp")
#'   \item \code{include_endpoints}: Whitelist specific endpoints
#'   \item \code{exclude_endpoints}: Blacklist specific endpoints
#'   \item \code{server_name}: Custom server name
#'   \item \code{server_version}: Custom server version
#'   \item \code{debug}: Enable debug logging (stdio only)
#' }
#'
#' @section Learn More:
#'
#' \itemize{
#'   \item MCP Specification: \url{https://modelcontextprotocol.io}
#'   \item GitHub Repository: \url{https://github.com/armish/plumber2mcp}
#'   \item Plumber Documentation: \url{https://www.rplumber.io}
#' }
#'
#' @examples
#' \dontrun{
#' # Basic HTTP server
#' library(plumber)
#' library(plumber2mcp)
#'
#' pr <- plumber::pr()
#' pr$handle("GET", "/echo", function(msg = "hello") {
#'   list(message = msg)
#' })
#'
#' pr %>%
#'   pr_mcp(transport = "http") %>%
#'   pr_run(port = 8000)
#'
#' # Full-featured stdio server
#' pr %>%
#'   pr_mcp(transport = "stdio") %>%
#'   pr_mcp_resource(
#'     uri = "/docs/api",
#'     func = function() "API Documentation",
#'     name = "API Docs"
#'   ) %>%
#'   pr_mcp_prompt(
#'     name = "help",
#'     description = "Get help with the API",
#'     func = function() "How can I help you use this API?"
#'   )
#' }
#'
#' @name plumber2mcp-package
NULL
