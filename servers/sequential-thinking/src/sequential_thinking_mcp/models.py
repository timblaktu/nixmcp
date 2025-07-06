"""
Data models for the Sequential Thinking MCP server.

This module defines the Pydantic models used for data validation and type safety
throughout the sequential thinking process.
"""

from __future__ import annotations

from typing import Dict, List, Optional
from pydantic import BaseModel, Field, validator


class ThoughtData(BaseModel):
    """
    Represents a single thought in the sequential thinking process.
    
    This model encapsulates all the data needed to track a thought,
    including its content, position in the sequence, and metadata
    about revisions and branches.
    """
    
    thought: str = Field(
        ..., 
        description="The current thinking step content",
        min_length=1
    )
    
    thought_number: int = Field(
        ...,
        description="Current thought number in the sequence",
        ge=1,
        alias="thoughtNumber"
    )
    
    total_thoughts: int = Field(
        ...,
        description="Estimated total number of thoughts needed",
        ge=1,
        alias="totalThoughts"
    )
    
    next_thought_needed: bool = Field(
        ...,
        description="Whether another thought step is needed",
        alias="nextThoughtNeeded"
    )
    
    is_revision: Optional[bool] = Field(
        None,
        description="Whether this thought revises previous thinking",
        alias="isRevision"
    )
    
    revises_thought: Optional[int] = Field(
        None,
        description="Which thought number is being reconsidered",
        ge=1,
        alias="revisesThought"
    )
    
    branch_from_thought: Optional[int] = Field(
        None,
        description="Thought number from which this branches",
        ge=1,
        alias="branchFromThought"
    )
    
    branch_id: Optional[str] = Field(
        None,
        description="Unique identifier for this branch",
        alias="branchId"
    )
    
    needs_more_thoughts: Optional[bool] = Field(
        None,
        description="Whether more thoughts are needed beyond current estimate",
        alias="needsMoreThoughts"
    )

    class Config:
        """Pydantic configuration for ThoughtData."""
        allow_population_by_field_name = True
        validate_assignment = True
        extra = "forbid"

    @validator("revises_thought")
    def validate_revises_thought(cls, v: Optional[int], values: Dict) -> Optional[int]:
        """Validate that revises_thought is consistent with is_revision."""
        if v is not None and not values.get("is_revision"):
            raise ValueError("revises_thought can only be set when is_revision is True")
        if values.get("is_revision") and v is None:
            raise ValueError("revises_thought must be set when is_revision is True")
        return v

    @validator("branch_id")
    def validate_branch_id(cls, v: Optional[str], values: Dict) -> Optional[str]:
        """Validate that branch_id is provided when branching."""
        if v is not None and values.get("branch_from_thought") is None:
            raise ValueError("branch_id requires branch_from_thought to be set")
        return v

    @validator("total_thoughts")
    def validate_total_thoughts(cls, v: int, values: Dict) -> int:
        """Validate that total_thoughts is at least as large as thought_number."""
        thought_number = values.get("thought_number")
        if thought_number is not None and v < thought_number:
            raise ValueError("total_thoughts must be at least as large as thought_number")
        return v

    def to_display_dict(self) -> Dict:
        """Convert to dictionary for display purposes, using original field names."""
        return {
            "thought": self.thought,
            "thoughtNumber": self.thought_number,
            "totalThoughts": self.total_thoughts,
            "nextThoughtNeeded": self.next_thought_needed,
            "isRevision": self.is_revision,
            "revisesThought": self.revises_thought,
            "branchFromThought": self.branch_from_thought,
            "branchId": self.branch_id,
            "needsMoreThoughts": self.needs_more_thoughts,
        }


class ThoughtSummary(BaseModel):
    """
    Summary of the entire thinking process.
    
    This model provides an overview of all thoughts, branches,
    and the overall progress of the sequential thinking session.
    """
    
    total_thoughts: int = Field(
        ...,
        description="Total number of thoughts recorded"
    )
    
    main_branch_thoughts: int = Field(
        ...,
        description="Number of thoughts in the main branch"
    )
    
    branches: List[str] = Field(
        default_factory=list,
        description="List of all branch identifiers"
    )
    
    revisions_count: int = Field(
        default=0,
        description="Total number of revisions made"
    )
    
    is_complete: bool = Field(
        ...,
        description="Whether the thinking process is marked as complete"
    )
    
    last_thought: Optional[ThoughtData] = Field(
        None,
        description="The most recent thought"
    )


class BranchInfo(BaseModel):
    """
    Information about a specific branch in the thinking process.
    
    This model tracks the metadata and thoughts associated with
    a particular branch of reasoning.
    """
    
    branch_id: str = Field(
        ...,
        description="Unique identifier for this branch"
    )
    
    branch_from_thought: int = Field(
        ...,
        description="Thought number from which this branch originated"
    )
    
    thoughts: List[ThoughtData] = Field(
        default_factory=list,
        description="List of thoughts in this branch"
    )
    
    created_at: Optional[str] = Field(
        None,
        description="ISO timestamp when branch was created"
    )


class ThinkingSession(BaseModel):
    """
    Represents a complete thinking session with all thoughts and branches.
    
    This model encapsulates the entire state of a sequential thinking
    session, including the main thought history and all branches.
    """
    
    session_id: str = Field(
        ...,
        description="Unique identifier for this thinking session"
    )
    
    main_thoughts: List[ThoughtData] = Field(
        default_factory=list,
        description="Main sequence of thoughts"
    )
    
    branches: Dict[str, List[ThoughtData]] = Field(
        default_factory=dict,
        description="Dictionary mapping branch IDs to their thoughts"
    )
    
    created_at: Optional[str] = Field(
        None,
        description="ISO timestamp when session was created"
    )
    
    updated_at: Optional[str] = Field(
        None,
        description="ISO timestamp when session was last updated"
    )
    
    def get_summary(self) -> ThoughtSummary:
        """Generate a summary of this thinking session."""
        total_thoughts = len(self.main_thoughts)
        for branch_thoughts in self.branches.values():
            total_thoughts += len(branch_thoughts)
        
        revisions_count = sum(
            1 for thought in self.main_thoughts if thought.is_revision
        )
        for branch_thoughts in self.branches.values():
            revisions_count += sum(
                1 for thought in branch_thoughts if thought.is_revision
            )
        
        is_complete = bool(
            self.main_thoughts and not self.main_thoughts[-1].next_thought_needed
        )
        
        last_thought = None
        if self.main_thoughts:
            last_thought = self.main_thoughts[-1]
        
        return ThoughtSummary(
            total_thoughts=total_thoughts,
            main_branch_thoughts=len(self.main_thoughts),
            branches=list(self.branches.keys()),
            revisions_count=revisions_count,
            is_complete=is_complete,
            last_thought=last_thought
        )
