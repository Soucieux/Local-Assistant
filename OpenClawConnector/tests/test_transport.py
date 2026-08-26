"""OpenClaw agent transport boundary tests."""

from __future__ import annotations

import unittest
from unittest.mock import patch

from local_assistant_connector import constants
from local_assistant_connector.models import ConnectorConfig, ConnectorError
from local_assistant_connector.transport import OpenClawTransport


class FakeJsonClient:
    """Captures one agent request and returns a fixed compatible response."""

    def __init__(self) -> None:
        """Create an empty capture slot."""
        self.document = None

    def post(self, route, token, document):
        """Record the outbound document without using a network."""
        self.document = document
        return {
            constants.FIELD_CHOICES: [
                {
                    constants.FIELD_MESSAGE: {
                        constants.FIELD_CONTENT: "The reminder was updated."
                    }
                }
            ]
        }


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

        with patch.object(transport, "_post", side_effect=capture.post):
            response = transport.send_agent("task-id", "context-id", submitted)

        content = capture.document[constants.FIELD_MESSAGES][0][
            constants.FIELD_CONTENT
        ]
        self.assertEqual(content, submitted)
        self.assertNotIn(constants.FIELD_CALENDAR_CHANGED, response)

    def test_rejects_an_oversized_agent_answer(self) -> None:
        """A bounded HTTP body cannot become an unbounded app message."""
        transport = OpenClawTransport(connector_config())
        document = {
            constants.FIELD_CHOICES: [
                {
                    constants.FIELD_MESSAGE: {
                        constants.FIELD_CONTENT: "x"
                        * (constants.MAX_AGENT_ANSWER_CHARACTERS + 1)
                    }
                }
            ]
        }

        with self.assertRaises(ConnectorError):
            transport._agent_answer(document)

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
