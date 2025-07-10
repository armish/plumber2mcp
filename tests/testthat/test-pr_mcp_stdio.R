test_that("pr_mcp_stdio exists and is exported", {
  expect_true(exists("pr_mcp_stdio"))
  expect_true("pr_mcp_stdio" %in% getNamespaceExports("plumber2mcp"))
})

test_that("pr_mcp supports transport parameter", {
  pr <- plumber::pr()
  
  # HTTP transport returns modified router
  pr_http <- pr_mcp(pr, transport = "http")
  expect_s3_class(pr_http, "Plumber")
  
  # Unknown transport throws error
  expect_error(pr_mcp(pr, transport = "unknown"), "Unknown transport")
})

test_that("process_mcp_request handles basic requests", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() { list(msg = "test") })
  
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  
  # Test initialize
  init_request <- list(
    jsonrpc = "2.0",
    id = 1,
    method = "initialize",
    params = list()
  )
  
  response <- plumber2mcp:::process_mcp_request(
    init_request, tools, "test-server", "1.0.0", pr
  )
  
  expect_equal(response$jsonrpc, "2.0")
  expect_equal(response$id, 1)
  expect_equal(response$result$protocolVersion, "2024-11-05")
  expect_equal(response$result$serverInfo$name, "test-server")
  
  # Test tools/list
  list_request <- list(
    jsonrpc = "2.0",
    id = 2,
    method = "tools/list"
  )
  
  response <- plumber2mcp:::process_mcp_request(
    list_request, tools, "test-server", "1.0.0", pr
  )
  
  expect_equal(response$jsonrpc, "2.0")
  expect_equal(length(response$result$tools), 1)
  expect_equal(response$result$tools[[1]]$name, "GET__test")
})

test_that("stdio JSON serialization is correct", {
  # Test that empty tools capability serializes as object not array
  init_response <- plumber2mcp:::handle_initialize_stdio(
    list(id = 1), "test", "1.0.0"
  )
  
  # Serialize to JSON and check
  json <- jsonlite::toJSON(init_response, auto_unbox = TRUE)
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  
  # capabilities.tools should be an object (list with names), not array
  expect_true(is.list(parsed$result$capabilities$tools))
  expect_false(is.null(names(parsed$result$capabilities$tools)))
})

test_that("stdio tool calls work correctly", {
  pr <- plumber::pr()
  pr$handle("GET", "/echo", function(msg = "") { list(echo = msg) })
  
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  
  call_request <- list(
    jsonrpc = "2.0",
    id = 3,
    method = "tools/call",
    params = list(
      name = "GET__echo",
      arguments = list(msg = "hello")
    )
  )
  
  response <- plumber2mcp:::process_mcp_request(
    call_request, tools, "test-server", "1.0.0", pr
  )
  
  expect_equal(response$jsonrpc, "2.0")
  expect_equal(response$id, 3)
  expect_true("result" %in% names(response))
  expect_true("content" %in% names(response$result))
  expect_true(is.list(response$result$content))
  expect_equal(response$result$content[[1]]$type, "text")
  
  # Check the actual result
  result_json <- response$result$content[[1]]$text
  result_data <- jsonlite::fromJSON(result_json)
  expect_equal(result_data$echo, "hello")
})