# Test enhanced schema functionality

test_that("create_enhanced_description generates rich descriptions", {
  # Create a simple test endpoint
  pr <- plumber::pr()
  pr %>% pr_get("/test", function() "test")
  
  # Get the endpoint
  endpoint <- pr$endpoints[["__no-preempt__"]][[1]]
  
  # Mock endpoint properties for testing
  endpoint$comments <- "Test endpoint"
  endpoint$description <- "This is a detailed description"
  endpoint$params <- list(
    list(desc = "Parameter 1", type = "string"),
    list(desc = "Parameter 2", type = "integer")
  )
  
  # Create enhanced description
  desc <- create_enhanced_description(endpoint, "GET", "/test")
  
  expect_type(desc, "character")
  expect_true(grepl("Test endpoint", desc))
  expect_true(grepl("This is a detailed description", desc))
  expect_true(grepl("HTTP Method: GET", desc))
  expect_true(grepl("Path: /test", desc))
})

test_that("create_input_schema generates proper JSON schemas", {
  # Create a test endpoint with parameters
  pr <- plumber::pr()
  pr %>% pr_post("/test", function(name, age = 25, active = TRUE) "test")
  
  # Get the endpoint
  endpoint <- pr$endpoints[["__no-preempt__"]][[1]]
  
  # Generate input schema
  schema <- create_input_schema(endpoint)
  
  expect_type(schema, "list")
  expect_equal(schema$type, "object")
  expect_type(schema$properties, "list")
  expect_type(schema$required, "character")
  
  # Check that parameters are included
  expect_true("name" %in% names(schema$properties))
  expect_true("age" %in% names(schema$properties))
  expect_true("active" %in% names(schema$properties))
  
  # Check required parameters
  expect_true("name" %in% schema$required)
  expect_false("age" %in% schema$required)
  expect_false("active" %in% schema$required)
  
  # Check default values
  expect_equal(schema$properties$age$default, 25)
  expect_equal(schema$properties$active$default, TRUE)
})

test_that("create_output_schema analyzes function returns", {
  # Create a test function that returns a list
  test_func <- function() {
    list(
      result = 42,
      status = "success",
      count = 10
    )
  }
  
  # Create endpoint with this function
  pr <- plumber::pr()
  pr %>% pr_get("/test", test_func)
  endpoint <- pr$endpoints[["__no-preempt__"]][[1]]
  
  # Generate output schema
  schema <- create_output_schema(endpoint)
  
  expect_type(schema, "list")
  expect_equal(schema$type, "object")
  expect_type(schema$properties, "list")
  
  # Check that return fields are detected
  expect_true("result" %in% names(schema$properties))
  expect_true("status" %in% names(schema$properties))
  expect_true("count" %in% names(schema$properties))
})

test_that("map_plumber_type_to_json_schema handles various types", {
  expect_equal(map_plumber_type_to_json_schema("string"), "string")
  expect_equal(map_plumber_type_to_json_schema("boolean"), "boolean")
  expect_equal(map_plumber_type_to_json_schema("integer"), "integer")
  expect_equal(map_plumber_type_to_json_schema("numeric"), "number")
  expect_equal(map_plumber_type_to_json_schema("logical"), "boolean")
  expect_equal(map_plumber_type_to_json_schema("character"), "string")
  expect_equal(map_plumber_type_to_json_schema("array"), "array")
  
  # Test unknown type with warning
  expect_warning(
    result <- map_plumber_type_to_json_schema("unknown"),
    "Unrecognized type: unknown"
  )
  expect_equal(result, "string")
})

