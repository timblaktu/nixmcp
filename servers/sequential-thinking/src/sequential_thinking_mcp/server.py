#!/usr/bin/env python3
"""
Sequential Thinking MCP Server

A Python implementation of the Sequential Thinking MCP server that enables
structured problem-solving by breaking down complex issues into sequential steps,
supporting revisions, and enabling multiple solution paths through the Model Context Protocol.
"""

from __future__ import annotations

import asyncio
import json
import os
import sys
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional, Sequence

from mcp import ClientSession, ServerSession, stdio_server
from mcp.server import Server
from mcp.types import (
    CallToolResult,
    ListToolsResult,
    ListResourcesResult,
    ReadResourceResult,
    Resource,
    TextContent,
    Tool,
    INVALID_PARAMS,
    INTERNAL_ERROR,
    ServerCapabilities,
    ToolsCapability,
    ResourcesCapability,
)
from pydantic import ValidationError
from rich.console import Console
from rich.panel import Panel
from rich.text import Text
from rich.tree import Tree

from .models import ThoughtData, ThoughtSummary, BranchInfo, ThinkingSession


class SequentialThinkingServer:
    """
    Main server class that implements the Sequential Thinking MCP protocol.
    
    This server provides a structured approach to problem-solving through
    sequential thinking, supporting revisions, branches, and comprehensive
    thought tracking.
    """
    
    def __init__(self) -> None:
        """Initialize the Sequential Thinking server."""
        self.console = Console(stderr=True, force_terminal=True)
        self.disable_thought_logging = (
            os.getenv("DISABLE_THOUGHT_LOGGING", "").lower() == "true"
        )
        
        # Initialize thinking session
        self.session = ThinkingSession(
            session_id=str(uuid.uuid4()),
            created_at=datetime.now().isoformat(),
            updated_at=datetime.now().isoformat()
        )
        
        # Create the MCP server
        self.server = Server("sequential-thinking-mcp")
        self._setup_handlers()
        
        if not self.disable_thought_logging:
            self._log_startup()
    
    def _setup_handlers(self) -> None:
        """Set up the MCP request handlers."""
        
        @self.server.list_tools()
        async def list_tools() -> ListToolsResult:
            """List available tools."""
            return ListToolsResult(
                tools=[
                    Tool(
                        name="think",
                        description=(
                            "Process a sequential thinking step with support for "
                            "revisions and branching. This tool facilitates a detailed, "
                            "step-by-step thinking process for problem-solving and analysis. "
                            "Only set next_thought_needed to false when truly done and "
                            "a satisfactory answer is reached."
                        ),
                        inputSchema={
                            "type": "object",
                            "properties": {
                                "thought": {
                                    "type": "string",
                                    "description": "Your current thinking step"
                                },
                                "nextThoughtNeeded": {
                                    "type": "boolean",
                                    "description": "Whether another thought step is needed"
                                },
                                "thoughtNumber": {
                                    "type": "integer",
                                    "description": "Current thought number",
                                    "minimum": 1
                                },
                                "totalThoughts": {
                                    "type": "integer",
                                    "description": "Estimated total thoughts needed",
                                    "minimum": 1
                                },
                                "isRevision": {
                                    "type": "boolean",
                                    "description": "Whether this revises previous thinking"
                                },
                                "revisesThought": {
                                    "type": "integer",
                                    "description": "Which thought is being reconsidered",
                                    "minimum": 1
                                },
                                "branchFromThought": {
                                    "type": "integer",
                                    "description": "Branching point thought number",
                                    "minimum": 1
                                },
                                "branchId": {
                                    "type": "string",
                                    "description": "Branch identifier"
                                },
                                "needsMoreThoughts": {
                                    "type": "boolean",
                                    "description": "If more thoughts are needed"
                                }
                            },
                            "required": [
                                "thought",
                                "nextThoughtNeeded", 
                                "thoughtNumber",
                                "totalThoughts"
                            ]
                        }
                    )
                ]
            )
        
        @self.server.list_resources()
        async def list_resources() -> ListResourcesResult:
            """List available resources."""
            return ListResourcesResult(
                resources=[
                    Resource(
                        uri="thoughts://history",
                        name="Thought History",
                        description="Complete history of all thoughts in the main branch"
                    ),
                    Resource(
                        uri="thoughts://summary",
                        name="Thinking Summary",
                        description="Summary of the entire thinking process"
                    ),
                    Resource(
                        uri="thoughts://branches",
                        name="Branch Overview",
                        description="Overview of all branches in the thinking process"
                    ),
                    Resource(
                        uri="thoughts://session",
                        name="Complete Session",
                        description="Complete thinking session with all thoughts and branches"
                    )
                ]
            )
        
        @self.server.read_resource()
        async def read_resource(uri: str) -> ReadResourceResult:
            """Read a specific resource."""
            if uri == "thoughts://history":
                return ReadResourceResult(
                    contents=[
                        TextContent(
                            type="text",
                            text=json.dumps(
                                [thought.to_display_dict() for thought in self.session.main_thoughts],
                                indent=2
                            )
                        )
                    ]
                )
            elif uri == "thoughts://summary":
                summary = self.session.get_summary()
                return ReadResourceResult(
                    contents=[
                        TextContent(
                            type="text", 
                            text=json.dumps(summary.dict(), indent=2)
                        )
                    ]
                )
            elif uri == "thoughts://branches":
                branches_info = []
                for branch_id, thoughts in self.session.branches.items():
                    branch_info = BranchInfo(
                        branch_id=branch_id,
                        branch_from_thought=thoughts[0].branch_from_thought or 0,
                        thoughts=thoughts
                    )
                    branches_info.append(branch_info.dict())
                
                return ReadResourceResult(
                    contents=[
                        TextContent(
                            type="text",
                            text=json.dumps(branches_info, indent=2)
                        )
                    ]
                )
            elif uri == "thoughts://session":
                return ReadResourceResult(
                    contents=[
                        TextContent(
                            type="text",
                            text=json.dumps(self.session.dict(), indent=2)
                        )
                    ]
                )
            elif uri.startswith("thoughts://branches/"):
                branch_id = uri.split("/")[-1]
                if branch_id in self.session.branches:
                    return ReadResourceResult(
                        contents=[
                            TextContent(
                                type="text",
                                text=json.dumps(
                                    [thought.to_display_dict() for thought in self.session.branches[branch_id]],
                                    indent=2
                                )
                            )
                        ]
                    )
                else:
                    raise ValueError(f"Branch '{branch_id}' not found")
            else:
                raise ValueError(f"Unknown resource: {uri}")
        
        @self.server.call_tool()
        async def call_tool(name: str, arguments: Dict[str, Any]) -> CallToolResult:
            """Handle tool calls."""
            if name != "think":
                raise ValueError(f"Unknown tool: {name}")
            
            try:
                # Validate and parse the thought data
                thought_data = ThoughtData(**arguments)
                
                # Process the thought
                await self._process_thought(thought_data)
                
                # Update session timestamp
                self.session.updated_at = datetime.now().isoformat()
                
                # Return success response
                return CallToolResult(
                    content=[
                        TextContent(
                            type="text",
                            text=f"✅ Processed thought {thought_data.thought_number}/{thought_data.total_thoughts}"
                        )
                    ]
                )
                
            except ValidationError as e:
                error_msg = f"Invalid thought data: {str(e)}"
                if not self.disable_thought_logging:
                    self._log_error(error_msg)
                return CallToolResult(
                    content=[
                        TextContent(
                            type="text",
                            text=f"❌ {error_msg}"
                        )
                    ],
                    isError=True
                )
            except Exception as e:
                error_msg = f"Error processing thought: {str(e)}"
                if not self.disable_thought_logging:
                    self._log_error(error_msg)
                return CallToolResult(
                    content=[
                        TextContent(
                            type="text",
                            text=f"❌ {error_msg}"
                        )
                    ],
                    isError=True
                )
    
    async def _process_thought(self, thought_data: ThoughtData) -> None:
        """Process a single thought and update the session state."""
        
        # Determine if this is a branch or main thought
        if thought_data.branch_id and thought_data.branch_from_thought:
            # This is a branch thought
            if thought_data.branch_id not in self.session.branches:
                self.session.branches[thought_data.branch_id] = []
            
            self.session.branches[thought_data.branch_id].append(thought_data)
            
            if not self.disable_thought_logging:
                self._log_branch_thought(thought_data)
        else:
            # This is a main branch thought
            if thought_data.is_revision and thought_data.revises_thought:
                # Handle revision
                self._handle_revision(thought_data)
            else:
                # Regular thought
                self.session.main_thoughts.append(thought_data)
            
            if not self.disable_thought_logging:
                self._log_main_thought(thought_data)
    
    def _handle_revision(self, thought_data: ThoughtData) -> None:
        """Handle a revision of a previous thought."""
        if thought_data.revises_thought and thought_data.revises_thought <= len(self.session.main_thoughts):
            # Replace the thought being revised
            revision_index = thought_data.revises_thought - 1
            self.session.main_thoughts[revision_index] = thought_data
            
            # Remove any subsequent thoughts that are now invalidated
            self.session.main_thoughts = self.session.main_thoughts[:revision_index + 1]
        else:
            # If revision target is invalid, treat as regular thought
            self.session.main_thoughts.append(thought_data)
    
    def _log_startup(self) -> None:
        """Log server startup message."""
        startup_panel = Panel.fit(
            Text("Sequential Thinking MCP Server Started", style="bold green"),
            border_style="bright_blue"
        )
        self.console.print(startup_panel)
        self.console.print(
            f"[dim]Session ID: {self.session.session_id}[/dim]"
        )
        self.console.print()
    
    def _log_main_thought(self, thought_data: ThoughtData) -> None:
        """Log a main branch thought with rich formatting."""
        
        # Create thought header
        if thought_data.is_revision:
            header = f"🔄 Revision {thought_data.thought_number}/{thought_data.total_thoughts}"
            color = "yellow"
        else:
            header = f"💭 Thought {thought_data.thought_number}/{thought_data.total_thoughts}"
            color = "bright_blue"
        
        # Create the thought panel
        thought_panel = Panel(
            Text(thought_data.thought, style="white"),
            title=header,
            border_style=color,
            width=80
        )
        
        self.console.print(thought_panel)
        
        # Add status indicators
        status_parts = []
        if thought_data.next_thought_needed:
            status_parts.append("[bright_green]→ More thoughts needed[/bright_green]")
        else:
            status_parts.append("[bright_red]✓ Thinking complete[/bright_red]")
        
        if thought_data.needs_more_thoughts:
            status_parts.append("[bright_yellow]📈 Expanding scope[/bright_yellow]")
        
        if status_parts:
            self.console.print(" ".join(status_parts))
        
        self.console.print()
    
    def _log_branch_thought(self, thought_data: ThoughtData) -> None:
        """Log a branch thought with rich formatting."""
        
        header = f"🌿 Branch: {thought_data.branch_id} ({thought_data.thought_number}/{thought_data.total_thoughts})"
        
        # Create the branch panel
        branch_panel = Panel(
            Text(thought_data.thought, style="white"),
            title=header,
            border_style="bright_magenta",
            width=80
        )
        
        self.console.print(branch_panel)
        
        # Add branch info
        branch_info = f"[dim]Branched from thought {thought_data.branch_from_thought}[/dim]"
        self.console.print(branch_info)
        
        # Add status indicators
        if thought_data.next_thought_needed:
            self.console.print("[bright_green]→ More thoughts needed in this branch[/bright_green]")
        else:
            self.console.print("[bright_red]✓ Branch complete[/bright_red]")
        
        self.console.print()
    
    def _log_error(self, error_msg: str) -> None:
        """Log an error message with rich formatting."""
        error_panel = Panel(
            Text(error_msg, style="bold red"),
            title="Error",
            border_style="red",
            width=80
        )
        self.console.print(error_panel)
        self.console.print()
    
    def _log_session_summary(self) -> None:
        """Log a summary of the current session."""
        if self.disable_thought_logging:
            return
        
        summary = self.session.get_summary()
        
        # Create a tree view of the session
        tree = Tree("📚 Thinking Session Summary", style="bold bright_blue")
        
        # Main branch
        main_branch = tree.add(f"🎯 Main Branch ({summary.main_branch_thoughts} thoughts)")
        for i, thought in enumerate(self.session.main_thoughts, 1):
            status = "✅" if not thought.next_thought_needed else "⏳"
            revision = " 🔄" if thought.is_revision else ""
            main_branch.add(f"{status} Thought {i}: {thought.thought[:50]}...{revision}")
        
        # Branches
        if summary.branches:
            branches_node = tree.add(f"🌳 Branches ({len(summary.branches)})")
            for branch_id in summary.branches:
                branch_thoughts = self.session.branches[branch_id]
                branch_node = branches_node.add(f"🌿 {branch_id} ({len(branch_thoughts)} thoughts)")
                for i, thought in enumerate(branch_thoughts, 1):
                    status = "✅" if not thought.next_thought_needed else "⏳"
                    branch_node.add(f"{status} Thought {i}: {thought.thought[:50]}...")
        
        # Summary stats
        stats_node = tree.add("📊 Statistics")
        stats_node.add(f"Total thoughts: {summary.total_thoughts}")
        stats_node.add(f"Revisions: {summary.revisions_count}")
        stats_node.add(f"Status: {'Complete' if summary.is_complete else 'In Progress'}")
        
        self.console.print(tree)
        self.console.print()
    
    async def run(self) -> None:
        """Run the server using stdio transport."""
        try:
            # Use stdio transport for MCP communication
            from mcp.server.models import InitializationOptions
            
            init_options = InitializationOptions(
                server_name="sequential-thinking-mcp",
                server_version="0.1.0",
                capabilities=ServerCapabilities(
                    tools=ToolsCapability(),
                    resources=ResourcesCapability()
                )
            )
            
            async with stdio_server() as (read_stream, write_stream):
                await self.server.run(
                    read_stream,
                    write_stream,
                    init_options
                )
        except KeyboardInterrupt:
            if not self.disable_thought_logging:
                self.console.print("\n[bright_red]Server stopped by user[/bright_red]")
                self._log_session_summary()
        except Exception as e:
            if not self.disable_thought_logging:
                self._log_error(f"Server error: {str(e)}")
            raise


def main() -> None:
    """Main entry point for the server."""
    server = SequentialThinkingServer()
    
    try:
        asyncio.run(server.run())
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception as e:
        print(f"Fatal error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
