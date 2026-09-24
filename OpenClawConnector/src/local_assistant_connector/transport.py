"""Tunnel-local HTTP transport for reminder and agent lanes."""

from __future__ import annotations

import json
import time
from typing import Any, Mapping
from urllib import error, parse, request
from uuid import uuid4

from . import constants
from .a2a import (
    parse_send_message_response,
    send_message_request,
    validate_agent_card,
)
from .keychain import load_token
from .models import ConnectorConfig, ConnectorError
from .ssh_tunnel import OpenClawSSHTunnel


def reminder_snapshot_request(task_id: str) -> dict[str, Any]:
    """Build the only reminder request the connector ever originates.

    Args:
        task_id: Canonical UUID that the response must echo.

    Returns:
        An unconfirmed, read-only request for one complete reminder snapshot
        that never touches Calendar.
    """
    return {
        constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
        constants.FIELD_TASK_ID: task_id,
        constants.FIELD_SKILL: constants.REMINDER_SKILL,
        constants.FIELD_OPERATION: constants.OPERATION_LIST,
        constants.FIELD_IDEMPOTENCY_KEY: str(uuid4()),
        constants.FIELD_CALENDAR_POLICY: constants.CALENDAR_POLICY_NEVER,
        constants.FIELD_CONFIRMED: False,
        constants.FIELD_PAYLOAD: {},
    }


class _ExactOriginRedirectHandler(request.HTTPRedirectHandler):
    """Reject redirects away from the explicitly configured origin."""

    def __init__(self, origin: tuple[str, str]) -> None:
        """Create a guard for one tunnel-local scheme and authority.

        Args:
            origin: Scheme and network location every redirect must keep.
        """
        super().__init__()
        self._origin = origin

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        """Allow only same-origin redirects.

        Args:
            req: Request that received the redirect.
            fp: Response body of the redirect.
            code: HTTP status of the redirect.
            msg: HTTP reason phrase of the redirect.
            headers: Response headers of the redirect.
            newurl: Location the server asked the client to follow.

        Returns:
            The follow-up request the standard handler builds.

        Raises:
            ConnectorError: When the location leaves the configured origin.
        """
        parsed = parse.urlsplit(newurl)
        if (parsed.scheme, parsed.netloc) != self._origin:
            raise ConnectorError.operational(constants.ERROR_REDIRECT, retryable=False)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class _JsonClient:
    """Bounded JSON client for one exact loopback origin."""

    def __init__(self, origin: str, timeout_seconds: float) -> None:
        """Create a client for a validated configuration origin.

        Args:
            origin: Local HTTP origin of the open tunnel.
            timeout_seconds: Longest one attempt may wait for the server.
        """
        parsed = parse.urlsplit(origin)
        self._origin = origin
        self._timeout_seconds = timeout_seconds
        self._opener = request.build_opener(
            _ExactOriginRedirectHandler((parsed.scheme, parsed.netloc))
        )

    def get(self, route: str, token: str) -> Mapping[str, Any]:
        """GET one authenticated bounded JSON object.

        Args:
            route: Absolute path on the tunnel origin.
            token: Bearer credential scoped to that route.

        Returns:
            The decoded response object.

        Raises:
            ConnectorError: When the request fails or the response is invalid.
        """
        http_request = request.Request(
            self._origin + route,
            headers={
                constants.HEADER_AUTHORIZATION: constants.BEARER_PREFIX + token,
                constants.HEADER_ACCEPT: constants.CONTENT_TYPE_JSON,
            },
            method=constants.HTTP_GET,
        )
        return self._perform(http_request)

    def post(
        self,
        route: str,
        token: str,
        document: Mapping[str, Any],
        content_type: str = constants.CONTENT_TYPE_JSON,
    ) -> Mapping[str, Any]:
        """POST one authenticated bounded JSON object with retryable status handling.

        Args:
            route: Absolute path on the tunnel origin.
            token: Bearer credential scoped to that route.
            document: JSON-serializable request body.
            content_type: Media type sent and accepted.

        Returns:
            The decoded response object.

        Raises:
            ConnectorError: When the body is too large, the request fails, or
                the response is invalid.
        """
        body = json.dumps(
            document, separators=(",", ":"), ensure_ascii=False
        ).encode("utf-8")
        if len(body) > constants.MAX_REQUEST_BYTES:
            raise ConnectorError.invalid_request(constants.ERROR_TOO_LARGE)
        http_request = request.Request(
            self._origin + route,
            data=body,
            headers={
                constants.HEADER_AUTHORIZATION: constants.BEARER_PREFIX + token,
                constants.HEADER_CONTENT_TYPE: content_type,
                constants.HEADER_ACCEPT: content_type,
            },
            method=constants.HTTP_POST,
        )
        return self._perform(http_request)

    def _perform(self, http_request: request.Request) -> Mapping[str, Any]:
        """Perform one bounded request with the connector retry policy.

        Args:
            http_request: Prepared request for the tunnel origin.

        Returns:
            The decoded response object.

        Raises:
            ConnectorError: When authentication is rejected, every attempt
                fails, or the response is invalid.
        """
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
                if exc.code in constants.AUTHENTICATION_HTTP_STATUS:
                    raise ConnectorError.operational(
                        constants.ERROR_AUTHENTICATION,
                        retryable=False,
                    ) from exc
                retryable = exc.code in constants.RETRYABLE_HTTP_STATUS
                if retryable and attempt + 1 < constants.MAX_RETRY_ATTEMPTS:
                    time.sleep(constants.RETRY_BASE_SECONDS * (2**attempt))
                    continue
                raise ConnectorError.operational(
                    constants.ERROR_REMOTE,
                    retryable=retryable,
                ) from exc
            except (error.URLError, TimeoutError, OSError) as exc:
                if attempt + 1 < constants.MAX_RETRY_ATTEMPTS:
                    time.sleep(constants.RETRY_BASE_SECONDS * (2**attempt))
                    continue
                raise ConnectorError.operational(
                    constants.ERROR_UNREACHABLE,
                    retryable=True,
                ) from exc
        raise ConnectorError.operational(constants.ERROR_REMOTE, retryable=True)

    def _decode(self, raw: bytes) -> Mapping[str, Any]:
        """Decode one bounded remote JSON object.

        Args:
            raw: Response body, read one byte past the size bound.

        Returns:
            The decoded response object.

        Raises:
            ConnectorError: When the body is too large or not a JSON object.
        """
        if len(raw) > constants.MAX_RESPONSE_BYTES:
            raise ConnectorError.operational(
                constants.ERROR_REMOTE_RESPONSE,
                retryable=True,
            )
        try:
            document = json.loads(raw.decode("utf-8"))
        except (UnicodeError, json.JSONDecodeError) as exc:
            raise ConnectorError.operational(
                constants.ERROR_REMOTE_RESPONSE,
                retryable=True,
            ) from exc
        if not isinstance(document, dict):
            raise ConnectorError.operational(
                constants.ERROR_REMOTE_RESPONSE,
                retryable=True,
            )
        return document