test_that("infer_type_from_expression detects types correctly", {
  expect_equal(infer_type_from_expression("mean(x)"), "number")
  expect_equal(infer_type_from_expression("sum(data)"), "number")
  expect_equal(infer_type_from_expression("length(items)"), "number")
  expect_equal(infer_type_from_expression("round(value, 2)"), "number")
  expect_equal(infer_type_from_expression("min(data)"), "number")
  expect_equal(infer_type_from_expression("max(data)"), "number")
  
  expect_equal(infer_type_from_expression("paste(a, b)"), "string")
  expect_equal(infer_type_from_expression("as.character(x)"), "string")
  
  expect_equal(infer_type_from_expression("TRUE"), "boolean")
  expect_equal(infer_type_from_expression("FALSE"), "boolean")
  expect_equal(infer_type_from_expression("as.logical(x)"), "boolean")
  
  expect_equal(infer_type_from_expression("c(1, 2, 3)"), "array")
  expect_equal(infer_type_from_expression("list(a = 1)"), "array")
  
  # Test variable name inference
  expect_equal(infer_type_from_expression("count"), "number")
  expect_equal(infer_type_from_expression("operation"), "string")
  expect_equal(infer_type_from_expression("na_rm"), "boolean")
  
  # Default case
  expect_equal(infer_type_from_expression("unknown_expr"), "string")
})

test_that("extract_plumber_tools includes output schemas", {
  # Create test API
  pr <- plumber::pr()
  pr %>% pr_post("/calc", function(x, y = 1) list(result = x + y))
  
  # Extract tools
  tools <- extract_plumber_tools(pr, NULL, NULL)
  
  expect_type(tools, "list")
  expect_true(length(tools) > 0)
  
  # Check first tool
  tool <- tools[[1]]
  expect_true("name" %in% names(tool))
  expect_true("description" %in% names(tool))
  expect_true("inputSchema" %in% names(tool))
  expect_true("outputSchema" %in% names(tool))
  
  # Verify output schema structure
  expect_equal(tool$outputSchema$type, "object")
  expect_type(tool$outputSchema$properties, "list")
})

test_that("enhanced schemas work with complex roxygen documentation", {
  # Create a temporary test file with complex roxygen
  temp_file <- tempfile(fileext = ".R")
  writeLines(c(
    "#* Complex calculation endpoint",
    "#* ",
    "#* This endpoint performs complex mathematical operations",
    "#* with detailed parameter validation and error handling.",
    "#* ",
    "#* @param numbers:array Numeric array of input values",
    "#* @param operation:string Mathematical operation to perform",
    "#* @param precision:int Number of decimal places (default: 2)",
    "#* @param validate:bool Whether to validate inputs (default: TRUE)",
    "#* @return Complex result object with statistics",
    "#* @post /complex",
    "function(numbers, operation, precision = 2, validate = TRUE) {",
    "  list(",
    "    computed_value = 42.5,",
    "    operation_used = operation,",
    "    precision_applied = precision,",
    "    validation_passed = validate,",
    "    item_count = length(numbers)",
    "  )",
    "}"
  ), temp_file)
  
  # Load the API
  pr <- plumber::pr(temp_file)
  tools <- extract_plumber_tools(pr, NULL, NULL)
  
  expect_true(length(tools) > 0)
  
  tool <- tools[[1]]
  
  # Check enhanced description
  expect_true(grepl("Complex calculation endpoint", tool$description))
  expect_true(grepl("complex mathematical operations", tool$description))
  expect_true(grepl("Parameters:", tool$description))
  expect_true(grepl("HTTP Method: POST", tool$description))
  
  # Check input schema
  expect_equal(tool$inputSchema$type, "object")
  expect_true("numbers" %in% names(tool$inputSchema$properties))
  expect_true("operation" %in% names(tool$inputSchema$properties))
  expect_true("precision" %in% names(tool$inputSchema$properties))
  expect_true("validate" %in% names(tool$inputSchema$properties))
  
  # Check required vs optional parameters
  expect_true("numbers" %in% tool$inputSchema$required)
  expect_true("operation" %in% tool$inputSchema$required)
  expect_false("precision" %in% tool$inputSchema$required)
  expect_false("validate" %in% tool$inputSchema$required)
  
  # Check default values
  expect_equal(tool$inputSchema$properties$precision$default, 2)
  expect_equal(tool$inputSchema$properties$validate$default, TRUE)
  
  # Check output schema
  expect_equal(tool$outputSchema$type, "object")
  output_props <- names(tool$outputSchema$properties)
  expect_true("computed_value" %in% output_props)
  expect_true("operation_used" %in% output_props)
  expect_true("precision_applied" %in% output_props)
  expect_true("validation_passed" %in% output_props)
  expect_true("item_count" %in% output_props)
  
  # Clean up
  unlink(temp_file)
})