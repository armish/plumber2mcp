test_that("pr_mcp_resource exists and is exported", {
  expect_true(exists("pr_mcp_resource"))
  expect_true("pr_mcp_resource" %in% getNamespaceExports("plumber2mcp"))
})

test_that("pr_mcp_help_resources exists and is exported", {
  expect_true(exists("pr_mcp_help_resources"))
  expect_true("pr_mcp_help_resources" %in% getNamespaceExports("plumber2mcp"))
})

test_that("pr_mcp_resource adds resource to router", {
  pr <- plumber::pr()
  
  # Add a simple resource
  pr <- pr_mcp_resource(
    pr, 
    uri = "/test/resource",
    func = function() "test content",
    name = "Test Resource"
  )
  
  # Check that resource was added to environment
  expect_true("mcp_resources" %in% names(pr$environment))
  expect_equal(length(pr$environment$mcp_resources), 1)
  expect_equal(pr$environment$mcp_resources[["/test/resource"]]$name, "Test Resource")
})

test_that("resources capability is included in server info", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() list(msg = "test"))
  
  init_request <- list(
    jsonrpc = "2.0",
    id = 1,
    method = "initialize",
    params = list()
  )
  
  # Test that capabilities include resources
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  resources <- list()
  
  response <- plumber2mcp:::process_mcp_request(
    init_request, tools, resources, list(), "test-server", "1.0.0", pr
  )
  
  expect_equal(response$jsonrpc, "2.0")
  expect_equal(response$id, 1)
  expect_true("resources" %in% names(response$result$capabilities))
})

test_that("resources/list returns empty list when no resources", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() list(msg = "test"))
  
  list_request <- list(
    jsonrpc = "2.0",
    id = 2,
    method = "resources/list"
  )
  
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  resources <- list()
  
  response <- plumber2mcp:::process_mcp_request(
    list_request, tools, resources, list(), "test-server", "1.0.0", pr
  )
  
  expect_equal(response$jsonrpc, "2.0")
  expect_equal(response$id, 2)
  expect_equal(length(response$result$resources), 0)
})

test_that("resources/list returns resource information", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() list(msg = "test"))
  
  # Add a resource
  pr <- pr_mcp_resource(
    pr,
    uri = "/test/resource",
    func = function() "test content",
    name = "Test Resource",
    description = "A test resource"
  )
  
  list_request <- list(
    jsonrpc = "2.0",
    id = 2,
    method = "resources/list"
  )
  
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  resources <- pr$environment$mcp_resources
  
  response <- plumber2mcp:::process_mcp_request(
    list_request, tools, resources, list(), "test-server", "1.0.0", pr
  )
  
  expect_equal(response$jsonrpc, "2.0")
  expect_equal(response$id, 2)
  expect_equal(length(response$result$resources), 1)
  
  resource <- response$result$resources[[1]]
  expect_equal(resource$uri, "/test/resource")
  expect_equal(resource$name, "Test Resource")
  expect_equal(resource$description, "A test resource")
  expect_equal(resource$mimeType, "text/plain")
})

test_that("resources/read returns resource content", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() list(msg = "test"))
  
  # Add a resource
  pr <- pr_mcp_resource(
    pr,
    uri = "/test/resource",
    func = function() "Hello from resource",
    name = "Test Resource"
  )
  
  read_request <- list(
    jsonrpc = "2.0",
    id = 3,
    method = "resources/read",
    params = list(uri = "/test/resource")
  )
  
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  resources <- pr$environment$mcp_resources
  
  response <- plumber2mcp:::process_mcp_request(
    read_request, tools, resources, list(), "test-server", "1.0.0", pr
  )
  
  expect_equal(response$jsonrpc, "2.0")
  expect_equal(response$id, 3)
  expect_true("contents" %in% names(response$result))
  
  content <- response$result$contents[[1]]
  expect_equal(content$uri, "/test/resource")
  expect_equal(content$mimeType, "text/plain")
  expect_equal(content$text, "Hello from resource")
})

test_that("resources/read returns error for unknown resource", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() list(msg = "test"))
  
  read_request <- list(
    jsonrpc = "2.0",
    id = 3,
    method = "resources/read",
    params = list(uri = "/unknown/resource")
  )
  
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  resources <- list()
  
  response <- plumber2mcp:::process_mcp_request(
    read_request, tools, resources, list(), "test-server", "1.0.0", pr
  )
  
  expect_equal(response$jsonrpc, "2.0")
  expect_equal(response$id, 3)
  expect_true("error" %in% names(response))
  expect_equal(response$error$code, -32602)
})

test_that("pr_mcp_help_resources adds default help topics", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() list(msg = "test"))
  
  # Add help resources
  pr <- pr_mcp_help_resources(pr)
  
  # Should have 8 help topics + 2 system resources (session-info, packages)
  expect_equal(length(pr$environment$mcp_resources), 10)
  
  # Check that specific help resources exist
  expect_true("/help/mean" %in% names(pr$environment$mcp_resources))
  expect_true("/help/lm" %in% names(pr$environment$mcp_resources))
  expect_true("/r/session-info" %in% names(pr$environment$mcp_resources))
  expect_true("/r/packages" %in% names(pr$environment$mcp_resources))
})

test_that("pr_mcp_help_resources works with custom topics", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() list(msg = "test"))
  
  # Add help resources with custom topics
  pr <- pr_mcp_help_resources(pr, topics = c("mean", "sum"))
  
  # Should have 2 help topics + 2 system resources
  expect_equal(length(pr$environment$mcp_resources), 4)
  
  # Check that specific help resources exist
  expect_true("/help/mean" %in% names(pr$environment$mcp_resources))
  expect_true("/help/sum" %in% names(pr$environment$mcp_resources))
  expect_false("/help/lm" %in% names(pr$environment$mcp_resources))
})

test_that("help resource content is readable", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() list(msg = "test"))
  
  # Add help resources
  pr <- pr_mcp_help_resources(pr, topics = c("mean"))
  
  # Get the help resource function
  help_func <- pr$environment$mcp_resources[["/help/mean"]]$func
  
  # Execute it
  content <- help_func()
  
  # Should be character and non-empty
  expect_true(is.character(content))
  expect_true(length(content) > 0)
  expect_true(any(grepl("mean", content, ignore.case = TRUE)))
})

test_that("session info resource works", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() list(msg = "test"))
  
  # Add help resources
  pr <- pr_mcp_help_resources(pr, topics = c())
  
  # Get the session info resource function
  session_func <- pr$environment$mcp_resources[["/r/session-info"]]$func
  
  # Execute it
  content <- session_func()
  
  # Should contain R version info
  expect_true(is.character(content))
  expect_true(length(content) > 0)
  expect_true(any(grepl("R version", content)))
})