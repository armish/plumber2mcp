#' @import plumber
#' @importFrom jsonlite toJSON
NULL

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
                   server_version = "0.1.0",
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
                        server_version = "0.1.0") {
  
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
    pr_post(paste0(path, "/messages"), mcp_handler$handle_message, serializer = serializer_json()) %>%
    pr_get(path, mcp_handler$server_info, serializer = serializer_json())
  
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
        "tools/list" = handle_tools_list(body, tools),
        "tools/call" = handle_tools_call(body, tools, pr),
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
        
        # Create tool definition
        tool <- list(
          name = endpoint_id,
          description = if (is.null(endpoint$comments)) paste("Endpoint:", verb, path) else endpoint$comments,
          inputSchema = create_input_schema(endpoint),
          endpoint = endpoint,
          verb = verb
        )
        
        tools[[endpoint_id]] <- tool
      }
    }
  }
  
  tools
}

#' Create input schema for an endpoint
#' @noRd
create_input_schema <- function(endpoint) {
  # Get function arguments
  func <- endpoint$getFunc()
  if (is.null(func)) {
    return(list(
      type = "object",
      properties = structure(list(), names = character(0)),
      required = character()
    ))
  }
  
  args <- names(formals(func))
  
  properties <- list()
  required <- character()
  
  # Extract parameters from function arguments
  for (arg_name in args) {
    if (arg_name %in% c("req", "res", "...")) next
    
    # Check if parameter has a default value (making it optional)
    default_val <- formals(func)[[arg_name]]
    is_optional <- !missing(default_val)
    
    # Try to get parameter description from comments
    param_desc <- paste("Parameter", arg_name)
    if (!is.null(endpoint$comments)) {
      # Parse roxygen-style comments for @param descriptions
      param_pattern <- paste0("@param\\s+", arg_name, "\\s+(.+)")
      matches <- regmatches(endpoint$comments, regexec(param_pattern, endpoint$comments))
      if (length(matches[[1]]) > 1) {
        param_desc <- matches[[1]][2]
      }
    }
    
    properties[[arg_name]] <- list(
      type = "string",  # Default to string, could be enhanced
      description = param_desc
    )
    
    if (!is_optional) {
      required <- c(required, arg_name)
    }
  }
  
  # Ensure properties is serialized as object, not array when empty
  if (length(properties) == 0) {
    properties <- structure(list(), names = character(0))
  }
  
  list(
    type = "object",
    properties = properties,
    required = required
  )
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
        tools = list()
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
        list(
          name = tool$name,
          description = tool$description,
          inputSchema = tool$inputSchema
        )
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