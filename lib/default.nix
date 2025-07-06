{ pkgs, lib, uv2nix, pyproject-nix }:

rec {
  # Import all library modules
  builders = import ./builders.nix { inherit pkgs lib uv2nix pyproject-nix; };
  mcpOverrides = import ./mcp-overrides.nix { inherit pkgs lib; };
  conversion = import ./conversion.nix { inherit pkgs lib; };
  debug = import ./debug.nix { inherit pkgs lib; };

  # Re-export main functions for convenience
  inherit (builders) buildMCPServer buildAllServers;
  inherit (mcpOverrides) commonMcpOverlays;
  inherit (conversion) convertPoetryProject;
  inherit (debug) inspectWorkspace debugBuild;

  # Common Python versions supported
  supportedPythonVersions = [ "311" "312" "313" ];
  defaultPythonVersion = "312";

  # Common MCP server configuration
  defaultMcpConfig = {
    timeout = 30;
    maxMemory = "512M";
    debug = false;
  };

  # WSL execution helpers
  wslHelpers = {
    # Generate WSL command for MCP server execution
    mkWslCommand = { distroName ? "NixOS", serverPath, args ? [], env ? {} }:
      let
        envVars = lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}='${v}'") env);
        serverArgs = lib.concatStringsSep " " (map lib.escapeShellArg args);
      in {
        command = "C:\\WINDOWS\\system32\\wsl.exe";
        args = [
          "-d" distroName
          "bash" "-c"
          "${envVars} exec ${serverPath} ${serverArgs}"
        ];
      };

    # Generate allowed directories for filesystem access
    mkAllowedDirectories = { homeDir, windowsHomeDir ? "/mnt/c/Users/unknown", wslDistroName ? "NixOS" }: [
      homeDir
      "/etc"
      "/nix/store"
      windowsHomeDir
      "/mnt/wsl"
      "${windowsHomeDir}/AppData/Roaming/Claude/logs"
    ];
  };

  # Version and metadata
  version = "0.1.0";
  meta = {
    description = "UV-based MCP servers with uv2nix integration";
    homepage = "https://github.com/timblaktu/uv-mcp-servers";
    license = lib.licenses.mit;
    maintainers = [ "timblaktu" ];
  };
}
