# Sequential Thinking MCP Server - Complete Setup Guide

This guide will walk you through setting up the Python Sequential Thinking MCP server from scratch, including all dependencies and configuration.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Structure](#project-structure)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Testing](#testing)
6. [Integration with MCP Clients](#integration-with-mcp-clients)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Configuration](#advanced-configuration)

## Prerequisites

### Required Software

1. **Python 3.9+**
   ```bash
   # Check Python version
   python --version
   # or
   python3 --version
   ```

2. **UV (Universal Virtualenv)**
   ```bash
   # Install UV
   curl -LsSf https://astral.sh/uv/install.sh | sh
   # or using pip
   pip install uv
   
   # Verify installation
   uv --version
   ```

3. **Git**
   ```bash
   # Check if git is installed
   git --version
   ```

### Optional Tools

- **MCP Inspector**: For testing the server
- **Claude Desktop**: For integration testing
- **Cursor**: Alternative MCP client

## Project Structure

Create your project directory with this structure:

```
sequential-thinking-mcp/
├── pyproject.toml              # UV project configuration
├── README.md                   # Project documentation
├── LICENSE                     # MIT license
├── .gitignore                  # Git ignore rules
├── SETUP_GUIDE.md             # This file
├── src/
│   └── sequential_thinking_mcp/
│       ├── __init__.py        # Package initialization
│       ├── models.py          # Pydantic data models
│       └── server.py          # Main server implementation
└── tests/
    └── test_server.py         # Unit tests
```

## Installation

### Step 1: Create Project Directory

```bash
mkdir sequential-thinking-mcp
cd sequential-thinking-mcp
```

### Step 2: Create All Project Files

Create each file with the content provided in the artifacts. The key files are:

1. **pyproject.toml** - Project configuration and dependencies
2. **src/sequential_thinking_mcp/models.py** - Data models
3. **src/sequential_thinking_mcp/server.py** - Main server
4. **src/sequential_thinking_mcp/__init__.py** - Package initialization
5. **README.md** - Documentation
6. **LICENSE** - MIT license
7. **.gitignore** - Git ignore rules
8. **tests/test_server.py** - Tests

### Step 3: Install Dependencies

```bash
# Initialize UV project (if not already done)
uv init

# Install the project and all dependencies
uv install

# Install development dependencies
uv install --dev
```

### Step 4: Verify Installation

```bash
# Test the server can be imported
uv run python -c "from sequential_thinking_mcp import SequentialThinkingServer; print('✅ Installation successful!')"

# Run the server briefly to test
uv run sequential-thinking-mcp &
PID=$!
sleep 2
kill $PID
```

## Configuration

### Environment Variables

Create a `.env` file (optional):

```bash
# .env file
DISABLE_THOUGHT_LOGGING=false
PYTHONPATH=./src
```

### MCP Client Configuration

#### For Claude Desktop

1. **Find Configuration File**
   - **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
   - **Linux**: `~/.config/claude/claude_desktop_config.json`

2. **Add Server Configuration**
   ```json
   {
     "mcpServers": {
       "sequential-thinking": {
         "command": "uv",
         "args": [
           "--directory",
           "/absolute/path/to/sequential-thinking-mcp",
           "run",
           "sequential-thinking-mcp"
         ],
         "env": {
           "DISABLE_THOUGHT_LOGGING": "false"
         }
       }
     }
   }
   ```

#### For Cursor

1. **Global Configuration** (`~/.cursor/mcp.json`):
   ```json
   {
     "mcpServers": {
       "sequential-thinking": {
         "command": "uv",
         "args": [
           "--directory",
           "/absolute/path/to/sequential-thinking-mcp",
           "run",
           "sequential-thinking-mcp"
         ]
       }
     }
   }
   ```

2. **Project-specific Configuration** (`.cursor/mcp.json`):
   ```json
   {
     "mcpServers": {
       "sequential-thinking": {
         "command": "uv",
         "args": [
           "--directory",
           "./sequential-thinking-mcp",
           "run",
           "sequential-thinking-mcp"
         ]
       }
     }
   }
   ```

## Testing

### Unit Tests

```bash
# Run all tests
uv run pytest

# Run tests with verbose output
uv run pytest -v

# Run tests with coverage
uv run pytest --cov=src/sequential_thinking_mcp

# Run specific test file
uv run pytest tests/test_server.py

# Run specific test method
uv run pytest tests/test_server.py::TestSequentialThinkingServer::test_basic_thought_processing
```

### Integration Testing with MCP Inspector

```bash
# Install MCP CLI tools
pip install mcp

# Test the server with MCP Inspector
npx @modelcontextprotocol/inspector uv --directory /absolute/path/to/sequential-thinking-mcp run sequential-thinking-mcp
```

### Manual Testing

```bash
# Run the server manually
uv run sequential-thinking-mcp

# In another terminal, test with a simple client
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}' | uv run sequential-thinking-mcp
```

## Integration with MCP Clients

### Claude Desktop Integration

1. **Install Claude Desktop** from the official website
2. **Configure the server** as shown in the configuration section
3. **Restart Claude Desktop**
4. **Test the integration**:
   - Open a new conversation
   - Ask Claude to "use sequential thinking to solve a problem"
   - Claude should start using the `think` tool

### Cursor Integration

1. **Install Cursor** from the official website
2. **Configure the server** in the MCP settings
3. **Restart Cursor**
4. **Test the integration**:
   - Open a project
   - Use the AI features
   - The sequential thinking tool should be available

### Testing the Integration

Try this example conversation:

```
User: "Use sequential thinking to plan a birthday party for a 10-year-old"

Expected behavior:
- Claude/Cursor will use the think tool multiple times
- You'll see structured thinking steps
- The server will log colorful output (if logging is enabled)
- The AI will break down the problem systematically
```

## Troubleshooting

### Common Issues

1. **"Module not found" errors**
   ```bash
   # Ensure you're in the project directory
   cd /path/to/sequential-thinking-mcp
   
   # Reinstall dependencies
   uv install
   
   # Check Python path
   uv run python -c "import sys; print(sys.path)"
   ```

2. **Permission errors**
   ```bash
   # Make sure the server script is executable
   chmod +x src/sequential_thinking_mcp/server.py
   
   # Check file permissions
   ls -la src/sequential_thinking_mcp/
   ```

3. **MCP connection issues**
   ```bash
   # Test the server manually
   uv run sequential-thinking-mcp
   
   # Check if the path in MCP config is correct
   uv run which sequential-thinking-mcp
   ```

4. **Import errors**
   ```bash
   # Check if all dependencies are installed
   uv run pip list
   
   # Reinstall the package
   uv install --reload
   ```

### Debug Mode

Enable debug logging:

```bash
# Set environment variables
export DISABLE_THOUGHT_LOGGING=false
export PYTHONPATH=/path/to/sequential-thinking-mcp/src

# Run with debug output
uv run sequential-thinking-mcp 2>&1 | tee debug.log
```

### Checking MCP Client Logs

#### Claude Desktop Logs

- **macOS**: `~/Library/Logs/Claude/`
- **Windows**: `%APPDATA%\Claude\logs\`
- **Linux**: `~/.config/claude/logs/`

#### Cursor Logs

- Check Cursor's developer tools
- Look for MCP-related errors in the console

## Advanced Configuration

### Custom Installation Location

```bash
# Install to a custom location
UV_PROJECT_DIR=/opt/sequential-thinking-mcp uv install

# Use custom Python executable
UV_PYTHON=/usr/bin/python3.11 uv install
```

### Development Setup

```bash
# Install in development mode
uv install --dev

# Install pre-commit hooks
uv run pre-commit install

# Run code quality checks
uv run black src/ tests/
uv run isort src/ tests/
uv run ruff check src/ tests/
uv run mypy src/
```

### Production Deployment

```bash
# Build distribution
uv build

# Install from wheel
pip install dist/sequential_thinking_mcp-*.whl

# Run as a service (systemd example)
sudo systemctl daemon-reload
sudo systemctl enable sequential-thinking-mcp
sudo systemctl start sequential-thinking-mcp
```

### Performance Tuning

```bash
# Disable logging for better performance
export DISABLE_THOUGHT_LOGGING=true

# Use faster JSON serialization
uv add orjson

# Profile the server
uv run python -m cProfile -o profile.stats src/sequential_thinking_mcp/server.py
```

## Verification Checklist

- [ ] Python 3.9+ is installed
- [ ] UV is installed and working
- [ ] Project structure is created correctly
- [ ] All dependencies are installed (`uv install`)
- [ ] Tests pass (`uv run pytest`)
- [ ] Server starts without errors
- [ ] MCP client configuration is correct
- [ ] Integration with Claude Desktop/Cursor works
- [ ] Sequential thinking tool is available in the AI interface

## Getting Help

If you encounter issues:

1. **Check the logs** - Enable debug logging and check output
2. **Run tests** - Ensure all tests pass
3. **Verify configuration** - Double-check file paths and settings
4. **Check dependencies** - Ensure all required packages are installed
5. **Review documentation** - Check the README and this guide
6. **Search issues** - Look for similar problems in the project repository

## Next Steps

After successful setup:

1. **Explore the features** - Try different types of sequential thinking
2. **Customize the server** - Modify the code for your specific needs
3. **Add more tools** - Extend the server with additional MCP tools
4. **Contribute** - Submit improvements and bug fixes
5. **Share your experience** - Help others with setup and usage

---

**Congratulations!** You now have a fully functional Sequential Thinking MCP server running with Python and UV. The server provides structured problem-solving capabilities through the Model Context Protocol, enabling AI assistants to break down complex problems into manageable sequential steps.
