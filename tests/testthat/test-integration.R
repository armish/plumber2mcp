# Integration tests - combining tools, resources, and prompts

test_that("full MCP server with tools, resources, and prompts works together", {
  # Create comprehensive API
  pr <- plumber::pr()

  # Add endpoints (tools)
  pr$handle("GET", "/status", function() list(status = "running"))
  pr$handle("POST", "/process", function(data) list(processed = toupper(data)))

  # Add MCP support
  pr <- pr_mcp_http(pr)

  # Add resources
  pr <- pr_mcp_resource(
    pr,
    uri = "/docs/api",
    func = function() "API Documentation here",
    name = "API Docs"
  )

  # Add prompts
  pr <- pr_mcp_prompt(
    pr,
    name = "help",
    description = "Get help",
    func = function() "How can I help?"
  )

  # Create handler
  handler <- plumber2mcp:::create_mcp_handler(pr, NULL, NULL, "test", "1.0")

  # Test initialize
  init_response <- handler$handle_message(
    list(body = list(jsonrpc = "2.0", id = 1, method = "initialize")),
    list()
  )

  expect_equal(init_response$result$protocolVersion, "2024-11-05")
  expect_true("tools" %in% names(init_response$result$capabilities))
  expect_true("resources" %in% names(init_response$result$capabilities))
  expect_true("prompts" %in% names(init_response$result$capabilities))

  # Test tools/list
  tools_response <- handler$handle_message(
    list(body = list(jsonrpc = "2.0", id = 2, method = "tools/list")),
    list()
  )

  tool_names <- sapply(tools_response$result$tools, function(t) t$name)
  expect_true("GET__status" %in% tool_names)
  expect_true("POST__process" %in% tool_names)

  # Test resources/list
  resources_response <- handler$handle_message(
    list(body = list(jsonrpc = "2.0", id = 3, method = "resources/list")),
    list()
  )

  resource_uris <- sapply(resources_response$result$resources, function(r) {
    r$uri
  })
  expect_true("/docs/api" %in% resource_uris)

  # Test prompts/list
  prompts_response <- handler$handle_message(
    list(body = list(jsonrpc = "2.0", id = 4, method = "prompts/list")),
    list()
  )

  prompt_names <- sapply(prompts_response$result$prompts, function(p) p$name)
  expect_true("help" %in% prompt_names)

  # Test actual tool call
  call_response <- handler$handle_message(
    list(
      body = list(
        jsonrpc = "2.0",
        id = 5,
        method = "tools/call",
        params = list(
          name = "POST__process",
          arguments = list(data = "hello")
        )
      )
    ),
    list()
  )

  expect_true("result" %in% names(call_response))
  result_data <- jsonlite::fromJSON(call_response$result$content[[1]]$text)
  expect_equal(result_data$processed, "HELLO")

  # Test actual resource read
  read_response <- handler$handle_message(
    list(
      body = list(
        jsonrpc = "2.0",
        id = 6,
        method = "resources/read",
        params = list(uri = "/docs/api")
      )
    ),
    list()
  )

  expect_equal(
    read_response$result$contents[[1]]$text,
    "API Documentation here"
  )

  # Test actual prompt get
  prompt_response <- handler$handle_message(
    list(
      body = list(
        jsonrpc = "2.0",
        id = 7,
        method = "prompts/get",
        params = list(name = "help")
      )
    ),
    list()
  )

  expect_equal(
    prompt_response$result$messages[[1]]$content$text,
    "How can I help?"
  )
})

test_that("HTTP and stdio transports have feature parity", {
  # Create same API for both transports
  create_test_api <- function() {
    pr <- plumber::pr()
    pr$handle("GET", "/test", function(x = 1) list(value = x))
    pr
  }

  # For fair comparison, extract tools BEFORE adding MCP endpoints
  pr_http <- create_test_api()
  pr_stdio <- create_test_api()

  # Extract tools from both (before MCP is added, so they're identical)
  tools_http <- plumber2mcp:::extract_plumber_tools(pr_http, NULL, NULL)
  tools_stdio <- plumber2mcp:::extract_plumber_tools(pr_stdio, NULL, NULL)

  # Should extract same tools
  expect_equal(names(tools_http), names(tools_stdio))
  expect_equal(tools_http[[1]]$name, tools_stdio[[1]]$name)

  # Test initialize response is same
  http_init <- plumber2mcp:::handle_initialize(
    list(id = 1, jsonrpc = "2.0"),
    "test",
    "1.0"
  )

  stdio_init <- plumber2mcp:::handle_initialize_stdio(
    list(id = 1, jsonrpc = "2.0"),
    "test",
    "1.0"
  )

  expect_equal(
    http_init$result$protocolVersion,
    stdio_init$result$protocolVersion
  )
  expect_equal(
    names(http_init$result$capabilities),
    names(stdio_init$result$capabilities)
  )

  # Test tools/list is same
  http_list <- plumber2mcp:::handle_tools_list(list(id = 1), tools_http)
  stdio_list <- plumber2mcp:::handle_tools_list_stdio(list(id = 1), tools_stdio)

  expect_equal(length(http_list$result$tools), length(stdio_list$result$tools))
})

