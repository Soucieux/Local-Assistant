"""Durable LangGraph routing for reminder and agent tasks."""

from __future__ import annotations

import os
import re
import stat
from pathlib import Path
from typing import Any, Mapping
from uuid import UUID

from langgraph.checkpoint.sqlite import SqliteSaver
from langgraph.graph import END, START, StateGraph

from . import constants
from .models import ConnectorError, ConnectorState
from .transport import OpenClawTransport


def _canonical_uuid(value: object) -> str | None:
    """Return one validated UUID in the connector's lowercase wire format."""
    if not isinstance(value, str):
        return None
    try:
        canonical = str(UUID(value))
    except ValueError:
        return None
    return canonical if canonical == value.lower() else None


def _validate_common(document: object) -> tuple[str, str, str]:
    """Validate common connector envelope fields and return routing identity."""
    if not isinstance(document, dict):
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_INVALID_REQUEST,
            False,
        )
    fields = frozenset(document)
    task_id = _canonical_uuid(document.get(constants.FIELD_TASK_ID))
    idempotency_key = _canonical_uuid(document.get(constants.FIELD_IDEMPOTENCY_KEY))
    if (
        not constants.REQUEST_REQUIRED_FIELDS.issubset(fields)
        or not fields.issubset(
            constants.REQUEST_REQUIRED_FIELDS | constants.REQUEST_OPTIONAL_FIELDS
        )
        or type(document[constants.FIELD_SCHEMA_VERSION]) is not int
        or document[constants.FIELD_SCHEMA_VERSION] != constants.SCHEMA_VERSION
        or task_id is None
        or idempotency_key is None
        or not isinstance(document[constants.FIELD_PAYLOAD], dict)
        or not isinstance(document[constants.FIELD_CONFIRMED], bool)
        or not isinstance(document[constants.FIELD_CALENDAR_POLICY], str)
    ):
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_INVALID_REQUEST,
            False,
        )
    context_id = document.get(constants.FIELD_CONTEXT_ID)
    canonical_context_id = task_id if context_id is None else _canonical_uuid(context_id)
    if canonical_context_id is None:
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_INVALID_REQUEST,
            False,
        )
    skill = document[constants.FIELD_SKILL]
    if not isinstance(skill, str) or skill not in {
        constants.REMINDER_SKILL,
        constants.AGENT_SKILL,
    }:
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_UNSUPPORTED_SKILL,
            False,
        )
    return task_id, canonical_context_id, skill


