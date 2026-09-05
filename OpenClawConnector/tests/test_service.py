"""One-shot scheduled snapshot service tests."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from uuid import uuid4

from local_assistant_connector import constants
from local_assistant_connector.models import ConnectorConfig
from local_assistant_connector.service import ConnectorService
from local_assistant_connector.workflow import ConnectorWorkflow


class FakeWorkflow:
    """Return a complete reminder snapshot without opening a network route."""

    def __init__(self) -> None:
        self.documents = []

    def invoke(self, document):
        """Record the request and return one complete snapshot response."""
        self.documents.append(document)
        return {
            constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
            constants.FIELD_TASK_ID: document[constants.FIELD_TASK_ID],
            constants.FIELD_STATUS: constants.STATUS_COMPLETED,
            constants.FIELD_CALENDAR_CHANGED: False,
            constants.FIELD_PAYLOAD: {constants.FIELD_SUCCESS: True, constants.FIELD_DATA: []},
        }


class LowercaseTransport:
    """Echo one response only after Swift-style UUIDs are canonicalized."""

    def send_reminder(self, document):
        """Return one response only after both UUIDs arrive canonicalized."""
        task_id = document[constants.FIELD_TASK_ID]
        idempotency_key = document[constants.FIELD_IDEMPOTENCY_KEY]
        if task_id != task_id.lower() or idempotency_key != idempotency_key.lower():
            raise AssertionError("workflow forwarded a non-canonical UUID")
        return {
            constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
            constants.FIELD_TASK_ID: task_id,
            constants.FIELD_STATUS: constants.STATUS_COMPLETED,
            constants.FIELD_CALENDAR_CHANGED: False,
            constants.FIELD_PAYLOAD: {constants.FIELD_SUCCESS: True, constants.FIELD_DATA: []},
        }


class ServiceTests(unittest.TestCase):
    """Verify launchd runs create only a due complete snapshot."""

    def test_due_schedule_publishes_one_complete_snapshot_and_stops(self) -> None:
        """A due launchd run publishes one snapshot and reports itself stopped."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            spool_directory = Path(temporary_directory) / "spool"
            spool_directory.mkdir()
            (spool_directory / constants.SCHEDULE_FILE_NAME).write_text(
                json.dumps(
                    {
                        constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
                        constants.SCHEDULE_KEY_ENABLED: True,
                        constants.SCHEDULE_KEY_INTERVAL_MINUTES: 240,
                    }
                ),
                encoding="utf-8",
            )
            workflow = FakeWorkflow()
            service = ConnectorService(
                config=ConnectorConfig(
                    ssh_host="openclaw.example.test",
                    ssh_port=22,
                    ssh_user="local-assistant-tunnel",
                    spool_directory=str(spool_directory),
                    request_timeout_seconds=20,
                ),
                workflow=workflow,
            )
            try:
                self.assertEqual(service.process_once(), 0)
            finally:
                service.close()

            self.assertEqual(len(workflow.documents), 1)
            response = json.loads(
                (
                    spool_directory
                    / constants.RESPONSES_DIRECTORY_NAME
                    / constants.SCHEDULED_SNAPSHOT_FILE_NAME
                ).read_text(encoding="utf-8")
            )
            self.assertEqual(response[constants.FIELD_STATUS], constants.STATUS_COMPLETED)
            status = json.loads(
                (spool_directory / constants.STATUS_FILE_NAME).read_text(encoding="utf-8")
            )
            self.assertFalse(status[constants.STATUS_KEY_RUNNING])
            self.assertEqual(
                status[constants.STATUS_KEY_RUNTIME_CONTRACT_VERSION],
                constants.RUNTIME_CONTRACT_VERSION,
            )
            self.assertIsNotNone(status[constants.STATUS_KEY_LAST_REMINDER_SUCCESS_AT])

    def test_swift_uuid_case_does_not_turn_valid_response_into_internal_error(self) -> None:
        """The lowercase spool filename remains equal to the normalized response task ID."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            spool_directory = root / "spool"
            requests = spool_directory / constants.REQUESTS_DIRECTORY_NAME
            requests.mkdir(parents=True)
            task_id = str(uuid4())
            request = {
                constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
                constants.FIELD_TASK_ID: task_id.upper(),
                constants.FIELD_SKILL: constants.REMINDER_SKILL,
                constants.FIELD_OPERATION: constants.OPERATION_LIST,
                constants.FIELD_IDEMPOTENCY_KEY: str(uuid4()).upper(),
                constants.FIELD_CALENDAR_POLICY: constants.CALENDAR_POLICY_NEVER,
                constants.FIELD_CONFIRMED: False,
                constants.FIELD_PAYLOAD: {},
            }
            (requests / f"{task_id}.json").write_text(
                json.dumps(request),
                encoding="utf-8",
            )
            workflow = ConnectorWorkflow(LowercaseTransport(), root / "checkpoint.sqlite3")
            service = ConnectorService(
                config=ConnectorConfig(
                    ssh_host="openclaw.example.test",
                    ssh_port=22,
                    ssh_user="local-assistant-tunnel",
                    spool_directory=str(spool_directory),
                    request_timeout_seconds=20,
                ),
                workflow=workflow,
            )
            try:
                self.assertEqual(service.process_once(), 1)
            finally:
                service.close()
                workflow.close()

            response = json.loads(
                (
                    spool_directory
                    / constants.RESPONSES_DIRECTORY_NAME
                    / f"{task_id}.json"
                ).read_text(encoding="utf-8")
            )
            self.assertEqual(response[constants.FIELD_TASK_ID], task_id)
            self.assertEqual(response[constants.FIELD_STATUS], constants.STATUS_COMPLETED)
            self.assertNotIn(constants.FIELD_ERROR, response)


if __name__ == "__main__":
    unittest.main()
