{
  description = "UV MCP Server Framework - Nix infrastructure for UV-based MCP servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    
    # uv2nix for Python package management
    uv2nix = {
      url = "github:adisbladis/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # pyproject-nix for build system integration
    pyproject-nix = {
      url = "github:nix-community/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # External MCP servers as inputs
    sequential-thinking-mcp = {
      url = "git+file:../sequential-thinking-mcp";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, nixpkgs, sequential-thinking-mcp, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      
      perSystem = { config, self', inputs', pkgs, system, lib, ... }: {

        # Development shell with all necessary tools
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            uv
            python312
            git
            jq
            nodejs  # For MCP protocol testing
          ];
          
          shellHook = ''
            echo "=== UV MCP Server Framework Development Environment ==="
            echo "Available tools:"
            echo "  uv: $(uv --version)"
            echo "  python: $(python3 --version)"
            echo "  git: $(git --version | head -1)"
            echo
            echo "Framework components:"
            echo "  lib/         - Nix builders and UV integration functions"
            echo "  modules/     - Home Manager modules for MCP deployment"
            echo "  scripts/     - Development and deployment tools"
            echo "  docs/        - Framework documentation and guides"
            echo "  examples/    - Template projects and usage patterns"
            echo
            echo "Next steps:"
            echo "  1. Create/clone MCP server repositories"
            echo "  2. Add servers as flake inputs"
            echo "  3. Build with framework: nix build .#<server-name>"
            echo
          '';
        };
        
        # Framework packages
        packages = {
          default = pkgs.writeText "uv-mcp-framework-readme" ''
            UV MCP Server Framework
            =======================
            
            Nix infrastructure for building and deploying UV-based MCP servers.
            
            This framework provides:
            - UV-Nix integration builders
            - Home Manager deployment modules
            - Development tools and templates
            - Standardized MCP server patterns
            
            Available commands:
            - nix develop    # Enter development shell
            - nix flake show # Show available outputs
            
            External MCP servers (add as flake inputs):
            - sequential-thinking-mcp
            - cli-mcp-server
            - mcp-filesystem
            - mcp-nixos
          '';
          
          # Re-export external MCP servers for convenience
          sequential-thinking-mcp = sequential-thinking-mcp.packages.${system}.default;
        };
      };

      # Flake-level outputs
      flake = {
        # Home Manager module
        homeManagerModules.default = import ./modules/home-manager.nix;
        homeManagerModules.uv-mcp-servers = import ./modules/home-manager.nix;
        
        # Simple overlay for now
        overlays.default = final: prev: {
          uv-mcp-servers = {
            lib = import ./lib { 
              pkgs = final; 
              lib = final.lib; 
              uv2nix = inputs.uv2nix; 
              pyproject-nix = inputs.pyproject-nix; 
            };
          };
        };
      };
    };
}
