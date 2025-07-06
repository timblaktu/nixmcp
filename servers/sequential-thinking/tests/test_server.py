"""
Tests for the Sequential Thinking MCP server.

This module contains tests for the core functionality of the server,
including thought processing, validation, and resource handling.
"""

import pytest
from unittest.mock import patch, MagicMock
import json
import os
from typing import Dict, Any

from sequential_thinking_mcp.server import SequentialThinkingServer
from sequential_thinking_mcp.models import ThoughtData, ThinkingSession


class TestSequentialThinkingServer:
    """Test suite for the SequentialThinkingServer class."""

    def setup_method(self):
        """Set up test fixtures."""
        # Disable logging for tests
        with patch.dict(os.environ, {"DISABLE_THOUGHT_LOGGING": "true"}):
            self.server = SequentialThinkingServer()

    def test_server_initialization(self):
        """Test that the server initializes properly."""
        assert self.server is not None
        assert self.server.session is not None
        assert self.server.session.session_id is not None
        assert len(self.server.session.main_thoughts) == 0
        assert len(self.server.session.branches) == 0

    def test_disable_logging_environment_variable(self):
        """Test that the DISABLE_THOUGHT_LOGGING environment variable works."""
        # Test with logging disabled
        with patch.dict(os.environ, {"DISABLE_THOUGHT_LOGGING": "true"}):
            server = SequentialThinkingServer()
            assert server.disable_thought_logging is True

        # Test with logging enabled
        with patch.dict(os.environ, {"DISABLE_THOUGHT_LOGGING": "false"}):
            server = SequentialThinkingServer()
            assert server.disable_thought_logging is False

        # Test with default (logging enabled)
        with patch.dict(os.environ, {}, clear=True):
            server = SequentialThinkingServer()
            assert server.disable_thought_logging is False

    @pytest.mark.asyncio
    async def test_basic_thought_processing(self):
        """Test basic thought processing without revisions or branches."""
        thought_data = ThoughtData(
            thought="This is a test thought",
            thoughtNumber=1,
            totalThoughts=3,
            nextThoughtNeeded=True
        )

        await self.server._process_thought(thought_data)

        assert len(self.server.session.main_thoughts) == 1
        assert self.server.session.main_thoughts[0].thought == "This is a test thought"
        assert self.server.session.main_thoughts[0].thought_number == 1
        assert self.server.session.main_thoughts[0].total_thoughts == 3
        assert self.server.session.main_thoughts[0].next_thought_needed is True

    @pytest.mark.asyncio
    async def test_revision_processing(self):
        """Test revision processing."""
        # Add initial thought
        initial_thought = ThoughtData(
            thought="Initial thought",
            thoughtNumber=1,
            totalThoughts=3,
            nextThoughtNeeded=True
        )
        await self.server._process_thought(initial_thought)

        # Add second thought
        second_thought = ThoughtData(
            thought="Second thought",
            thoughtNumber=2,
            totalThoughts=3,
            nextThoughtNeeded=True
        )
        await self.server._process_thought(second_thought)

        # Revise the first thought
        revised_thought = ThoughtData(
            thought="Revised first thought",
            thoughtNumber=1,
            totalThoughts=3,
            nextThoughtNeeded=True,
            isRevision=True,
            revisesThought=1
        )
        await self.server._process_thought(revised_thought)

        # Should only have one thought (the revision)
        assert len(self.server.session.main_thoughts) == 1
        assert self.server.session.main_thoughts[0].thought == "Revised first thought"
        assert self.server.session.main_thoughts[0].is_revision is True

    @pytest.mark.asyncio
    async def test_branch_processing(self):
        """Test branch processing."""
        # Add initial thoughts
        thought1 = ThoughtData(
            thought="First thought",
            thoughtNumber=1,
            totalThoughts=3,
            nextThoughtNeeded=True
        )
        await self.server._process_thought(thought1)

        thought2 = ThoughtData(
            thought="Second thought",
            thoughtNumber=2,
            totalThoughts=3,
            nextThoughtNeeded=True
        )
        await self.server._process_thought(thought2)

        # Create a branch
        branch_thought = ThoughtData(
            thought="Alternative approach",
            thoughtNumber=3,
            totalThoughts=4,
            nextThoughtNeeded=True,
            branchFromThought=2,
            branchId="alternative"
        )
        await self.server._process_thought(branch_thought)

        # Check that branch was created
        assert len(self.server.session.main_thoughts) == 2
        assert "alternative" in self.server.session.branches
        assert len(self.server.session.branches["alternative"]) == 1
        assert self.server.session.branches["alternative"][0].thought == "Alternative approach"

    def test_thought_validation(self):
        """Test thought data validation."""
        # Valid thought
        valid_thought = ThoughtData(
            thought="Valid thought",
            thoughtNumber=1,
            totalThoughts=3,
            nextThoughtNeeded=True
        )
        assert valid_thought.thought == "Valid thought"

        # Invalid thought (missing required fields)
        with pytest.raises(ValueError):
            ThoughtData(
                thought="Invalid thought",
                # Missing thoughtNumber
                totalThoughts=3,
                nextThoughtNeeded=True
            )

        # Invalid thought (thoughtNumber < 1)
        with pytest.raises(ValueError):
            ThoughtData(
                thought="Invalid thought",
                thoughtNumber=0,
                totalThoughts=3,
                nextThoughtNeeded=True
            )

        # Invalid thought (totalThoughts < thoughtNumber)
        with pytest.raises(ValueError):
            ThoughtData(
                thought="Invalid thought",
                thoughtNumber=5,
                totalThoughts=3,
                nextThoughtNeeded=True
            )

    def test_revision_validation(self):
        """Test revision-specific validation."""
        # Valid revision
        valid_revision = ThoughtData(
            thought="Revised thought",
            thoughtNumber=1,
            totalThoughts=3,
            nextThoughtNeeded=True,
            isRevision=True,
            revisesThought=1
        )
        assert valid_revision.is_revision is True
        assert valid_revision.revises_thought == 1

        # Invalid revision (isRevision=True but no revisesThought)
        with pytest.raises(ValueError):
            ThoughtData(
                thought="Invalid revision",
                thoughtNumber=1,
                totalThoughts=3,
                nextThoughtNeeded=True,
                isRevision=True
                # Missing revisesThought
            )

        # Invalid revision (revisesThought without isRevision)
        with pytest.raises(ValueError):
            ThoughtData(
                thought="Invalid revision",
                thoughtNumber=1,
                totalThoughts=3,
                nextThoughtNeeded=True,
                revisesThought=1
                # Missing isRevision=True
            )

    def test_session_summary(self):
        """Test session summary generation."""
        # Empty session
        summary = self.server.session.get_summary()
        assert summary.total_thoughts == 0
        assert summary.main_branch_thoughts == 0
        assert len(summary.branches) == 0
        assert summary.revisions_count == 0
        assert summary.is_complete is False

        # Add some thoughts
        thought1 = ThoughtData(
            thought="First thought",
            thoughtNumber=1,
            totalThoughts=2,
            nextThoughtNeeded=True
        )
        self.server.session.main_thoughts.append(thought1)

        thought2 = ThoughtData(
            thought="Second thought",
            thoughtNumber=2,
            totalThoughts=2,
            nextThoughtNeeded=False  # Complete
        )
        self.server.session.main_thoughts.append(thought2)

        # Add a branch
        branch_thought = ThoughtData(
            thought="Branch thought",
            thoughtNumber=1,
            totalThoughts=1,
            nextThoughtNeeded=False,
            branchFromThought=1,
            branchId="test_branch"
        )
        self.server.session.branches["test_branch"] = [branch_thought]

        # Test updated summary
        summary = self.server.session.get_summary()
        assert summary.total_thoughts == 3
        assert summary.main_branch_thoughts == 2
        assert len(summary.branches) == 1
        assert "test_branch" in summary.branches
        assert summary.is_complete is True  # Last main thought has nextThoughtNeeded=False

    def test_to_display_dict(self):
        """Test ThoughtData to_display_dict method."""
        thought = ThoughtData(
            thought="Test thought",
            thoughtNumber=1,
            totalThoughts=3,
            nextThoughtNeeded=True,
            isRevision=True,
            revisesThought=1
        )

        display_dict = thought.to_display_dict()
        
        # Check that all original field names are preserved
        assert "thoughtNumber" in display_dict
        assert "totalThoughts" in display_dict
        assert "nextThoughtNeeded" in display_dict
        assert "isRevision" in display_dict
        assert "revisesThought" in display_dict

        # Check values
        assert display_dict["thought"] == "Test thought"
        assert display_dict["thoughtNumber"] == 1
        assert display_dict["totalThoughts"] == 3
        assert display_dict["nextThoughtNeeded"] is True
        assert display_dict["isRevision"] is True
        assert display_dict["revisesThought"] == 1

    @pytest.mark.asyncio
    async def test_tool_call_integration(self):
        """Test the full tool call integration."""
        # Mock the server's tool handlers
        server = self.server.server
        
        # Test list_tools
        tools_result = await server._request_handlers["tools/list"]()
        assert len(tools_result.tools) == 1
        assert tools_result.tools[0].name == "think"

        # Test resources
        resources_result = await server._request_handlers["resources/list"]()
        assert len(resources_result.resources) >= 4
        
        resource_uris = [r.uri for r in resources_result.resources]
        assert "thoughts://history" in resource_uris
        assert "thoughts://summary" in resource_uris
        assert "thoughts://branches" in resource_uris
        assert "thoughts://session" in resource_uris

    @pytest.mark.asyncio
    async def test_resource_reading(self):
        """Test resource reading functionality."""
        # Add a test thought
        thought = ThoughtData(
            thought="Test thought for resource",
            thoughtNumber=1,
            totalThoughts=1,
            nextThoughtNeeded=False
        )
        await self.server._process_thought(thought)

        # Test reading history resource
        history_result = await self.server.server._request_handlers["resources/read"]("thoughts://history")
        assert len(history_result.contents) == 1
        history_data = json.loads(history_result.contents[0].text)
        assert len(history_data) == 1
        assert history_data[0]["thought"] == "Test thought for resource"

        # Test reading summary resource
        summary_result = await self.server.server._request_handlers["resources/read"]("thoughts://summary")
        assert len(summary_result.contents) == 1
        summary_data = json.loads(summary_result.contents[0].text)
        assert summary_data["total_thoughts"] == 1
        assert summary_data["is_complete"] is True


if __name__ == "__main__":
    pytest.main([__file__])
