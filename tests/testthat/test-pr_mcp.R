test_that("pr_mcp adds MCP endpoints to plumber router", {
  # Create a simple plumber router
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() {
    list(msg = "test")
  })

  # Add MCP support
  pr_with_mcp <- pr_mcp(pr, transport = "http")

  # Check that MCP endpoints were added by looking at all paths
  all_paths <- unlist(lapply(pr_with_mcp$endpoints, function(group) {
    sapply(group, function(ep) ep$path)
  }))

  expect_true("/mcp" %in% all_paths)
  expect_true("/mcp/messages" %in% all_paths)
})

test_that("pr_mcp validates input is plumber router", {
  expect_error(
    pr_mcp("not a router", transport = "http"),
    "Input must be a Plumber router object"
  )
  expect_error(
    pr_mcp(list(), transport = "http"),
    "Input must be a Plumber router object"
  )
  expect_error(
    pr_mcp(NULL, transport = "http"),
    "Input must be a Plumber router object"
  )
})

test_that("pr_mcp requires transport parameter", {
  pr <- plumber::pr()
  expect_error(
    pr_mcp(pr),
    "Transport parameter is required. Choose 'http' or 'stdio'."
  )
})

test_that("pr_mcp validates transport parameter", {
  pr <- plumber::pr()
  expect_error(
    pr_mcp(pr, transport = "invalid"),
    "Unknown transport: 'invalid'. Must be 'http' or 'stdio'."
  )
  expect_error(
    pr_mcp(pr, transport = ""),
    "Unknown transport: ''. Must be 'http' or 'stdio'."
  )
})

test_that("pr_mcp accepts custom path", {
  pr <- plumber::pr()
  pr_with_mcp <- pr_mcp(pr, transport = "http", path = "/custom-mcp")

  all_paths <- unlist(lapply(pr_with_mcp$endpoints, function(group) {
    sapply(group, function(ep) ep$path)
  }))

  expect_true("/custom-mcp" %in% all_paths)
  expect_true("/custom-mcp/messages" %in% all_paths)
})

test_that("pr_mcp accepts custom server info", {
  pr <- plumber::pr()
  pr_with_mcp <- pr_mcp(
    pr,
    transport = "http",
    server_name = "test-server",
    server_version = "2.0.0"
  )

  # Find the server info endpoint
  server_info_endpoint <- NULL
  for (group in pr_with_mcp$endpoints) {
    for (ep in group) {
      if (ep$path == "/mcp") {
        server_info_endpoint <- ep
        break
      }
    }
  }

  # Get the server info function through the handler
  handler <- plumber2mcp:::create_mcp_handler(
    pr,
    NULL,
    NULL,
    "test-server",
    "2.0.0"
  )
  info <- handler$server_info()

  expect_equal(info$name, "test-server")
  expect_equal(info$version, "2.0.0")
  expect_equal(info$protocol_version, "2024-11-05")
})

test_that("extract_plumber_tools extracts endpoints correctly", {
  pr <- plumber::pr()
  pr$handle("GET", "/echo", function(msg = "") {
    list(message = msg)
  })
  pr$handle("POST", "/add", function(a, b) {
    list(sum = a + b)
  })

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  expect_true("GET__echo" %in% names(tools))
  expect_true("POST__add" %in% names(tools))

  # Check tool structure
  echo_tool <- tools[["GET__echo"]]
  expect_equal(echo_tool$name, "GET__echo")
  expect_equal(echo_tool$verb, "GET")
  expect_true("inputSchema" %in% names(echo_tool))
})

test_that("extract_plumber_tools respects include/exclude filters", {
  pr <- plumber::pr()
  pr$handle("GET", "/public", function() {
    "public"
  })
  pr$handle("GET", "/private", function() {
    "private"
  })
  pr$handle("POST", "/admin", function() {
    "admin"
  })

  # Test include filter
  tools_include <- plumber2mcp:::extract_plumber_tools(
    pr,
    include_endpoints = c("GET__public", "POST__admin"),
    exclude_endpoints = NULL
  )
  expect_true("GET__public" %in% names(tools_include))
  expect_true("POST__admin" %in% names(tools_include))
  expect_false("GET__private" %in% names(tools_include))

  # Test exclude filter
  tools_exclude <- plumber2mcp:::extract_plumber_tools(
    pr,
    include_endpoints = NULL,
    exclude_endpoints = c("GET__private")
  )
  expect_true("GET__public" %in% names(tools_exclude))
  expect_true("POST__admin" %in% names(tools_exclude))
  expect_false("GET__private" %in% names(tools_exclude))
})

test_that("create_input_schema creates correct schema", {
  # Create a real plumber endpoint
  pr <- plumber::pr()
  pr$handle(
    "GET",
    "/test",
    function(required_param, optional_param = "default") {}
  )

  # Get the endpoint
  endpoint <- pr$endpoints[[1]][[1]]

  schema <- plumber2mcp:::create_input_schema(endpoint)

  expect_equal(schema$type, "object")
  expect_true("required_param" %in% names(schema$properties))
  expect_true("optional_param" %in% names(schema$properties))
  expect_true("required_param" %in% schema$required)
  expect_false("optional_param" %in% schema$required)
})

test_that("handle_initialize returns correct response", {
  response <- plumber2mcp:::handle_initialize(
    list(id = 1, jsonrpc = "2.0"),
    "test-server",
    "1.0.0"
  )

  expect_equal(response$jsonrpc, "2.0")
  expect_equal(response$id, 1)
  expect_equal(response$result$protocolVersion, "2024-11-05")
  expect_equal(response$result$serverInfo$name, "test-server")
  expect_equal(response$result$serverInfo$version, "1.0.0")
})

