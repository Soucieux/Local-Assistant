"""LangGraph connector routing and disclosure tests."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from uuid import uuid4

from local_assistant_connector import constants
from local_assistant_connector.models import ConnectorError
from local_assistant_connector.workflow import ConnectorWorkflow


TASK_ID = "de43e41a-11d1-460d-b51c-f078690b2bb6"
CONTEXT_ID = "0aa97db3-b0d4-4319-a78d-3eec154316c2"
IDEMPOTENCY_KEY = "a270a1c0-7b54-459f-9b6e-ad01f69826c7"


class FakeTransport:
    """Captures which of the two connector lanes executes."""

    def __init__(self) -> None:
        """Create empty reminder and agent call logs."""
        self.reminders = []
        self.agents = []

    def send_reminder(self, document):
        """Return one typed read-only snapshot response."""
        self.reminders.append(document)
        return {
            constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
            constants.FIELD_TASK_ID: document[constants.FIELD_TASK_ID],
            constants.FIELD_STATUS: constants.STATUS_COMPLETED,
            constants.FIELD_CALENDAR_CHANGED: False,
            constants.FIELD_PAYLOAD: {"success": True, "data": []},
        }

    def send_agent(self, task_id, context_id, message):
        """Return one typed agent response and capture the exact message."""
        self.agents.append((task_id, context_id, message))
        return {
            constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
            constants.FIELD_TASK_ID: task_id,
            constants.FIELD_CONTEXT_ID: context_id,
            constants.FIELD_STATUS: constants.STATUS_COMPLETED,
            constants.FIELD_PAYLOAD: {constants.FIELD_MESSAGE: "Done"},
        }


def request_document(skill, operation, payload, confirmed=False):
    """Build one connector task envelope with the skill's required policy."""
    policy = (
        constants.CALENDAR_POLICY_OPENCLAW_DEFAULT
        if skill == constants.AGENT_SKILL
        else constants.CALENDAR_POLICY_NEVER
    )
    return {
        constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
        constants.FIELD_TASK_ID: TASK_ID,
        constants.FIELD_CONTEXT_ID: CONTEXT_ID,
        constants.FIELD_SKILL: skill,
        constants.FIELD_OPERATION: operation,
        constants.FIELD_IDEMPOTENCY_KEY: IDEMPOTENCY_KEY,
        constants.FIELD_CALENDAR_POLICY: policy,
        constants.FIELD_CONFIRMED: confirmed,
        constants.FIELD_PAYLOAD: payload,
    }


