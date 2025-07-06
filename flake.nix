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

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      
      imports = [
        inputs.uv2nix.flakeModule
      ];

      perSystem = { config, self', inputs', pkgs, system, lib, ... }: let
        # Import our library functions
        uvMcpLib = import ./lib { 
          inherit pkgs lib; 
          inherit (inputs) uv2nix pyproject-nix;
        };
        
        # Build all MCP servers
        mcpServers = uvMcpLib.buildAllServers ./servers;
        
        # Create overlay for external use
        uvMcpOverlay = final: prev: {
          uv-mcp-servers = mcpServers // {
            lib = uvMcpLib;
          };
        };
        
      in {
        # Configure nixpkgs with necessary overlays
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            inputs.pyproject-nix.overlays.default
            uvMcpOverlay
          ];
        };

        # Export packages
        packages = mcpServers // {
          default = mcpServers.filesystem;
        };

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
            echo "UV MCP Servers Development Environment"
            echo "Available servers: ${builtins.concatStringsSep ", " (builtins.attrNames mcpServers)}"
            echo "Use 'uv --help' for UV commands"
          '';
        };

        # Export overlays for external use
        overlays.default = uvMcpOverlay;
      };

      # Flake-level outputs
      flake = {
        # Home Manager module
        homeManagerModules.default = import ./modules/home-manager.nix;
        homeManagerModules.uv-mcp-servers = import ./modules/home-manager.nix;
        
        # NixOS module  
        nixosModules.default = import ./modules/nixos.nix;
        nixosModules.uv-mcp-servers = import ./modules/nixos.nix;
        
        # Darwin module
        darwinModules.default = import ./modules/darwin.nix;
        darwinModules.uv-mcp-servers = import ./modules/darwin.nix;
        
        # Library functions for external use
        lib = inputs.self.lib.uv-mcp-servers or {};
      };
    };
}