test_that("handle_tools_list returns tool list", {
  tools <- list(
    test_tool = list(
      name = "test_tool",
      description = "A test tool",
      inputSchema = list(type = "object", properties = list())
    )
  )

  response <- plumber2mcp:::handle_tools_list(
    list(id = 2, jsonrpc = "2.0"),
    tools
  )

  expect_equal(response$jsonrpc, "2.0")
  expect_equal(response$id, 2)
  expect_equal(length(response$result$tools), 1)
  expect_equal(response$result$tools[[1]]$name, "test_tool")
})

test_that("handle_tools_call executes tool correctly", {
  # Create a real plumber endpoint
  pr <- plumber::pr()
  pr$handle("POST", "/add", function(x, y) {
    list(result = as.numeric(x) + as.numeric(y))
  })

  # Get the endpoint
  endpoint <- pr$endpoints[[1]][[1]]

  tools <- list(
    POST__add = list(
      name = "POST__add",
      endpoint = endpoint,
      verb = "POST"
    )
  )

  response <- plumber2mcp:::handle_tools_call(
    list(
      id = 3,
      jsonrpc = "2.0",
      params = list(
        name = "POST__add",
        arguments = list(x = 5, y = 3)
      )
    ),
    tools,
    pr
  )

  expect_equal(response$jsonrpc, "2.0")
  expect_equal(response$id, 3)
  expect_true("result" %in% names(response))

  # Parse the JSON result
  result_text <- response$result$content[[1]]$text
  result_data <- jsonlite::fromJSON(result_text)
  expect_equal(result_data$result, 8)
})

test_that("handle_tools_call returns error for unknown tool", {
  response <- plumber2mcp:::handle_tools_call(
    list(
      id = 4,
      jsonrpc = "2.0",
      params = list(name = "unknown_tool", arguments = list())
    ),
    list(),
    NULL
  )

  expect_equal(response$jsonrpc, "2.0")
  expect_equal(response$id, 4)
  expect_true("error" %in% names(response))
  expect_equal(response$error$code, -32602)
})

test_that("MCP handler processes JSON-RPC requests correctly", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() {
    "test"
  })

  handler <- plumber2mcp:::create_mcp_handler(
    pr,
    NULL,
    NULL,
    "test-server",
    "1.0.0"
  )

  # Test invalid JSON-RPC
  req <- list(body = list(method = "test"))
  res <- list(status = NULL)
  response <- handler$handle_message(req, res)
  expect_equal(response$error$code, -32600)
  # Note: In the actual code, res$status is set to 400 when jsonrpc is missing

  # Test unknown method
  req <- list(body = list(jsonrpc = "2.0", id = 1, method = "unknown"))
  res <- list()
  response <- handler$handle_message(req, res)
  expect_equal(response$error$code, -32601)
})

test_that("Integration: Full MCP workflow works", {
  # Create a plumber API with endpoints
  pr <- plumber::pr()
  pr$handle("GET", "/echo", function(msg = "hello") {
    list(echo = msg)
  })
  pr$handle("POST", "/multiply", function(a, b) {
    list(result = as.numeric(a) * as.numeric(b))
  })

  # Add MCP support
  pr_with_mcp <- pr_mcp(pr, transport = "http")

  # Get the MCP handler directly
  handler <- plumber2mcp:::create_mcp_handler(
    pr,
    NULL,
    NULL,
    "plumber-mcp",
    "0.1.0"
  )

  # Test initialize
  req <- list(
    body = list(
      jsonrpc = "2.0",
      id = 1,
      method = "initialize"
    )
  )
  res <- list()
  init_response <- handler$handle_message(req, res)
  expect_equal(init_response$result$protocolVersion, "2024-11-05")

  # Test tools/list
  req <- list(
    body = list(
      jsonrpc = "2.0",
      id = 2,
      method = "tools/list"
    )
  )
  list_response <- handler$handle_message(req, res)
  tool_names <- sapply(list_response$result$tools, function(t) t$name)
  expect_true("GET__echo" %in% tool_names)
  expect_true("POST__multiply" %in% tool_names)

  # Test tools/call
  req <- list(
    body = list(
      jsonrpc = "2.0",
      id = 3,
      method = "tools/call",
      params = list(
        name = "POST__multiply",
        arguments = list(a = 4, b = 5)
      )
    )
  )
  call_response <- handler$handle_message(req, res)

  result_text <- call_response$result$content[[1]]$text
  result_data <- jsonlite::fromJSON(result_text)
  expect_equal(result_data$result, 20)
})

test_that("empty properties serializes as object not array", {
  pr <- plumber::pr()
  # Function with no parameters
  pr$handle("GET", "/no-params", function() {
    list(msg = "no params")
  })
  # Function with parameters
  pr$handle("POST", "/with-params", function(a, b) {
    list(result = a + b)
  })

  tools <- extract_plumber_tools(pr, NULL, NULL)

  # Test that function with no parameters has properties as object
  no_params_tool <- tools[["GET__no-params"]]
  expect_true(is.list(no_params_tool$inputSchema$properties))
  expect_equal(length(no_params_tool$inputSchema$properties), 0)

  # Test JSON serialization - properties should be object, not array
  json <- jsonlite::toJSON(no_params_tool$inputSchema, auto_unbox = TRUE)
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_true(is.list(parsed$properties))
  expect_false(is.null(names(parsed$properties)))

  # Test that function with parameters works normally
  with_params_tool <- tools[["POST__with-params"]]
  expect_true(length(with_params_tool$inputSchema$properties) > 0)
})
