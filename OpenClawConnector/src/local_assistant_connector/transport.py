"""Tunnel-local HTTP transport for reminder and agent lanes."""

from __future__ import annotations

import json
import time
from typing import Any, Mapping
from urllib import error, parse, request
from uuid import uuid4

from . import constants
from .keychain import load_token
from .models import ConnectorConfig, ConnectorError
from .ssh_tunnel import OpenClawSSHTunnel


class _ExactOriginRedirectHandler(request.HTTPRedirectHandler):
    """Reject redirects away from the explicitly configured origin."""

    def __init__(self, origin: tuple[str, str]) -> None:
        """Create a guard for one tunnel-local scheme and authority."""
        super().__init__()
        self._origin = origin

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        """Allow only same-origin redirects."""
        parsed = parse.urlsplit(newurl)
        if (parsed.scheme, parsed.netloc) != self._origin:
            raise ConnectorError(
                constants.ERROR_KIND_OPERATIONAL,
                constants.ERROR_REDIRECT,
                False,
            )
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class _JsonClient:
    """Bounded JSON client for one exact loopback origin."""

    def __init__(self, origin: str, timeout_seconds: float) -> None:
        """Create a client for a validated configuration origin."""
        parsed = parse.urlsplit(origin)
        self._origin = origin
        self._timeout_seconds = timeout_seconds
        self._opener = request.build_opener(
            _ExactOriginRedirectHandler((parsed.scheme, parsed.netloc))
        )

    def post(self, route: str, token: str, document: Mapping[str, Any]) -> Mapping[str, Any]:
        """POST one authenticated bounded JSON object with retryable status handling."""
        body = json.dumps(
            document, separators=(",", ":"), ensure_ascii=False
        ).encode("utf-8")
        if len(body) > constants.MAX_REQUEST_BYTES:
            raise ConnectorError(
                constants.ERROR_KIND_INVALID_REQUEST,
                constants.ERROR_TOO_LARGE,
                False,
            )
        http_request = request.Request(
            self._origin + route,
            data=body,
            headers={
                constants.HEADER_AUTHORIZATION: constants.BEARER_PREFIX + token,
                constants.HEADER_CONTENT_TYPE: constants.CONTENT_TYPE_JSON,
                constants.HEADER_ACCEPT: constants.CONTENT_TYPE_JSON,
            },
            method=constants.HTTP_POST,
        )
        for attempt in range(constants.MAX_RETRY_ATTEMPTS):
            try:
                with self._opener.open(
                    http_request, timeout=self._timeout_seconds
                ) as response:
                    raw = response.read(constants.MAX_RESPONSE_BYTES + 1)
                return self._decode(raw)
            except ConnectorError:
                raise
            except error.HTTPError as exc:
                if exc.code in {401, 403}:
                    raise ConnectorError(
                        constants.ERROR_KIND_OPERATIONAL,
                        constants.ERROR_AUTHENTICATION,
                        False,
                    ) from exc
                retryable = exc.code in constants.RETRYABLE_HTTP_STATUS
                if retryable and attempt + 1 < constants.MAX_RETRY_ATTEMPTS:
                    time.sleep(constants.RETRY_BASE_SECONDS * (2**attempt))
                    continue
                raise ConnectorError(
                    constants.ERROR_KIND_OPERATIONAL,
                    constants.ERROR_REMOTE,
                    retryable,
                ) from exc
            except (error.URLError, TimeoutError, OSError) as exc:
                if attempt + 1 < constants.MAX_RETRY_ATTEMPTS:
                    time.sleep(constants.RETRY_BASE_SECONDS * (2**attempt))
                    continue
                raise ConnectorError(
                    constants.ERROR_KIND_OPERATIONAL,
                    constants.ERROR_UNREACHABLE,
                    True,
                ) from exc
        raise ConnectorError(
            constants.ERROR_KIND_OPERATIONAL,
            constants.ERROR_REMOTE,
            True,
        )

    def _decode(self, raw: bytes) -> Mapping[str, Any]:
        """Decode one bounded remote JSON object."""
        if len(raw) > constants.MAX_RESPONSE_BYTES:
            raise ConnectorError(
                constants.ERROR_KIND_OPERATIONAL,
                constants.ERROR_REMOTE_RESPONSE,
                True,
            )
        try:
            document = json.loads(raw.decode("utf-8"))
        except (UnicodeError, json.JSONDecodeError) as exc:
            raise ConnectorError(
                constants.ERROR_KIND_OPERATIONAL,
                constants.ERROR_REMOTE_RESPONSE,
                True,
            ) from exc
        if not isinstance(document, dict):
            raise ConnectorError(
                constants.ERROR_KIND_OPERATIONAL,
                constants.ERROR_REMOTE_RESPONSE,
                True,
            )
        return document


