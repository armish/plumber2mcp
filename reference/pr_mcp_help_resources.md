# Add built-in R help resources to an MCP-enabled Plumber router

This convenience function adds resources for R documentation that AI
assistants can read to better understand R functions and packages.

## Usage

``` r
pr_mcp_help_resources(pr, topics = NULL)
```

## Arguments

- pr:

  A Plumber router object (must have MCP support added)

- topics:

  Character vector of help topics to expose (NULL for common topics)

## Examples

``` r
if (FALSE) { # \dontrun{
pr %>%
  pr_mcp(transport = "stdio") %>%
  pr_mcp_help_resources()
} # }
```
