{ config, lib, pkgs, ... }:

let
  cfg = config.services.uv-mcp-servers;
  
  # WSL environment detection and variable reading with fallbacks
  isWSLEnabled = config.targets.wsl.enable or false;
  
  # Read variables produced by wsl target at build-time (with fallbacks)
  windowsUsername = if isWSLEnabled then 
    config.targets.wsl.windowsUsernameFinal or "unknown"
  else 
    "unknown";
    
  windowsHomeDir = if isWSLEnabled then 
    config.targets.wsl.windowsHomeDir or "/mnt/c/Users/unknown"
  else 
    "/mnt/c/Users/unknown";
    
  wslDistroName = if isWSLEnabled then 
    config.targets.wsl.wslDistroName or "NixOS"
  else 
    "NixOS";

  # Import UV MCP servers if available
  uvMcpServers = if pkgs ? uv-mcp-servers then pkgs.uv-mcp-servers else {};
  uvMcpLib = if uvMcpServers ? lib then uvMcpServers.lib else null;

  # Single source of truth for allowed directories
  allowedDirectories = if uvMcpLib != null then
    uvMcpLib.wslHelpers.mkAllowedDirectories {
      homeDir = config.home.homeDirectory;
      inherit windowsHomeDir wslDistroName;
    }
  else [
    config.home.homeDirectory
    "/etc" 
    "/nix/store"
    windowsHomeDir
    "/mnt/wsl"
    "${windowsHomeDir}/AppData/Roaming/Claude/logs"
  ];

  # Server configuration helpers
  mkServerConfig = name: serverCfg: let
    serverPackage = uvMcpServers.${name} or (throw "MCP server '${name}' not found in uv-mcp-servers");
    serverBinary = "${serverPackage}/bin/mcp-${name}";
    
  in {
    command = if serverCfg.useWSL then "C:\\WINDOWS\\system32\\wsl.exe" else serverBinary;
    args = if serverCfg.useWSL then 
      [ "-d" wslDistroName "-e" serverBinary ] ++ (serverCfg.args or [])
    else
      serverCfg.args or [];
    env = serverCfg.env or {};
  } // (lib.optionalAttrs (serverCfg ? timeout) { inherit (serverCfg) timeout; });

  # Generate Claude Desktop configuration
  claudeConfig = {
    mcpServers = lib.mapAttrs mkServerConfig (lib.filterAttrs (_: v: v.enable) cfg.servers);
  };

  # Server type definition
  serverOptions = { name, ... }: {
    options = {
      enable = lib.mkEnableOption "MCP server ${name}";
      
      package = lib.mkOption {
        type = lib.types.package;
        default = uvMcpServers.${name} or (throw "Server ${name} not available");
        description = "Package for the MCP server";
      };
      
      useWSL = lib.mkOption {
        type = lib.types.bool;
        default = isWSLEnabled;
        description = "Execute server via WSL (Windows Subsystem for Linux)";
      };
      
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional arguments to pass to the server";
      };
      
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Environment variables for the server";
      };
      
      timeout = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Server timeout in seconds";
      };
    };
  };

