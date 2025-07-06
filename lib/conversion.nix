{ pkgs, lib }:

rec {
  # Convert a Poetry project to UV format
  convertPoetryProject = { src, outputDir ? "./converted" }: let
    
    # Check if this is a Poetry project
    isPoetryProject = builtins.pathExists "${src}/pyproject.toml" && 
                     builtins.pathExists "${src}/poetry.lock";
    
    # Read pyproject.toml to extract Poetry config
    pyprojectContent = builtins.fromTOML (builtins.readFile "${src}/pyproject.toml");
    hasPoetryConfig = pyprojectContent ? tool.poetry;
    
  in if !isPoetryProject then
    throw "Source directory ${src} is not a Poetry project (missing pyproject.toml or poetry.lock)"
  else if !hasPoetryConfig then  
    throw "pyproject.toml does not contain [tool.poetry] configuration"
  else pkgs.runCommand "convert-poetry-to-uv" {
    nativeBuildInputs = with pkgs; [ 
      migrate-to-uv
      uv
      python312
    ];
  } ''
    # Copy source to output
    cp -r ${src}/* $out/
    cd $out
    
    # Convert using migrate-to-uv tool
    migrate-to-uv
    
    # Generate uv.lock file
    uv lock
    
    # Clean up Poetry artifacts
    rm -f poetry.lock
    
    echo "Conversion complete. Project converted from Poetry to UV."
  '';

  # Extract UV configuration from existing pyproject.toml
  extractUvConfig = pyprojectFile: let
    content = builtins.fromTOML (builtins.readFile pyprojectFile);
    
    poetryDeps = content.tool.poetry.dependencies or {};
    poetryDevDeps = content.tool.poetry.group.dev.dependencies or {};
    
    # Convert Poetry dependencies to UV format
    convertDependencies = deps: 
      lib.mapAttrs (name: spec: 
        if builtins.isString spec then spec
        else if spec ? version then spec.version
        else "*"
      ) deps;
      
  in {
    project = {
      name = content.tool.poetry.name or "unknown";
      version = content.tool.poetry.version or "0.1.0";
      description = content.tool.poetry.description or "";
      authors = content.tool.poetry.authors or [];
      license = content.tool.poetry.license or null;
      readme = content.tool.poetry.readme or null;
      
      # Convert dependencies
      dependencies = lib.mapAttrsToList (name: spec: 
        if name == "python" then spec
        else "${name}${if spec == "*" then "" else "==${spec}"}"
      ) (convertDependencies (removeAttrs poetryDeps ["python"]));
      
      # Python version requirement
      requires-python = poetryDeps.python or ">=3.8";
    };
    
    # Build system
    build-system = {
      requires = ["hatchling"];
      build-backend = "hatchling.build";
    };
    
    # Development dependencies
    tool.uv = lib.optionalAttrs (poetryDevDeps != {}) {
      dev-dependencies = lib.mapAttrsToList (name: spec:
        "${name}${if spec == "*" then "" else "==${spec}"}"
      ) (convertDependencies poetryDevDeps);
    };
  };

  # Generate a UV-compatible pyproject.toml
  generateUvPyproject = config: let
    tomlContent = lib.generators.toTOML {} config;
  in pkgs.writeText "pyproject.toml" tomlContent;

  # Validate UV project structure
  validateUvProject = src: let
    hasPyproject = builtins.pathExists "${src}/pyproject.toml";
    hasUvLock = builtins.pathExists "${src}/uv.lock";
    hasSourceCode = builtins.pathExists "${src}/src" || 
                   builtins.pathExists "${src}/__init__.py";
    
    issues = lib.filterAttrs (_: v: !v) {
      inherit hasPyproject hasUvLock hasSourceCode;
    };
    
  in {
    isValid = issues == {};
    inherit issues;
    suggestions = lib.mapAttrsToList (issue: _:
      if issue == "hasPyproject" then "Create pyproject.toml with project configuration"
      else if issue == "hasUvLock" then "Run 'uv lock' to generate lock file"
      else if issue == "hasSourceCode" then "Add source code in src/ directory or root"
      else "Unknown validation issue"
    ) issues;
  };

  # Create UV project template
  createUvProjectTemplate = { name, description ? "", author ? "Unknown" }: {
    project = {
      inherit name description;
      version = "0.1.0";
      authors = [{ name = author; }];
      readme = "README.md";
      requires-python = ">=3.8";
      dependencies = [
        "mcp>=1.0.0"
      ];
    };
    
    build-system = {
      requires = ["hatchling"];
      build-backend = "hatchling.build";
    };
    
    tool.uv = {
      dev-dependencies = [
        "pytest>=6.0"
        "black"
        "ruff"
      ];
    };
    
    project.scripts = {
      "mcp-${name}" = "${name}:main";
    };
  };

  # Batch convert multiple Poetry projects
  batchConvertProjects = projectPaths: let
    convertProject = path: {
      source = path;
      result = convertPoetryProject { src = path; };
      name = baseNameOf path;
    };
  in map convertProject projectPaths;

  # Generate migration report
  generateMigrationReport = conversions: let
    successful = lib.filter (c: c.result.success or false) conversions;
    failed = lib.filter (c: !(c.result.success or false)) conversions;
  in {
    total = lib.length conversions;
    successful = lib.length successful;
    failed = lib.length failed;
    successRate = (lib.length successful) * 100 / (lib.length conversions);
    
    details = {
      inherit successful failed;
    };
  };
}
