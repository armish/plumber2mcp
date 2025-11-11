# plumber2mcp vs mcptools: Feature Comparison & Improvement Plan

## Executive Summary

After analyzing the competitive package `mcptools`
(<https://posit-dev.github.io/mcptools/>), we’ve identified several
feature gaps that, if addressed, would make plumber2mcp more competitive
and feature-complete. This document outlines the key differences and
provides a prioritized roadmap for improvements.

## Feature Comparison

### Current plumber2mcp Features ✓

- **MCP Server** (HTTP & stdio transports)
- **Tools**: Auto-convert Plumber endpoints to MCP tools
- **Resources**: Expose R documentation, data, and analysis results
- **Prompts**: Reusable prompt templates
- **Rich Schema Generation**: Enhanced input/output schemas from roxygen
  comments
- **Security-focused**: Only exposes pre-defined Plumber endpoints

### mcptools Features

#### Present in mcptools, Missing in plumber2mcp ⚠️

1.  **MCP Client Capability** 🔴 HIGH PRIORITY
    - mcptools can act as an MCP client to connect to third-party MCP
      servers
    - Allows integration of external tools (GitHub, Confluence, Google
      Drive, etc.)
    - Works with ellmer library for chat integration
    - plumber2mcp currently only acts as a server
2.  **Built-in Environment Inspection Tools** 🟡 MEDIUM PRIORITY
    - mcptools integrates with the `btw` package providing:
      - Package documentation browsing (dynamic)
      - Global environment object inspection
      - Session and platform metadata retrieval
    - plumber2mcp has
      [`pr_mcp_help_resources()`](https://armish.github.io/plumber2mcp/reference/pr_mcp_help_resources.md)
      but it’s limited and requires manual topic specification
3.  **Session Management** 🟡 MEDIUM PRIORITY
    - mcptools has `mcp_session()` for managing R sessions
    - Routes requests to active R sessions
    - plumber2mcp doesn’t have session management concepts
4.  **Chat Library Integration** 🟢 LOW PRIORITY
    - mcptools integrates with shinychat, querychat, and ellmer
    - plumber2mcp is standalone (not necessarily a gap - different
      design goals)

#### Design Differences (Not Gaps)

5.  **Arbitrary R Code Execution**
    - mcptools can execute any R code in running sessions
    - plumber2mcp only exposes pre-defined Plumber endpoints
    - This is intentional: plumber2mcp prioritizes security and
      controlled API exposure
    - **Recommendation**: Keep this difference - it’s a feature, not a
      bug

## Improvement Roadmap

### Phase 1: MCP Client Support (HIGH PRIORITY) 🔴

**Goal**: Enable plumber2mcp to act as an MCP client, allowing Plumber
APIs to integrate external MCP servers as tools.

**New Functions**:

``` r
# Register an external MCP server
pr_mcp_client_add(
  pr,
  server_name = "github",
  config = list(
    command = "npx",
    args = c("-y", "@modelcontextprotocol/server-github"),
    env = list(GITHUB_TOKEN = Sys.getenv("GITHUB_TOKEN"))
  )
)

# List registered MCP clients
pr_mcp_clients(pr)

# Call a tool from a registered MCP client
pr_mcp_client_call(
  pr,
  server = "github",
  tool = "search_repositories",
  arguments = list(query = "plumber")
)
```

**Use Cases**: - Plumber API endpoints can call GitHub/Confluence/Drive
MCP servers - AI assistants can orchestrate between your Plumber API and
external services - Combine local R computations with external data
sources

**Implementation Considerations**: - Store client configurations in
`pr$environment$mcp_clients` - Implement JSON-RPC client to communicate
with external MCP servers - Handle stdio and HTTP transports for
external servers - Proper error handling and timeout management -
Optional: Create helper functions for common MCP servers (GitHub,
filesystem, etc.)

**Estimated Effort**: 2-3 weeks

------------------------------------------------------------------------

### Phase 2: Enhanced Built-in Tools (MEDIUM PRIORITY) 🟡

**Goal**: Provide a comprehensive set of built-in tools for environment
inspection, similar to the `btw` package.

**New Functions**:

``` r
# Add all built-in inspection tools at once
pr_mcp_builtin_tools(
  pr,
  include = c("env", "packages", "help", "session", "objects", "search")
)

# Or add them individually:

# List objects in global environment
pr_mcp_tool_env_objects(pr)
# Tool: GET__mcp_env_objects
# Returns: list of objects with names, classes, sizes

# Inspect a specific object
pr_mcp_tool_env_inspect(pr)
# Tool: GET__mcp_env_inspect?name=mydata
# Returns: str() output, summary(), dimensions, etc.

# Browse package documentation dynamically
pr_mcp_tool_pkg_help(pr)
# Tool: GET__mcp_pkg_help?topic=mean&package=base
# Returns: formatted help text

# Search for functions across packages
pr_mcp_tool_pkg_search(pr)
# Tool: GET__mcp_pkg_search?pattern=linear
# Returns: matching functions with packages

# Get comprehensive session info
pr_mcp_tool_session_info(pr)
# Tool: GET__mcp_session_info
# Returns: R version, platform, loaded packages, capabilities

# Get workspace metadata
pr_mcp_tool_workspace_info(pr)
# Tool: GET__mcp_workspace_info
# Returns: memory usage, object counts, search path
```

**Benefits**: - AI assistants can explore the R environment
dynamically - Better understanding of available packages and functions -
Self-documenting APIs - AI can discover capabilities on-the-fly -
Reduces manual resource definition

**Implementation Considerations**: - These should be optional (opt-in
via `pr_mcp_builtin_tools()`) - Respect security: only expose global
environment, not internal plumber state - Provide filtering options
(e.g., exclude certain objects) - Cache expensive operations where
appropriate - Format output in AI-friendly markdown

**Estimated Effort**: 2 weeks

------------------------------------------------------------------------

### Phase 3: Advanced Resource Templates (MEDIUM PRIORITY) 🟡

**Goal**: Support URI templates for dynamic resources, as mentioned in
MCP spec but not yet implemented.

**New Capability**:

``` r
# Define a resource template with URI parameters
pr_mcp_resource_template(
  pr,
  uri_template = "/help/{topic}",
  func = function(topic) {
    # topic is extracted from URI
    capture.output(help(topic))
  },
  name = "R Help for Any Topic",
  description = "Get R documentation for any help topic"
)

# Example template for datasets
pr_mcp_resource_template(
  pr,
  uri_template = "/data/{dataset}/summary",
  func = function(dataset) {
    data <- get(dataset, envir = .GlobalEnv)
    capture.output(summary(data))
  },
  name = "Dataset Summary",
  description = "Get summary statistics for any dataset in the environment"
)
```

**Benefits**: - More flexible resource exposure - Reduce boilerplate for
similar resources - Better align with MCP specification - AI can
construct URIs dynamically

**Implementation Considerations**: - Implement URI template parsing (RFC
6570) - Add to `handle_resources_templates()` - Support in both HTTP and
stdio transports - Validate parameters before executing functions

**Estimated Effort**: 1 week

------------------------------------------------------------------------

### Phase 4: Performance & Scalability (MEDIUM PRIORITY) 🟡

**Goal**: Improve performance for large-scale deployments.

**Improvements**:

1.  **Caching Layer**

``` r
pr_mcp(
  pr,
  transport = "http",
  cache = list(
    tools = TRUE,           # Cache tools list
    resources = TRUE,       # Cache resource responses
    ttl = 300,             # Cache TTL in seconds
    max_size = "100MB"     # Max cache size
  )
)
```

2.  **Async Tool Execution**

``` r
# Allow long-running tools to execute asynchronously
pr_mcp_tool_async(pr, "/long-computation", timeout = 300)
```

3.  **Rate Limiting**

``` r
pr_mcp(
  pr,
  transport = "http",
  rate_limit = list(
    requests_per_minute = 60,
    per_tool_limit = TRUE
  )
)
```

4.  **Streaming Responses**

``` r
# Support streaming for large resources
pr_mcp_resource(
  pr,
  uri = "/data/large-dataset",
  func = function() { ... },
  streaming = TRUE
)
```

**Estimated Effort**: 2-3 weeks

------------------------------------------------------------------------

### Phase 5: Enhanced Documentation & Discovery (LOW PRIORITY) 🟢

**Goal**: Make it easier for AI assistants to understand and use the
API.

**Improvements**:

1.  **OpenAPI/Swagger Integration**

``` r
pr_mcp(
  pr,
  transport = "http",
  openapi = TRUE,  # Auto-generate OpenAPI spec from MCP tools
  openapi_path = "/openapi.json"
)
```

2.  **Enhanced Tool Categorization**

``` r
pr_mcp_tool_category(
  pr,
  category = "data-analysis",
  tools = c("POST__analyze", "GET__summary"),
  description = "Tools for statistical analysis"
)
```

3.  **Example Requests**

``` r
# Add examples to tool definitions
pr_mcp_tool_example(
  pr,
  tool = "POST__analyze",
  example = list(
    name = "Analyze mtcars MPG",
    arguments = list(
      data = "mtcars$mpg",
      method = "summary"
    ),
    expected_result = list(
      mean = 20.09,
      median = 19.2
    )
  )
)
```

**Estimated Effort**: 1-2 weeks

------------------------------------------------------------------------

## Priority Matrix

| Feature               | Impact | Effort | Priority | Timeline |
|-----------------------|--------|--------|----------|----------|
| MCP Client Support    | High   | High   | P0       | Q1 2025  |
| Built-in Tools        | Medium | Medium | P1       | Q1 2025  |
| Resource Templates    | Medium | Low    | P1       | Q2 2025  |
| Performance & Caching | Medium | High   | P2       | Q2 2025  |
| Documentation         | Low    | Low    | P3       | Q2 2025  |

## Implementation Plan

### Immediate (Next 4 weeks)

1.  ✅ Complete feature gap analysis
2.  🔲 Design MCP client architecture
3.  🔲 Implement basic MCP client functionality
4.  🔲 Add tests for client mode

### Short-term (2-3 months)

1.  🔲 Complete MCP client with stdio & HTTP support
2.  🔲 Implement built-in environment inspection tools
3.  🔲 Add comprehensive documentation
4.  🔲 Create example integrations (GitHub MCP server, etc.)

### Medium-term (3-6 months)

1.  🔲 Implement resource templates
2.  🔲 Add caching layer
3.  🔲 Performance optimizations
4.  🔲 Rate limiting support

### Long-term (6+ months)

1.  🔲 Streaming support
2.  🔲 OpenAPI integration
3.  🔲 Advanced tool categorization
4.  🔲 Plugin system for custom transports

## Success Metrics

- **Feature Parity**: Cover 80%+ of mcptools functionality (where
  applicable)
- **Performance**: Tools list generation \< 100ms for 50 endpoints
- **Adoption**: Used in 3+ production projects
- **Documentation**: 100% of new features documented with examples
- **Testing**: 90%+ code coverage for new features

## Questions & Considerations

1.  **Client vs Server**: Should plumber2mcp remain primarily
    server-focused, or should client capabilities be first-class?
    - **Recommendation**: Keep server-focused, but add client as
      optional feature
2.  **Security**: How to handle credentials for external MCP servers?
    - **Recommendation**: Use environment variables, support config
      files
3.  **Compatibility**: Maintain backward compatibility?
    - **Recommendation**: Yes, all new features should be opt-in
4.  **Dependency Management**: Adding MCP client will increase
    dependencies
    - **Recommendation**: Keep client features in separate optional
      module
5.  **Testing**: How to test MCP client without external servers?
    - **Recommendation**: Mock MCP servers for testing, provide example
      servers

## Next Steps

1.  Review this plan with maintainers and community
2.  Create GitHub issues for each phase
3.  Seek feedback on API design for new functions
4.  Start with Phase 1 implementation
5.  Update CLAUDE.md with new architecture once Phase 1 is complete

## References

- mcptools: <https://posit-dev.github.io/mcptools/>
- btw package: <https://github.com/posit-dev/btw>
- MCP Specification: <https://modelcontextprotocol.io/>
- ellmer: <https://ellmer.tidyverse.org/>
