{ pkgs, lib, uv2nix, pyproject-nix }:

let
  inherit (pkgs.uv-mcp-servers.lib) buildMCPServer;
in

buildMCPServer {
  name = "sequential-thinking";
  src = ./.;
  pythonVersion = "312";
  preferWheels = true;
  
  mcpConfig = {
    name = "sequential-thinking";
    description = "Sequential thinking MCP server for structured problem-solving";
    version = "0.1.0";
  };
  
  meta = {
    description = "A Python implementation of the Sequential Thinking MCP server for structured problem-solving";
    homepage = "https://github.com/timblaktu/uv-mcp-servers";
    license = lib.licenses.mit;
    maintainers = [ "timblaktu" ];
    platforms = lib.platforms.unix;
  };
}
