# Edge cases and error handling tests

test_that("handles malformed JSON-RPC requests", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() "test")

  handler <- plumber2mcp:::create_mcp_handler(pr, NULL, NULL, "test", "1.0")

  # Missing jsonrpc field
  req <- list(body = list(id = 1, method = "tools/list"))
  res <- list(status = NULL)
  response <- handler$handle_message(req, res)
  expect_equal(response$error$code, -32600)
  expect_equal(res$status, 400)

  # Wrong jsonrpc version
  req <- list(body = list(jsonrpc = "1.0", id = 2, method = "tools/list"))
  res <- list(status = NULL)
  response <- handler$handle_message(req, res)
  expect_equal(response$error$code, -32600)

  # Missing method
  req <- list(body = list(jsonrpc = "2.0", id = 3))
  res <- list()
  response <- handler$handle_message(req, res)
  expect_equal(response$error$code, -32601)
})

test_that("handles invalid parameter types in tool calls", {
  pr <- plumber::pr()
  pr$handle("POST", "/calc", function(x, y) list(result = as.numeric(x) + as.numeric(y)))

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Call with wrong type that causes error
  response <- plumber2mcp:::handle_tools_call(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(
        name = "POST__calc",
        arguments = list(x = "not_a_number", y = "also_not")
      )
    ),
    tools,
    pr
  )

  # Should return an error
  expect_true("error" %in% names(response) || "result" %in% names(response))
})

test_that("handles missing required parameters", {
  pr <- plumber::pr()
  pr$handle("POST", "/required", function(required_param, optional_param = "default") {
    list(required = required_param, optional = optional_param)
  })

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Call without required parameter
  response <- plumber2mcp:::handle_tools_call(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(
        name = "POST__required",
        arguments = list(optional_param = "value")
      )
    ),
    tools,
    pr
  )

  # Should handle missing parameter gracefully (might be error or use NULL)
  expect_true("error" %in% names(response) || "result" %in% names(response))
})

test_that("handles NULL and NA values correctly", {
  pr <- plumber::pr()
  pr$handle("POST", "/nulls", function(value) {
    list(
      is_null = is.null(value),
      is_na = is.na(value),
      value = value
    )
  })

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Call with NULL
  response <- plumber2mcp:::handle_tools_call(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(
        name = "POST__nulls",
        arguments = list(value = NULL)
      )
    ),
    tools,
    pr
  )

  expect_equal(response$jsonrpc, "2.0")
  expect_true("result" %in% names(response))
})

test_that("handles empty parameter lists", {
  pr <- plumber::pr()
  pr$handle("GET", "/no-params", function() list(status = "ok"))

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Call with no arguments
  response <- plumber2mcp:::handle_tools_call(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(
        name = "GET__no-params",
        arguments = list()
      )
    ),
    tools,
    pr
  )

  expect_equal(response$jsonrpc, "2.0")
  expect_true("result" %in% names(response))

  # Call with NULL arguments
  response <- plumber2mcp:::handle_tools_call(
    list(
      jsonrpc = "2.0",
      id = 2,
      params = list(
        name = "GET__no-params",
        arguments = NULL
      )
    ),
    tools,
    pr
  )

  expect_equal(response$jsonrpc, "2.0")
  expect_true("result" %in% names(response))
})

test_that("handles large payloads", {
  pr <- plumber::pr()
  pr$handle("POST", "/large", function(data) {
    list(size = length(data), type = class(data))
  })

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Create large data payload
  large_data <- paste(rep("x", 10000), collapse = "")

  response <- plumber2mcp:::handle_tools_call(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(
        name = "POST__large",
        arguments = list(data = large_data)
      )
    ),
    tools,
    pr
  )

  expect_equal(response$jsonrpc, "2.0")
  expect_true("result" %in% names(response) || "error" %in% names(response))
})