test_that("chaining pr_mcp functions works correctly", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() "ok")

  # Chain all the functions
  pr_complete <- pr %>%
    pr_mcp_http() %>%
    pr_mcp_resource(
      uri = "/resource1",
      func = function() "r1",
      name = "R1"
    ) %>%
    pr_mcp_resource(
      uri = "/resource2",
      func = function() "r2",
      name = "R2"
    ) %>%
    pr_mcp_prompt(
      name = "prompt1",
      description = "P1",
      func = function() "p1"
    ) %>%
    pr_mcp_prompt(
      name = "prompt2",
      description = "P2",
      func = function() "p2"
    )

  # Verify all were added
  expect_equal(length(pr_complete$environment$mcp_resources), 2)
  expect_equal(length(pr_complete$environment$mcp_prompts), 2)

  # Verify chain didn't break functionality
  handler <- plumber2mcp:::create_mcp_handler(
    pr_complete,
    NULL,
    NULL,
    "test",
    "1.0"
  )

  resources_response <- handler$handle_message(
    list(body = list(jsonrpc = "2.0", id = 1, method = "resources/list")),
    list()
  )

  expect_equal(length(resources_response$result$resources), 2)

  prompts_response <- handler$handle_message(
    list(body = list(jsonrpc = "2.0", id = 2, method = "prompts/list")),
    list()
  )

  expect_equal(length(prompts_response$result$prompts), 2)
})

test_that("tools with roxygen docs integrate with resources and prompts", {
  # Create temp file with well-documented endpoint
  temp_file <- tempfile(fileext = ".R")
  writeLines(
    c(
      "#* Calculate sum of numbers",
      "#* @param numbers:array Numeric values",
      "#* @post /sum",
      "function(numbers) {",
      "  list(sum = sum(as.numeric(numbers)))",
      "}"
    ),
    temp_file
  )

  pr <- plumber::pr(temp_file)
  pr <- pr_mcp_http(pr)

  # Add related resource
  pr <- pr_mcp_resource(
    pr,
    uri = "/docs/sum",
    func = function() {
      paste(
        "Sum Endpoint Documentation:",
        "Calculates the sum of an array of numbers",
        "Parameters: numbers (array of numeric values)",
        sep = "\n"
      )
    },
    name = "Sum Docs"
  )

  # Add related prompt
  pr <- pr_mcp_prompt(
    pr,
    name = "sum-help",
    description = "Help with sum endpoint",
    func = function() {
      "The /sum endpoint adds numbers together. Pass an array of numbers."
    }
  )

  # Extract everything
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  handler <- plumber2mcp:::create_mcp_handler(pr, NULL, NULL, "test", "1.0")

  # Verify tool has rich description
  expect_true(grepl("Calculate sum", tools[[1]]$description))

  # Verify resource provides docs
  resource_response <- handler$handle_message(
    list(
      body = list(
        jsonrpc = "2.0",
        id = 1,
        method = "resources/read",
        params = list(uri = "/docs/sum")
      )
    ),
    list()
  )

  expect_true(grepl(
    "Sum Endpoint",
    resource_response$result$contents[[1]]$text
  ))

  # Verify prompt provides guidance
  prompt_response <- handler$handle_message(
    list(
      body = list(
        jsonrpc = "2.0",
        id = 2,
        method = "prompts/get",
        params = list(name = "sum-help")
      )
    ),
    list()
  )

  expect_true(grepl(
    "/sum endpoint",
    prompt_response$result$messages[[1]]$content$text
  ))

  unlink(temp_file)
})

test_that("custom path works with all features", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() "ok")

  pr <- pr_mcp(pr, transport = "http", path = "/custom")
  pr <- pr_mcp_resource(pr, uri = "/r", func = function() "r", name = "R")
  pr <- pr_mcp_prompt(pr, name = "p", description = "P", func = function() "p")

  # Check that custom path was used
  all_paths <- unlist(lapply(pr$endpoints, function(group) {
    sapply(group, function(ep) ep$path)
  }))

  expect_true("/custom" %in% all_paths)
  expect_true("/custom/messages" %in% all_paths)
  expect_false("/mcp" %in% all_paths)
})

