# Getting Started with plumber2mcp

``` r
library(plumber)
library(plumber2mcp)
```

## Introduction

The Model Context Protocol (MCP) is a standard protocol that enables AI
assistants (like Claude, ChatGPT, etc.) to interact with external tools
and services. The `plumber2mcp` package makes it incredibly easy to add
MCP support to your existing Plumber APIs with just a single function
call.

By adding MCP support, your R functions become available to AI
assistants as:

- **Tools**: AI assistants can call your API endpoints directly
- **Resources**: AI assistants can read documentation, data, and
  analysis results
- **Prompts**: AI assistants can use pre-defined templates to guide
  interactions

## Quick Start

### Basic Example

Let’s create a simple Plumber API and add MCP support:

``` r
# Create a simple plumber API file
library(plumber)
library(plumber2mcp)

# Define your API
pr <- plumb(text = '
#* Echo back the input
#* @param msg The message to echo
#* @get /echo
function(msg = "Hello World") {
  list(message = paste("Echo:", msg))
}

#* Add two numbers
#* @param a First number
#* @param b Second number
#* @post /add
function(a, b) {
  list(result = as.numeric(a) + as.numeric(b))
}
')

# Add MCP support with HTTP transport
pr %>%
  pr_mcp(transport = "http") %>%
  pr_run(port = 8000)
```

That’s it! Your API now has: - Regular HTTP endpoints at
`http://localhost:8000/` - MCP server at `http://localhost:8000/mcp`

## Transport Options

### HTTP Transport (Default)

HTTP transport is great for testing and when you want to run a
traditional web server:

``` r
pr("api.R") %>%
  pr_mcp(transport = "http") %>%
  pr_run(port = 8000)
```

Your MCP endpoints are now available at: - `GET /mcp` - Server
information - `POST /mcp/messages` - JSON-RPC message handler

### Stdio Transport (Native MCP)

For native MCP client compatibility (mcp-cli, Claude Desktop, etc.), use
stdio transport:

``` r
pr("api.R") %>%
  pr_mcp(transport = "stdio")
```

This starts a server that communicates over standard input/output using
the MCP protocol.

#### Using with mcp-cli

Create a `server_config.json` file:

``` json
{
  "mcpServers": {
    "my-r-api": {
      "command": "Rscript",
      "args": ["-e", "plumber::pr('api.R') %>% plumber2mcp::pr_mcp(transport='stdio')"]
    }
  }
}
```

Then test:

``` bash
mcp-cli tools              # List available tools
mcp-cli cmd --tool GET__echo --tool-args '{"msg": "Hello!"}'
```

## Enhanced Documentation

One of the most powerful features of `plumber2mcp` is automatic schema
generation. When you document your endpoints with roxygen comments, the
package creates rich, detailed tool descriptions that help AI assistants
understand and use your APIs effectively.

### Basic Documentation

``` r
#* Calculate statistics on numeric data
#*
#* @param numbers Numeric vector of values
#* @param operation:string Operation to perform: "mean", "median", "sum", "sd"
#* @param na_rm:bool Remove NA values (default: TRUE)
#* @post /stats
function(numbers, operation = "mean", na_rm = TRUE) {
  if (is.character(numbers)) {
    numbers <- as.numeric(strsplit(numbers, ",")[[1]])
  }

  result <- switch(operation,
    "mean" = mean(numbers, na.rm = na_rm),
    "median" = median(numbers, na.rm = na_rm),
    "sum" = sum(numbers, na.rm = na_rm),
    "sd" = sd(numbers, na.rm = na_rm),
    stop("Unknown operation")
  )

  list(result = result, operation = operation)
}
```

This creates an MCP tool with: - Full parameter descriptions - Type
information (string, bool, number) - Default values - Required vs
optional parameters

### Type Annotations

Use plumber type annotations for precise type information:

- `:bool` or `:logical` → boolean
- `:int` or `:integer` → integer
- `:number` or `:numeric` → number
- `:string` or `:character` → string
- `:array` → array

## Working with Resources

Resources allow AI assistants to read content from your R environment,
such as documentation, data descriptions, or analysis results.

### Adding Custom Resources

``` r
pr("api.R") %>%
  pr_mcp(transport = "stdio") %>%

  # Add dataset information
  pr_mcp_resource(
    uri = "/data/iris-summary",
    name = "Iris Dataset Summary",
    description = "Statistical summary of the iris dataset",
    func = function() {
      paste(
        "Dataset: iris",
        paste("Dimensions:", paste(dim(iris), collapse = " x ")),
        "",
        capture.output(summary(iris)),
        sep = "\n"
      )
    }
  ) %>%

  # Add memory usage info
  pr_mcp_resource(
    uri = "/system/memory",
    name = "R Memory Usage",
    description = "Current R session memory statistics",
    func = function() {
      mem <- gc()
      paste(
        "R Memory Usage:",
        paste("Used (Mb):", round(sum(mem[,2]), 2)),
        sep = "\n"
      )
    }
  )
```

