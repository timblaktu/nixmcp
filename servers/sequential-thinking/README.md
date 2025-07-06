# Sequential Thinking MCP Server (Python)

A Python implementation of the Sequential Thinking MCP server using UV for modern Python dependency management. This server enables structured problem-solving by breaking down complex issues into sequential steps, supporting revisions, and enabling multiple solution paths through the Model Context Protocol.

## Features

- **🧠 Structured Problem-Solving**: Break down complex problems into manageable sequential steps
- **🔄 Revision Support**: Revise and refine previous thoughts as understanding deepens
- **🌳 Branching Logic**: Explore alternative reasoning paths with branch support
- **📊 Dynamic Adjustment**: Adjust the total number of thoughts as needed during the process
- **🎨 Rich Logging**: Beautiful colored console output with progress tracking (can be disabled)
- **📋 Comprehensive Resources**: Access thought history, summaries, and branch information
- **🔧 Environment Configuration**: Configurable logging and behavior via environment variables

## Installation

### Prerequisites

- Python 3.9 or higher
- [UV](https://docs.astral.sh/uv/) for dependency management

### Using UV (Recommended)

```bash
# Clone the repository
git clone https://github.com/your-org/sequential-thinking-mcp.git
cd sequential-thinking-mcp

# Install with UV
uv install

# Run the server
uv run sequential-thinking-mcp
```

### Using pip

```bash
# Clone the repository
git clone https://github.com/your-org/sequential-thinking-mcp.git
cd sequential-thinking-mcp

# Install in development mode
pip install -e .

# Run the server
sequential-thinking-mcp
```

## Configuration

### Environment Variables

- `DISABLE_THOUGHT_LOGGING`: Set to `"true"` to disable colored console logging (default: `"false"`)

### MCP Client Configuration

#### Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "uv",
      "args": [
        "--directory",
        "/path/to/sequential-thinking-mcp",
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

#### Cursor

Add to your `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "uv",
      "args": [
        "--directory",
        "/path/to/sequential-thinking-mcp",
        "run",
        "sequential-thinking-mcp"
      ]
    }
  }
}
```

#### Using Direct Python Execution

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "python",
      "args": [
        "/path/to/sequential-thinking-mcp/src/sequential_thinking_mcp/server.py"
      ]
    }
  }
}
```

## Usage

### Basic Sequential Thinking

```python
# First thought
think(
    thought="First, we need to understand the problem requirements.",
    thoughtNumber=1,
    totalThoughts=5,
    nextThoughtNeeded=True
)

# Second thought
think(
    thought="Now, let's analyze the key constraints and limitations.",
    thoughtNumber=2,
    totalThoughts=5,
    nextThoughtNeeded=True
)

# Final thought
think(
    thought="Based on the analysis, here's the recommended solution approach.",
    thoughtNumber=3,
    totalThoughts=3,
    nextThoughtNeeded=False
)
```

### Advanced Features

#### Revising Previous Thoughts

```python
# Revise the first thought
think(
    thought="Actually, we need to first clarify the stakeholder requirements.",
    thoughtNumber=1,
    totalThoughts=5,
    nextThoughtNeeded=True,
    isRevision=True,
    revisesThought=1
)
```

#### Branching Reasoning

```python
# Create a branch from thought 2
think(
    thought="Let's explore an alternative approach using a different methodology.",
    thoughtNumber=3,
    totalThoughts=5,
    nextThoughtNeeded=True,
    branchFromThought=2,
    branchId="alternative-approach"
)

# Continue in the branch
think(
    thought="This alternative approach has several advantages...",
    thoughtNumber=4,
    totalThoughts=5,
    nextThoughtNeeded=True,
    branchFromThought=2,
    branchId="alternative-approach"
)
```

#### Dynamic Scope Adjustment

```python
# Indicate that more thoughts are needed than initially estimated
think(
    thought="The problem is more complex than initially assessed.",
    thoughtNumber=5,
    totalThoughts=8,  # Increased from original estimate
    nextThoughtNeeded=True,
    needsMoreThoughts=True
)
```

## Tool Parameters

The `think` tool accepts the following parameters:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `thought` | string | ✅ | The current thinking step content |
| `thoughtNumber` | integer | ✅ | Current thought number (minimum: 1) |
| `totalThoughts` | integer | ✅ | Estimated total thoughts needed (minimum: 1) |
| `nextThoughtNeeded` | boolean | ✅ | Whether another thought step is needed |
| `isRevision` | boolean | ❌ | Whether this revises previous thinking |
| `revisesThought` | integer | ❌ | Which thought number is being reconsidered |
| `branchFromThought` | integer | ❌ | Branching point thought number |
| `branchId` | string | ❌ | Branch identifier |
| `needsMoreThoughts` | boolean | ❌ | Whether more thoughts are needed |

## Resources

The server provides several resources for accessing thought data:

| Resource URI | Description |
|-------------|-------------|
| `thoughts://history` | Complete history of all thoughts in the main branch |
| `thoughts://summary` | Summary of the entire thinking process |
| `thoughts://branches` | Overview of all branches in the thinking process |
| `thoughts://session` | Complete thinking session with all thoughts and branches |
| `thoughts://branches/{branch_id}` | Specific branch thoughts |

