#' @import plumber
#' @importFrom jsonlite toJSON
#' @importFrom utils capture.output sessionInfo installed.packages help
#' @importFrom tools Rd2txt
NULL

# Null-coalescing operator for convenience
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Validate that input is a Plumber router
#' @noRd
validate_pr <- function(pr) {
  if (!inherits(pr, "Plumber")) {
    stop("Input must be a Plumber router object")
  }
  invisible(pr)
}

#' Add MCP (Model Context Protocol) support to a Plumber router
#'
#' @param pr A Plumber router
#' @param transport Transport method: "http" or "stdio" (required)
#' @param path The path to mount the MCP server (default: "/mcp") - only used for HTTP transport
#' @param include_endpoints Endpoints to include as MCP tools (NULL for all)
#' @param exclude_endpoints Endpoints to exclude from MCP tools
#' @param server_name Name of the MCP server
#' @param server_version Version of the MCP server
#' @param debug Logical, whether to write debug messages (stdio transport only)
#' @export
pr_mcp <- function(pr,
                   transport,
                   path = "/mcp",
                   include_endpoints = NULL,
                   exclude_endpoints = NULL,
                   server_name = "plumber-mcp",
                   server_version = "0.3.0",
                   debug = FALSE) {
  
  validate_pr(pr)
  
  # Validate transport parameter
  if (missing(transport)) {
    stop("Transport parameter is required. Choose 'http' or 'stdio'.")
  }
  
  if (transport == "stdio") {
    # Stdio transport blocks and runs the server
    pr_mcp_stdio(pr, include_endpoints, exclude_endpoints, server_name, server_version, debug)
  } else if (transport == "http") {
    # HTTP transport adds endpoints and returns the router
    pr_mcp_http(pr, path, include_endpoints, exclude_endpoints, server_name, server_version)
  } else {
    stop("Unknown transport: '", transport, "'. Must be 'http' or 'stdio'.")
  }
}

#' Add MCP support via HTTP transport
#' 
#' This is the original pr_mcp implementation that adds HTTP endpoints
#' 
#' @inheritParams pr_mcp
#' @export
pr_mcp_http <- function(pr,
                        path = "/mcp",
                        include_endpoints = NULL,
                        exclude_endpoints = NULL,
                        server_name = "plumber-mcp",
                        server_version = "0.3.0") {
  
  validate_pr(pr)
  
  # Create MCP handler
  mcp_handler <- create_mcp_handler(
    pr = pr,
    include_endpoints = include_endpoints,
    exclude_endpoints = exclude_endpoints,
    server_name = server_name,
    server_version = server_version
  )
  
  # Mount MCP endpoints
  pr %>%
    pr_post(paste0(path, "/messages"), mcp_handler$handle_message, serializer = serializer_json(auto_unbox = TRUE)) %>%
    pr_get(path, mcp_handler$server_info, serializer = serializer_json(auto_unbox = TRUE))
  
  invisible(pr)
}

#' Create MCP handler for processing JSON-RPC requests
#' @noRd
create_mcp_handler <- function(pr, include_endpoints, exclude_endpoints, server_name, server_version) {
  
  # Extract tools from plumber endpoints
  tools <- extract_plumber_tools(pr, include_endpoints, exclude_endpoints)
  
  list(
    # Handle MCP JSON-RPC messages
    handle_message = function(req, res) {
      body <- req$body
      
      if (is.null(body$jsonrpc) || body$jsonrpc != "2.0") {
        res$status <- 400
        return(list(
          jsonrpc = "2.0",
          id = body$id,
          error = list(
            code = -32600,
            message = "Invalid Request"
          )
        ))
      }
      
      # Route to appropriate handler based on method
      result <- switch(body$method,
        "initialize" = handle_initialize(body, server_name, server_version),
        "ping" = handle_ping(body),
        "tools/list" = handle_tools_list(body, tools),
        "tools/call" = handle_tools_call(body, tools, pr),
        "resources/list" = handle_resources_list(body, pr),
        "resources/read" = handle_resources_read(body, pr),
        "resources/templates" = handle_resources_templates(body),
        "resources/subscribe" = handle_resources_subscribe(body),
        "resources/unsubscribe" = handle_resources_unsubscribe(body),
        "prompts/list" = handle_prompts_list(body, pr),
        "prompts/get" = handle_prompts_get(body, pr),
        {
          list(
            jsonrpc = "2.0",
            id = body$id,
            error = list(
              code = -32601,
              message = "Method not found"
            )
          )
        }
      )
      
      return(result)
    },
    
    # Return server information
    server_info = function() {
      list(
        name = server_name,
        version = server_version,
        protocol_version = "2024-11-05",
        capabilities = list(
          tools = list()
        )
      )
    }
  )
}

