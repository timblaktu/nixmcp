{
  description = "UV-based MCP servers with uv2nix integration";

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
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }:
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
            echo "=== UV MCP Servers Development Environment ==="
            echo "Available tools:"
            echo "  uv: $(uv --version)"
            echo "  python: $(python3 --version)"
            echo "  git: $(git --version | head -1)"
            echo
            echo "Next steps:"
            echo "  1. cd servers/<server-name>"
            echo "  2. uv lock --python python3"
            echo "  3. Build with: nix build .#<server-name>"
            echo
          '';
        };
        
        # Simple packages export for now - we'll add the real servers later
        packages = {
          # Placeholder packages that will be replaced with real servers
          default = pkgs.writeText "uv-mcp-servers-readme" ''
            UV MCP Servers Project
            =====================
            
            This is a collection of MCP servers built with UV and packaged with Nix.
            
            Available development commands:
            - nix develop    # Enter development shell
            - nix flake show # Show available outputs
            
            Servers in development:
            - sequential-thinking
            - filesystem
            - mcp-nixos
            - cli-mcp-server
          '';
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
