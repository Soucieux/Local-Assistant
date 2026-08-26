"""Atomic spool behavior tests."""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path

from local_assistant_connector import constants
from local_assistant_connector.models import ConnectorError
from local_assistant_connector.spool import SpoolStore


TASK_ID = "9a570416-c54f-4521-b943-96d46401041d"


class SpoolTests(unittest.TestCase):
    """Verify owner-only claim and response handoff."""

    def test_claim_and_publish_are_atomic(self) -> None:
        """A response appears only after the request leaves the queue."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            spool = SpoolStore(temporary_directory)
            request_path = spool.requests / f"{TASK_ID}.json"
            request_path.write_text(
                json.dumps({constants.FIELD_TASK_ID: TASK_ID}),
                encoding="utf-8",
            )
            os.chmod(request_path, constants.OWNER_FILE_MODE)

            claimed = spool.claim(request_path)
            self.assertIsNotNone(claimed)
            self.assertFalse(request_path.exists())
            spool.publish_response(
                TASK_ID,
                {
                    constants.FIELD_TASK_ID: TASK_ID,
                    constants.FIELD_STATUS: constants.STATUS_COMPLETED,
                },
                claimed,
            )

            response_path = spool.responses / f"{TASK_ID}.json"
            self.assertTrue(response_path.is_file())
            self.assertEqual(response_path.stat().st_mode & 0o777, 0o600)
            self.assertFalse(claimed.exists())

    def test_rejects_an_oversized_response_before_publication(self) -> None:
        """The app's response ceiling is enforced on the serialized file."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            spool = SpoolStore(temporary_directory)
            claimed = spool.processing / f"{TASK_ID}.json"
            claimed.write_text("{}", encoding="utf-8")

            with self.assertRaises(ConnectorError):
                spool.publish_response(
                    TASK_ID,
                    {"message": "x" * constants.MAX_RESPONSE_BYTES},
                    claimed,
                )

            self.assertTrue(claimed.exists())
            self.assertFalse((spool.responses / f"{TASK_ID}.json").exists())

    def test_status_read_never_follows_a_symbolic_link(self) -> None:
        """The status command cannot be redirected to an unrelated file."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            spool = SpoolStore(Path(temporary_directory) / "spool")
            unrelated = Path(temporary_directory) / "unrelated.txt"
            unrelated.write_text("unrelated content", encoding="utf-8")
            spool.status_path.symlink_to(unrelated)

            with self.assertRaises(ConnectorError):
                spool.read_status_text()

    def test_schedule_requires_the_exact_allowlisted_shape(self) -> None:
        """Only the app's enabled flag and supported intervals drive timer runs."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            spool = SpoolStore(temporary_directory)
            spool.schedule_path.write_text(
                json.dumps(
                    {
                        constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
                        constants.SCHEDULE_KEY_ENABLED: True,
                        constants.SCHEDULE_KEY_INTERVAL_MINUTES: 240,
                    }
                ),
                encoding="utf-8",
            )
            os.chmod(spool.schedule_path, constants.OWNER_FILE_MODE)

            self.assertEqual(
                spool.read_schedule_document()[
                    constants.SCHEDULE_KEY_INTERVAL_MINUTES
                ],
                240,
            )

            spool.schedule_path.write_text(
                json.dumps(
                    {
                        constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
                        constants.SCHEDULE_KEY_ENABLED: True,
                        constants.SCHEDULE_KEY_INTERVAL_MINUTES: 60,
                    }
                ),
                encoding="utf-8",
            )
            self.assertIsNone(spool.read_schedule_document())


if __name__ == "__main__":
    unittest.main()
