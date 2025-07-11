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

### HTTP Transport (Default)

```r
library(plumber)
library(plumber2mcp)

# Create and run a Plumber API with MCP support via HTTP
pr("plumber.R") %>%
  pr_mcp(transport = "http") %>%
  pr_run(port = 8000)
```

Your API now has:
- Regular HTTP endpoints at `http://localhost:8000/`
- MCP server at `http://localhost:8000/mcp`

### Stdio Transport (Native MCP)

```r
library(plumber)
library(plumber2mcp)

# Create and run a Plumber API with native stdio transport
pr("plumber.R") %>%
  pr_mcp(transport = "stdio")
```

Use with mcp-cli or other MCP clients:

1. Create a `server_config.json` file:
```json
{
  "mcpServers": {
    "plumber2mcp": {
      "command": "Rscript",
      "args": ["-e", "plumber::pr('api.R') %>% plumber2mcp::pr_mcp(transport='stdio')"],
      "cwd": "."
    }
  }
}
```

2. Test the connection:
```bash
mcp-cli servers  # Should show your server as "Ready"
mcp-cli tools    # List available tools
mcp-cli cmd --tool GET__echo --tool-args '{"msg": "Hello!"}'  # Call a tool
```

## How It Works

The `pr_mcp()` function automatically:

1. **Discovers your endpoints**: Scans all endpoints in your Plumber API
2. **Creates MCP tools**: Converts each endpoint into an MCP tool with proper schema
3. **Adds MCP endpoints**: Adds the necessary MCP protocol endpoints
4. **Handles JSON-RPC**: Manages all MCP communication via JSON-RPC
5. **Supports resources**: Allows AI assistants to read documentation and data from your R environment
6. **Generates rich schemas**: Creates detailed input/output schemas with documentation from your roxygen comments

## Enhanced Documentation & Schema Generation

plumber2mcp automatically generates rich JSON schemas and detailed documentation for your API endpoints by analyzing your roxygen comments and function signatures. This feature, inspired by FastAPI-MCP, makes your R APIs much more usable by AI assistants.

### Rich Tool Descriptions

When you document your endpoints with roxygen comments, plumber2mcp creates comprehensive tool descriptions:

```r
#* Calculate statistical operations on numeric data
#* 
#* This endpoint performs various statistical calculations on a vector of numbers.
#* It supports multiple operations and handles missing values.
#* 
#* @param numbers Numeric vector of values to calculate statistics for
#* @param operation Statistical operation to perform: "mean", "median", "sum", "sd" (default: "mean")
#* @param na_rm:bool Logical value indicating whether to remove NA values (default: TRUE)
#* @param digits:int Number of decimal places to round the result (default: 2)
#* @return List containing the calculated result and metadata
#* @post /calculate
function(numbers, operation = "mean", na_rm = TRUE, digits = 2) {
  # Convert input to numeric
  if (is.character(numbers)) {
    numbers <- as.numeric(strsplit(numbers, ",")[[1]])
  } else {
    numbers <- as.numeric(numbers)
  }
  
  result <- switch(operation,
    "mean" = mean(numbers, na.rm = na_rm),
    "median" = median(numbers, na.rm = na_rm),
    "sum" = sum(numbers, na.rm = na_rm),
    "sd" = sd(numbers, na.rm = na_rm),
    stop("Unknown operation: ", operation)
  )
  
  list(
    result = round(result, digits),
    operation = operation,
    count = length(numbers[!is.na(numbers)]),
    input_length = length(numbers)
  )
}
```

This creates an MCP tool with:

