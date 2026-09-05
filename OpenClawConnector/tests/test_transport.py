"""OpenClaw agent transport boundary tests."""

from __future__ import annotations

import unittest
from unittest.mock import patch

from local_assistant_connector import constants
from local_assistant_connector.models import ConnectorConfig, ConnectorError
from local_assistant_connector.transport import OpenClawTransport


class FakeJsonClient:
    """Captures one A2A agent request and returns a fixed compatible response."""

    def __init__(self) -> None:
        """Create an empty capture slot."""
        self.document = None

    def get(self, route, token):
        """Return the private A2A v1.0 Agent Card."""
        return {
            constants.FIELD_NAME: "OpenClaw",
            constants.FIELD_VERSION: "1.0.0",
            constants.FIELD_SUPPORTED_INTERFACES: [
                {
                    constants.FIELD_URL: (
                        "http://127.0.0.1:23116"
                        + constants.A2A_AGENT_ROUTE_PATH
                    ),
                    constants.FIELD_PROTOCOL_BINDING: constants.A2A_PROTOCOL_BINDING,
                    constants.FIELD_PROTOCOL_VERSION: constants.A2A_PROTOCOL_VERSION,
                }
            ],
        }

    def post(self, route, token, document, content_type=constants.CONTENT_TYPE_JSON):
        """Record the outbound document without using a network."""
        self.document = document
        return {
            constants.FIELD_JSONRPC: constants.A2A_JSONRPC_VERSION,
            constants.FIELD_ID: document[constants.FIELD_ID],
            constants.FIELD_RESULT: {
                constants.FIELD_MESSAGE: {
                    constants.FIELD_MESSAGE_ID: "reply-id",
                    constants.FIELD_CONTEXT_ID: document[constants.FIELD_PARAMS][
                        constants.FIELD_MESSAGE
                    ][constants.FIELD_CONTEXT_ID],
                    constants.FIELD_ROLE: constants.A2A_ROLE_AGENT,
                    constants.FIELD_PARTS: [
                        {constants.FIELD_TEXT: "The reminder was updated."}
                    ],
                }
            },
        }


class FakeTunnel:
    """Provides one deterministic tunnel-local origin."""

    def __enter__(self):
        """Return the fixed tunnel-local origin."""
        return "http://127.0.0.1:49000"

    def __exit__(self, exc_type, exc_value, traceback):
        """Close the fake tunnel without suppressing an error."""
        return False


class FakeSnapshotClient:
    """Returns one configurable reminder snapshot without using a network."""

    def __init__(self, complete=True) -> None:
        """Store whether the response should satisfy complete-snapshot checks."""
        self.complete = complete

    def post(self, route, token, document):
        """Return a task-bound read-only snapshot response."""
        return {
            constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
            constants.FIELD_TASK_ID: document[constants.FIELD_TASK_ID],
            constants.FIELD_STATUS: constants.STATUS_COMPLETED,
            constants.FIELD_CALENDAR_CHANGED: False,
            constants.FIELD_PAYLOAD: {
                constants.FIELD_SUCCESS: self.complete,
                constants.FIELD_DATA: [] if self.complete else None,
            },
        }


def connector_config() -> ConnectorConfig:
    """Build one exact-origin connector configuration without credentials."""
    return ConnectorConfig(
        ssh_host="openclaw.example.test",
        ssh_port=22,
        ssh_user="local-assistant-tunnel",
        spool_directory="/tmp/local-assistant-test-spool",
        request_timeout_seconds=5.0,
    )


class TransportTests(unittest.TestCase):
    """Verify exact-message disclosure and bounded agent output."""

    def test_sends_only_the_exact_submitted_message(self) -> None:
        """No reminder row, file context, or connector annotation is appended."""
        transport = OpenClawTransport(connector_config())
        capture = FakeJsonClient()
        submitted = "OpenClaw, update the permit reminder."

        with (
            patch(
                "local_assistant_connector.transport.OpenClawSSHTunnel",
                return_value=FakeTunnel(),
            ),
            patch(
                "local_assistant_connector.transport._JsonClient",
                return_value=capture,
            ),
            patch(
                "local_assistant_connector.transport.load_token",
                return_value="agent-token",
            ),
        ):
            response = transport.send_agent("task-id", "context-id", submitted)

        content = capture.document[constants.FIELD_PARAMS][constants.FIELD_MESSAGE][
            constants.FIELD_PARTS
        ][0][constants.FIELD_TEXT]
        self.assertEqual(content, submitted)
        self.assertNotIn(constants.FIELD_CALENDAR_CHANGED, response)

    def test_rejects_an_oversized_agent_answer(self) -> None:
        """A bounded HTTP body cannot become an unbounded app message."""
        transport = OpenClawTransport(connector_config())
        capture = FakeJsonClient()
        original_post = capture.post

        def oversized(route, token, document, content_type=constants.CONTENT_TYPE_JSON):
            response = original_post(route, token, document, content_type)
            response[constants.FIELD_RESULT][constants.FIELD_MESSAGE][
                constants.FIELD_PARTS
            ][0][constants.FIELD_TEXT] = "x" * (
                constants.MAX_AGENT_ANSWER_CHARACTERS + 1
            )
            return response

        capture.post = oversized
        with (
            patch(
                "local_assistant_connector.transport.OpenClawSSHTunnel",
                return_value=FakeTunnel(),
            ),
            patch(
                "local_assistant_connector.transport._JsonClient",
                return_value=capture,
            ),
            patch(
                "local_assistant_connector.transport.load_token",
                return_value="agent-token",
            ),
            self.assertRaises(ConnectorError),
        ):
            transport.send_agent("task-id", "context-id", "OpenClaw, answer.")

    def test_verification_requires_a_complete_read_only_snapshot(self) -> None:
        """Setup success proves the reminder route, credential, and complete payload."""
        transport = OpenClawTransport(connector_config())
        snapshot = FakeSnapshotClient()

        with patch.object(transport, "_post", side_effect=snapshot.post):
            transport.verify_reminder_snapshot()

    def test_verification_rejects_an_incomplete_snapshot(self) -> None:
        """Starting a process cannot be mistaken for a usable connection."""
        transport = OpenClawTransport(connector_config())
        snapshot = FakeSnapshotClient(complete=False)

        with patch.object(transport, "_post", side_effect=snapshot.post):
            with self.assertRaisesRegex(
                ConnectorError,
                constants.ERROR_VERIFICATION,
            ):
                transport.verify_reminder_snapshot()


if __name__ == "__main__":
    unittest.main()