#' Extract tools from Plumber endpoints
#' @noRd
extract_plumber_tools <- function(pr, include_endpoints, exclude_endpoints) {
  endpoints <- pr$endpoints
  tools <- list()
  
  
  # Iterate through all endpoint groups
  for (group_name in names(endpoints)) {
    group <- endpoints[[group_name]]
    
    # Each group contains a list of endpoints
    for (i in seq_along(group)) {
      endpoint <- group[[i]]
      
      # Skip if not a proper endpoint object
      if (!inherits(endpoint, "PlumberEndpoint")) {
        next
      }
      
      # Extract endpoint properties
      path <- endpoint$path
      verbs <- endpoint$verbs
      
      
      # Create a tool for each verb
      for (verb in verbs) {
        # Create tool ID
        endpoint_id <- paste0(verb, "_", gsub("^/", "", gsub("/", "_", path)))
        
        # Check inclusion/exclusion
        if (!is.null(include_endpoints) && !(endpoint_id %in% include_endpoints)) {
          next
        }
        if (!is.null(exclude_endpoints) && endpoint_id %in% exclude_endpoints) {
          next
        }
        
        # Create tool definition with enhanced description
        enhanced_description <- create_enhanced_description(endpoint, verb, path)
        
        tool <- list(
          name = endpoint_id,
          description = enhanced_description,
          inputSchema = create_input_schema(endpoint),
          # outputSchema = create_output_schema(endpoint),  # Commented out for n8n compatibility
          endpoint = endpoint,
          verb = verb
        )
        
        tools[[endpoint_id]] <- tool
      }
    }
  }
  
  tools
}

#' Create enhanced description using Plumber's parsed roxygen information
#' @noRd
create_enhanced_description <- function(endpoint, verb, path) {
  # Start with the title from comments
  title <- if (!is.null(endpoint$comments) && 
            length(endpoint$comments) > 0 && 
            !is.na(endpoint$comments) &&
            nchar(trimws(endpoint$comments)) > 0) {
    trimws(endpoint$comments)
  } else {
    paste("Endpoint:", verb, path)
  }
  
  # Add the detailed description if available
  description <- if (!is.null(endpoint$description) && 
                    length(endpoint$description) > 0 && 
                    !is.na(endpoint$description) &&
                    nchar(trimws(endpoint$description)) > 0) {
    trimws(endpoint$description)
  } else {
    ""
  }
  
  # Build the complete description
  result <- title
  
  if (description != "" && description != title) {
    result <- paste(result, "\n\n", description, sep = "")
  }
  
  # Add parameter information summary
  if (length(endpoint$params) > 0) {
    result <- paste(result, "\n\nParameters:", sep = "")
    
    # Get function formals to match parameter names
    func <- endpoint$getFunc()
    if (!is.null(func)) {
      formals_list <- formals(func)
      param_names <- names(formals_list)
      param_names <- param_names[!param_names %in% c("req", "res", "...")]
      
      for (i in seq_along(endpoint$params)) {
        if (i <= length(param_names)) {
          param_name <- param_names[i]
          param_info <- endpoint$params[[i]]
          
          param_line <- paste("- ", param_name, sep = "")
          
          # Handle param_info safely - could be list or atomic vector
          if (is.list(param_info) && !is.null(param_info$type)) {
            param_line <- paste(param_line, " (", param_info$type, ")", sep = "")
          } else if (is.character(param_info) && length(param_info) == 1) {
            param_line <- paste(param_line, " (", param_info, ")", sep = "")
          }
          
          # Add default value if parameter is optional
          default_val <- formals_list[[param_name]]
          if (!missing(default_val)) {
            param_line <- paste(param_line, " [default: ", format(default_val), "]", sep = "")
          }
          
          # Handle description safely
          if (is.list(param_info) && !is.null(param_info$desc) && nchar(trimws(param_info$desc)) > 0) {
            param_line <- paste(param_line, ": ", trimws(param_info$desc), sep = "")
          }
          
          result <- paste(result, "\n", param_line, sep = "")
        }
      }
    }
  }
  
  # Add endpoint information
  result <- paste(result, "\n\nHTTP Method: ", toupper(verb), "\nPath: ", path, sep = "")
  
  result
}