## Development

### Setting Up Development Environment

```bash
# Clone the repository
git clone https://github.com/your-org/sequential-thinking-mcp.git
cd sequential-thinking-mcp

# Install development dependencies
uv install --dev

# Run tests
uv run pytest

# Run linting
uv run ruff check
uv run black --check .

# Run type checking
uv run mypy src/
```

### Code Quality

This project uses several tools for code quality:

- **Black**: Code formatting
- **isort**: Import sorting
- **Ruff**: Fast Python linter
- **MyPy**: Static type checking
- **Pytest**: Testing framework

### Running Tests

```bash
# Run all tests
uv run pytest

# Run tests with coverage
uv run pytest --cov=src/sequential_thinking_mcp

# Run specific test file
uv run pytest tests/test_server.py
```

## Architecture

### Core Components

1. **ThoughtData**: Pydantic model representing individual thoughts with validation
2. **ThinkingSession**: Complete session state with main thoughts and branches
3. **SequentialThinkingServer**: Main MCP server implementation
4. **Rich Logging**: Colored console output with progress tracking

### Data Flow

1. Client sends `think` tool call with thought parameters
2. Server validates input using Pydantic models
3. Thought is processed and added to session state
4. Server updates internal state (main branch or specific branch)
5. Rich logging displays formatted output (if enabled)
6. Resources provide access to session data

### Error Handling

- Input validation using Pydantic with descriptive error messages
- Graceful error handling with structured error responses
- Comprehensive logging of errors and validation issues

## Comparison with TypeScript Version

This Python implementation maintains full functional parity with the original TypeScript version while adding Python-specific enhancements:

### Identical Features
- Same tool interface and parameters
- Identical validation logic
- Same branching and revision behavior
- Environment variable support (`DISABLE_THOUGHT_LOGGING`)
- Compatible MCP protocol implementation

### Python Enhancements
- **Type Safety**: Full type hints throughout using Python's typing system
- **Rich Logging**: Enhanced console output using the Rich library
- **Pydantic Validation**: Robust data validation with detailed error messages
- **Modern Python**: Uses modern Python features and best practices
- **UV Support**: Modern Python dependency management with UV

### Performance Considerations
- Python implementation may have slightly higher latency than TypeScript
- Memory usage is comparable for typical use cases
- Rich logging can be disabled for minimal overhead

## Troubleshooting

### Common Issues

1. **Import Errors**: Ensure all dependencies are installed with `uv install`
2. **Permission Errors**: Make sure the server script has execute permissions
3. **MCP Connection Issues**: Verify the correct path in your MCP client configuration
4. **Logging Issues**: Check the `DISABLE_THOUGHT_LOGGING` environment variable

### Debug Mode

Enable debug logging by setting environment variables:

```bash
export DISABLE_THOUGHT_LOGGING=false
export PYTHONPATH=/path/to/sequential-thinking-mcp/src
```

### Testing the Server

Use the MCP Inspector for testing:

```bash
# Install MCP CLI tools
pip install mcp

# Test the server
npx @modelcontextprotocol/inspector uv --directory /path/to/sequential-thinking-mcp run sequential-thinking-mcp
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and add tests
4. Ensure all tests pass: `uv run pytest`
5. Check code quality: `uv run ruff check && uv run black --check .`
6. Commit your changes: `git commit -m 'Add amazing feature'`
7. Push to the branch: `git push origin feature/amazing-feature`
8. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

- Original TypeScript implementation by [Anthropic](https://github.com/modelcontextprotocol/servers)
- Python implementation with UV integration
- Built with the [Model Context Protocol](https://modelcontextprotocol.io/)

## Support

- 📖 [Documentation](https://github.com/your-org/sequential-thinking-mcp#readme)
- 🐛 [Issues](https://github.com/your-org/sequential-thinking-mcp/issues)
- 💬 [Discussions](https://github.com/your-org/sequential-thinking-mcp/discussions)
- 🌟 [Model Context Protocol](https://modelcontextprotocol.io/)
