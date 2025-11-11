test_that("description is always a string, never an array", {
  # Create a simple endpoint
  pr <- plumber::pr()
  pr$handle("GET", "/test", function() {
    list(msg = "test")
  })

  # Extract tools
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Check that description exists and is a single string
  expect_true(length(tools) > 0)
  tool <- tools[[1]]

  expect_true("description" %in% names(tool))
  expect_type(tool$description, "character")
  expect_length(tool$description, 1)
})

test_that("description with multiple comments sources returns single string", {
  # This simulates the case where endpoint has multiple documentation sources
  # We'll manually create an endpoint object with array comments/description

  pr <- plumber::pr()

  # Create a test function
  test_func <- function(x = "test") {
    list(result = x)
  }

  pr$handle("POST", "/multi", test_func)

  # Get the endpoint
  endpoint <- pr$endpoints[[1]][[1]]

  # Simulate multiple documentation sources by setting comments as array
  # This is what happens when plumber collects docs from multiple places
  endpoint$comments <- c(
    "First documentation source",
    "Second documentation source"
  )
  endpoint$description <- c(
    "First detailed description",
    "Second detailed description"
  )

  # Create enhanced description
  desc <- plumber2mcp:::create_enhanced_description(
    endpoint,
    "POST",
    "/multi"
  )

  # Must be a single string
  expect_type(desc, "character")
  expect_length(desc, 1)

  # Should not contain both descriptions as separate elements
  # It should have prioritized the first one
  expect_true(grepl("First documentation source", desc))
})

test_that("empty or NULL descriptions are handled correctly", {
  pr <- plumber::pr()
  pr$handle("GET", "/empty", function() {
    list(msg = "test")
  })

  # Get endpoint and clear its documentation
  endpoint <- pr$endpoints[[1]][[1]]
  endpoint$comments <- NULL
  endpoint$description <- NULL

  # Create description
  desc <- plumber2mcp:::create_enhanced_description(endpoint, "GET", "/empty")

  # Should be a string (fallback)
  expect_type(desc, "character")
  expect_length(desc, 1)
  expect_true(grepl("Endpoint:", desc))
})

test_that("description with NA values is handled correctly", {
  pr <- plumber::pr()
  pr$handle("POST", "/na", function() {
    list(msg = "test")
  })

  endpoint <- pr$endpoints[[1]][[1]]
  endpoint$comments <- c(NA, "Valid comment")
  endpoint$description <- c("Valid description", NA)

  desc <- plumber2mcp:::create_enhanced_description(endpoint, "POST", "/na")

  # Should be a single string
  expect_type(desc, "character")
  expect_length(desc, 1)

  # Should contain the valid content
  expect_true(grepl("Valid comment", desc))
})

test_that("full tool schema has string description", {
  # Create endpoint with potential multiple doc sources
  pr <- plumber::pr()

  # Add a function that might have roxygen docs
  pr$handle(
    "POST",
    "/normalize",
    function(
      symbols,
      fields = c("symbol", "name")
    ) {
      list(symbols = symbols, fields = fields)
    }
  )

  # Extract tools
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Verify the tool schema
  tool <- tools[["POST__normalize"]]

  # Description must be a single string
  expect_type(tool$description, "character")
  expect_length(tool$description, 1)

  # When serialized to JSON, it should be a string
  json <- jsonlite::toJSON(
    list(description = tool$description),
    auto_unbox = TRUE
  )
  parsed <- jsonlite::fromJSON(json)

  expect_type(parsed$description, "character")
  expect_length(parsed$description, 1)
})

test_that("tools/list response has string descriptions", {
  pr <- plumber::pr()
  pr$handle("GET", "/test1", function() "test1")
  pr$handle("POST", "/test2", function() "test2")

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Simulate tools/list response
  response <- plumber2mcp:::handle_tools_list(
    list(id = 1, jsonrpc = "2.0"),
    tools
  )

  # Check each tool in the response
  for (tool in response$result$tools) {
    expect_type(tool$description, "character")
    expect_length(tool$description, 1)
  }

  # Verify JSON serialization
  json <- jsonlite::toJSON(response, auto_unbox = TRUE)
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  for (tool in parsed$result$tools) {
    # In JSON, description should be a string, not an array
    expect_type(tool$description, "character")
  }
})
