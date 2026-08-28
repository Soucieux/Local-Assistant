"""Strict A2A v1.0 JSON-RPC request and response validation."""

from __future__ import annotations

from typing import Any, Mapping, NoReturn
from urllib import parse

from . import constants
from .models import ConnectorError


def validate_agent_card(document: Mapping[str, Any]) -> None:
    """Require the private OpenClaw Agent Card and its exact JSON-RPC interface."""
    interfaces = document.get(constants.FIELD_SUPPORTED_INTERFACES)
    if (
        document.get(constants.FIELD_NAME) != constants.A2A_AGENT_NAME
        or not isinstance(document.get(constants.FIELD_VERSION), str)
        or not isinstance(interfaces, list)
    ):
        _raise_card_error()
    for interface in interfaces:
        if not isinstance(interface, dict):
            continue
        endpoint = interface.get(constants.FIELD_URL)
        try:
            parsed = parse.urlsplit(endpoint) if isinstance(endpoint, str) else None
            port = parsed.port if parsed is not None else None
        except ValueError:
            continue
        if (
            parsed is not None
            and parsed.scheme == constants.LOOPBACK_URL_SCHEME
            and parsed.hostname == constants.SSH_REMOTE_GATEWAY_HOST
            and port == constants.SSH_REMOTE_GATEWAY_PORT
            and parsed.path == constants.A2A_AGENT_ROUTE_PATH
            and not parsed.query
            and not parsed.fragment
            and interface.get(constants.FIELD_PROTOCOL_BINDING)
            == constants.A2A_PROTOCOL_BINDING
            and interface.get(constants.FIELD_PROTOCOL_VERSION)
            == constants.A2A_PROTOCOL_VERSION
        ):
            return
    _raise_card_error()


def send_message_request(message_id: str, context_id: str, text: str) -> Mapping[str, Any]:
    """Build one A2A v1.0 SendMessage request from exact authorized user text."""
    return {
        constants.FIELD_JSONRPC: constants.A2A_JSONRPC_VERSION,
        constants.FIELD_ID: message_id,
        constants.FIELD_METHOD: constants.A2A_METHOD_SEND_MESSAGE,
        constants.FIELD_PARAMS: {
            constants.FIELD_MESSAGE: {
                constants.FIELD_MESSAGE_ID: message_id,
                constants.FIELD_CONTEXT_ID: context_id,
                constants.FIELD_ROLE: constants.A2A_ROLE_USER,
                constants.FIELD_PARTS: [
                    {
                        constants.FIELD_TEXT: text,
                        constants.FIELD_MEDIA_TYPE: constants.CONTENT_TYPE_TEXT_PLAIN,
                    }
                ],
            }
        },
    }


def parse_send_message_response(
    document: Mapping[str, Any],
    request_id: str,
    context_id: str,
) -> tuple[str, str]:
    """Return validated text and connector status from an A2A response."""
    if (
        document.get(constants.FIELD_JSONRPC) != constants.A2A_JSONRPC_VERSION
        or document.get(constants.FIELD_ID) != request_id
        or constants.FIELD_ERROR in document
    ):
        _raise_response_error()
    result = document.get(constants.FIELD_RESULT)
    if not isinstance(result, dict):
        _raise_response_error()
    message = result.get(constants.FIELD_MESSAGE)
    connector_status = constants.STATUS_COMPLETED
    if message is None:
        task = result.get(constants.FIELD_TASK)
        if not isinstance(task, dict) or task.get(constants.FIELD_CONTEXT_ID) != context_id:
            _raise_response_error()
        task_status = task.get(constants.FIELD_STATUS)
        if not isinstance(task_status, dict):
            _raise_response_error()
        state = task_status.get(constants.FIELD_STATE)
        if state == constants.A2A_TASK_STATE_INPUT_REQUIRED:
            connector_status = constants.STATUS_INPUT_REQUIRED
        elif state != constants.A2A_TASK_STATE_COMPLETED:
            _raise_response_error()
        message = task_status.get(constants.FIELD_MESSAGE)
    answer = _message_text(message, context_id)
    return answer, connector_status


def _message_text(document: object, context_id: str) -> str:
    """Extract bounded text from one server-authored A2A Message."""
    if (
        not isinstance(document, dict)
        or document.get(constants.FIELD_CONTEXT_ID) != context_id
        or document.get(constants.FIELD_ROLE) != constants.A2A_ROLE_AGENT
        or not isinstance(document.get(constants.FIELD_MESSAGE_ID), str)
    ):
        _raise_response_error()
    parts = document.get(constants.FIELD_PARTS)
    if not isinstance(parts, list) or not parts:
        _raise_response_error()
    texts: list[str] = []
    for part in parts:
        if not isinstance(part, dict):
            _raise_response_error()
        text = part.get(constants.FIELD_TEXT)
        if isinstance(text, str) and text.strip():
            texts.append(text.strip())
    answer = constants.AGENT_ANSWER_SEPARATOR.join(texts)
    if not answer or len(answer) > constants.MAX_AGENT_ANSWER_CHARACTERS:
        _raise_response_error()
    return answer


def _raise_card_error() -> NoReturn:
    """Reject one OpenClaw Agent Card that is missing its exact JSON-RPC interface."""
    raise ConnectorError(
        constants.ERROR_KIND_OPERATIONAL,
        constants.ERROR_A2A_CARD_VERIFICATION,
        False,
    )


def _raise_response_error() -> NoReturn:
    """Reject one A2A response that does not match the sent request exactly."""
    raise ConnectorError(
        constants.ERROR_KIND_OPERATIONAL,
        constants.ERROR_REMOTE_RESPONSE,
        True,
    )