### Built-in Help Resources

Quickly add R help documentation:

``` r
pr("api.R") %>%
  pr_mcp(transport = "stdio") %>%
  pr_mcp_help_resources()
```

This adds resources for: - R help topics (`/help/mean`, `/help/lm`) -
Session information (`/r/session-info`) - Installed packages
(`/r/packages`)

## Working with Prompts

Prompts are reusable templates that guide AI assistants in interacting
with your API.

### Simple Prompts

``` r
pr("api.R") %>%
  pr_mcp(transport = "stdio") %>%
  pr_mcp_prompt(
    name = "r-help",
    description = "Get help with R programming",
    func = function() {
      paste(
        "I need help with R programming.",
        "Please provide guidance on best practices.",
        sep = "\n"
      )
    }
  )
```

### Prompts with Arguments

``` r
pr("api.R") %>%
  pr_mcp(transport = "stdio") %>%
  pr_mcp_prompt(
    name = "analyze-dataset",
    description = "Generate analysis plan for a dataset",
    arguments = list(
      list(
        name = "dataset",
        description = "Name of the R dataset to analyze",
        required = TRUE
      ),
      list(
        name = "focus",
        description = "Specific aspect to focus on",
        required = FALSE
      )
    ),
    func = function(dataset, focus = "general") {
      sprintf(
        paste(
          "Please analyze the %s dataset in R.",
          "Focus: %s",
          "",
          "Provide:",
          "1. Summary statistics",
          "2. Data quality assessment",
          "3. Key insights",
          sep = "\n"
        ),
        dataset, focus
      )
    }
  )
```

### Multi-turn Conversation Prompts

``` r
pr("api.R") %>%
  pr_mcp(transport = "stdio") %>%
  pr_mcp_prompt(
    name = "code-review",
    description = "Review R code for quality",
    arguments = list(
      list(name = "code", description = "R code to review", required = TRUE)
    ),
    func = function(code) {
      list(
        list(
          role = "user",
          content = list(type = "text", text = paste("Review this R code:", code, sep = "\n"))
        ),
        list(
          role = "assistant",
          content = list(type = "text", text = "I'll review your code for correctness and style.")
        ),
        list(
          role = "user",
          content = list(type = "text", text = "Please provide specific suggestions.")
        )
      )
    }
  )
```

## Advanced Configuration

### Filtering Endpoints

Include only specific endpoints:

``` r
pr("api.R") %>%
  pr_mcp(
    transport = "http",
    include_endpoints = c("GET__echo", "POST__add")
  ) %>%
  pr_run(port = 8000)
```

Exclude specific endpoints:

``` r
pr("api.R") %>%
  pr_mcp(
    transport = "stdio",
    exclude_endpoints = c("POST__internal")
  )
```

### Custom Server Information

``` r
pr("api.R") %>%
  pr_mcp(
    transport = "http",
    server_name = "my-stats-api",
    server_version = "1.0.0"
  ) %>%
  pr_run(port = 8000)
```

### Custom MCP Path

``` r
pr("api.R") %>%
  pr_mcp(
    transport = "http",
    path = "/my-mcp-server"
  ) %>%
  pr_run(port = 8000)
```

Now your MCP endpoints are at `/my-mcp-server` instead of `/mcp`.

## Complete Example

Here’s a comprehensive example bringing it all together:

