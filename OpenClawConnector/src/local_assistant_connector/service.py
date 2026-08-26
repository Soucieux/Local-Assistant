"""Polling service that runs connector tasks through the durable graph."""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping
from uuid import uuid4

from . import constants
from .configuration import checkpoint_path, load_config
from .models import ConnectorConfig, ConnectorError
from .spool import SpoolStore
from .transport import OpenClawTransport
from .workflow import ConnectorWorkflow


def _timestamp() -> str:
    """Return one UTC connector status timestamp."""
    return datetime.now(timezone.utc).strftime(constants.ISO8601_UTC_FORMAT)


def _failure_response(
    document: Mapping[str, Any] | None,
    error: ConnectorError,
) -> Mapping[str, Any]:
    """Build a typed response without echoing request content."""
    task_id = document.get(constants.FIELD_TASK_ID) if document else None
    context_id = document.get(constants.FIELD_CONTEXT_ID) if document else None
    response: dict[str, Any] = {
        constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
        constants.FIELD_TASK_ID: task_id,
        constants.FIELD_STATUS: constants.STATUS_FAILED,
        constants.FIELD_ERROR: {
            constants.FIELD_KIND: error.kind,
            constants.FIELD_MESSAGE: str(error),
            constants.FIELD_RETRYABLE: error.retryable,
        },
    }
    if document and document.get(constants.FIELD_SKILL) == constants.REMINDER_SKILL:
        response[constants.FIELD_CALENDAR_CHANGED] = False
    if isinstance(context_id, str):
        response[constants.FIELD_CONTEXT_ID] = context_id
    return response


