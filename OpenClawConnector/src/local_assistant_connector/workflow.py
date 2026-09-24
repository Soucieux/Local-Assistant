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
    """Validate one UUID in the connector's lowercase wire format.

    Args:
        value: Untrusted identifier from a request.

    Returns:
        The lowercase UUID, or ``None`` when the value is not a UUID written
        in canonical hyphenated form.
    """
    if not isinstance(value, str):
        return None
    try:
        canonical = str(UUID(value))
    except ValueError:
        return None
    return canonical if canonical == value.lower() else None


def _validate_common(document: object) -> tuple[str, str, str]:
    """Validate the envelope fields every connector request shares.

    Args:
        document: Untrusted decoded request.

    Returns:
        The canonical task identifier, the canonical context identifier
        (the task's own when none was sent), and the requested skill.

    Raises:
        ConnectorError: When a field is missing, unknown, mistyped, or names
            an unsupported skill.
    """
    if not isinstance(document, dict):
        raise ConnectorError.invalid_request(constants.ERROR_INVALID_REQUEST)
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
        raise ConnectorError.invalid_request(constants.ERROR_INVALID_REQUEST)
    context_id = document.get(constants.FIELD_CONTEXT_ID)
    canonical_context_id = task_id if context_id is None else _canonical_uuid(context_id)
    if canonical_context_id is None:
        raise ConnectorError.invalid_request(constants.ERROR_INVALID_REQUEST)
    skill = document[constants.FIELD_SKILL]
    if not isinstance(skill, str) or skill not in {
        constants.REMINDER_SKILL,
        constants.AGENT_SKILL,
    }:
        raise ConnectorError.invalid_request(constants.ERROR_UNSUPPORTED_SKILL)
    return task_id, canonical_context_id, skill