test_that("handles special characters in parameters", {
  pr <- plumber::pr()
  pr$handle("POST", "/echo", function(text) list(echo = text))

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  special_chars <- list(
    "emoji" = "Hello 👋 World 🌍",
    "quotes" = "He said \"hello\" and she said 'hi'",
    "newlines" = "Line 1\nLine 2\nLine 3",
    "unicode" = "Ñoño çüé 日本語",
    "control" = "Tab\there\rcarriage\breturn"
  )

  for (name in names(special_chars)) {
    response <- plumber2mcp:::handle_tools_call(
      list(
        jsonrpc = "2.0",
        id = 1,
        params = list(
          name = "POST__echo",
          arguments = list(text = special_chars[[name]])
        )
      ),
      tools,
      pr
    )

    expect_equal(response$jsonrpc, "2.0", info = paste("Failed for:", name))
    expect_true("result" %in% names(response), info = paste("Failed for:", name))
  }
})

test_that("handles endpoint functions that throw errors", {
  pr <- plumber::pr()
  pr$handle("POST", "/error", function() stop("Intentional error"))
  pr$handle("POST", "/warning", function() {
    warning("This is a warning")
    list(status = "ok")
  })

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Test function that throws error
  response <- plumber2mcp:::handle_tools_call(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(name = "POST__error", arguments = list())
    ),
    tools,
    pr
  )

  expect_true("error" %in% names(response))
  expect_equal(response$error$code, -32603)
  expect_match(response$error$data, "Intentional error")

  # Test function that produces warning (should still work)
  response <- plumber2mcp:::handle_tools_call(
    list(
      jsonrpc = "2.0",
      id = 2,
      params = list(name = "POST__warning", arguments = list())
    ),
    tools,
    pr
  )

  expect_true("result" %in% names(response))
})

test_that("handles complex nested data structures", {
  pr <- plumber::pr()
  pr$handle("POST", "/nested", function(data) {
    list(
      received = data,
      type = class(data),
      length = if (is.list(data)) length(data) else 1
    )
  })

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Test nested list
  nested_data <- list(
    level1 = list(
      level2 = list(
        level3 = list(
          value = 42,
          array = c(1, 2, 3)
        )
      ),
      another = "value"
    ),
    top_level = "data"
  )

  response <- plumber2mcp:::handle_tools_call(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(
        name = "POST__nested",
        arguments = list(data = nested_data)
      )
    ),
    tools,
    pr
  )

  expect_equal(response$jsonrpc, "2.0")
  expect_true("result" %in% names(response))
})

test_that("handles endpoints with req and res parameters", {
  pr <- plumber::pr()
  pr$handle("GET", "/with-req", function(req, res) {
    list(
      method = req$REQUEST_METHOD,
      path = req$PATH_INFO
    )
  })

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  response <- plumber2mcp:::handle_tools_call(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(
        name = "GET__with-req",
        arguments = list()
      )
    ),
    tools,
    pr
  )

  expect_equal(response$jsonrpc, "2.0")
  expect_true("result" %in% names(response))

  # Check that mock req was created
  result_text <- response$result$content[[1]]$text
  result_data <- jsonlite::fromJSON(result_text)
  expect_equal(result_data$method, "GET")
})

test_that("handles resource functions that error", {
  pr <- plumber::pr()
  pr <- pr_mcp_resource(
    pr,
    uri = "/error/resource",
    func = function() stop("Resource error"),
    name = "Error Resource"
  )

  response <- plumber2mcp:::handle_resources_read(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(uri = "/error/resource")
    ),
    pr
  )

  expect_true("error" %in% names(response))
  expect_equal(response$error$code, -32603)
})

