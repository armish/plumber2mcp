# Add a prompt template to an MCP-enabled Plumber router

Prompts are reusable templates that AI assistants can discover and use
to interact with your API. They provide structured messages with
optional arguments that can be filled in by the AI or user.

## Usage

``` r
pr_mcp_prompt(pr, name, description, arguments = NULL, func)
```

## Arguments

- pr:

  A Plumber router object (must have MCP support added)

- name:

  Unique identifier for the prompt (e.g., "code-review", "analyze-data")

- description:

  Human-readable description of what the prompt does

- arguments:

  Optional list of argument definitions. Each argument should be a list
  with:

  - `name`: The argument name

  - `description`: What the argument is for

  - `required`: Boolean indicating if the argument is required (default:
    FALSE)

- func:

  A function that generates prompt messages. The function should:

  - Accept arguments matching those defined in the arguments parameter

  - Return either a character vector, a list of messages, or a single
    message

  - Each message can be either a string (treated as user message) or a
    list with `role` and `content`

## Examples

``` r
if (FALSE) { # \dontrun{
# Simple prompt with no arguments
pr %>%
  pr_mcp(transport = "stdio") %>%
  pr_mcp_prompt(
    name = "greeting",
    description = "Generate a friendly greeting",
    func = function() {
      "Hello! How can I help you with R today?"
    }
  )

# Prompt with arguments
pr %>%
  pr_mcp(transport = "stdio") %>%
  pr_mcp_prompt(
    name = "analyze-dataset",
    description = "Guide for analyzing a dataset",
    arguments = list(
      list(name = "dataset", description = "Name of the dataset to analyze", required = TRUE),
      list(name = "focus", description = "Specific aspect to focus on", required = FALSE)
    ),
    func = function(dataset, focus = "general") {
      if (focus == "general") {
        msg <- sprintf(
          paste(
            "Please analyze the %s dataset. Provide:",
            "1. Summary statistics",
            "2. Data quality assessment",
            "3. Interesting patterns or relationships",
            "4. Recommendations for further analysis",
            sep = "\n"
          ),
          dataset
        )
      } else {
        msg <- sprintf(
          "Please analyze the %s dataset with a focus on: %s",
          dataset, focus
        )
      }

      # Return as a structured message
      list(
        role = "user",
        content = list(type = "text", text = msg)
      )
    }
  )

# Multi-turn conversation prompt
pr %>%
  pr_mcp(transport = "stdio") %>%
  pr_mcp_prompt(
    name = "code-review",
    description = "Review R code for quality and best practices",
    arguments = list(
      list(name = "code", description = "The R code to review", required = TRUE)
    ),
    func = function(code) {
      list(
        list(
          role = "user",
          content = list(
            type = "text",
            text = paste("Please review this R code:", code, sep = "\n\n")
          )
        ),
        list(
          role = "assistant",
          content = list(
            type = "text",
            text = "I'll review your R code for:"
          )
        ),
        list(
          role = "user",
          content = list(
            type = "text",
            text = paste(
              "Focus on:",
              "1. Code correctness and logic",
              "2. R idioms and best practices",
              "3. Performance considerations",
              "4. Documentation and readability",
              sep = "\n"
            )
          )
        )
      )
    }
  )
} # }
```