class ConnectorWorkflow:
    """Compiles one persistent graph over the two narrowly authorized lanes."""

    def __init__(
        self,
        transport: OpenClawTransport,
        checkpoint_file: Path,
    ) -> None:
        """Create and compile the workflow with SQLite checkpoint persistence.

        Args:
            transport: Transport both lanes send through.
            checkpoint_file: Owner-only SQLite database holding graph state.

        Raises:
            ConnectorError: When the checkpoint file or its directory is a
                link or not the expected kind of file.
        """
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
            raise ConnectorError.invalid_request(constants.ERROR_FILE_BOUNDARY)
        os.chmod(checkpoint_file.parent, constants.OWNER_DIRECTORY_MODE)
        if checkpoint_file.is_symlink():
            raise ConnectorError.invalid_request(constants.ERROR_FILE_BOUNDARY)
        if checkpoint_file.exists():
            metadata = checkpoint_file.lstat()
            if not stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
                raise ConnectorError.invalid_request(constants.ERROR_FILE_BOUNDARY)
        self._checkpoint_context = SqliteSaver.from_conn_string(
            str(checkpoint_file)
        )
        self._checkpointer = self._checkpoint_context.__enter__()
        os.chmod(checkpoint_file, constants.OWNER_FILE_MODE)
        self._closed = False
        builder = StateGraph(ConnectorState)
        builder.add_node(constants.WORKFLOW_NODE_VALIDATE, self._validate_node)
        builder.add_node(constants.WORKFLOW_NODE_REMINDER, self._reminder_node)
        builder.add_node(constants.WORKFLOW_NODE_AGENT, self._agent_node)
        builder.add_edge(START, constants.WORKFLOW_NODE_VALIDATE)
        builder.add_conditional_edges(
            constants.WORKFLOW_NODE_VALIDATE,
            self._route_after_validation,
            {
                constants.REMINDER_SKILL: constants.WORKFLOW_NODE_REMINDER,
                constants.AGENT_SKILL: constants.WORKFLOW_NODE_AGENT,
            },
        )
        builder.add_edge(constants.WORKFLOW_NODE_REMINDER, END)
        builder.add_edge(constants.WORKFLOW_NODE_AGENT, END)
        self._graph = builder.compile(checkpointer=self._checkpointer)

    def close(self) -> None:
        """Close the durable checkpoint connection."""
        if self._closed:
            return
        self._closed = True
        self._checkpoint_context.__exit__(None, None, None)

    def invoke(self, document: Mapping[str, Any]) -> Mapping[str, Any]:
        """Run one request under a stable task-or-context checkpoint thread.

        Args:
            document: Untrusted decoded request; validated inside the graph.

        Returns:
            The response produced by the reminder or agent lane.

        Raises:
            ConnectorError: When validation or the selected lane fails, or the
                graph ends without a response.
        """
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
            raise ConnectorError.operational(constants.ERROR_INTERNAL, retryable=False)
        return response

    def _validate_node(self, state: ConnectorState) -> ConnectorState:
        """Validate the read-only snapshot lane or authorized OpenClaw lane.

        Args:
            state: Graph state holding the untrusted request.

        Returns:
            State with the normalized request and its routing identity.

        Raises:
            ConnectorError: When the request is not exactly what its lane allows.
        """
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
                or constants.FIELD_AUTHORIZATION in document
                or payload
            ):
                raise ConnectorError.invalid_request(constants.ERROR_REMINDER_PAYLOAD)
        else:
            if (
                document[constants.FIELD_OPERATION] != constants.OPERATION_CHAT
                or document[constants.FIELD_CALENDAR_POLICY]
                != constants.CALENDAR_POLICY_OPENCLAW_DEFAULT
                or document[constants.FIELD_CONFIRMED] is not True
                or frozenset(payload) != constants.AGENT_PAYLOAD_FIELDS
            ):
                raise ConnectorError.invalid_request(constants.ERROR_AGENT_PAYLOAD)
            message = payload.get(constants.FIELD_MESSAGE)
            authorization = document.get(constants.FIELD_AUTHORIZATION)
            if (
                not isinstance(message, str)
                or not message.strip()
                or len(message) > constants.MAX_AGENT_MESSAGE_CHARACTERS
                or authorization not in {
                    constants.AUTHORIZATION_EXPLICIT_OPENCLAW,
                    constants.AUTHORIZATION_CONFIRMED_REMINDER_MUTATION,
                }
            ):
                raise ConnectorError.invalid_request(constants.ERROR_AGENT_MESSAGE)
            if (
                authorization == constants.AUTHORIZATION_EXPLICIT_OPENCLAW
                and re.search(constants.OPENCLAW_INVOCATION_PATTERN, message) is None
            ):
                raise ConnectorError.invalid_request(constants.ERROR_OPENCLAW_REQUIRED)
        return {
            "request": normalized_document,
            "task_id": task_id,
            "context_id": context_id,
            "skill": skill,
        }

    def _route_after_validation(self, state: ConnectorState) -> str:
        """Route only to the validated reminder or agent lane.

        Args:
            state: Graph state produced by validation.

        Returns:
            The validated skill, which names the lane to run.
        """
        return state["skill"]

    def _reminder_node(self, state: ConnectorState) -> ConnectorState:
        """Forward the original reminder envelope to the narrow plugin route.

        Args:
            state: Graph state holding the normalized reminder request.

        Returns:
            State carrying the bridge's response.

        Raises:
            ConnectorError: When the transport or response validation fails.
        """
        return {"response": self._transport.send_reminder(state["request"])}

    def _agent_node(self, state: ConnectorState) -> ConnectorState:
        """Send only the exact locally authorized user text to OpenClaw.

        Args:
            state: Graph state holding the normalized agent request.

        Returns:
            State carrying the connector response with the agent's answer.

        Raises:
            ConnectorError: When the transport or response validation fails.
        """
        payload = state["request"][constants.FIELD_PAYLOAD]
        return {
            "response": self._transport.send_agent(
                state["task_id"],
                state["context_id"],
                payload[constants.FIELD_MESSAGE],
            )
        }