``` r
library(plumber)
library(plumber2mcp)

# Create the API
pr <- plumb(text = '
#* @apiTitle Statistical Analysis API
#* @apiDescription MCP-enabled API for statistical operations

#* Calculate descriptive statistics
#* @param values:string Comma-separated numeric values
#* @param stats:string Statistics to compute: "all", "mean", "median", "sd"
#* @post /describe
function(values, stats = "all") {
  nums <- as.numeric(strsplit(values, ",")[[1]])

  result <- list()
  if (stats %in% c("all", "mean")) result$mean <- mean(nums, na.rm = TRUE)
  if (stats %in% c("all", "median")) result$median <- median(nums, na.rm = TRUE)
  if (stats %in% c("all", "sd")) result$sd <- sd(nums, na.rm = TRUE)

  result
}

#* Perform t-test
#* @param group1:string Comma-separated values for group 1
#* @param group2:string Comma-separated values for group 2
#* @param paired:bool Whether to perform paired t-test
#* @post /ttest
function(group1, group2, paired = FALSE) {
  g1 <- as.numeric(strsplit(group1, ",")[[1]])
  g2 <- as.numeric(strsplit(group2, ",")[[1]])

  test <- t.test(g1, g2, paired = paired)

  list(
    statistic = test$statistic,
    p_value = test$p.value,
    conf_int = test$conf.int,
    method = test$method
  )
}
')

# Add MCP capabilities
pr %>%
  pr_mcp(
    transport = "stdio",
    server_name = "stats-api",
    server_version = "1.0.0"
  ) %>%

  # Add resource for available datasets
  pr_mcp_resource(
    uri = "/info/datasets",
    name = "Available Datasets",
    description = "List of R datasets available for analysis",
    func = function() {
      datasets <- data(package = "datasets")$results[, c("Item", "Title")]
      paste(apply(datasets, 1, paste, collapse = ": "), collapse = "\n")
    }
  ) %>%

  # Add analysis prompt
  pr_mcp_prompt(
    name = "statistical-analysis",
    description = "Guide for statistical analysis workflow",
    arguments = list(
      list(name = "question", description = "Research question", required = TRUE)
    ),
    func = function(question) {
      sprintf(
        "Research Question: %s\n\nHelp me:\n1. Choose appropriate test\n2. Check assumptions\n3. Interpret results",
        question
      )
    }
  )
```

## Testing Your MCP Server

### Direct HTTP Testing

For HTTP transport, test with curl:

``` bash
# List tools
curl -X POST http://localhost:8000/mcp/messages \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}'

# Call a tool
curl -X POST http://localhost:8000/mcp/messages \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc": "2.0", "id": 2, "method": "tools/call",
       "params": {"name": "GET__echo", "arguments": {"msg": "Hello!"}}}'
```

### Using MCP Inspector

For both transports, use MCP Inspector for interactive testing:

``` bash
# For stdio transport
cd inst/examples
mcp-inspector --config stdio_config.json --server plumber2mcp

# For HTTP transport
mcp-inspector --config http_wrapper_config.json --server plumber2mcp
```

## Best Practices

### 1. Document Everything

Use roxygen comments extensively:

``` r
#* Calculate correlation between two variables
#*
#* This endpoint computes Pearson or Spearman correlation
#* and provides confidence intervals and p-values.
#*
#* @param x:string Comma-separated numeric values for variable X
#* @param y:string Comma-separated numeric values for variable Y
#* @param method:string Correlation method: "pearson" or "spearman" (default: "pearson")
#* @param conf_level:number Confidence level for intervals (default: 0.95)
#* @post /correlate
function(x, y, method = "pearson", conf_level = 0.95) {
  # Implementation...
}
```

### 2. Provide Meaningful Defaults

Default values appear in the schema and help AI assistants:

``` r
function(data, method = "lm", alpha = 0.05, max_iter = 1000) {
  # Defaults make it easy for AI to call with minimal parameters
}
```

### 3. Return Structured Data

Always return lists with named elements:

``` r
function(x) {
  list(
    result = mean(x),
    n = length(x),
    valid_n = sum(!is.na(x)),
    timestamp = Sys.time()
  )
}
```

### 4. Add Resources for Context

Help AI assistants understand your data:

``` r
pr %>%
  pr_mcp_resource(
    uri = "/data/schema",
    name = "Data Schema",
    description = "Schema and description of available datasets",
    func = function() {
      # Return schema information
    }
  )
```

### 5. Use Prompts for Workflows

Guide AI through complex multi-step processes:

``` r
pr %>%
  pr_mcp_prompt(
    name = "full-analysis",
    description = "Complete data analysis workflow",
    func = function() {
      paste(
        "Guide me through:",
        "1. Data exploration",
        "2. Statistical testing",
        "3. Visualization",
        "4. Interpretation",
        sep = "\n"
      )
    }
  )
```

## Next Steps

- Explore the [package
  documentation](https://github.com/armish/plumber2mcp)
- Check out example APIs in `inst/examples/`
- Read about the [Model Context
  Protocol](https://modelcontextprotocol.io/)
- Try integrating with Claude Desktop or other MCP clients

## Getting Help

- GitHub Issues: <https://github.com/armish/plumber2mcp/issues>
- Package documentation:
  [`?pr_mcp`](https://armish.github.io/plumber2mcp/reference/pr_mcp.md)
- Examples: `system.file("examples", package = "plumber2mcp")`
