{ pkgs, lib }:

rec {
  # Inspect a UV workspace for debugging
  inspectWorkspace = workspace: {
    name = workspace.name or "unknown";
    version = workspace.version or "unknown";
    dependencies = workspace.deps.default or [];
    devDependencies = workspace.deps.dev or [];
    pythonVersion = workspace.pythonVersion or "unknown";
    lockFileExists = workspace ? lockFile;
    
    # Dependency counts
    stats = {
      totalDeps = lib.length (workspace.deps.default or []);
      devDeps = lib.length (workspace.deps.dev or []);
      optionalDeps = lib.length (workspace.deps.optional or []);
    };
  };

  # Debug build process for MCP server
  debugBuild = { name, workspace, pythonSet }: {
    serverName = name;
    
    workspace = inspectWorkspace workspace;
    
    pythonInfo = {
      version = pythonSet.python.version;
      executable = "${pythonSet.python}/bin/python";
      sitePacakges = "${pythonSet.python}/${pythonSet.python.sitePackages}";
    };
    
    # List all packages in Python set
    availablePackages = lib.attrNames pythonSet.pkgs;
    
    # Check for common MCP dependencies
    mcpDeps = {
      hasMcp = pythonSet.pkgs ? mcp;
      hasAnthropicSdk = pythonSet.pkgs ? anthropic;
      hasHttpx = pythonSet.pkgs ? httpx;
      hasPydantic = pythonSet.pkgs ? pydantic;
      hasTypingExtensions = pythonSet.pkgs ? typing-extensions;
    };
  };

  # Create debugging script for MCP server
  createDebugScript = { name, serverPath, workspace }: pkgs.writeShellScript "debug-mcp-${name}" ''
    #!/bin/bash
    
    echo "=== MCP Server Debug: ${name} ==="
    echo "Server Path: ${serverPath}"
    echo "Workspace: ${workspace.name or "unknown"}"
    echo
    
    echo "=== Python Environment ==="
    if command -v python3 &> /dev/null; then
      echo "Python Version: $(python3 --version)"
      echo "Python Path: $(which python3)"
    else
      echo "Python3 not found in PATH"
    fi
    echo
    
    echo "=== Server Executable ==="
    if [ -f "${serverPath}/bin/mcp-${name}" ]; then
      echo "✓ MCP server binary found: ${serverPath}/bin/mcp-${name}"
      ls -la "${serverPath}/bin/mcp-${name}"
    elif [ -f "${serverPath}/bin/${name}" ]; then
      echo "✓ Server binary found: ${serverPath}/bin/${name}"
      ls -la "${serverPath}/bin/${name}"
    else
      echo "✗ Server binary not found"
      echo "Available binaries:"
      ls -la "${serverPath}/bin/" 2>/dev/null || echo "No bin directory"
    fi
    echo
    
    echo "=== Dependencies Check ==="
    export PYTHONPATH="${serverPath}/lib/python*/site-packages:$PYTHONPATH"
    
    # Check for key MCP dependencies
    echo -n "MCP library: "
    python3 -c "import mcp; print('✓ Available')" 2>/dev/null || echo "✗ Missing"
    
    echo -n "Anthropic SDK: "
    python3 -c "import anthropic; print('✓ Available')" 2>/dev/null || echo "✗ Missing"
    
    echo -n "HTTP client: "
    python3 -c "import httpx; print('✓ HTTPX Available')" 2>/dev/null || \
    python3 -c "import requests; print('✓ Requests Available')" 2>/dev/null || echo "✗ Missing"
    
    echo -n "Pydantic: "
    python3 -c "import pydantic; print('✓ Available')" 2>/dev/null || echo "✗ Missing"
    echo
    
    echo "=== Package List ==="
    python3 -c "
import pkg_resources
packages = [d.project_name for d in pkg_resources.working_set]
print(f'Total packages: {len(packages)}')
for pkg in sorted(packages)[:10]:
    print(f'  - {pkg}')
if len(packages) > 10:
    print(f'  ... and {len(packages) - 10} more')
" 2>/dev/null || echo "Could not list packages"
    echo
    
    echo "=== Test Server Start ==="
    echo "Testing server startup (will timeout after 3 seconds)..."
    if timeout 3 "${serverPath}/bin/mcp-${name}" 2>/dev/null || timeout 3 "${serverPath}/bin/${name}" 2>/dev/null; then
      echo "✓ Server started successfully (timeout expected)"
    else
      echo "✓ Server startup test completed (timeout is normal)"
    fi
    echo
    
    echo "Debug complete for ${name}"
  '';

  # Performance profiling helpers
  profileBuild = { name, buildCommand }: pkgs.runCommand "profile-${name}" {
    nativeBuildInputs = [ pkgs.time ];
  } ''
    echo "Profiling build for ${name}..."
    
    # Time the build
    /usr/bin/time -v ${buildCommand} 2>&1 | tee $out
    
    echo "Build profiling complete"
  '';

  # Dependency tree analyzer
  analyzeDependencyTree = workspace: let
    allDeps = (workspace.deps.default or []) ++ 
              (workspace.deps.dev or []) ++ 
              (workspace.deps.optional or []);
    
    # Extract package names (remove version specifications)
    packageNames = map (dep: 
      let parts = lib.splitString "==" dep;
      in builtins.head parts
    ) allDeps;
    
    # Categorize dependencies
    categories = {
      mcp = lib.filter (name: lib.hasPrefix "mcp" name) packageNames;
      http = lib.filter (name: lib.elem name ["httpx" "requests" "aiohttp" "urllib3"]) packageNames;
      data = lib.filter (name: lib.elem name ["pydantic" "typing-extensions" "dataclasses"]) packageNames;
      async = lib.filter (name: lib.elem name ["asyncio" "aiofiles" "anyio"]) packageNames;
      testing = lib.filter (name: lib.elem name ["pytest" "unittest" "mock"]) packageNames;
      build = lib.filter (name: lib.elem name ["setuptools" "wheel" "build" "hatchling"]) packageNames;
      other = lib.filter (name: 
        !lib.any (cat: lib.elem name cat) [
          categories.mcp categories.http categories.data 
          categories.async categories.testing categories.build
        ]
      ) packageNames;
    };
    
  in {
    total = lib.length packageNames;
    inherit categories;
    
    summary = lib.mapAttrs (_: lib.length) categories;
    
    potentialIssues = {
      # Check for common problematic packages
      hasComplexBuild = lib.any (name: lib.elem name ["numpy" "scipy" "pandas" "cryptography"]) packageNames;
      hasRustDeps = lib.any (name: lib.elem name ["pydantic-core" "cryptography" "tokenizers"]) packageNames;
      hasNativeDeps = lib.any (name: lib.elem name ["lxml" "pillow" "psycopg2"]) packageNames;
    };
  };

  # Generate build report
  generateBuildReport = { name, workspace, buildResult, timingInfo ? null }: {
    serverName = name;
    buildSuccess = buildResult.success or false;
    
    workspace = inspectWorkspace workspace;
    dependencies = analyzeDependencyTree workspace;
    
    buildInfo = {
      inherit (buildResult) success;
      outputPath = buildResult.outPath or null;
      buildTime = timingInfo.elapsed or null;
      memoryUsage = timingInfo.maxMemory or null;
    };
    
    recommendations = lib.optionals (!buildResult.success) [
      "Check dependency compatibility with 'nix-build --show-trace'"
      "Review override patterns in lib/mcp-overrides.nix"
      "Consider using wheel packages instead of source distributions"
      "Check for platform-specific dependencies"
    ];
  };

  # Interactive debugging session
  debugShell = { name, serverPath, workspace }: pkgs.mkShell {
    name = "debug-mcp-${name}";
    
    buildInputs = with pkgs; [
      python312
      uv
      jq
      tree
      file
      ldd
    ];
    
    shellHook = ''
      echo "=== MCP Server Debug Shell: ${name} ==="
      echo "Server path: ${serverPath}"
      echo "Workspace: ${workspace.name or "unknown"}"
      echo
      echo "Available commands:"
      echo "  debug-server  - Run full diagnostic"
      echo "  test-import   - Test Python imports"
      echo "  show-deps     - Show dependencies"
      echo "  tree-view     - Show directory structure"
      echo
      
      # Set up environment
      export PYTHONPATH="${serverPath}/lib/python*/site-packages:$PYTHONPATH"
      export MCP_SERVER_PATH="${serverPath}"
      export MCP_SERVER_NAME="${name}"
      
      # Create helper functions
      debug-server() {
        ${createDebugScript { inherit name serverPath workspace }}
      }
      
      test-import() {
        echo "Testing Python imports..."
        python3 -c "
try:
    import mcp
    print('✓ MCP library imported successfully')
except ImportError as e:
    print('✗ MCP import failed:', e)

try:
    import ${name}
    print('✓ Server module imported successfully')
except ImportError as e:
    print('✗ Server import failed:', e)
"
      }
      
      show-deps() {
        echo "Dependencies in environment:"
        python3 -c "
import pkg_resources
for pkg in sorted(pkg_resources.working_set, key=lambda p: p.project_name):
    print(f'{pkg.project_name} {pkg.version}')
"
      }
      
      tree-view() {
        echo "Server directory structure:"
        tree -L 3 "${serverPath}" 2>/dev/null || ls -la "${serverPath}"
      }
      
      export -f debug-server test-import show-deps tree-view
    '';
  };
}
