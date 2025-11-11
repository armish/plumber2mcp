# Add a resource to an MCP-enabled Plumber router

Resources allow AI assistants to read content from your R environment,
such as documentation, data files, analysis results, or any other
content you want to make available.

## Usage

``` r
pr_mcp_resource(
  pr,
  uri,
  func,
  name,
  description = NULL,
  mimeType = "text/plain"
)
```

## Arguments

- pr:

  A Plumber router object (must have MCP support added)

- uri:

  The URI pattern for the resource (e.g., "/help/topic")

- func:

  A function that returns the resource content

- name:

  A human-readable name for the resource

- description:

  A description of what the resource provides

- mimeType:

  The MIME type of the resource content (default: "text/plain")

## Examples

``` r
if (FALSE) { # \dontrun{
# Add a resource for R help topics
pr %>%
  pr_mcp(transport = "stdio") %>%
  pr_mcp_resource(
    uri = "/help/mean",
    func = function() capture.output(help("mean")),
    name = "R Help: mean function",
    description = "Documentation for the mean() function"
  )
} # }
```