**Enhanced Description:**
```
Calculate statistical operations on numeric data

This endpoint performs various statistical calculations on a vector of numbers.
It supports multiple operations and handles missing values.

Parameters:
- numbers (string): Numeric vector of values to calculate statistics for
- operation (string) [default: mean]: Statistical operation to perform: "mean", "median", "sum", "sd"
- na_rm (boolean) [default: TRUE]: Logical value indicating whether to remove NA values
- digits (integer) [default: 2]: Number of decimal places to round the result

HTTP Method: POST
Path: /calculate
```

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "numbers": {
      "type": "string",
      "description": "Numeric vector of values to calculate statistics for"
    },
    "operation": {
      "type": "string",
      "description": "Statistical operation to perform: \"mean\", \"median\", \"sum\", \"sd\"",
      "default": "mean"
    },
    "na_rm": {
      "type": "boolean",
      "description": "Logical value indicating whether to remove NA values",
      "default": true
    },
    "digits": {
      "type": "integer",
      "description": "Number of decimal places to round the result",
      "default": 2
    }
  },
  "required": ["numbers"]
}
```

**Output Schema:**
```json
{
  "type": "object",
  "description": "Structured response object",
  "properties": {
    "result": {
      "type": "number",
      "description": "Response field: result"
    },
    "operation": {
      "type": "string",
      "description": "Response field: operation"
    },
    "count": {
      "type": "number",
      "description": "Response field: count"
    },
    "input_length": {
      "type": "number",
      "description": "Response field: input_length"
    }
  }
}
```

### Type Detection and Schema Features

1. **Smart Type Mapping**: Automatically maps R types to JSON Schema types:
   - `logical` → `boolean`
   - `integer` → `integer`
   - `numeric`/`double` → `number`
   - `character` → `string`
   - And supports plumber type annotations like `:bool`, `:int`, `:array`

2. **Default Value Detection**: Extracts default values from function signatures and includes them in schemas

3. **Required vs Optional Parameters**: Automatically determines which parameters are required based on whether they have default values

4. **Output Schema Generation**: Analyzes your function's return statements to automatically generate response schemas

5. **Rich Parameter Documentation**: Extracts parameter descriptions from roxygen `@param` tags

### Why This Matters for AI Assistants

With enhanced schemas, AI assistants can:

1. **Better understand your APIs**: Rich descriptions help AI assistants understand what each endpoint does
2. **Provide better suggestions**: Detailed parameter information helps AI assistants suggest appropriate values
3. **Generate better code**: Output schemas help AI assistants understand what to expect from your API
4. **Reduce errors**: Type information and required/optional parameter detection reduces API call mistakes
5. **Self-document**: Your API becomes self-documenting for both humans and AI

### Example AI Assistant Interaction

Without enhanced schemas:
```
User: "Can you help me calculate the mean of some numbers using this API?"
AI: "I can see there's a calculate endpoint, but I'm not sure what parameters it needs..."
```

With enhanced schemas:
```
User: "Can you help me calculate the mean of some numbers using this API?"
AI: "I can see you have a calculate endpoint that performs statistical operations! 
     It needs a 'numbers' parameter (required) and optionally 'operation' (defaults to 'mean'), 
     'na_rm' (defaults to TRUE), and 'digits' (defaults to 2). 
     
     Let me call it for you:
     POST /calculate with {"numbers": "1,2,3,4,5"}
     
     This will return an object with the result, operation used, count of valid numbers, 
     and input length."
```

### Best Practices for Documentation

To get the most out of enhanced schema generation:

1. **Use descriptive roxygen comments**: Write clear titles and descriptions
2. **Document all parameters**: Use `@param` tags with clear descriptions
3. **Specify types when helpful**: Use `:bool`, `:int`, `:array` annotations for clarity
4. **Provide meaningful default values**: Default values appear in the schema
5. **Use consistent return structures**: Return lists with named elements for better output schemas
6. **Include examples in descriptions**: Help AI assistants understand expected formats

## MCP Endpoints

Once `pr_mcp()` is applied, your API exposes:

- `GET /mcp` - Server information and capabilities
- `POST /mcp/messages` - JSON-RPC message handler for MCP protocol

## Example

Given a simple Plumber API:

```r
#* Echo back the input
#* 
#* Simple endpoint that echoes back whatever message you send it
#* 
#* @param msg:string The message to echo back (default: "Hello World")
#* @get /echo
function(msg = "Hello World") {
  list(message = paste("Echo:", msg))
}

#* Add two numbers together
#* 
#* Performs arithmetic addition on two numeric values
#* 
#* @param a:number First number to add
#* @param b:number Second number to add  
#* @param precision:int Number of decimal places to round result (default: 2)
#* @post /add
function(a, b, precision = 2) {
  result <- as.numeric(a) + as.numeric(b)
  list(
    result = round(result, precision),
    operation = "addition",
    inputs = c(a, b)
  )
}
```

These endpoints become rich MCP tools with full schemas:
- `GET__echo` - Echo back a message with intelligent default handling
- `POST__add` - Add two numbers with configurable precision and structured output

The enhanced documentation provides AI assistants with detailed information about parameter types, defaults, descriptions, and expected response formats.

## Resources Support

Resources allow AI assistants to read content from your R environment, such as documentation, data descriptions, or analysis results.

### Adding Custom Resources

```r
# Create a Plumber API with resources
pr(...) %>%
  pr_mcp(transport = "stdio") %>%
  
  # Add a resource that provides dataset information
  pr_mcp_resource(
    uri = "/data/iris-summary",
    func = function() {
      paste(
        "Dataset: iris",
        paste("Dimensions:", paste(dim(iris), collapse = " x ")),
        "",
        capture.output(summary(iris)),
        sep = "\n"
      )
    },
    name = "Iris Dataset Summary",
    description = "Statistical summary and structure of the iris dataset"
  ) %>%
  
  # Add a resource that shows current memory usage
  pr_mcp_resource(
    uri = "/system/memory",
    func = function() {
      mem <- gc()
      paste(
        "R Memory Usage:",
        paste("Used (Mb):", round(sum(mem[,2]), 2)),
        paste("Gc Trigger (Mb):", round(sum(mem[,6]), 2)),
        "",
        "Object sizes in workspace:",
        capture.output(print(object.size(ls.str()), units = "Mb")),
        sep = "\n"
      )
    },
    name = "R Memory Usage",
    description = "Current R session memory statistics"
  ) %>%
  
  # Add a resource with model diagnostics
  pr_mcp_resource(
    uri = "/models/latest-lm",
    func = function() {
      # Example: fit a model and return diagnostics
      model <- lm(mpg ~ wt + hp, data = mtcars)
      paste(
        "Linear Model: mpg ~ wt + hp",
        "",
        capture.output(summary(model)),
        "",
        "Diagnostic plots saved to: /tmp/lm_diagnostics.png",
        sep = "\n"
      )
    },
    name = "Latest Linear Model",
    description = "Diagnostics for the most recent linear model",
    mimeType = "text/plain"
  )