class OpenClawTransport:
    """Uses one ephemeral tunnel origin with separately scoped credentials."""

    def __init__(self, config: ConnectorConfig) -> None:
        """Retain validated SSH settings without opening a persistent connection."""
        self._config = config

    def _post(
        self,
        route: str,
        token_account: str,
        document: Mapping[str, Any],
    ) -> Mapping[str, Any]:
        """Open one tunnel, perform one exact-local-origin request, then close it."""
        with OpenClawSSHTunnel(self._config) as origin:
            client = _JsonClient(origin, self._config.request_timeout_seconds)
            return client.post(route, load_token(token_account), document)

    def send_reminder(self, document: Mapping[str, Any]) -> Mapping[str, Any]:
        """Forward one CloudBase-only reminder envelope."""
        response = self._post(
            constants.REMINDER_ROUTE_PATH,
            constants.KEYCHAIN_REMINDER_ACCOUNT,
            document,
        )
        if (
            response.get(constants.FIELD_CALENDAR_CHANGED) is not False
            or response.get(constants.FIELD_TASK_ID) != document.get(constants.FIELD_TASK_ID)
            or response.get(constants.FIELD_STATUS)
            not in {
                constants.STATUS_COMPLETED,
                constants.STATUS_FAILED,
                constants.STATUS_INPUT_REQUIRED,
            }
        ):
            raise ConnectorError(
                constants.ERROR_KIND_OPERATIONAL,
                constants.ERROR_REMOTE_RESPONSE,
                False,
            )
        return response

    def verify_reminder_snapshot(self) -> None:
        """Require one authenticated, complete, read-only reminder snapshot."""
        task_id = str(uuid4())
        response = self.send_reminder(
            {
                constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
                constants.FIELD_TASK_ID: task_id,
                constants.FIELD_SKILL: constants.REMINDER_SKILL,
                constants.FIELD_OPERATION: constants.OPERATION_LIST,
                constants.FIELD_IDEMPOTENCY_KEY: str(uuid4()),
                constants.FIELD_CALENDAR_POLICY: constants.CALENDAR_POLICY_NEVER,
                constants.FIELD_CONFIRMED: False,
                constants.FIELD_PAYLOAD: {},
            }
        )
        payload = response.get(constants.FIELD_PAYLOAD)
        if (
            response.get(constants.FIELD_STATUS) != constants.STATUS_COMPLETED
            or not isinstance(payload, dict)
            or payload.get(constants.FIELD_SUCCESS) is not True
            or not isinstance(payload.get(constants.FIELD_DATA), list)
        ):
            raise ConnectorError(
                constants.ERROR_KIND_OPERATIONAL,
                constants.ERROR_VERIFICATION,
                True,
            )

    def send_agent(
        self,
        task_id: str,
        context_id: str,
        message: str,
    ) -> Mapping[str, Any]:
        """Send only the exact explicit user text to OpenClaw."""
        remote = self._post(
            constants.AGENT_ROUTE_PATH,
            constants.KEYCHAIN_AGENT_ACCOUNT,
            {
                constants.FIELD_MODEL: constants.AGENT_MODEL,
                constants.FIELD_USER: f"local-assistant:{context_id}",
                constants.FIELD_MESSAGES: [
                    {
                        constants.FIELD_ROLE: constants.MESSAGE_ROLE_USER,
                        constants.FIELD_CONTENT: message,
                    }
                ],
                constants.FIELD_STREAM: False,
            },
        )
        answer = self._agent_answer(remote)
        return {
            constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
            constants.FIELD_TASK_ID: task_id,
            constants.FIELD_CONTEXT_ID: context_id,
            constants.FIELD_STATUS: constants.STATUS_COMPLETED,
            constants.FIELD_PAYLOAD: {constants.FIELD_MESSAGE: answer},
        }

    def _agent_answer(self, document: Mapping[str, Any]) -> str:
        """Extract one non-streaming OpenAI-compatible assistant message."""
        choices = document.get(constants.FIELD_CHOICES)
        if not isinstance(choices, list) or not choices:
            raise ConnectorError(
                constants.ERROR_KIND_OPERATIONAL,
                constants.ERROR_REMOTE_RESPONSE,
                True,
            )
        first = choices[0]
        message = first.get(constants.FIELD_MESSAGE) if isinstance(first, dict) else None
        content = message.get(constants.FIELD_CONTENT) if isinstance(message, dict) else None
        if (
            not isinstance(content, str)
            or not content.strip()
            or len(content.strip()) > constants.MAX_AGENT_ANSWER_CHARACTERS
        ):
            raise ConnectorError(
                constants.ERROR_KIND_OPERATIONAL,
                constants.ERROR_REMOTE_RESPONSE,
                True,
            )
        return content.strip()
