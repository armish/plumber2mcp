#' @import plumber
#' @importFrom jsonlite toJSON
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
                   server_version = "0.2.0",
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
                        server_version = "0.2.0") {
  
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

#' Add a resource to an MCP-enabled Plumber router
#'
#' Resources allow AI assistants to read content from your R environment,
#' such as documentation, data files, analysis results, or any other content
#' you want to make available.
#'
#' @param pr A Plumber router object (must have MCP support added)
#' @param uri The URI pattern for the resource (e.g., "/help/{topic}")
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
      
      # Create a temporary file to capture clean text output
      temp_file <- tempfile(fileext = ".txt")
      on.exit(unlink(temp_file))
      
      # Get the raw Rd content and convert to plain text file
      rd_file <- utils:::.getHelpFile(help_file[1])
      tools::Rd2txt(rd_file, out = temp_file)
      
      # Read the clean text from file
      if (file.exists(temp_file)) {
        clean_text <- readLines(temp_file, warn = FALSE)
        
        # Clean up any remaining underscore formatting
        clean_text <- gsub("_([^_])_", "\\1", clean_text)
        clean_text <- gsub("_", "", clean_text)
        
        return(clean_text)
      } else {
        return(paste("Error: Could not generate help text for", current_topic))
      }
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