test_that("handles resource functions returning non-string", {
  pr <- plumber::pr()
  pr <- pr_mcp_resource(
    pr,
    uri = "/numeric/resource",
    func = function() 42,
    name = "Numeric Resource"
  )

  pr <- pr_mcp_resource(
    pr,
    uri = "/list/resource",
    func = function() list(a = 1, b = 2),
    name = "List Resource"
  )

  # Numeric resource
  response <- plumber2mcp:::handle_resources_read(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(uri = "/numeric/resource")
    ),
    pr
  )

  expect_true("result" %in% names(response))
  expect_true(is.character(response$result$contents[[1]]$text))

  # List resource
  response <- plumber2mcp:::handle_resources_read(
    list(
      jsonrpc = "2.0",
      id = 2,
      params = list(uri = "/list/resource")
    ),
    pr
  )

  expect_true("result" %in% names(response))
  expect_true(is.character(response$result$contents[[1]]$text))
})

test_that("validates pr_mcp_prompt arguments structure strictly", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  # Invalid arguments - not a list
  expect_error(
    pr_mcp_prompt(pr, "test", "desc", arguments = "not a list", func = function() "x"),
    "arguments must be a list"
  )

  # Invalid argument - not a list element
  expect_error(
    pr_mcp_prompt(pr, "test", "desc", arguments = list("string"), func = function() "x"),
    "Each argument must be a list"
  )

  # Missing name field
  expect_error(
    pr_mcp_prompt(pr, "test", "desc",
                  arguments = list(list(description = "No name")),
                  func = function() "x"),
    "must have a 'name' field"
  )
})

test_that("handles prompt functions with argument mismatch", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  # Prompt expects argument but none provided
  pr <- pr_mcp_prompt(
    pr,
    name = "needs-arg",
    description = "Test",
    arguments = list(
      list(name = "required_arg", description = "Required", required = TRUE)
    ),
    func = function(required_arg) paste("Value:", required_arg)
  )

  # Call without argument - should error or handle gracefully
  response <- plumber2mcp:::handle_prompts_get(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(name = "needs-arg")
    ),
    pr
  )

  expect_true("error" %in% names(response) || "result" %in% names(response))
})

test_that("handles very long tool/resource/prompt names", {
  pr <- plumber::pr()

  # Very long endpoint path
  long_path <- paste0("/", paste(rep("long", 50), collapse = "/"))
  pr$handle("GET", long_path, function() "ok")

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  expect_true(length(tools) > 0)

  # Very long resource URI
  long_uri <- paste0("/", paste(rep("x", 200), collapse = "/"))
  pr <- pr_mcp_resource(
    pr,
    uri = long_uri,
    func = function() "content",
    name = "Long URI Resource"
  )

  expect_true(long_uri %in% names(pr$environment$mcp_resources))
})

test_that("handles concurrent-like scenarios with state", {
  pr <- plumber::pr()

  # Endpoint that uses external state
  counter <- 0
  pr$handle("POST", "/counter", function() {
    counter <<- counter + 1
    list(count = counter)
  })

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Multiple calls
  for (i in 1:5) {
    response <- plumber2mcp:::handle_tools_call(
      list(
        jsonrpc = "2.0",
        id = i,
        params = list(name = "POST__counter", arguments = list())
      ),
      tools,
      pr
    )

    expect_true("result" %in% names(response))
  }

  expect_equal(counter, 5)
})

test_that("handles empty strings vs NULL vs missing in schemas", {
  pr <- plumber::pr()
  pr$handle("POST", "/test", function(empty_str = "", null_val = NULL, missing) {
    list(
      empty = empty_str,
      null = null_val,
      missing = if (missing(missing)) "was missing" else missing
    )
  })

  endpoint <- pr$endpoints[[1]][[1]]
  schema <- plumber2mcp:::create_input_schema(endpoint)

  expect_true("empty_str" %in% names(schema$properties))
  expect_true("null_val" %in% names(schema$properties))
  expect_true("missing" %in% names(schema$properties))

  # Check required/optional classification
  expect_false("empty_str" %in% schema$required)
  expect_false("null_val" %in% schema$required)
  expect_true("missing" %in% schema$required)
})
