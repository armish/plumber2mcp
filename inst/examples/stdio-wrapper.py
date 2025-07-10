#!/usr/bin/env python3
"""
Final production wrapper for plumber2mcp
Handles all R jsonlite serialization quirks
"""

import sys
import json
import urllib.request
import urllib.error

MCP_ENDPOINT = "http://localhost:8000/mcp/messages"

def fix_r_json(obj):
    """Fix all R jsonlite serialization issues"""
    if obj is None:
        return None
    elif isinstance(obj, list):
        if len(obj) == 1:
            # Convert single-element arrays to scalars
            return fix_r_json(obj[0])
        else:
            # Process array elements
            return [fix_r_json(item) for item in obj]
    elif isinstance(obj, dict):
        if len(obj) == 0:
            # Empty dict - context dependent
            return None  # Most cases empty dict should be None
        
        # Process dictionary recursively
        fixed = {}
        for k, v in obj.items():
            if k == "id" and isinstance(v, dict) and len(v) == 0:
                # Empty dict for id should be null
                fixed[k] = None
            elif k == "id" and isinstance(v, list) and len(v) == 1:
                # Single element array for id should be scalar
                fixed[k] = v[0]
            elif k == "tools" and isinstance(v, list) and len(v) == 0:
                # Empty tools array should be empty object for capabilities
                fixed[k] = {}
            elif k == "properties" and isinstance(v, list) and len(v) == 0:
                # Empty properties array should be empty object
                fixed[k] = {}
            elif k == "required" and isinstance(v, dict) and len(v) == 0:
                # Empty required dict should be empty array
                fixed[k] = []
            elif k == "content" and isinstance(v, list):
                # content is already an array, just fix nested arrays
                fixed[k] = [fix_r_json(item) for item in v]
            elif k == "error" and isinstance(v, dict):
                # Process error object specially
                error_fixed = {}
                for ek, ev in v.items():
                    if isinstance(ev, list) and len(ev) == 1:
                        error_fixed[ek] = ev[0]
                    else:
                        error_fixed[ek] = ev
                fixed[k] = error_fixed
            else:
                # Recursive fix
                fixed[k] = fix_r_json(v)
        return fixed
    else:
        return obj

def main():
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break
                
            request = json.loads(line.strip())
            
            # Forward to HTTP endpoint
            data = json.dumps(request).encode('utf-8')
            req = urllib.request.Request(MCP_ENDPOINT, 
                                       data=data,
                                       headers={'Content-Type': 'application/json'})
            
            with urllib.request.urlopen(req) as response:
                result = json.loads(response.read().decode('utf-8'))
            
            # Fix R serialization issues
            fixed_result = fix_r_json(result)
            
            # Send response
            print(json.dumps(fixed_result))
            sys.stdout.flush()
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            # Send error response
            error_response = {
                "jsonrpc": "2.0",
                "id": request.get("id") if 'request' in locals() else None,
                "error": {
                    "code": -32603,
                    "message": f"Internal error: {str(e)}"
                }
            }
            print(json.dumps(error_response))
            sys.stdout.flush()

if __name__ == "__main__":
    main()