"""Typed connector configuration and workflow state."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping, TypedDict


@dataclass(frozen=True)
class ConnectorConfig:
    """Validated non-secret connector configuration."""

    ssh_host: str
    ssh_port: int
    ssh_user: str
    spool_directory: str
    request_timeout_seconds: float


class ConnectorState(TypedDict, total=False):
    """Durable LangGraph state for one connector task."""

    request: Mapping[str, Any]
    task_id: str
    context_id: str
    skill: str
    response: Mapping[str, Any]
    error_kind: str
    error_message: str
    error_retryable: bool


class ConnectorError(RuntimeError):
    """A typed, privacy-safe connector failure."""

    def __init__(self, kind: str, message: str, retryable: bool) -> None:
        """Create an error without retaining secret or response data."""
        super().__init__(message)
        self.kind = kind
        self.retryable = retryable