#' Create enhanced input schema using Plumber's parsed roxygen information
#' @noRd
create_input_schema <- function(endpoint) {
  # Get function arguments
  func <- endpoint$getFunc()
  if (is.null(func)) {
    return(list(
      type = "object",
      properties = structure(list(), names = character(0)),
      required = list()  # Changed to list() for n8n compatibility
    ))
  }
  
  formals_list <- formals(func)
  args <- names(formals_list)
  
  properties <- list()
  required <- character()
  
  # Create a lookup for plumber-parsed parameters
  plumber_params <- list()
  if (length(endpoint$params) > 0) {
    param_names <- names(formals_list)
    param_names <- param_names[!param_names %in% c("req", "res", "...")]
    
    for (i in seq_along(endpoint$params)) {
      if (i <= length(param_names)) {
        plumber_params[[param_names[i]]] <- endpoint$params[[i]]
      }
    }
  }
  
  # Extract parameters from function arguments
  for (arg_name in args) {
    if (arg_name %in% c("req", "res", "...")) next
    
    # Check if parameter has a default value (making it optional)
    default_val <- formals_list[[arg_name]]
    is_optional <- !missing(default_val)
    
    # Get parameter info from plumber's parsing
    param_info <- plumber_params[[arg_name]]
    
    # Build property definition
    property <- list(
      type = if (!is.null(param_info) && (is.list(param_info) && !is.null(param_info$type))) {
        map_plumber_type_to_json_schema(param_info$type)
      } else if (!is.null(param_info) && is.character(param_info)) {
        # Handle case where param_info is just a character string
        map_plumber_type_to_json_schema(param_info)
      } else {
        infer_type_from_default_value(default_val)
      },
      description = if (!is.null(param_info) && is.list(param_info) && !is.null(param_info$desc)) {
        trimws(param_info$desc)
      } else if (!is.null(param_info) && is.character(param_info)) {
        paste("Parameter", arg_name, "of type", param_info)
      } else {
        paste("Parameter", arg_name)
      }
    )
    
    # Add default value if available
    if (!missing(default_val)) {
      property$default <- convert_default_to_json_type(default_val, property$type)
    }
    
    properties[[arg_name]] <- property
    
    if (!is_optional) {
      required <- c(required, arg_name)
    }
  }
  
  # Ensure properties is serialized as object, not array when empty
  if (length(properties) == 0) {
    properties <- structure(list(), names = character(0))
  }

  # Convert required to list for n8n compatibility
  required_json <- if (length(required) == 0) {
    list()
  } else {
    as.list(required)
  }

  list(
    type = "object",
    properties = properties,
    required = required_json
  )
}

#' Map Plumber parameter types to JSON Schema types
#' @noRd
map_plumber_type_to_json_schema <- function(plumber_type) {
  type_mapping <- list(
    "string" = "string",
    "boolean" = "boolean", 
    "integer" = "integer",
    "numeric" = "number",
    "number" = "number",
    "array" = "array",
    "object" = "object",
    "logical" = "boolean",
    "double" = "number",
    "character" = "string"
  )
  
  # Handle multiple types or return string as fallback
  mapped_type <- type_mapping[[plumber_type]]
  if (is.null(mapped_type)) {
    # Issue warning for unrecognized types to help with debugging
    warning("Unrecognized type: ", plumber_type, ". Using type: string", call. = FALSE)
    return("string")
  }
  
  mapped_type
}

