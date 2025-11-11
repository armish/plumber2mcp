# Null-coalescing operator for convenience
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Run MCP server with stdio transport
#'
#' Creates an MCP server that communicates via standard input/output (stdio).
#' This is the standard transport for MCP clients like Claude Desktop, mcp-cli, etc.
#'
#' @param pr A Plumber router object
#' @param include_endpoints Character vector of endpoints to include as MCP tools (NULL for all)
#' @param exclude_endpoints Character vector of endpoints to exclude from MCP tools
#' @param server_name Name of the MCP server
#' @param server_version Version of the MCP server
#' @param debug Logical, whether to write debug messages to stderr
#'
#' @return This function runs until interrupted and doesn't return
#' @export
#'
#' @examples
#' \dontrun{
#' # Create a Plumber API and run as MCP stdio server
#' pr <- plumb("api.R")
#' pr_mcp_stdio(pr)
#' }
pr_mcp_stdio <- function(
  pr,
  include_endpoints = NULL,
  exclude_endpoints = NULL,
  server_name = "plumber-mcp",
  server_version = "0.2.0",
  debug = FALSE
) {
  validate_pr(pr)

  # Extract tools (reuse existing function)
  tools <- extract_plumber_tools(pr, include_endpoints, exclude_endpoints)

  # Extract resources from router environment (populated by pr_mcp_resource calls)
  resources <- pr$environment$mcp_resources %||% list()

  # Extract prompts from router environment (populated by pr_mcp_prompt calls)
  prompts <- pr$environment$mcp_prompts %||% list()

  if (debug) {
    message(
      "Starting MCP stdio server with ",
      length(tools),
      " tools, ",
      length(resources),
      " resources, and ",
      length(prompts),
      " prompts"
    )
  }

  # Run stdio loop
  run_stdio_server(
    tools,
    resources,
    prompts,
    server_name,
    server_version,
    pr,
    debug
  )
}

#' Run the stdio message loop
#' @noRd
run_stdio_server <- function(
  tools,
  resources,
  prompts,
  server_name,
  server_version,
  pr,
  debug = FALSE
) {
  if (debug) {
    message("MCP stdio server ready, waiting for messages...")
  }

  # Use stdin connection
  stdin_con <- file("stdin", "r")
  on.exit(close(stdin_con))

  # Main stdio loop
  repeat {
    # Read from stdin
    line <- tryCatch(
      {
        readLines(stdin_con, n = 1, warn = FALSE)
      },
      error = function(e) {
        if (debug) {
          message("Error reading stdin: ", e$message)
        }
        character(0)
      }
    )

    if (length(line) == 0) {
      if (debug) {
        message("EOF received, shutting down")
      }
      break # EOF
    }

    if (debug) {
      message("Received: ", line)
    }

    tryCatch(
      {
        # Parse JSON-RPC request
        request <- jsonlite::fromJSON(line, simplifyVector = FALSE)

        # Process request
        response <- process_mcp_request(
          request,
          tools,
          resources,
          prompts,
          server_name,
          server_version,
          pr,
          debug
        )

        # Write response to stdout (only if not NULL for notifications)
        if (!is.null(response)) {
          response_json <- jsonlite::toJSON(
            response,
            auto_unbox = TRUE,
            null = "null"
          )
          cat(response_json, "\n", sep = "", file = stdout())
          flush(stdout())

          if (debug) {
            message("Sent: ", response_json)
          }
        } else if (debug) {
          message("No response (notification)")
        }
      },
      error = function(e) {
        # Send error response
        error_response <- list(
          jsonrpc = "2.0",
          id = if (exists("request") && !is.null(request$id)) {
            request$id
          } else {
            NULL
          },
          error = list(
            code = -32603,
            message = paste("Internal error:", e$message)
          )
        )
        error_json <- jsonlite::toJSON(
          error_response,
          auto_unbox = TRUE,
          null = "null"
        )
        cat(error_json, "\n", sep = "", file = stdout())
        flush(stdout())

        if (debug) {
          message("Error: ", e$message)
          message("Sent error: ", error_json)
        }
      }
    )
  }

  if (debug) {
    message("MCP stdio server stopped")
  }
}

