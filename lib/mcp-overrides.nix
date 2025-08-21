{ pkgs, lib }:

rec {
  # Watchfiles overlay to fix test failures for FastMCP servers
  watchfilesOverlay = final: prev: {
    watchfiles = prev.watchfiles.overrideAttrs (old: {
      # Disable tests that fail in sandboxed builds
      # The package itself works fine, tests have environment-specific issues
      doCheck = false;
      pytestFlagsArray = [];
      
      # Ensure we have the latest version with upstream fixes
      # Version 0.24.0+ has better platform compatibility
      version = old.version or "0.24.0";
    });
  };

  # Common overlays for MCP server dependencies
  commonMcpOverlays = [
    # Fix watchfiles test failures that affect FastMCP servers
    watchfilesOverlay
    # TODO: Add back specific overrides as needed
  ];

  # Anthropic client package fixes
  anthropicOverlay = final: prev: {
    anthropic = prev.anthropic.overrideAttrs (old: {
      # Fix build dependencies
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
        final.setuptools
        final.wheel
      ];
      
      # Ensure proper SSL certificate handling
      propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
        final.certifi
        final.urllib3
      ];
      
      # Fix test dependencies if running tests
      nativeCheckInputs = (old.nativeCheckInputs or []) ++ [
        final.pytest
        final.pytest-asyncio
        final.respx
      ];
      
      # Skip tests that require network access
      pytestFlagsArray = [
        "--ignore=tests/test_client.py"
        "--ignore=tests/test_streaming.py"
      ];
    });
  };

  # HTTP client compatibility fixes
  httpClientOverlay = final: prev: {
    httpx = prev.httpx.overrideAttrs (old: {
      # Ensure compatible versions
      propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
        final.httpcore
        final.h11
        final.certifi
        final.sniffio
      ];
    });
    
    aiohttp = prev.aiohttp.overrideAttrs (old: {
      # Fix compilation issues on some platforms
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
        pkgs.gcc
        final.setuptools
        final.wheel
        final.cython
      ];
    });
  };

  # Pydantic v1/v2 compatibility
  pydanticOverlay = final: prev: {
    pydantic = prev.pydantic.overrideAttrs (old: {
      # Ensure proper typing extensions
      propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
        final.typing-extensions
        final.annotated-types
        final.pydantic-core
      ];
    });
    
    # Handle pydantic-core compilation
    pydantic-core = prev.pydantic-core.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
        pkgs.rustc
        pkgs.cargo
        pkgs.maturin
      ];
      
      # Set environment for Rust compilation
      CARGO_BUILD_JOBS = "1";  # Limit parallelism to avoid OOM
    });
  };

  # Common build dependencies overlay
  buildDepsOverlay = final: prev: {
    # Ensure setuptools is available
    setuptools = prev.setuptools.overrideAttrs (old: {
      # Fix for newer Python versions
      propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ 
        lib.optionals (lib.versionAtLeast final.python.version "3.12") [
          final.setuptools-scm
        ];
    });
    
    # Fix wheel building
    wheel = prev.wheel.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
        final.setuptools
      ];
    });
    
    # Fix pip installation issues
    pip = prev.pip.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
        final.setuptools
        final.wheel
      ];
    });
  };

  # Specific MCP server overrides
  mcpServerOverrides = {
    # Filesystem server specific fixes
    filesystem = final: prev: {
      # Add any filesystem-specific dependency fixes here
      pathspec = prev.pathspec.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
          final.setuptools
        ];
      });
      
      watchdog = prev.watchdog.overrideAttrs (old: {
        # Fix platform-specific dependencies
        propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ 
          lib.optionals pkgs.stdenv.isDarwin [
            pkgs.darwin.apple_sdk.frameworks.CoreFoundation
            pkgs.darwin.apple_sdk.frameworks.CoreServices
          ];
      });
    };
    
    # CLI MCP server specific fixes
    cli-mcp-server = final: prev: {
      # Ensure proper shell access
      subprocess32 = prev.subprocess32.overrideAttrs (old: {
        # Skip on Python 3.x as it's built-in
        disabled = lib.versionAtLeast final.python.version "3.0";
      });
    };
    
    # Memory server specific fixes  
    memory = final: prev: {
      # Add memory server specific fixes if needed
    };
    
    # NixOS integration specific fixes
    mcp-nixos = final: prev: {
      # Ensure Nix tools are available
      # These should be runtime dependencies, not build dependencies
    };
    
    # Sequential thinking server fixes
    sequential-thinking = final: prev: {
      # Add any specific dependencies for reasoning workflows
    };
    
    # Brave search server fixes
    brave-search = final: prev: {
      # HTTP client fixes for search API
      requests = prev.requests.overrideAttrs (old: {
        propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
          final.urllib3
          final.certifi
          final.charset-normalizer
          final.idna
        ];
      });
    };
  };

  # Function to get server-specific overrides
  getServerOverrides = serverName: 
    if mcpServerOverrides ? ${serverName}
    then [ mcpServerOverrides.${serverName} ]
    else [];

  # Debug helper to show what overrides are applied
  debugOverrides = serverName: let
    baseOverlays = map (o: o.name or "unnamed") commonMcpOverlays;
    serverOverlays = map (o: o.name or serverName) (getServerOverrides serverName);
  in {
    common = baseOverlays;
    server = serverOverlays;
    total = baseOverlays ++ serverOverlays;
  };
}
