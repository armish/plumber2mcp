test_that("pr_mcp_prompt adds prompts to router environment", {
  pr <- plumber::pr()

  # Add MCP support
  pr <- pr_mcp_http(pr)

  # Add a simple prompt
  pr <- pr_mcp_prompt(
    pr,
    name = "test-prompt",
    description = "A test prompt",
    func = function() "Test message"
  )

  # Check that prompt was added
  expect_true("mcp_prompts" %in% names(pr$environment))
  expect_true("test-prompt" %in% names(pr$environment$mcp_prompts))
  expect_equal(pr$environment$mcp_prompts[["test-prompt"]]$name, "test-prompt")
  expect_equal(
    pr$environment$mcp_prompts[["test-prompt"]]$description,
    "A test prompt"
  )
})

test_that("pr_mcp_prompt validates argument structure", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  # Valid arguments should work
  expect_silent({
    pr_mcp_prompt(
      pr,
      name = "test",
      description = "Test",
      arguments = list(
        list(name = "arg1", description = "First argument", required = TRUE)
      ),
      func = function(arg1) arg1
    )
  })

  # Invalid arguments structure should error
  expect_error(
    {
      pr_mcp_prompt(
        pr,
        name = "test2",
        description = "Test",
        arguments = "not a list",
        func = function() "test"
      )
    },
    "arguments must be a list"
  )

  # Argument without name should error
  expect_error(
    {
      pr_mcp_prompt(
        pr,
        name = "test3",
        description = "Test",
        arguments = list(list(description = "No name")),
        func = function() "test"
      )
    },
    "must have a 'name' field"
  )
})

test_that("prompts/list returns all prompts", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  # Add multiple prompts
  pr <- pr %>%
    pr_mcp_prompt(
      name = "prompt1",
      description = "First prompt",
      func = function() "Message 1"
    ) %>%
    pr_mcp_prompt(
      name = "prompt2",
      description = "Second prompt",
      arguments = list(
        list(name = "arg1", description = "An argument", required = TRUE)
      ),
      func = function(arg1) paste("Message:", arg1)
    )

  # Test prompts/list
  request <- list(
    jsonrpc = "2.0",
    id = 1,
    method = "prompts/list"
  )

  result <- handle_prompts_list(request, pr)

  expect_equal(result$jsonrpc, "2.0")
  expect_equal(result$id, 1)
  expect_true("result" %in% names(result))
  expect_true("prompts" %in% names(result$result))
  expect_equal(length(result$result$prompts), 2)

  # Check first prompt
  prompt1 <- result$result$prompts[[1]]
  expect_equal(prompt1$name, "prompt1")
  expect_equal(prompt1$description, "First prompt")

  # Check second prompt has arguments
  prompt2 <- result$result$prompts[[2]]
  expect_equal(prompt2$name, "prompt2")
  expect_true("arguments" %in% names(prompt2))
  expect_equal(length(prompt2$arguments), 1)
  expect_equal(prompt2$arguments[[1]]$name, "arg1")
})

test_that("prompts/get executes prompt function with simple string", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  pr <- pr_mcp_prompt(
    pr,
    name = "test-prompt",
    description = "Test prompt",
    func = function() "Hello World"
  )

  request <- list(
    jsonrpc = "2.0",
    id = 2,
    method = "prompts/get",
    params = list(
      name = "test-prompt"
    )
  )

  result <- handle_prompts_get(request, pr)

  expect_equal(result$jsonrpc, "2.0")
  expect_equal(result$id, 2)
  expect_true("result" %in% names(result))
  expect_equal(result$result$description, "Test prompt")
  expect_true("messages" %in% names(result$result))
  expect_equal(length(result$result$messages), 1)

  # Check message was normalized to proper structure
  msg <- result$result$messages[[1]]
  expect_equal(msg$role, "user")
  expect_equal(msg$content$type, "text")
  expect_equal(msg$content$text, "Hello World")
})