class ConnectorService:
    """Processes app-owned spool requests without reading any unrelated data."""

    def __init__(
        self,
        config: ConnectorConfig | None = None,
        workflow: ConnectorWorkflow | None = None,
        checkpoint_file: Path | None = None,
    ) -> None:
        """Create the spool, exact-origin transport, and durable workflow."""
        self.config = config or load_config()
        self.spool = SpoolStore(self.config.spool_directory)
        self.spool.recover_claims()
        self.workflow = workflow or ConnectorWorkflow(
            OpenClawTransport(self.config),
            checkpoint_file or checkpoint_path(),
        )
        self._owns_workflow = workflow is None
        prior_status = self.spool.read_status_document() or {}
        prior_success = prior_status.get(constants.STATUS_KEY_LAST_SUCCESS_AT)
        self._last_success_at = prior_success if isinstance(prior_success, str) else None
        prior_reminder_success = prior_status.get(
            constants.STATUS_KEY_LAST_REMINDER_SUCCESS_AT
        )
        self._last_reminder_success_at = (
            prior_reminder_success if isinstance(prior_reminder_success, str) else None
        )
        prior_error = prior_status.get(constants.STATUS_KEY_LAST_ERROR)
        self._last_error = prior_error if isinstance(prior_error, str) else None
        self._closed = False

    def close(self) -> None:
        """Close workflow state and mark the connector stopped."""
        if self._closed:
            return
        self._closed = True
        try:
            self._write_status(False)
        finally:
            if self._owns_workflow:
                self.workflow.close()

    def process_once(self) -> int:
        """Process every currently queued request once and return the count."""
        processed = 0
        self._write_status(True)
        for request_path in self.spool.request_paths():
            claimed_path = self.spool.claim(request_path)
            if claimed_path is None:
                continue
            processed += 1
            document: Mapping[str, Any] | None = None
            task_id = claimed_path.stem
            try:
                document = self.spool.read_claim(claimed_path)
                response = self.workflow.invoke(document)
                response_task_id = response.get(constants.FIELD_TASK_ID)
                if response_task_id != task_id:
                    raise ConnectorError(
                        constants.ERROR_KIND_OPERATIONAL,
                        constants.ERROR_INTERNAL,
                        False,
                    )
                self._last_success_at = _timestamp()
                if document.get(constants.FIELD_SKILL) == constants.REMINDER_SKILL:
                    self._last_reminder_success_at = self._last_success_at
                self._last_error = None
            except ConnectorError as exc:
                response = _failure_response(document, exc)
                response[constants.FIELD_TASK_ID] = task_id
                self._last_error = str(exc)
            except Exception:
                safe_error = ConnectorError(
                    constants.ERROR_KIND_OPERATIONAL,
                    constants.ERROR_INTERNAL,
                    False,
                )
                response = _failure_response(document, safe_error)
                response[constants.FIELD_TASK_ID] = task_id
                self._last_error = constants.ERROR_INTERNAL
            try:
                self.spool.publish_response(task_id, response, claimed_path)
            except ConnectorError as exc:
                response = _failure_response(document, exc)
                response[constants.FIELD_TASK_ID] = task_id
                self._last_error = str(exc)
                self.spool.publish_response(task_id, response, claimed_path)
            self._write_status(True)
        self._process_scheduled_snapshot_if_due()
        return processed

    def _process_scheduled_snapshot_if_due(self) -> None:
        """Fetch one complete snapshot when the app-owned launchd schedule is due."""
        schedule = self.spool.read_schedule_document()
        if schedule is None or schedule[constants.SCHEDULE_KEY_ENABLED] is not True:
            return
        interval = int(schedule[constants.SCHEDULE_KEY_INTERVAL_MINUTES])
        if self._last_reminder_success_at:
            try:
                last_success = datetime.strptime(
                    self._last_reminder_success_at,
                    constants.ISO8601_UTC_FORMAT,
                ).replace(tzinfo=timezone.utc)
            except ValueError:
                last_success = None
            if last_success is not None and datetime.now(timezone.utc) < (
                last_success + timedelta(minutes=interval)
            ):
                return

        task_id = str(uuid4())
        document = {
            constants.FIELD_SCHEMA_VERSION: constants.SCHEMA_VERSION,
            constants.FIELD_TASK_ID: task_id,
            constants.FIELD_SKILL: constants.REMINDER_SKILL,
            constants.FIELD_OPERATION: constants.OPERATION_LIST,
            constants.FIELD_IDEMPOTENCY_KEY: str(uuid4()),
            constants.FIELD_CALENDAR_POLICY: constants.CALENDAR_POLICY_NEVER,
            constants.FIELD_CONFIRMED: False,
            constants.FIELD_PAYLOAD: {},
        }
        try:
            response = self.workflow.invoke(document)
            if response.get(constants.FIELD_TASK_ID) != task_id:
                raise ConnectorError(
                    constants.ERROR_KIND_OPERATIONAL,
                    constants.ERROR_INTERNAL,
                    False,
                )
            self._last_success_at = _timestamp()
            self._last_reminder_success_at = self._last_success_at
            self._last_error = None
        except ConnectorError as exc:
            response = _failure_response(document, exc)
            self._last_error = str(exc)
        except Exception:
            safe_error = ConnectorError(
                constants.ERROR_KIND_OPERATIONAL,
                constants.ERROR_INTERNAL,
                False,
            )
            response = _failure_response(document, safe_error)
            self._last_error = constants.ERROR_INTERNAL
        self.spool.publish_scheduled_snapshot(response)
        self._write_status(True)

    def _write_status(self, running: bool) -> None:
        """Publish connector health without configuration or credentials."""
        self.spool.write_status(
            {
                constants.STATUS_KEY_SCHEMA_VERSION: constants.SCHEMA_VERSION,
                constants.STATUS_KEY_RUNTIME_CONTRACT_VERSION:
                    constants.RUNTIME_CONTRACT_VERSION,
                constants.STATUS_KEY_RUNNING: running,
                constants.STATUS_KEY_LAST_SEEN_AT: _timestamp(),
                constants.STATUS_KEY_LAST_SUCCESS_AT: self._last_success_at,
                constants.STATUS_KEY_LAST_REMINDER_SUCCESS_AT:
                    self._last_reminder_success_at,
                constants.STATUS_KEY_LAST_ERROR: self._last_error,
                constants.STATUS_KEY_PID: os.getpid(),
            }
        )
