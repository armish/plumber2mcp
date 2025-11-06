# Example: MCP Server with Prompts
#
# This example demonstrates how to add prompt templates to your MCP-enabled
# Plumber API. Prompts are reusable templates that AI assistants can discover
# and use to interact with your API.
#
# To run this example with stdio transport:
# Rscript -e "source('inst/examples/prompts_example.R')"

library(plumber)
library(plumber2mcp)

# Create a simple Plumber API
pr <- pr() %>%
  # Add a simple endpoint
  pr_get("/data", function() {
    list(
      datasets = c("mtcars", "iris", "airquality"),
      description = "Available R datasets"
    )
  })

# Add MCP support with prompts
pr <- pr %>%
  pr_mcp(transport = "stdio") %>%

  # Simple prompt with no arguments
  pr_mcp_prompt(
    name = "r-help",
    description = "Get help with R programming",
    func = function() {
      paste(
        "I need help with R programming.",
        "Please provide guidance on:",
        "1. Understanding R syntax and data structures",
        "2. Working with common R packages",
        "3. Best practices for R code",
        "4. Debugging R code",
        sep = "\n"
      )
    }
  ) %>%

  # Prompt with required argument
  pr_mcp_prompt(
    name = "analyze-dataset",
    description = "Generate a comprehensive analysis plan for an R dataset",
    arguments = list(
      list(
        name = "dataset",
        description = "Name of the R dataset to analyze (e.g., 'mtcars', 'iris')",
        required = TRUE
      )
    ),
    func = function(dataset) {
      sprintf(
        paste(
          "Please analyze the %s dataset in R. Provide:",
          "",
          "1. **Summary Statistics**",
          "   - Use summary() to get basic statistics",
          "   - Identify the data types of each variable",
          "   - Check for missing values",
          "",
          "2. **Data Structure**",
          "   - Number of observations and variables",
          "   - Variable names and their meanings",
          "",
          "3. **Exploratory Analysis**",
          "   - Distribution of key variables",
          "   - Relationships between variables",
          "   - Any interesting patterns or outliers",
          "",
          "4. **Visualization Recommendations**",
          "   - Suggest appropriate plots",
          "   - Provide ggplot2 code examples",
          "",
          "5. **Further Analysis**",
          "   - Recommended statistical tests",
          "   - Potential modeling approaches",
          sep = "\n"
        ),
        dataset
      )
    }
  ) %>%

  # Prompt with multiple arguments (some optional)
  pr_mcp_prompt(
    name = "code-review",
    description = "Review R code for quality, performance, and best practices",
    arguments = list(
      list(
        name = "code",
        description = "The R code to review",
        required = TRUE
      ),
      list(
        name = "focus",
        description = "Specific aspect to focus on: 'performance', 'style', 'correctness', or 'all'",
        required = FALSE
      )
    ),
    func = function(code, focus = "all") {
      intro <- paste("Please review this R code:", code, sep = "\n\n")

      if (focus == "performance") {
        criteria <- paste(
          "Focus on performance optimization:",
          "- Vectorization opportunities",
          "- Efficient data structure usage",
          "- Memory efficiency",
          "- Computational complexity",
          sep = "\n"
        )
      } else if (focus == "style") {
        criteria <- paste(
          "Focus on code style and readability:",
          "- Naming conventions",
          "- Code organization",
          "- Comments and documentation",
          "- Adherence to tidyverse style guide",
          sep = "\n"
        )
      } else if (focus == "correctness") {
        criteria <- paste(
          "Focus on correctness:",
          "- Logic errors",
          "- Edge cases",
          "- Error handling",
          "- Type safety",
          sep = "\n"
        )
      } else {
        criteria <- paste(
          "Provide a comprehensive review covering:",
          "1. Correctness - Logic and edge cases",
          "2. Performance - Efficiency opportunities",
          "3. Style - Readability and conventions",
          "4. Best Practices - R idioms and patterns",
          sep = "\n"
        )
      }

      paste(intro, "", criteria, sep = "\n")
    }
  ) %>%

  # Multi-turn conversation prompt
  pr_mcp_prompt(
    name = "debug-help",
    description = "Get interactive help debugging R code errors",
    arguments = list(
      list(
        name = "error_message",
        description = "The error message you're seeing",
        required = TRUE
      ),
      list(
        name = "code_context",
        description = "The code that's producing the error",
        required = FALSE
      )
    ),
    func = function(error_message, code_context = NULL) {
      messages <- list()

      # Initial message from user
      if (!is.null(code_context) && nchar(code_context) > 0) {
        messages[[1]] <- list(
          role = "user",
          content = list(
            type = "text",
            text = sprintf(
              "I'm getting this error in R:\n\n%s\n\nHere's the code:\n\n%s",
              error_message,
              code_context
            )
          )
        )
      } else {
        messages[[1]] <- list(
          role = "user",
          content = list(
            type = "text",
            text = sprintf("I'm getting this error in R:\n\n%s", error_message)
          )
        )
      }

      # Assistant's structured response approach
      messages[[2]] <- list(
        role = "assistant",
        content = list(
          type = "text",
          text = "I'll help you debug this error. Let me analyze:"
        )
      )

      # Follow-up prompt guiding the debugging process
      messages[[3]] <- list(
        role = "user",
        content = list(
          type = "text",
          text = paste(
            "Please help me by:",
            "1. Explaining what this error means",
            "2. Identifying the likely cause",
            "3. Suggesting how to fix it",
            "4. Providing a corrected code example if applicable",
            "5. Recommending how to avoid this error in the future",
            sep = "\n"
          )
        )
      )

      messages
    }
  ) %>%

  # Domain-specific prompt
  pr_mcp_prompt(
    name = "statistical-test",
    description = "Guide for choosing and implementing appropriate statistical tests",
    arguments = list(
      list(
        name = "research_question",
        description = "The research question or hypothesis to test",
        required = TRUE
      ),
      list(
        name = "data_description",
        description = "Description of the data (types, sample size, etc.)",
        required = FALSE
      )
    ),
    func = function(research_question, data_description = NULL) {
      base_prompt <- sprintf(
        "Research Question: %s\n\nHelp me:",
        research_question
      )

      criteria <- paste(
        "1. Choose the appropriate statistical test",
        "2. Verify the test assumptions",
        "3. Implement the test in R",
        "4. Interpret the results",
        "5. Report the findings appropriately",
        sep = "\n"
      )

      if (!is.null(data_description) && nchar(data_description) > 0) {
        data_context <- sprintf("\n\nData Description: %s", data_description)
        paste(base_prompt, data_context, "\n", criteria, sep = "\n")
      } else {
        paste(base_prompt, "\n", criteria, sep = "\n")
      }
    }
  )

# Note: The server will start when you run this file
# For HTTP transport, use pr_run(port = 8000) at the end