class OpenClawTransport:
    """Uses one ephemeral tunnel origin with separately scoped credentials."""

    def __init__(self, config: ConnectorConfig) -> None:
        """Retain validated SSH settings without opening a persistent connection.

        Args:
            config: Validated server address, port, account, and timeout.
        """
        self._config = config

    def _post(
        self,
        route: str,
        token_account: str,
        document: Mapping[str, Any],
    ) -> Mapping[str, Any]:
        """Open one tunnel, perform one exact-local-origin request, then close it.

        Args:
            route: Absolute path on the tunnel origin.
            token_account: Keychain account holding that route's credential.
            document: JSON-serializable request body.

        Returns:
            The decoded response object.

        Raises:
            ConnectorError: When the tunnel, credential, request, or response fails.
        """
        with OpenClawSSHTunnel(self._config) as origin:
            client = _JsonClient(origin, self._config.request_timeout_seconds)
            return client.post(route, load_token(token_account), document)

    def send_reminder(self, document: Mapping[str, Any]) -> Mapping[str, Any]:
        """Forward one CloudBase-only reminder envelope.

        Args:
            document: Validated reminder request.

        Returns:
            The bridge's response for the same task.

        Raises:
            ConnectorError: When the request fails, or the response reports a
                Calendar change, another task, or an unknown status.
        """
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
            raise ConnectorError.operational(
                constants.ERROR_REMOTE_RESPONSE,
                retryable=False,
            )
        return response

    def verify_reminder_snapshot(self) -> None:
        """Require one authenticated, complete, read-only reminder snapshot.

        Raises:
            ConnectorError: When the request fails or the snapshot is incomplete.
        """
        response = self.send_reminder(reminder_snapshot_request(str(uuid4())))
        payload = response.get(constants.FIELD_PAYLOAD)
        if (
            response.get(constants.FIELD_STATUS) != constants.STATUS_COMPLETED
            or not isinstance(payload, dict)
            or payload.get(constants.FIELD_SUCCESS) is not True
            or not isinstance(payload.get(constants.FIELD_DATA), list)
        ):
            raise ConnectorError.operational(
                constants.ERROR_VERIFICATION,
                retryable=True,
            )

    def send_agent(
        self,
        task_id: str,
        context_id: str,
        message: str,
    ) -> Mapping[str, Any]:
        """Discover OpenClaw and send only exact user text over A2A v1.0.

        Args:
            task_id: Canonical UUID of the connector task.
            context_id: Canonical UUID of the conversation it continues.
            message: Exact text the user authorized.

        Returns:
            The connector response carrying the agent's answer and status.

        Raises:
            ConnectorError: When the tunnel, credential, Agent Card, request,
                or response fails validation.
        """
        token = load_token(constants.KEYCHAIN_AGENT_ACCOUNT)
        with OpenClawSSHTunnel(self._config) as origin:
            client = _JsonClient(origin, self._config.request_timeout_seconds)
            validate_agent_card(
                client.get(constants.A2A_AGENT_CARD_ROUTE_PATH, token)
            )
            remote = client.post(
                constants.A2A_AGENT_ROUTE_PATH,
                token,
                send_message_request(task_id, context_id, message),
                constants.CONTENT_TYPE_A2A_JSON,
            )
        answer, status = parse_send_message_response(remote, task_id, context_id)
        return {
            constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
            constants.FIELD_TASK_ID: task_id,
            constants.FIELD_CONTEXT_ID: context_id,
            constants.FIELD_STATUS: status,
            constants.FIELD_PAYLOAD: {constants.FIELD_MESSAGE: answer},
        }

    def verify_agent_card(self) -> None:
        """Require the authenticated OpenClaw A2A v1.0 capability declaration.

        Raises:
            ConnectorError: When the tunnel, credential, or Agent Card fails.
        """
        token = load_token(constants.KEYCHAIN_AGENT_ACCOUNT)
        with OpenClawSSHTunnel(self._config) as origin:
            client = _JsonClient(origin, self._config.request_timeout_seconds)
            validate_agent_card(
                client.get(constants.A2A_AGENT_CARD_ROUTE_PATH, token)
            )
