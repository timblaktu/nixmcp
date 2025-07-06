{ pkgs, lib, uv2nix, pyproject-nix }:

let
  # Import common overrides
  mcpOverrides = import ./mcp-overrides.nix { inherit pkgs lib; };

in rec {
  
  # Main function to build an MCP server using uv2nix
  buildMCPServer = {
    name,
    src,
    pythonVersion ? "312",
    preferWheels ? true,
    extraOverlays ? [],
    mcpConfig ? {},
    meta ? {},
    ...
  }@args: let
    
    # Load the UV workspace from the source
    workspace = uv2nix.lib.workspace.loadWorkspace { 
      workspaceRoot = src; 
    };
    
    # Create the UV overlay for this workspace
    uvOverlay = workspace.mkPyprojectOverlay {
      sourcePreference = if preferWheels then "wheel" else "sdist";
    };
    
    # Combine all overlays: common MCP fixes + UV overlay + user extras
    allOverlays = mcpOverrides.commonMcpOverlays ++ [ uvOverlay ] ++ extraOverlays;
    
    # Get Python package set with overlays applied
    pythonSet = pkgs."python${pythonVersion}".override {
      packageOverrides = lib.composeManyExtensions allOverlays;
    };
    
    # Create virtual environment with dependencies
    mcpEnv = pythonSet.mkVirtualEnv name workspace.deps.default;
    
    # Enhanced metadata
    finalMeta = {
      description = "MCP server: ${name}";
      homepage = "https://github.com/timblaktu/uv-mcp-servers";
      license = lib.licenses.mit;
      maintainers = [ "timblaktu" ];
      platforms = lib.platforms.unix;
    } // meta;
    
  in mcpEnv.overrideAttrs (old: {
    name = "mcp-server-${name}";
    
    # Add MCP-specific metadata
    passthru = (old.passthru or {}) // {
      inherit mcpConfig workspace pythonSet;
      
      # Convenience attributes
      mcpServerName = name;
      pythonVersion = pythonVersion;
      preferWheels = preferWheels;
      
      # Debugging helpers
      debug = {
        showDependencies = workspace.deps.default;
        showOverlays = map (o: o.name or "unnamed") allOverlays;
        showPythonPath = pythonSet.pythonPath;
      };
    };
    
    meta = finalMeta;
    
    # Ensure proper binary naming and paths
    postInstall = (old.postInstall or "") + ''
      # Create standard MCP server binary if it doesn't exist
      if [ ! -f "$out/bin/mcp-${name}" ] && [ -f "$out/bin/${name}" ]; then
        ln -sf "$out/bin/${name}" "$out/bin/mcp-${name}"
      fi
      
      # Create debugging script
      cat > "$out/bin/debug-mcp-${name}" << 'EOF'
      #!/bin/bash
      echo "=== MCP Server Debug Info: ${name} ==="
      echo "Python Version: ${pythonVersion}"
      echo "Prefer Wheels: ${lib.boolToString preferWheels}"
      echo "Workspace Root: ${src}"
      echo "Virtual Env Path: $out"
      echo "Available binaries:"
      ls -la "$out/bin/" | grep -E "(mcp-|${name})"
      echo "Python path:"
      PYTHONPATH="$out/lib/python*/site-packages" python -c "import sys; print('\n'.join(sys.path))"
      echo "=== Dependencies ==="
      PYTHONPATH="$out/lib/python*/site-packages" python -c "import pkg_resources; [print(d) for d in pkg_resources.working_set]"
      EOF
      chmod +x "$out/bin/debug-mcp-${name}"
    '';
  });

  # Function to build all servers in a directory
  buildAllServers = serversDir: let
    # Find all server directories (those containing pyproject.toml)
    serverDirs = lib.filterAttrs 
      (name: type: type == "directory" && builtins.pathExists "${serversDir}/${name}/pyproject.toml")
      (builtins.readDir serversDir);
    
    # Build each server
    buildServer = name: _: let
      serverSrc = "${serversDir}/${name}";
      
      # Check for custom overrides file
      hasOverrides = builtins.pathExists "${serverSrc}/pyproject-overrides.nix";
      serverOverrides = if hasOverrides 
        then [ (import "${serverSrc}/pyproject-overrides.nix" { inherit pkgs lib; }) ]
        else [];
      
      # Check for custom meta file
      hasMeta = builtins.pathExists "${serverSrc}/meta.nix";
      serverMeta = if hasMeta
        then import "${serverSrc}/meta.nix"
        else {};
        
    in buildMCPServer {
      inherit name;
      src = serverSrc;
      extraOverlays = serverOverrides;
      meta = serverMeta;
    };
    
  in lib.mapAttrs buildServer serverDirs;

  # Utility to check if a server source is UV-compatible
  isUvCompatible = src: 
    builtins.pathExists "${src}/pyproject.toml" && 
    (builtins.pathExists "${src}/uv.lock" || builtins.pathExists "${src}/poetry.lock");

  # Function to validate server structure
  validateServerStructure = src: let
    checks = {
      hasProjectFile = builtins.pathExists "${src}/pyproject.toml";
      hasLockFile = builtins.pathExists "${src}/uv.lock" || builtins.pathExists "${src}/poetry.lock";
      hasSourceCode = builtins.pathExists "${src}/src" || builtins.pathExists "${src}/__init__.py";
    };
    
    issues = lib.filterAttrs (_: v: !v) checks;
    
  in {
    isValid = issues == {};
    inherit issues;
    suggestions = lib.mapAttrsToList (check: _: 
      if check == "hasProjectFile" then "Add pyproject.toml with project configuration"
      else if check == "hasLockFile" then "Run 'uv lock' to generate uv.lock or convert from poetry.lock"  
      else if check == "hasSourceCode" then "Ensure source code is present in src/ directory or root"
      else "Unknown issue"
    ) issues;
  };

  # Helper to show available servers
  listAvailableServers = serversDir: 
    lib.attrNames (lib.filterAttrs 
      (name: type: type == "directory" && isUvCompatible "${serversDir}/${name}")
      (builtins.readDir serversDir));
}