test_that("prompts/get executes prompt function with arguments", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  pr <- pr_mcp_prompt(
    pr,
    name = "greet",
    description = "Greeting prompt",
    arguments = list(
      list(name = "name", description = "Name to greet", required = TRUE)
    ),
    func = function(name) {
      paste("Hello", name)
    }
  )

  request <- list(
    jsonrpc = "2.0",
    id = 3,
    method = "prompts/get",
    params = list(
      name = "greet",
      arguments = list(name = "Alice")
    )
  )

  result <- handle_prompts_get(request, pr)

  expect_true("result" %in% names(result))
  expect_equal(result$result$messages[[1]]$content$text, "Hello Alice")
})

test_that("prompts/get handles structured message format", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  pr <- pr_mcp_prompt(
    pr,
    name = "structured",
    description = "Structured prompt",
    func = function() {
      list(
        list(
          role = "user",
          content = list(type = "text", text = "First message")
        ),
        list(
          role = "assistant",
          content = list(type = "text", text = "Second message")
        )
      )
    }
  )

  request <- list(
    jsonrpc = "2.0",
    id = 4,
    method = "prompts/get",
    params = list(name = "structured")
  )

  result <- handle_prompts_get(request, pr)

  expect_equal(length(result$result$messages), 2)
  expect_equal(result$result$messages[[1]]$role, "user")
  expect_equal(result$result$messages[[1]]$content$text, "First message")
  expect_equal(result$result$messages[[2]]$role, "assistant")
  expect_equal(result$result$messages[[2]]$content$text, "Second message")
})

test_that("prompts/get returns error for unknown prompt", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  request <- list(
    jsonrpc = "2.0",
    id = 5,
    method = "prompts/get",
    params = list(name = "nonexistent")
  )

  result <- handle_prompts_get(request, pr)

  expect_true("error" %in% names(result))
  expect_equal(result$error$code, -32602)
  expect_match(result$error$message, "Unknown prompt")
})

test_that("prompts/get handles function errors gracefully", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  pr <- pr_mcp_prompt(
    pr,
    name = "error-prompt",
    description = "Prompt that errors",
    func = function() {
      stop("Intentional error")
    }
  )

  request <- list(
    jsonrpc = "2.0",
    id = 6,
    method = "prompts/get",
    params = list(name = "error-prompt")
  )

  result <- handle_prompts_get(request, pr)

  expect_true("error" %in% names(result))
  expect_equal(result$error$code, -32603)
  expect_equal(result$error$message, "Internal error")
})

test_that("initialize includes prompts capability", {
  request <- list(
    jsonrpc = "2.0",
    id = 1,
    method = "initialize",
    params = list(
      protocolVersion = "2025-06-18",
      capabilities = list(),
      clientInfo = list(name = "test", version = "1.0")
    )
  )

  result <- handle_initialize(request, "test-server", "1.0.0")

  expect_true("capabilities" %in% names(result$result))
  expect_true("prompts" %in% names(result$result$capabilities))
})

test_that("stdio transport supports prompts", {
  pr <- plumber::pr()
  pr <- pr_mcp_http(pr)

  pr <- pr_mcp_prompt(
    pr,
    name = "stdio-test",
    description = "Test for stdio",
    func = function() "Test message"
  )

  prompts <- pr$environment$mcp_prompts

  # Test stdio prompts/list handler
  request <- list(
    jsonrpc = "2.0",
    id = 1,
    method = "prompts/list"
  )

  result <- handle_prompts_list_stdio(request, prompts)

  expect_equal(result$jsonrpc, "2.0")
  expect_equal(length(result$result$prompts), 1)
  expect_equal(result$result$prompts[[1]]$name, "stdio-test")

  # Test stdio prompts/get handler
  request2 <- list(
    jsonrpc = "2.0",
    id = 2,
    method = "prompts/get",
    params = list(name = "stdio-test")
  )

  result2 <- handle_prompts_get_stdio(request2, prompts)

  expect_true("result" %in% names(result2))
  expect_equal(result2$result$messages[[1]]$content$text, "Test message")
})