#' Process a single MCP request
#' @noRd
process_mcp_request <- function(
  request,
  tools,
  resources,
  prompts,
  server_name,
  server_version,
  pr,
  debug = FALSE
) {
  # Validate JSON-RPC
  if (is.null(request$jsonrpc) || request$jsonrpc != "2.0") {
    return(list(
      jsonrpc = "2.0",
      id = request$id,
      error = list(code = -32600, message = "Invalid Request")
    ))
  }

  # Debug: log the method being called
  if (debug) {
    message("Processing method: ", request$method)
  }

  # Route to appropriate handler
  result <- switch(
    request$method,
    "initialize" = handle_initialize_stdio(
      request,
      server_name,
      server_version
    ),
    "notifications/initialized" = handle_notifications_initialized_stdio(
      request
    ),
    "ping" = handle_ping_stdio(request),
    "tools/list" = handle_tools_list_stdio(request, tools),
    "tools/call" = handle_tools_call_stdio(request, tools, pr),
    "resources/list" = handle_resources_list_stdio(request, resources),
    "resources/read" = handle_resources_read_stdio(request, resources),
    "resources/templates" = handle_resources_templates_stdio(request),
    "resources/templates/list" = handle_resources_templates_stdio(request),
    "resources/subscribe" = handle_resources_subscribe_stdio(request),
    "resources/unsubscribe" = handle_resources_unsubscribe_stdio(request),
    "prompts/list" = handle_prompts_list_stdio(request, prompts),
    "prompts/get" = handle_prompts_get_stdio(request, prompts),
    {
      list(
        jsonrpc = "2.0",
        id = request$id,
        error = list(code = -32601, message = "Method not found")
      )
    }
  )

  return(result)
}

#' Handle initialize request for stdio transport
#' @noRd
handle_initialize_stdio <- function(body, server_name, server_version) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = list(
      protocolVersion = "2025-06-18",
      capabilities = list(
        tools = structure(list(), names = character(0)), # Force empty object, not array
        resources = structure(list(), names = character(0)), # Force empty object, not array
        prompts = structure(list(), names = character(0)) # Force empty object, not array
      ),
      serverInfo = list(
        name = server_name,
        version = server_version
      )
    )
  )
}

#' Handle notifications/initialized request for stdio transport
#' @noRd
handle_notifications_initialized_stdio <- function(body) {
  # This is a notification, no response needed
  # Return NULL to indicate no response
  NULL
}

#' Handle ping request for stdio transport
#' @noRd
handle_ping_stdio <- function(body) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = structure(list(), names = character(0)) # Force empty object, not array
  )
}

#' Handle tools/list request for stdio transport
#' @noRd
handle_tools_list_stdio <- function(body, tools) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = list(
      tools = unname(lapply(tools, function(tool) {
        # Create base tool definition
        tool_def <- list(
          name = tool$name,
          description = tool$description,
          inputSchema = tool$inputSchema
        )

        # Add optional title field (new in 2025-06-18)
        if (!is.null(tool$title)) {
          tool_def$title <- tool$title
        }

        # Add output schema if available
        if (!is.null(tool$outputSchema)) {
          tool_def$outputSchema <- tool$outputSchema
        }

        tool_def
      }))
    )
  )
}

#' Handle resources/list request for stdio transport
#' @noRd
handle_resources_list_stdio <- function(body, resources) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = list(
      resources = unname(lapply(resources, function(resource) {
        list(
          uri = resource$uri,
          name = resource$name,
          description = resource$description,
          mimeType = resource$mimeType %||% "text/plain"
        )
      }))
    )
  )
}

#' Handle resources/read request for stdio transport
#' @noRd
handle_resources_read_stdio <- function(body, resources) {
  resource_uri <- body$params$uri

  if (!(resource_uri %in% names(resources))) {
    return(list(
      jsonrpc = "2.0",
      id = body$id,
      error = list(
        code = -32602,
        message = paste("Unknown resource:", resource_uri)
      )
    ))
  }

  resource <- resources[[resource_uri]]

  # Execute the resource function
  tryCatch(
    {
      # Get the function that generates the resource content
      func <- resource$func

      # Execute the function to get content
      content <- func()

      # Convert content to string if needed
      if (!is.character(content)) {
        content <- as.character(content)
      }

      list(
        jsonrpc = "2.0",
        id = body$id,
        result = list(
          contents = list(
            list(
              uri = resource_uri,
              mimeType = resource$mimeType %||% "text/plain",
              text = paste(content, collapse = "\n")
            )
          )
        )
      )
    },
    error = function(e) {
      list(
        jsonrpc = "2.0",
        id = body$id,
        error = list(
          code = -32603,
          message = "Internal error",
          data = as.character(e)
        )
      )
    }
  )
}

#' Handle resources/templates request for stdio transport
#' @noRd
handle_resources_templates_stdio <- function(body) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = list(
      resourceTemplates = list() # Empty array - no dynamic templates supported yet
    )
  )
}

