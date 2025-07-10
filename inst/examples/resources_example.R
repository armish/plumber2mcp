# Example: Creating an MCP server with various resource types
#
# This example demonstrates how to create resources that expose
# different types of R content to AI assistants.

library(plumber)
library(plumber2mcp)

# Create a new Plumber router
pr <- pr()

# Add some example API endpoints
pr %>%
  pr_get("/status", function() {
    list(
      status = "running",
      timestamp = Sys.time(),
      r_version = R.version.string
    )
  }) %>%
  pr_post("/analyze", function(data) {
    # Simple analysis endpoint
    summary_stats <- summary(as.numeric(data))
    list(summary = as.list(summary_stats))
  })

# Add various types of resources
pr <- pr %>%
  
  # 1. Dataset summaries
  pr_mcp_resource(
    uri = "/data/mtcars-overview",
    func = function() {
      paste(
        "Motor Trend Car Road Tests Dataset (mtcars)",
        paste(rep("=", 50), collapse = ""),
        "",
        paste("Observations:", nrow(mtcars)),
        paste("Variables:", ncol(mtcars)),
        "",
        "Variable descriptions:",
        "- mpg:  Miles/(US) gallon",
        "- cyl:  Number of cylinders", 
        "- disp: Displacement (cu.in.)",
        "- hp:   Gross horsepower",
        "- drat: Rear axle ratio",
        "- wt:   Weight (1000 lbs)",
        "- qsec: 1/4 mile time",
        "- vs:   Engine (0 = V-shaped, 1 = straight)",
        "- am:   Transmission (0 = automatic, 1 = manual)",
        "- gear: Number of forward gears",
        "- carb: Number of carburetors",
        "",
        "Summary statistics:",
        capture.output(summary(mtcars)),
        sep = "\n"
      )
    },
    name = "mtcars Dataset Overview",
    description = "Complete overview of the Motor Trend car dataset with variable descriptions"
  ) %>%
  
  # 2. Current R environment information
  pr_mcp_resource(
    uri = "/env/loaded-packages",
    func = function() {
      pkgs <- search()
      attached <- sessionInfo()$otherPkgs
      paste(
        "Currently Loaded Packages and Namespaces",
        paste(rep("=", 40), collapse = ""),
        "",
        "Search path:",
        paste(pkgs, collapse = "\n"),
        "",
        "Attached packages:",
        if (!is.null(attached)) {
          paste(names(attached), sapply(attached, function(p) p$Version), sep = " ")
        } else {
          "No additional packages attached"
        },
        sep = "\n"
      )
    },
    name = "Loaded Packages",
    description = "List of currently loaded R packages and namespaces"
  ) %>%
  
  # 3. Statistical analysis results
  pr_mcp_resource(
    uri = "/analysis/correlation-matrix",
    func = function() {
      # Select numeric columns from mtcars
      numeric_cols <- mtcars[, sapply(mtcars, is.numeric)]
      cor_matrix <- cor(numeric_cols)
      
      paste(
        "Correlation Matrix for mtcars Dataset",
        paste(rep("=", 40), collapse = ""),
        "",
        "Correlation coefficients between all numeric variables:",
        "",
        capture.output(print(round(cor_matrix, 3))),
        "",
        "Interpretation:",
        "- Values range from -1 to 1",
        "- Positive values indicate positive correlation",
        "- Negative values indicate negative correlation", 
        "- Values close to 0 indicate weak correlation",
        "",
        "Strongest correlations (|r| > 0.8):",
        capture.output({
          high_cor <- which(abs(cor_matrix) > 0.8 & cor_matrix != 1, arr.ind = TRUE)
          if (nrow(high_cor) > 0) {
            for (i in 1:nrow(high_cor)) {
              if (high_cor[i, 1] < high_cor[i, 2]) {  # Avoid duplicates
                cat(sprintf("- %s vs %s: %.3f\n", 
                  rownames(cor_matrix)[high_cor[i, 1]],
                  colnames(cor_matrix)[high_cor[i, 2]],
                  cor_matrix[high_cor[i, 1], high_cor[i, 2]]))
              }
            }
          } else {
            cat("No correlations above 0.8 threshold")
          }
        }),
        sep = "\n"
      )
    },
    name = "mtcars Correlation Analysis",
    description = "Correlation matrix and interpretation for mtcars dataset"
  ) %>%
  
  # 4. Custom data transformations
  pr_mcp_resource(
    uri = "/data/cars-by-transmission",
    func = function() {
      auto_cars <- subset(mtcars, am == 0)
      manual_cars <- subset(mtcars, am == 1)
      
      paste(
        "Cars Grouped by Transmission Type",
        paste(rep("=", 35), collapse = ""),
        "",
        paste("Automatic transmission cars:", nrow(auto_cars)),
        paste("Manual transmission cars:", nrow(manual_cars)),
        "",
        "Automatic Transmission Cars:",
        paste(rownames(auto_cars), collapse = ", "),
        "",
        "Manual Transmission Cars:",
        paste(rownames(manual_cars), collapse = ", "),
        "",
        "Average MPG by transmission:",
        paste("- Automatic:", round(mean(auto_cars$mpg), 2)),
        paste("- Manual:", round(mean(manual_cars$mpg), 2)),
        sep = "\n"
      )
    },
    name = "Cars by Transmission Type",
    description = "Breakdown of cars in mtcars dataset by transmission type"
  ) %>%
  
  # 5. Add built-in R help resources
  pr_mcp_help_resources(topics = c("lm", "glm", "summary", "plot", "ggplot2"))

# Now run the server with stdio transport
message("Starting MCP server with resources...")
message("Available resources:")
resources <- pr$environment$mcp_resources
for (uri in names(resources)) {
  message("  ", uri, " - ", resources[[uri]]$name)
}

# Run the server
pr_mcp_stdio(pr, debug = TRUE)