#' Infer JSON Schema type from default value
#' @noRd
infer_type_from_default_value <- function(default_val) {
  if (missing(default_val)) {
    return("string")
  }
  
  if (is.logical(default_val)) {
    return("boolean")
  } else if (is.integer(default_val)) {
    return("integer")
  } else if (is.numeric(default_val)) {
    return("number")
  } else {
    return("string")
  }
}

#' Convert default value to appropriate JSON type
#' @noRd
convert_default_to_json_type <- function(default_val, json_type) {
  if (missing(default_val)) {
    return(NULL)
  }
  
  tryCatch({
    switch(json_type,
      "boolean" = as.logical(default_val),
      "integer" = as.integer(default_val),
      "number" = as.numeric(default_val),
      "string" = as.character(default_val),
      default_val
    )
  }, error = function(e) {
    as.character(default_val)
  })
}

#' Create output schema by analyzing function source code
#' @noRd
create_output_schema <- function(endpoint) {
  # Get function source
  func <- endpoint$getFunc()
  if (is.null(func)) {
    return(list(
      type = "object",
      description = "Function response"
    ))
  }
  
  # Try to analyze function source for return patterns
  tryCatch({
    # Get function body as character
    func_body <- deparse(body(func))
    func_text <- paste(func_body, collapse = "\n")
    
    # Look for common return patterns
    schema <- analyze_return_patterns(func_text)
    
    # If we can't determine schema from patterns, provide generic response
    if (is.null(schema)) {
      schema <- list(
        type = "object",
        description = "Response from the API endpoint",
        properties = structure(list(), names = character(0))
      )
    }
    
    schema
  }, error = function(e) {
    # Fallback to generic schema
    list(
      type = "object",
      description = "Response from the API endpoint"
    )
  })
}

#' Analyze return patterns in function source code
#' @noRd
analyze_return_patterns <- function(func_text) {
  # Look for list() return patterns - first find all list() calls
  # Need to handle balanced parentheses properly
  list_start_pattern <- "list\\s*\\("
  list_starts <- gregexpr(list_start_pattern, func_text, perl = TRUE)[[1]]
  
  if (list_starts[1] != -1) {
    # For each list( found, find the matching closing parenthesis
    for (start_pos in list_starts) {
      # Find the complete list() call with balanced parentheses
      list_content <- extract_balanced_parentheses(func_text, start_pos)
      
      if (!is.null(list_content)) {
        # Parse the list content
        properties <- parse_list_content(list_content)
        
        if (length(properties) > 0) {
          return(list(
            type = "object",
            description = "Structured response object",
            properties = properties
          ))
        }
      }
    }
  }
  
  # Fallback to generic object
  list(
    type = "object",
    description = "Response from the API endpoint"
  )
}

#' Extract content between balanced parentheses starting from a position
#' @noRd
extract_balanced_parentheses <- function(text, start_pos) {
  # Find the 'list(' part
  list_match <- regexpr("list\\s*\\(", substr(text, start_pos, nchar(text)), perl = TRUE)
  if (list_match == -1) return(NULL)
  
  # Adjust position to after 'list('
  paren_start <- start_pos + attr(list_match, "match.length") - 1
  
  # Count parentheses to find the matching close
  paren_count <- 1
  pos <- paren_start + 1
  
  while (pos <= nchar(text) && paren_count > 0) {
    char <- substr(text, pos, pos)
    if (char == "(") {
      paren_count <- paren_count + 1
    } else if (char == ")") {
      paren_count <- paren_count - 1
    }
    pos <- pos + 1
  }
  
  if (paren_count == 0) {
    # Extract content between parentheses
    content <- substr(text, paren_start + 1, pos - 2)
    return(content)
  }
  
  NULL
}