```

### Built-in R Help Resources

```r
pr(...) %>% 
  pr_mcp(transport = "stdio") %>%
  pr_mcp_help_resources()  # Adds help for common R functions
```

This automatically adds resources for:
- R help topics (`/help/mean`, `/help/lm`, etc.)
- R session information (`/r/session-info`)
- Installed packages (`/r/packages`)

### Dynamic Resources with Parameters

While the current implementation doesn't support URI templates, you can create resources that adapt based on runtime conditions:

```r
# Create resources based on available data files
data_files <- list.files("data/", pattern = "\\.csv$")

my_pr <- pr(...)
for (file in data_files) {
  my_pr <- my_pr %>%
    pr_mcp_resource(
      uri = paste0("/data/", tools::file_path_sans_ext(file)),
      func = local({
        current_file <- file  # Capture the file name
        function() {
          data <- read.csv(file.path("data", current_file))
          paste(
            paste("File:", current_file),
            paste("Rows:", nrow(data)),
            paste("Columns:", paste(names(data), collapse = ", ")),
            "",
            "First 5 rows:",
            capture.output(print(head(data, 5))),
            sep = "\n"
          )
        }
      }),
      name = paste("Dataset:", tools::file_path_sans_ext(file)),
      description = paste("Contents of", file)
    )
}
```

### Resource Usage Examples

Once your MCP server is running with resources, AI assistants can:

1. **Browse available resources** - The AI can list all resources to see what information is available
2. **Read specific resources** - The AI can read resource content to understand your data and environment
3. **Use resources for context** - The AI can reference resource information when answering questions or writing code

Example interaction with an AI assistant:
```
You: "What datasets are available in this R session?"
AI: *Lists resources and reads relevant ones*
    "I can see you have the iris dataset available. Based on the 
    /data/iris-summary resource, it has 150 observations of 5 variables..."

You: "Can you help me analyze the relationship between Sepal.Length and Petal.Length?"
AI: *Reads the iris summary resource for context*
    "Based on the iris dataset summary, I can see that Sepal.Length ranges 
    from 4.3 to 7.9 and Petal.Length from 1.0 to 6.9. Let me create a 
    linear model to analyze their relationship..."
```

## Advanced Usage

### Customizing MCP Path

```r
my_pr %>% pr_mcp(transport = "http", path = "/my-mcp-server")
```

### Filtering Endpoints

```r
# Include only specific endpoints
my_pr %>% pr_mcp(transport = "http", include_endpoints = c("GET__echo", "POST__add"))

# Exclude specific endpoints
my_pr %>% pr_mcp(transport = "stdio", exclude_endpoints = c("POST__internal"))
```

### Custom Server Info

```r
my_pr %>% pr_mcp(
  transport = "http",
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

pr("my_api.R") %>%
  pr_mcp(transport = "http") %>%
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

## Testing with MCP Inspector

[MCP Inspector](https://github.com/modelcontextprotocol/inspector) is a tool for testing and debugging MCP servers.

### Using MCP Inspector with HTTP Transport

1. Start your plumber API with HTTP transport:
```r
library(plumber)
library(plumber2mcp)

pr("api.R") %>%
  pr_mcp(transport = "http") %>%
  pr_run(port = 8000)
```

2. In a new terminal, navigate to the examples directory:
```bash
cd /path/to/plumber2mcp/inst/examples
mcp-inspector --config http_wrapper_config.json --server plumber2mcp
```

The `stdio-wrapper.py` script bridges MCP Inspector's stdio interface to your HTTP server.

### Using MCP Inspector with Stdio Transport

Use the stdio configuration directly:
```bash
cd /path/to/plumber2mcp/inst/examples
mcp-inspector --config stdio_config.json --server plumber2mcp
```

## Troubleshooting

### Common Issues

1. **Port already in use**: Change the port number in `pr_run(port = 8001)`
2. **MCP endpoint not found**: Ensure you called `pr_mcp()` before `pr_run()`
3. **Tools not showing up**: Check that your Plumber endpoints have proper annotations
4. **MCP Inspector connection error**: 
   - For HTTP: Ensure the server is running on port 8000 before starting MCP Inspector
   - Check that the `cwd` path in config files points to the correct directory

### Debug Mode

Enable verbose logging:

```r
# For stdio transport
my_pr %>% pr_mcp(transport = "stdio", debug = TRUE)

# For HTTP transport (debug not available)
my_pr %>% pr_mcp(transport = "http") %>% pr_run(port = 8000)
```

## Contributing

Contributions are welcome! Please file issues and pull requests on GitHub.

## License

MIT
