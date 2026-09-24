"""Typed connector configuration and workflow state."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping, TypedDict

from . import constants


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
        """Create an error without retaining secret or response data.

        Args:
            kind: Stable failure category reported to Local Assistant.
            message: Allowlisted, credential-free explanation.
            retryable: Whether repeating the same request may succeed.
        """
        super().__init__(message)
        self.kind = kind
        self.retryable = retryable

    @classmethod
    def invalid_request(cls, message: str) -> ConnectorError:
        """Build the failure for input that can never succeed as sent.

        Args:
            message: Allowlisted, credential-free explanation.

        Returns:
            A non-retryable invalid-request error.
        """
        return cls(constants.ERROR_KIND_INVALID_REQUEST, message, False)

    @classmethod
    def not_configured(cls, message: str) -> ConnectorError:
        """Build the failure for setup that has not been completed.

        Args:
            message: Allowlisted, credential-free explanation.

        Returns:
            A non-retryable not-configured error.
        """
        return cls(constants.ERROR_KIND_NOT_CONFIGURED, message, False)

    @classmethod
    def operational(cls, message: str, *, retryable: bool) -> ConnectorError:
        """Build the failure for a request that was valid but did not complete.

        Args:
            message: Allowlisted, credential-free explanation.
            retryable: Whether repeating the same request may succeed.

        Returns:
            An operational error with the given retry guidance.
        """
        return cls(constants.ERROR_KIND_OPERATIONAL, message, retryable)