#' Parse list content to extract key-value pairs
#' @noRd
parse_list_content <- function(content) {
  properties <- list()
  
  # Split by comma, but be careful of nested function calls
  # Simple approach: split by comma and then look for = 
  parts <- strsplit(content, ",")[[1]]
  
  for (part in parts) {
    part <- trimws(part)
    if (nchar(part) == 0) next
    
    # Look for key = value pattern
    if (grepl("\\w+\\s*=", part)) {
      # Extract key name (everything before first =)
      eq_pos <- regexpr("=", part)[1]
      if (eq_pos > 0) {
        key <- trimws(substr(part, 1, eq_pos - 1))
        value_part <- trimws(substr(part, eq_pos + 1, nchar(part)))
        
        # Clean up key name
        key <- gsub("[\"'`]", "", key)
        
        # Skip invalid keys
        if (nchar(key) == 0 || !grepl("^[a-zA-Z_][a-zA-Z0-9_]*$", key)) {
          next
        }
        
        # Infer type from value expression
        property_type <- infer_type_from_expression(value_part)
        
        properties[[key]] <- list(
          type = property_type,
          description = paste("Response field:", key)
        )
      }
    }
  }
  
  properties
}

#' Infer type from R expression patterns
#' @noRd
infer_type_from_expression <- function(expr) {
  expr <- trimws(expr)
  
  # Check for numeric functions
  if (grepl("(mean|sum|median|sd|round|length|as\\.numeric|min|max)", expr)) {
    return("number")
  }
  
  # Check for string functions
  if (grepl("(paste|as\\.character|toString)", expr)) {
    return("string")
  }
  
  # Check for logical functions
  if (grepl("(as\\.logical|TRUE|FALSE)", expr)) {
    return("boolean")
  }
  
  # Check for array/list functions
  if (grepl("(c\\(|list\\(|array)", expr)) {
    return("array")
  }
  
  # Check if it's a variable name that might represent a parameter
  if (grepl("^[a-zA-Z_][a-zA-Z0-9_]*$", expr)) {
    # It's a simple variable name - try to infer from common names
    if (grepl("(count|length|size|num)", expr, ignore.case = TRUE)) {
      return("number")
    }
    if (grepl("(operation|type|name|message)", expr, ignore.case = TRUE)) {
      return("string")
    }
    if (grepl("(flag|enable|disable|na_rm|include)", expr, ignore.case = TRUE)) {
      return("boolean")
    }
  }
  
  # Default to string for unknown expressions
  "string"
}


#' Handle initialize request
#' @noRd
handle_initialize <- function(body, server_name, server_version) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = list(
      protocolVersion = "2024-11-05",
      capabilities = list(
        tools = structure(list(), names = character(0)),  # Force empty object, not array
        resources = structure(list(), names = character(0)),  # Force empty object, not array
        prompts = structure(list(), names = character(0))  # Force empty object, not array
      ),
      serverInfo = list(
        name = server_name,
        version = server_version
      )
    )
  )
}

#' Handle tools/list request
#' @noRd
handle_tools_list <- function(body, tools) {
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
        
        # Add output schema if available
        if (!is.null(tool$outputSchema)) {
          tool_def$outputSchema <- tool$outputSchema
        }
        
        tool_def
      }))
    )
  )
}

#' Handle tools/call request
#' @noRd
handle_tools_call <- function(body, tools, pr) {
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
  tryCatch({
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
  }, error = function(e) {
    list(
      jsonrpc = "2.0",
      id = body$id,
      error = list(
        code = -32603,
        message = "Internal error",
        data = as.character(e)
      )
    )
  })
}

#' Handle ping request for HTTP transport
#' @noRd
handle_ping <- function(body) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = structure(list(), names = character(0))  # Force empty object, not array
  )
}

#' Handle resources/list request for HTTP transport
#' @noRd
handle_resources_list <- function(body, pr) {
  # Extract resources from router environment
  resources <- pr$environment$mcp_resources %||% list()
  
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

#' Handle resources/read request for HTTP transport
#' @noRd
handle_resources_read <- function(body, pr) {
  resource_uri <- body$params$uri
  
  # Extract resources from router environment
  resources <- pr$environment$mcp_resources %||% list()
  
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
  tryCatch({
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
  }, error = function(e) {
    list(
      jsonrpc = "2.0",
      id = body$id,
      error = list(
        code = -32603,
        message = "Internal error",
        data = as.character(e)
      )
    )
  })
}

#' Handle resources/templates request for HTTP transport
#' @noRd
handle_resources_templates <- function(body) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = list(
      resourceTemplates = list()  # Empty array - no dynamic templates supported yet
    )
  )
}