in {
  options.services.uv-mcp-servers = {
    enable = lib.mkEnableOption "UV-based MCP servers";
    
    configFormat = lib.mkOption {
      type = lib.types.enum [ "json" "yaml" ];
      default = "json";
      description = "Format for Claude Desktop configuration";
    };
    
    configFile = lib.mkOption {
      type = lib.types.str;
      default = "claude-mcp-config.json";
      description = "Name of the Claude Desktop configuration file";
    };
    
    servers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule serverOptions);
      default = {};
      description = "MCP servers to configure";
      example = lib.literalExpression ''
        {
          filesystem = {
            enable = true;
            args = [ "/home/user" "/etc" ];
            env = { DEBUG = "*"; };
          };
          mcp-nixos = {
            enable = true;
            useWSL = true;
          };
        }
      '';
    };
    
    allowedDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = allowedDirectories;
      description = "Directories accessible to MCP servers";
    };
    
    globalEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { DEBUG = "*"; };
      description = "Global environment variables for all servers";
    };

    # Quick server enablement options
    quickEnable = {
      filesystem = lib.mkEnableOption "filesystem server";
      cli-mcp-server = lib.mkEnableOption "CLI MCP server"; 
      mcp-nixos = lib.mkEnableOption "NixOS integration server";
      memory = lib.mkEnableOption "memory server";
      brave-search = lib.mkEnableOption "Brave search server";
      sequential-thinking = lib.mkEnableOption "sequential thinking server";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure UV MCP servers are available
    assertions = [
      {
        assertion = uvMcpLib != null;
        message = "uv-mcp-servers overlay not found. Add uv-mcp-servers to your flake inputs and overlays.";
      }
    ];

    # Install necessary tools
    home.packages = with pkgs; [
      uv
      python312
      git
      jq
      nodejs  # For MCP protocol
    ] ++ lib.optionals isWSLEnabled [
      # WSL-specific tools
    ];

    # Quick server configuration - auto-enable based on quickEnable flags
    services.uv-mcp-servers.servers = lib.mkMerge [
      # User-defined servers
      cfg.servers
      
      # Quick-enabled servers with sensible defaults
      (lib.mkIf cfg.quickEnable.filesystem {
        filesystem = {
          enable = true;
          args = cfg.allowedDirectories;
          env = cfg.globalEnv // { DEBUG = "*"; };
        };
      })
      
      (lib.mkIf cfg.quickEnable.cli-mcp-server {
        cli-mcp-server = {
          enable = true;
          env = cfg.globalEnv // {
            ALLOWED_DIR = "/";
            ALLOWED_COMMANDS = "ls,cd,cp,mv,cat,env,pwd,fd,find,git,rg,grep,head,tail,tree,which,echo,date,whoami,uname,file,wc,sort,uniq,cut,awk,sed,nix,home-manager,nixos-rebuild,uv,uvx,./run.sh,python,python3,./swt,./scripts/swt,chmod,bash";
            ALLOWED_FLAGS = "all";
            MAX_COMMAND_LENGTH = "1024";
            COMMAND_TIMEOUT = "900";
            ALLOW_SHELL_OPERATORS = "true";
          };
        };
      })
      
      (lib.mkIf cfg.quickEnable.mcp-nixos {
        mcp-nixos = {
          enable = true;
          env = cfg.globalEnv // {
            MCP_NIXOS_CLEANUP_ORPHANS = "true";
          };
        };
      })
      
      (lib.mkIf cfg.quickEnable.memory {
        memory = {
          enable = true;
          env = cfg.globalEnv;
        };
      })
      
      (lib.mkIf cfg.quickEnable.brave-search {
        brave-search = {
          enable = true;
          # Use bash wrapper for API key loading to work around WSL env issues
          useWSL = true;
          args = [ "bash" "-c" 
            "BRAVE_API_KEY=$(cat ${config.home.homeDirectory}/brave-search-api-key) exec ${uvMcpServers.brave-search}/bin/mcp-brave-search"
          ];
        };
      })
      
      (lib.mkIf cfg.quickEnable.sequential-thinking {
        sequential-thinking = {
          enable = true;
          env = cfg.globalEnv;
        };
      })
    ];

    # Generate Claude Desktop configuration file
    home.file.${cfg.configFile} = {
      text = if cfg.configFormat == "json" then
        builtins.toJSON claudeConfig
      else
        lib.generators.toYAML {} claudeConfig;
    };

    # Create test and verification scripts
    home.file."bin/test-uv-mcp-servers" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        
        echo "Testing UV MCP Servers..."
        echo
        
        echo "=== Configuration ==="
        echo "WSL Enabled: ${lib.boolToString isWSLEnabled}"
        echo "Windows User: ${windowsUsername}"
        echo "Windows Home: ${windowsHomeDir}"
        echo "WSL Distro: ${wslDistroName}"
        echo "Config Format: ${cfg.configFormat}"
        echo
        
        echo "=== Available Servers ==="
        ${lib.concatMapStringsSep "\n" (name: 
          "echo '  - ${name}: ${if cfg.servers.${name}.enable then "enabled" else "disabled"}'"
        ) (lib.attrNames cfg.servers)}
        echo
        
        echo "=== Configuration File ==="
        if [ -f "$HOME/${cfg.configFile}" ]; then
          echo "✓ Config file exists: $HOME/${cfg.configFile}"
          if command -v jq &> /dev/null && [[ "${cfg.configFile}" == *.json ]]; then
            echo "Server count: $(jq '.mcpServers | keys | length' "$HOME/${cfg.configFile}")"
            echo "Servers: $(jq -r '.mcpServers | keys | join(", ")' "$HOME/${cfg.configFile}")"
          fi
        else
          echo "✗ Config file missing: $HOME/${cfg.configFile}"
        fi
        echo
        
        echo "=== Package Verification ==="
        ${lib.concatMapStringsSep "\n" (name: 
          if cfg.servers.${name}.enable then ''
            if [ -x "${uvMcpServers.${name} or "missing"}/bin/mcp-${name}" ]; then
              echo "✓ ${name}: $(${uvMcpServers.${name}}/bin/mcp-${name} --version 2>/dev/null || echo 'available')"
            else
              echo "✗ ${name}: binary not found"
            fi
          '' else ""
        ) (lib.attrNames cfg.servers)}
        echo
        
        echo "=== Directory Access ==="
        ${lib.concatMapStringsSep "\n" (dir: ''
          if [ -d "${dir}" ]; then
            echo "✓ ${dir}"
          else
            echo "✗ ${dir} (not accessible)"
          fi
        '') cfg.allowedDirectories}
        echo
        
        echo "Testing complete."
      '';
    };

    # Debug and troubleshooting helper
    home.file."bin/debug-uv-mcp-servers" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        
        echo "=== UV MCP Servers Debug Information ==="
        echo
        
        echo "=== System Information ==="
        echo "User: $(whoami)"
        echo "Home: $HOME" 
        echo "PWD: $PWD"
        echo "WSL_DISTRO_NAME: ''${WSL_DISTRO_NAME:-not set}"
        echo
        
        echo "=== UV MCP Environment ==="
        echo "UV available: $(command -v uv &>/dev/null && echo "yes" || echo "no")"
        echo "Python available: $(command -v python3 &>/dev/null && echo "yes" || echo "no")"
        echo "Git available: $(command -v git &>/dev/null && echo "yes" || echo "no")"
        echo
        
        echo "=== Server Packages ==="
        ${lib.concatMapStringsSep "\n" (name: ''
          echo "=== ${name} ==="
          if [ -d "${uvMcpServers.${name} or "missing"}" ]; then
            echo "  Package path: ${uvMcpServers.${name}}"
            echo "  Binary exists: $([ -x "${uvMcpServers.${name}}/bin/mcp-${name}" ] && echo "yes" || echo "no")"
            if [ -x "${uvMcpServers.${name}}/bin/debug-mcp-${name}" ]; then
              echo "  Debug info:"
              "${uvMcpServers.${name}}/bin/debug-mcp-${name}" | sed 's/^/    /'
            fi
          else
            echo "  Package: NOT FOUND"
          fi
          echo
        '') (lib.attrNames (lib.filterAttrs (_: v: v.enable) cfg.servers))}
        
        echo "Debug complete."
      '';
    };
  };
}