#' Handle resources/subscribe request for stdio transport
#' @noRd
handle_resources_subscribe_stdio <- function(body) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = structure(list(), names = character(0)) # Empty object - subscriptions not supported
  )
}

#' Handle resources/unsubscribe request for stdio transport
#' @noRd
handle_resources_unsubscribe_stdio <- function(body) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = structure(list(), names = character(0)) # Empty object - subscriptions not supported
  )
}

#' Handle tools/call request for stdio transport
#' @noRd
handle_tools_call_stdio <- function(body, tools, pr) {
  tool_name <- body$params$name
  tool_args <- body$params$arguments

  if (!(tool_name %in% names(tools))) {
    return(list(
      jsonrpc = "2.0",
      id = body$id,
      error = list(
        code = -32602,
        message = paste("Unknown tool:", tool_name)
      )
    ))
  }

  tool <- tools[[tool_name]]

  # Execute the endpoint
  tryCatch(
    {
      # Get the endpoint from the tool
      endpoint <- tool$endpoint

      # Create arguments list for the function
      func_args <- list()
      if (!is.null(tool_args)) {
        func_args <- as.list(tool_args)
      }

      # Get the function
      func <- endpoint$getFunc()

      # If the function expects req, create a mock request object
      if ("req" %in% names(formals(func))) {
        func_args$req <- list(
          REQUEST_METHOD = tool$verb,
          PATH_INFO = endpoint$path,
          body = tool_args,
          args = tool_args
        )
      }

      # Execute the function with arguments
      result <- do.call(func, func_args)

      list(
        jsonrpc = "2.0",
        id = body$id,
        result = list(
          content = list(
            list(
              type = "text",
              text = jsonlite::toJSON(result, auto_unbox = TRUE)
            )
          )
        )
      )
    },
    error = function(e) {
      list(
        jsonrpc = "2.0",
        id = body$id,
        error = list(
          code = -32603,
          message = "Internal error",
          data = as.character(e)
        )
      )
    }
  )
}

#' Handle prompts/list request for stdio transport
#' @noRd
handle_prompts_list_stdio <- function(body, prompts) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = list(
      prompts = unname(lapply(prompts, function(prompt) {
        prompt_def <- list(
          name = prompt$name,
          description = prompt$description
        )

        # Add arguments if defined
        if (!is.null(prompt$arguments) && length(prompt$arguments) > 0) {
          prompt_def$arguments = prompt$arguments
        }

        prompt_def
      }))
    )
  )
}

#' Handle prompts/get request for stdio transport
#' @noRd
handle_prompts_get_stdio <- function(body, prompts) {
  prompt_name <- body$params$name
  prompt_args <- body$params$arguments

  if (!(prompt_name %in% names(prompts))) {
    return(list(
      jsonrpc = "2.0",
      id = body$id,
      error = list(
        code = -32602,
        message = paste("Unknown prompt:", prompt_name)
      )
    ))
  }

  prompt <- prompts[[prompt_name]]

  # Execute the prompt function
  tryCatch(
    {
      # Get the function that generates the prompt messages
      func <- prompt$func

      # Execute the function with arguments
      func_args <- if (!is.null(prompt_args)) as.list(prompt_args) else list()
      messages <- do.call(func, func_args)

      # Ensure messages is a list
      if (!is.list(messages)) {
        messages <- list(messages)
      }

      # Validate and normalize message format
      normalized_messages <- lapply(messages, function(msg) {
        if (is.character(msg)) {
          # Simple string - convert to user message
          list(
            role = "user",
            content = list(
              type = "text",
              text = msg
            )
          )
        } else if (is.list(msg)) {
          # Already structured - validate it has role and content
          if (is.null(msg$role)) {
            msg$role <- "user"
          }
          if (is.null(msg$content)) {
            # If content is missing, look for text field
            if (!is.null(msg$text)) {
              msg$content <- list(type = "text", text = msg$text)
              msg$text <- NULL
            } else {
              stop("Message must have content")
            }
          } else if (is.character(msg$content)) {
            # Content is a string - wrap it
            msg$content <- list(type = "text", text = msg$content)
          }
          msg
        } else {
          stop("Invalid message format")
        }
      })

      list(
        jsonrpc = "2.0",
        id = body$id,
        result = list(
          description = prompt$description,
          messages = normalized_messages
        )
      )
    },
    error = function(e) {
      list(
        jsonrpc = "2.0",
        id = body$id,
        error = list(
          code = -32603,
          message = "Internal error",
          data = as.character(e)
        )
      )
    }
  )
}
