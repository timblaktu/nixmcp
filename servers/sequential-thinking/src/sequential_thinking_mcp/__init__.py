"""
Sequential Thinking MCP Server

A Python implementation of the Sequential Thinking MCP server that enables
structured problem-solving by breaking down complex issues into sequential steps,
supporting revisions, and enabling multiple solution paths through the Model Context Protocol.

This package provides:
- ThoughtData: Pydantic model for individual thoughts
- ThoughtSummary: Summary of thinking sessions
- BranchInfo: Information about thinking branches
- ThinkingSession: Complete session state
- SequentialThinkingServer: Main MCP server implementation
"""

from .models import (
    ThoughtData,
    ThoughtSummary,
    BranchInfo,
    ThinkingSession,
)
from .server import SequentialThinkingServer

__version__ = "0.1.0"
__author__ = "Sequential Thinking MCP"
__email__ = "info@example.com"
__license__ = "MIT"

__all__ = [
    "ThoughtData",
    "ThoughtSummary", 
    "BranchInfo",
    "ThinkingSession",
    "SequentialThinkingServer",
    "__version__",
    "__author__",
    "__email__",
    "__license__",
]