class WorkflowTests(unittest.TestCase):
    """Verify read-only snapshots and exact explicit OpenClaw disclosure."""

    def invoke(self, transport, document):
        """Invoke one isolated graph and close its checkpoint connection."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            workflow = ConnectorWorkflow(
                transport,
                Path(temporary_directory) / "checkpoints.sqlite3",
            )
            try:
                return workflow.invoke(document)
            finally:
                workflow.close()

    def test_reminder_task_uses_only_snapshot_lane(self) -> None:
        """A complete list never reaches the full-operator endpoint."""
        transport = FakeTransport()
        response = self.invoke(
            transport,
            request_document(constants.REMINDER_SKILL, constants.OPERATION_LIST, {}),
        )

        self.assertEqual(response[constants.FIELD_STATUS], constants.STATUS_COMPLETED)
        self.assertEqual(len(transport.reminders), 1)
        self.assertEqual(transport.agents, [])

    def test_normalizes_swift_uuid_case_before_forwarding(self) -> None:
        """Swift UUID strings cannot diverge from lowercase spool filenames."""
        transport = FakeTransport()
        document = request_document(
            constants.REMINDER_SKILL,
            constants.OPERATION_LIST,
            {},
        )
        document[constants.FIELD_TASK_ID] = TASK_ID.upper()
        document[constants.FIELD_CONTEXT_ID] = CONTEXT_ID.upper()
        document[constants.FIELD_IDEMPOTENCY_KEY] = IDEMPOTENCY_KEY.upper()

        response = self.invoke(transport, document)

        forwarded = transport.reminders[0]
        self.assertEqual(forwarded[constants.FIELD_TASK_ID], TASK_ID)
        self.assertEqual(forwarded[constants.FIELD_CONTEXT_ID], CONTEXT_ID)
        self.assertEqual(forwarded[constants.FIELD_IDEMPOTENCY_KEY], IDEMPOTENCY_KEY)
        self.assertEqual(response[constants.FIELD_TASK_ID], TASK_ID)

    def test_missing_uuid_field_is_a_typed_invalid_request(self) -> None:
        """A malformed spool document never escapes validation as a KeyError."""
        transport = FakeTransport()
        document = request_document(
            constants.REMINDER_SKILL,
            constants.OPERATION_LIST,
            {},
        )
        del document[constants.FIELD_TASK_ID]

        with self.assertRaisesRegex(
            ConnectorError,
            constants.ERROR_INVALID_REQUEST,
        ):
            self.invoke(transport, document)

    def test_reminder_lane_rejects_every_non_list_operation(self) -> None:
        """Exact reads and confirmed writes cannot widen the snapshot lane."""
        for operation in ("get", "create", "update", "delete"):
            with self.subTest(operation=operation):
                with self.assertRaises(ConnectorError):
                    self.invoke(
                        FakeTransport(),
                        request_document(
                            constants.REMINDER_SKILL,
                            operation,
                            {"id": "r1"},
                            confirmed=True,
                        ),
                    )

    def test_agent_task_forwards_only_exact_explicit_message(self) -> None:
        """The only agent payload field is a message that names OpenClaw."""
        transport = FakeTransport()
        message = "OpenClaw, update the permit reminder."
        response = self.invoke(
            transport,
            request_document(
                constants.AGENT_SKILL,
                constants.OPERATION_CHAT,
                {constants.FIELD_MESSAGE: message},
                confirmed=True,
            ),
        )

        self.assertEqual(transport.agents[0][2], message)
        self.assertNotIn(constants.FIELD_CALENDAR_CHANGED, response)

    def test_agent_context_accepts_sequential_explicit_messages(self) -> None:
        """One stable context handles later exact messages without replaying earlier text."""
        transport = FakeTransport()
        with tempfile.TemporaryDirectory() as temporary_directory:
            checkpoint_file = Path(temporary_directory) / "checkpoints.sqlite3"
            workflow = ConnectorWorkflow(transport, checkpoint_file)
            try:
                for message in (
                    "OpenClaw, first question",
                    "Open Claw, second question",
                ):
                    document = request_document(
                        constants.AGENT_SKILL,
                        constants.OPERATION_CHAT,
                        {constants.FIELD_MESSAGE: message},
                        confirmed=True,
                    )
                    document[constants.FIELD_TASK_ID] = str(uuid4())
                    document[constants.FIELD_IDEMPOTENCY_KEY] = str(uuid4())
                    workflow.invoke(document)
            finally:
                workflow.close()

            self.assertEqual(checkpoint_file.stat().st_mode & 0o777, 0o600)

        self.assertEqual(
            [call[2] for call in transport.agents],
            ["OpenClaw, first question", "Open Claw, second question"],
        )

    def test_agent_rejects_context_fields(self) -> None:
        """Cached reminders, files, history, and arbitrary metadata cannot enter the lane."""
        payload = {
            constants.FIELD_MESSAGE: "OpenClaw, use this.",
            "selectedReminders": [{"id": "r1", "text": "private"}],
        }
        with self.assertRaises(ConnectorError):
            self.invoke(
                FakeTransport(),
                request_document(
                    constants.AGENT_SKILL,
                    constants.OPERATION_CHAT,
                    payload,
                    confirmed=True,
                ),
            )

    def test_agent_rejects_message_without_explicit_openclaw_name(self) -> None:
        """Connector-side validation independently enforces the app's routing gate."""
        with self.assertRaises(ConnectorError):
            self.invoke(
                FakeTransport(),
                request_document(
                    constants.AGENT_SKILL,
                    constants.OPERATION_CHAT,
                    {constants.FIELD_MESSAGE: "Update the permit reminder."},
                    confirmed=True,
                ),
            )


if __name__ == "__main__":
    unittest.main()
