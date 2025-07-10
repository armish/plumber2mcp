#!/bin/bash
# Test stdio transport with mcp-cli

echo "Testing plumber2mcp stdio transport with mcp-cli..."

# Create a test R script that runs stdio server
cat > test_stdio_server.R << 'EOF'
devtools::load_all()
library(plumber)

# Create test API
pr <- plumber::pr()
pr$handle("GET", "/hello", function() { list(msg = "Hello from R!") })
pr$handle("POST", "/add", function(a, b) { list(result = as.numeric(a) + as.numeric(b)) })

# Run as stdio server
plumber2mcp::pr_mcp_stdio(pr, server_name = "test-stdio", debug = FALSE)
EOF

# Test with mcp-cli if available
if command -v mcp-cli &> /dev/null; then
    echo "Found mcp-cli, testing..."
    
    # Send test commands
    echo "Sending initialize..."
    echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}' | Rscript test_stdio_server.R
    
    echo -e "\nSending tools/list..."
    echo '{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}' | Rscript test_stdio_server.R
    
    echo -e "\nCalling GET__hello..."
    echo '{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "GET__hello", "arguments": {}}}' | Rscript test_stdio_server.R
    
else
    echo "mcp-cli not found, testing with direct JSON-RPC..."
    
    # Test with direct messages
    (
        echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}'
        echo '{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}'
        echo '{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "GET__hello", "arguments": {}}}'
    ) | Rscript test_stdio_server.R
fi

# Cleanup
rm -f test_stdio_server.R

echo -e "\nTest complete!"