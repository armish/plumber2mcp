test_that("default values with c() are correctly evaluated", {
  # Create a plumber router with a function that has c() defaults
  pr <- plumber::pr()
  pr$handle(
    "POST",
    "/normalize",
    function(
      symbols,
      return_fields = c("symbol", "name", "hgnc_id")
    ) {
      list(symbols = symbols, fields = return_fields)
    }
  )

  # Extract tools
  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)

  # Get the normalize tool
  normalize_tool <- tools[["POST__normalize"]]

  # Check that inputSchema exists
  expect_true("inputSchema" %in% names(normalize_tool))

  # Check the return_fields parameter
  schema <- normalize_tool$inputSchema
  expect_true("return_fields" %in% names(schema$properties))

  return_fields_prop <- schema$properties$return_fields

  # The type should be inferred as array (since it's a vector)
  expect_equal(return_fields_prop$type, "array")

  # The default should be a list (JSON array) without "c" as first element
  expect_true("default" %in% names(return_fields_prop))
  default_val <- return_fields_prop$default

  # Should be a list/vector
  expect_true(is.list(default_val) || is.vector(default_val))

  # Should have 3 elements
  expect_equal(length(default_val), 3)

  # Should NOT start with "c"
  expect_false(default_val[[1]] == "c")

  # Should contain the actual values
  expect_true("symbol" %in% default_val)
  expect_true("name" %in% default_val)
  expect_true("hgnc_id" %in% default_val)
})

test_that("default values with empty vectors are handled correctly", {
  pr <- plumber::pr()
  pr$handle(
    "GET",
    "/test",
    function(
      items = character(0)
    ) {
      list(items = items)
    }
  )

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  test_tool <- tools[["GET__test"]]

  schema <- test_tool$inputSchema
  items_prop <- schema$properties$items

  # Type should be inferred correctly
  expect_true(items_prop$type %in% c("array", "string"))

  # Default should be empty list or NULL, not contain "character"
  if (!is.null(items_prop$default)) {
    expect_true(length(items_prop$default) == 0)
    if (length(items_prop$default) > 0) {
      expect_false(items_prop$default[[1]] == "character")
    }
  }
})

test_that("default values with list() are correctly evaluated", {
  pr <- plumber::pr()
  pr$handle(
    "POST",
    "/config",
    function(
      options = list(verbose = TRUE, timeout = 30)
    ) {
      list(options = options)
    }
  )

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  config_tool <- tools[["POST__config"]]

  schema <- config_tool$inputSchema
  options_prop <- schema$properties$options

  # Should have a default
  expect_true("default" %in% names(options_prop))

  # Default should not start with "list"
  default_val <- options_prop$default
  if (is.list(default_val) && length(default_val) > 0) {
    expect_false(names(default_val)[1] == "list")
  }
})

test_that("simple default values still work correctly", {
  pr <- plumber::pr()
  pr$handle(
    "GET",
    "/greet",
    function(
      name = "World",
      count = 1L,
      excited = FALSE
    ) {
      list(name = name, count = count, excited = excited)
    }
  )

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  greet_tool <- tools[["GET__greet"]]

  schema <- greet_tool$inputSchema

  # String default
  expect_equal(schema$properties$name$default, "World")

  # Integer default
  expect_equal(schema$properties$count$default, 1L)

  # Boolean default
  expect_equal(schema$properties$excited$default, FALSE)
})

test_that("NULL defaults are handled correctly", {
  pr <- plumber::pr()
  pr$handle(
    "POST",
    "/optional",
    function(
      data = NULL
    ) {
      list(data = data)
    }
  )

  tools <- plumber2mcp:::extract_plumber_tools(pr, NULL, NULL)
  optional_tool <- tools[["POST__optional"]]

  schema <- optional_tool$inputSchema
  data_prop <- schema$properties$data

  # NULL default should result in NULL or absence of default
  if ("default" %in% names(data_prop)) {
    expect_null(data_prop$default)
  }
})

test_that("evaluate_default_value helper works correctly", {
  # Test with simple values
  expect_equal(
    plumber2mcp:::evaluate_default_value("test"),
    "test"
  )

  expect_equal(
    plumber2mcp:::evaluate_default_value(123),
    123
  )

  # Test with language objects
  expr <- quote(c("a", "b", "c"))
  result <- plumber2mcp:::evaluate_default_value(expr)
  expect_equal(result, c("a", "b", "c"))

  # Test with list
  expr <- quote(list(x = 1, y = 2))
  result <- plumber2mcp:::evaluate_default_value(expr)
  expect_equal(result, list(x = 1, y = 2))

  # Test with NULL
  expect_null(plumber2mcp:::evaluate_default_value(NULL))
})