test_that("include/exclude filters work with full setup", {
  pr <- plumber::pr()
  pr$handle("GET", "/public1", function() "p1")
  pr$handle("GET", "/public2", function() "p2")
  pr$handle("GET", "/private", function() "priv")
  pr$handle("POST", "/admin", function() "admin")

  # Only include public endpoints
  pr <- pr_mcp(
    pr,
    transport = "http",
    include_endpoints = c("GET__public1", "GET__public2")
  )

  pr <- pr_mcp_resource(pr, uri = "/r", func = function() "r", name = "R")
  pr <- pr_mcp_prompt(pr, name = "p", description = "P", func = function() "p")

  handler <- plumber2mcp:::create_mcp_handler(
    pr,
    include_endpoints = c("GET__public1", "GET__public2"),
    exclude_endpoints = NULL,
    "test",
    "1.0"
  )

  # List tools
  tools_response <- handler$handle_message(
    list(body = list(jsonrpc = "2.0", id = 1, method = "tools/list")),
    list()
  )

  tool_names <- sapply(tools_response$result$tools, function(t) t$name)

  expect_true("GET__public1" %in% tool_names)
  expect_true("GET__public2" %in% tool_names)
  expect_false("GET__private" %in% tool_names)
  expect_false("POST__admin" %in% tool_names)

  # But resources and prompts should still work
  resources_response <- handler$handle_message(
    list(body = list(jsonrpc = "2.0", id = 2, method = "resources/list")),
    list()
  )

  expect_equal(length(resources_response$result$resources), 1)

  prompts_response <- handler$handle_message(
    list(body = list(jsonrpc = "2.0", id = 3, method = "prompts/list")),
    list()
  )

  expect_equal(length(prompts_response$result$prompts), 1)
})

test_that("multiple prompts with same arguments structure", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  # Add multiple prompts with similar args
  pr <- pr %>%
    pr_mcp_prompt(
      name = "analyze-mtcars",
      description = "Analyze mtcars dataset",
      arguments = list(
        list(name = "focus", description = "Analysis focus", required = FALSE)
      ),
      func = function(focus = "all") {
        sprintf("Analyze mtcars focusing on: %s", focus)
      }
    ) %>%
    pr_mcp_prompt(
      name = "analyze-iris",
      description = "Analyze iris dataset",
      arguments = list(
        list(name = "focus", description = "Analysis focus", required = FALSE)
      ),
      func = function(focus = "all") {
        sprintf("Analyze iris focusing on: %s", focus)
      }
    )

  # Both should work independently
  prompts <- pr$environment$mcp_prompts

  mtcars_response <- plumber2mcp:::handle_prompts_get(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(
        name = "analyze-mtcars",
        arguments = list(focus = "mpg")
      )
    ),
    pr
  )

  expect_true(grepl(
    "mtcars",
    mtcars_response$result$messages[[1]]$content$text
  ))
  expect_true(grepl("mpg", mtcars_response$result$messages[[1]]$content$text))

  iris_response <- plumber2mcp:::handle_prompts_get(
    list(
      jsonrpc = "2.0",
      id = 2,
      params = list(
        name = "analyze-iris",
        arguments = list(focus = "species")
      )
    ),
    pr
  )

  expect_true(grepl("iris", iris_response$result$messages[[1]]$content$text))
  expect_true(grepl("species", iris_response$result$messages[[1]]$content$text))
})

test_that("dynamic resource content works with tool results", {
  pr <- plumber::pr()

  # State to track last result
  last_result <- NULL

  # Tool that stores result
  pr$handle("POST", "/calc", function(x, y) {
    result <- as.numeric(x) + as.numeric(y)
    last_result <<- result
    list(result = result)
  })

  pr <- pr_mcp_http(pr)

  # Resource that shows last result
  pr <- pr_mcp_resource(
    pr,
    uri = "/last-result",
    func = function() {
      if (is.null(last_result)) {
        "No calculations yet"
      } else {
        sprintf("Last result: %s", last_result)
      }
    },
    name = "Last Result"
  )

  handler <- plumber2mcp:::create_mcp_handler(pr, NULL, NULL, "test", "1.0")

  # Check initial state
  resource_response1 <- handler$handle_message(
    list(
      body = list(
        jsonrpc = "2.0",
        id = 1,
        method = "resources/read",
        params = list(uri = "/last-result")
      )
    ),
    list()
  )

  expect_equal(
    resource_response1$result$contents[[1]]$text,
    "No calculations yet"
  )

  # Call tool
  handler$handle_message(
    list(
      body = list(
        jsonrpc = "2.0",
        id = 2,
        method = "tools/call",
        params = list(
          name = "POST__calc",
          arguments = list(x = 10, y = 5)
        )
      )
    ),
    list()
  )

  # Check updated state
  resource_response2 <- handler$handle_message(
    list(
      body = list(
        jsonrpc = "2.0",
        id = 3,
        method = "resources/read",
        params = list(uri = "/last-result")
      )
    ),
    list()
  )

  expect_match(resource_response2$result$contents[[1]]$text, "Last result: 15")
})