#' Handle resources/subscribe request for HTTP transport
#' @noRd
handle_resources_subscribe <- function(body) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = structure(list(), names = character(0))  # Empty object - subscriptions not supported
  )
}

#' Handle resources/unsubscribe request for HTTP transport
#' @noRd
handle_resources_unsubscribe <- function(body) {
  list(
    jsonrpc = "2.0",
    id = body$id,
    result = structure(list(), names = character(0))  # Empty object - subscriptions not supported
  )
}

#' Handle prompts/list request
#' @noRd
handle_prompts_list <- function(body, pr) {
  # Extract prompts from router environment
  prompts <- pr$environment$mcp_prompts %||% list()

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

#' Handle prompts/get request
#' @noRd
handle_prompts_get <- function(body, pr) {
  prompt_name <- body$params$name
  prompt_args <- body$params$arguments

  # Extract prompts from router environment
  prompts <- pr$environment$mcp_prompts %||% list()

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
  tryCatch({
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
  }, error = function(e) {
    list(
      jsonrpc = "2.0",
      id = body$id,
      error = list(
        code = -32603,
        message = "Internal error",
        data = as.character(e)
      )
    )
  })
}

#' Add a resource to an MCP-enabled Plumber router
#'
#' Resources allow AI assistants to read content from your R environment,
#' such as documentation, data files, analysis results, or any other content
#' you want to make available.
#'
#' @param pr A Plumber router object (must have MCP support added)
#' @param uri The URI pattern for the resource (e.g., "/help/topic")
#' @param func A function that returns the resource content
#' @param name A human-readable name for the resource
#' @param description A description of what the resource provides
#' @param mimeType The MIME type of the resource content (default: "text/plain")
#' @export
#'
#' @examples
#' \dontrun{
#' # Add a resource for R help topics
#' pr %>% 
#'   pr_mcp(transport = "stdio") %>%
#'   pr_mcp_resource(
#'     uri = "/help/mean",
#'     func = function() capture.output(help("mean")),
#'     name = "R Help: mean function",
#'     description = "Documentation for the mean() function"
#'   )
#' }
pr_mcp_resource <- function(pr, uri, func, name, description = NULL, mimeType = "text/plain") {
  validate_pr(pr)
  
  # Check if this router has MCP support in its environment
  env <- pr$environment
  if (is.null(env$mcp_resources)) {
    env$mcp_resources <- list()
  }
  
  # Create resource definition
  resource <- list(
    uri = uri,
    name = name,
    description = description %||% paste("Resource:", uri),
    mimeType = mimeType,
    func = func
  )
  
  # Add to router's resources in its environment
  env$mcp_resources[[uri]] <- resource
  
  invisible(pr)
}

#' Add built-in R help resources to an MCP-enabled Plumber router
#'
#' This convenience function adds resources for R documentation that AI assistants
#' can read to better understand R functions and packages.
#'
#' @param pr A Plumber router object (must have MCP support added)
#' @param topics Character vector of help topics to expose (NULL for common topics)
#' @export
#'
#' @examples
#' \dontrun{
#' pr %>% 
#'   pr_mcp(transport = "stdio") %>%
#'   pr_mcp_help_resources()
#' }
pr_mcp_help_resources <- function(pr, topics = NULL) {
  validate_pr(pr)
  
  # Default topics if none specified
  if (is.null(topics)) {
    topics <- c("mean", "lm", "plot", "data.frame", "summary", "str", "head", "tail")
  }
  
  # Add resources for each help topic
  for (topic in topics) {
    pr <- pr_mcp_resource(
      pr = pr,
      uri = paste0("/help/", topic),
      func = create_help_function(topic),
      name = paste("R Help:", topic),
      description = paste("R documentation for the", topic, "function/topic"),
      mimeType = "text/plain"
    )
  }
  
  # Add a general R session info resource
  pr <- pr_mcp_resource(
    pr = pr,
    uri = "/r/session-info",
    func = function() capture.output(sessionInfo()),
    name = "R Session Information",
    description = "Current R session information including version and loaded packages",
    mimeType = "text/plain"
  )
  
  # Add a resource for installed packages
  pr <- pr_mcp_resource(
    pr = pr,
    uri = "/r/packages",
    func = function() {
      pkgs <- installed.packages()
      # Check which columns are available
      available_cols <- colnames(pkgs)
      desired_cols <- c("Package", "Version")
      if ("Title" %in% available_cols) {
        desired_cols <- c(desired_cols, "Title")
      }
      
      pkg_info <- pkgs[, desired_cols, drop = FALSE]
      capture.output(print(as.data.frame(pkg_info), row.names = FALSE))
    },
    name = "Installed R Packages",
    description = "List of installed R packages with versions and descriptions",
    mimeType = "text/plain"
  )
  
  invisible(pr)
}

#' Create a help function for a specific topic
#' @noRd
create_help_function <- function(topic) {
  # Force evaluation of topic to create proper closure
  force(topic)
  
  function() {
    # Use the captured topic value
    current_topic <- topic
    
    tryCatch({
      # Get help content
      help_file <- utils::help(current_topic, try.all.packages = TRUE)
      if (length(help_file) == 0) {
        return(paste("No help found for topic:", current_topic))
      }
      
      # Use capture.output to get help text
      help_text <- capture.output({
        # Capture the help output
        print(help_file)
      })
      
      # Try to get better formatted help using tools
      tryCatch({
        # Create a temporary file to capture clean text output
        temp_file <- tempfile(fileext = ".txt")
        on.exit(unlink(temp_file))
        
        # Get the raw Rd content and convert to plain text file using internal function
        rd_file <- get(".getHelpFile", envir = asNamespace("utils"))(help_file[1])
        tools::Rd2txt(rd_file, out = temp_file)
        
        # Read the clean text from file
        if (file.exists(temp_file)) {
          clean_text <- readLines(temp_file, warn = FALSE)
          
          # Clean up any remaining underscore formatting
          clean_text <- gsub("_([^_])_", "\\1", clean_text)
          clean_text <- gsub("_", "", clean_text)
          
          return(clean_text)
        } else {
          return(help_text)
        }
      }, error = function(e) {
        return(help_text)
      })
    }, error = function(e) {
      # Fallback: try to get basic help information
      tryCatch({
        # Simple approach - just get function signature and description
        func_obj <- get(current_topic, envir = globalenv())
        if (is.function(func_obj)) {
          paste(
            paste("Function:", current_topic),
            paste("Usage:", paste(deparse(args(func_obj)), collapse = " ")),
            "Use help() in R console for full documentation.",
            sep = "\n"
          )
        } else {
          paste("Topic:", current_topic, "- Use help() in R console for documentation.")
        }
      }, error = function(e2) {
        paste("Help topic:", current_topic, "- Use help() in R console for documentation.")
      })
    })
  }
}

#' Add a prompt template to an MCP-enabled Plumber router
#'
#' Prompts are reusable templates that AI assistants can discover and use
#' to interact with your API. They provide structured messages with optional
#' arguments that can be filled in by the AI or user.
#'
#' @param pr A Plumber router object (must have MCP support added)
#' @param name Unique identifier for the prompt (e.g., "code-review", "analyze-data")
#' @param description Human-readable description of what the prompt does
#' @param arguments Optional list of argument definitions. Each argument should be a list with:
#'   \itemize{
#'     \item \code{name}: The argument name
#'     \item \code{description}: What the argument is for
#'     \item \code{required}: Boolean indicating if the argument is required (default: FALSE)
#'   }
#' @param func A function that generates prompt messages. The function should:
#'   \itemize{
#'     \item Accept arguments matching those defined in the arguments parameter
#'     \item Return either a character vector, a list of messages, or a single message
#'     \item Each message can be either a string (treated as user message) or a list with \code{role} and \code{content}
#'   }
#' @export
#'
#' @examples
#' \dontrun{
#' # Simple prompt with no arguments
#' pr %>%
#'   pr_mcp(transport = "stdio") %>%
#'   pr_mcp_prompt(
#'     name = "greeting",
#'     description = "Generate a friendly greeting",
#'     func = function() {
#'       "Hello! How can I help you with R today?"
#'     }
#'   )
#'
#' # Prompt with arguments
#' pr %>%
#'   pr_mcp(transport = "stdio") %>%
#'   pr_mcp_prompt(
#'     name = "analyze-dataset",
#'     description = "Guide for analyzing a dataset",
#'     arguments = list(
#'       list(name = "dataset", description = "Name of the dataset to analyze", required = TRUE),
#'       list(name = "focus", description = "Specific aspect to focus on", required = FALSE)
#'     ),
#'     func = function(dataset, focus = "general") {
#'       if (focus == "general") {
#'         msg <- sprintf(
#'           paste(
#'             "Please analyze the %s dataset. Provide:",
#'             "1. Summary statistics",
#'             "2. Data quality assessment",
#'             "3. Interesting patterns or relationships",
#'             "4. Recommendations for further analysis",
#'             sep = "\n"
#'           ),
#'           dataset
#'         )
#'       } else {
#'         msg <- sprintf(
#'           "Please analyze the %s dataset with a focus on: %s",
#'           dataset, focus
#'         )
#'       }
#'
#'       # Return as a structured message
#'       list(
#'         role = "user",
#'         content = list(type = "text", text = msg)
#'       )
#'     }
#'   )
#'
#' # Multi-turn conversation prompt
#' pr %>%
#'   pr_mcp(transport = "stdio") %>%
#'   pr_mcp_prompt(
#'     name = "code-review",
#'     description = "Review R code for quality and best practices",
#'     arguments = list(
#'       list(name = "code", description = "The R code to review", required = TRUE)
#'     ),
#'     func = function(code) {
#'       list(
#'         list(
#'           role = "user",
#'           content = list(
#'             type = "text",
#'             text = paste("Please review this R code:", code, sep = "\n\n")
#'           )
#'         ),
#'         list(
#'           role = "assistant",
#'           content = list(
#'             type = "text",
#'             text = "I'll review your R code for:"
#'           )
#'         ),
#'         list(
#'           role = "user",
#'           content = list(
#'             type = "text",
#'             text = paste(
#'               "Focus on:",
#'               "1. Code correctness and logic",
#'               "2. R idioms and best practices",
#'               "3. Performance considerations",
#'               "4. Documentation and readability",
#'               sep = "\n"
#'             )
#'           )
#'         )
#'       )
#'     }
#'   )
#' }
pr_mcp_prompt <- function(pr, name, description, arguments = NULL, func) {
  validate_pr(pr)

  # Check if this router has MCP support in its environment
  env <- pr$environment
  if (is.null(env$mcp_prompts)) {
    env$mcp_prompts <- list()
  }

  # Validate arguments structure if provided
  if (!is.null(arguments)) {
    if (!is.list(arguments)) {
      stop("arguments must be a list")
    }

    # Validate each argument definition
    for (i in seq_along(arguments)) {
      arg <- arguments[[i]]
      if (!is.list(arg)) {
        stop("Each argument must be a list with 'name', 'description', and optionally 'required'")
      }
      if (is.null(arg$name)) {
        stop("Each argument must have a 'name' field")
      }
      if (is.null(arg$description)) {
        arguments[[i]]$description <- paste("Argument:", arg$name)
      }
      if (is.null(arg$required)) {
        arguments[[i]]$required <- FALSE
      }
    }
  }

  # Create prompt definition
  prompt <- list(
    name = name,
    description = description,
    arguments = arguments,
    func = func
  )

  # Add to router's prompts in its environment
  env$mcp_prompts[[name]] <- prompt

  invisible(pr)
}