class ConnectorWorkflow:
    """Compiles one persistent graph over the two explicitly allowed lanes."""

    def __init__(
        self,
        transport: OpenClawTransport,
        checkpoint_file: Path,
    ) -> None:
        """Create and compile the workflow with SQLite checkpoint persistence."""
        self._transport = transport
        checkpoint_file.parent.mkdir(
            parents=True,
            exist_ok=True,
            mode=constants.OWNER_DIRECTORY_MODE,
        )
        parent_metadata = checkpoint_file.parent.lstat()
        if (
            not stat.S_ISDIR(parent_metadata.st_mode)
            or stat.S_ISLNK(parent_metadata.st_mode)
        ):
            raise ConnectorError(
                constants.ERROR_KIND_INVALID_REQUEST,
                constants.ERROR_FILE_BOUNDARY,
                False,
            )
        os.chmod(checkpoint_file.parent, constants.OWNER_DIRECTORY_MODE)
        if checkpoint_file.is_symlink():
            raise ConnectorError(
                constants.ERROR_KIND_INVALID_REQUEST,
                constants.ERROR_FILE_BOUNDARY,
                False,
            )
        if checkpoint_file.exists():
            metadata = checkpoint_file.lstat()
            if not stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
                raise ConnectorError(
                    constants.ERROR_KIND_INVALID_REQUEST,
                    constants.ERROR_FILE_BOUNDARY,
                    False,
                )
        self._checkpoint_context = SqliteSaver.from_conn_string(
            str(checkpoint_file)
        )
        self._checkpointer = self._checkpoint_context.__enter__()
        os.chmod(checkpoint_file, constants.OWNER_FILE_MODE)
        self._closed = False
        builder = StateGraph(ConnectorState)
        builder.add_node("validate", self._validate_node)
        builder.add_node("reminder", self._reminder_node)
        builder.add_node("agent", self._agent_node)
        builder.add_edge(START, "validate")
        builder.add_conditional_edges(
            "validate",
            self._route_after_validation,
            {
                constants.REMINDER_SKILL: "reminder",
                constants.AGENT_SKILL: "agent",
            },
        )
        builder.add_edge("reminder", END)
        builder.add_edge("agent", END)
        self._graph = builder.compile(checkpointer=self._checkpointer)

    def close(self) -> None:
        """Close the durable checkpoint connection."""
        if self._closed:
            return
        self._closed = True
        self._checkpoint_context.__exit__(None, None, None)

    def invoke(self, document: Mapping[str, Any]) -> Mapping[str, Any]:
        """Run one request under a stable task-or-context checkpoint thread."""
        task_id = document.get(constants.FIELD_TASK_ID)
        context_id = document.get(constants.FIELD_CONTEXT_ID)
        thread_id = _canonical_uuid(context_id) or _canonical_uuid(task_id)
        if thread_id is None:
            thread_id = constants.INVALID_REQUEST_THREAD_ID
        state = self._graph.invoke(
            {"request": document},
            {"configurable": {"thread_id": thread_id}},
        )
        response = state.get("response")
        if not isinstance(response, dict):
            raise ConnectorError(
                constants.ERROR_KIND_OPERATIONAL,
                constants.ERROR_INTERNAL,
                False,
            )
        return response

    def _validate_node(self, state: ConnectorState) -> ConnectorState:
        """Validate the read-only snapshot lane or explicit OpenClaw lane."""
        document = state["request"]
        task_id, context_id, skill = _validate_common(document)
        normalized_document = dict(document)
        normalized_document[constants.FIELD_TASK_ID] = task_id
        normalized_document[constants.FIELD_IDEMPOTENCY_KEY] = str(
            UUID(document[constants.FIELD_IDEMPOTENCY_KEY])
        )
        if constants.FIELD_CONTEXT_ID in normalized_document:
            normalized_document[constants.FIELD_CONTEXT_ID] = context_id
        payload = document[constants.FIELD_PAYLOAD]
        if skill == constants.REMINDER_SKILL:
            if (
                document[constants.FIELD_OPERATION] != constants.OPERATION_LIST
                or document[constants.FIELD_CALENDAR_POLICY]
                != constants.CALENDAR_POLICY_NEVER
                or document[constants.FIELD_CONFIRMED] is not False
                or payload
            ):
                raise ConnectorError(
                    constants.ERROR_KIND_INVALID_REQUEST,
                    constants.ERROR_REMINDER_PAYLOAD,
                    False,
                )
        else:
            if (
                document[constants.FIELD_OPERATION] != constants.OPERATION_CHAT
                or document[constants.FIELD_CALENDAR_POLICY]
                != constants.CALENDAR_POLICY_OPENCLAW_DEFAULT
                or document[constants.FIELD_CONFIRMED] is not True
                or frozenset(payload) != constants.AGENT_PAYLOAD_FIELDS
            ):
                raise ConnectorError(
                    constants.ERROR_KIND_INVALID_REQUEST,
                    constants.ERROR_AGENT_PAYLOAD,
                    False,
                )
            message = payload.get(constants.FIELD_MESSAGE)
            if (
                not isinstance(message, str)
                or not message.strip()
                or len(message) > constants.MAX_AGENT_MESSAGE_CHARACTERS
            ):
                raise ConnectorError(
                    constants.ERROR_KIND_INVALID_REQUEST,
                    constants.ERROR_AGENT_MESSAGE,
                    False,
                )
            if re.search(constants.OPENCLAW_INVOCATION_PATTERN, message) is None:
                raise ConnectorError(
                    constants.ERROR_KIND_INVALID_REQUEST,
                    constants.ERROR_OPENCLAW_REQUIRED,
                    False,
                )
        return {
            "request": normalized_document,
            "task_id": task_id,
            "context_id": context_id,
            "skill": skill,
        }

    def _route_after_validation(self, state: ConnectorState) -> str:
        """Route only to the validated reminder or agent lane."""
        return state["skill"]

    def _reminder_node(self, state: ConnectorState) -> ConnectorState:
        """Forward the original reminder envelope to the narrow plugin route."""
        return {"response": self._transport.send_reminder(state["request"])}

    def _agent_node(self, state: ConnectorState) -> ConnectorState:
        """Send only the exact explicit user text to OpenClaw."""
        payload = state["request"][constants.FIELD_PAYLOAD]
        return {
            "response": self._transport.send_agent(
                state["task_id"],
                state["context_id"],
                payload[constants.FIELD_MESSAGE],
            )
        }
