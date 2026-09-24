"""Owner-only file spool shared with the sandboxed Local Assistant app."""

from __future__ import annotations

import json
import os
import stat
import tempfile
from pathlib import Path
from typing import Any, Mapping
from uuid import UUID

from . import constants
from .models import ConnectorError


def _read_bounded_regular(path: Path, maximum_bytes: int) -> bytes:
    """Read one regular file descriptor without following a symbolic link.

    Args:
        path: File inside the shared spool.
        maximum_bytes: Largest size accepted before the content is trusted.

    Returns:
        The complete file content.

    Raises:
        ConnectorError: When the path is a link or not a regular file, cannot
            be opened, or exceeds the size bound.
    """
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as exc:
        raise ConnectorError.invalid_request(constants.ERROR_FILE_BOUNDARY) from exc
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            raise ConnectorError.invalid_request(constants.ERROR_FILE_BOUNDARY)
        if metadata.st_size > maximum_bytes:
            raise ConnectorError.invalid_request(constants.ERROR_TOO_LARGE)
        with os.fdopen(descriptor, "rb", closefd=True) as handle:
            descriptor = -1
            raw = handle.read(maximum_bytes + 1)
        if len(raw) > maximum_bytes:
            raise ConnectorError.invalid_request(constants.ERROR_TOO_LARGE)
        return raw
    finally:
        if descriptor >= 0:
            os.close(descriptor)


def _atomic_write_json(
    target: Path,
    document: Mapping[str, Any],
    maximum_bytes: int,
) -> None:
    """Publish bounded JSON through a unique owner-only temporary file.

    Args:
        target: Final path, replaced atomically so readers never see a partial file.
        document: JSON-serializable content.
        maximum_bytes: Largest encoded size that may be published.

    Raises:
        ConnectorError: When the document cannot be encoded or is too large.
    """
    try:
        encoded = (
            json.dumps(document, separators=(",", ":"), ensure_ascii=False) + "\n"
        ).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise ConnectorError.operational(
            constants.ERROR_INTERNAL,
            retryable=False,
        ) from exc
    if len(encoded) > maximum_bytes:
        raise ConnectorError.operational(
            constants.ERROR_REMOTE_RESPONSE,
            retryable=False,
        )

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{target.name}.",
        suffix=constants.TEMPORARY_SUFFIX,
        dir=target.parent,
    )
    temporary = Path(temporary_name)
    try:
        os.fchmod(descriptor, constants.OWNER_FILE_MODE)
        with os.fdopen(descriptor, "wb", closefd=True) as handle:
            descriptor = -1
            handle.write(encoded)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, target)
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        temporary.unlink(missing_ok=True)


def _safe_task_stem(path: Path) -> str:
    """Read the task identifier from one expected JSON filename.

    Args:
        path: Candidate request, claim, or response file.

    Returns:
        The filename stem, proven to be a canonical UUID.

    Raises:
        ConnectorError: When the name is not a canonical UUID with the JSON suffix.
    """
    if path.suffix != constants.JSON_SUFFIX:
        raise ConnectorError.invalid_request(constants.ERROR_FILE_BOUNDARY)
    try:
        identifier = UUID(path.stem)
    except ValueError as exc:
        raise ConnectorError.invalid_request(constants.ERROR_FILE_BOUNDARY) from exc
    if str(identifier) != path.stem.lower():
        raise ConnectorError.invalid_request(constants.ERROR_FILE_BOUNDARY)
    return path.stem


class SpoolStore:
    """Claims requests and publishes responses through atomic renames."""

    def __init__(self, root: str | Path) -> None:
        """Create and protect the three shared spool directories.

        Args:
            root: Spool directory shared with the sandboxed application.

        Raises:
            ConnectorError: When a spool directory is a link or not a directory.
        """
        self.root = Path(root)
        self.requests = self.root / constants.REQUESTS_DIRECTORY_NAME
        self.processing = self.root / constants.PROCESSING_DIRECTORY_NAME
        self.responses = self.root / constants.RESPONSES_DIRECTORY_NAME
        for directory in (self.root, self.requests, self.processing, self.responses):
            directory.mkdir(
                parents=True,
                exist_ok=True,
                mode=constants.OWNER_DIRECTORY_MODE,
            )
            metadata = directory.lstat()
            if not stat.S_ISDIR(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
                raise ConnectorError.invalid_request(constants.ERROR_FILE_BOUNDARY)
            os.chmod(directory, constants.OWNER_DIRECTORY_MODE)
        self.status_path = self.root / constants.STATUS_FILE_NAME
        self.schedule_path = self.root / constants.SCHEDULE_FILE_NAME
        self.scheduled_snapshot_path = (
            self.responses / constants.SCHEDULED_SNAPSHOT_FILE_NAME
        )

    def recover_claims(self) -> None:
        """Return unfinished claims to the request queue after a stopped process."""
        for claimed in sorted(self.processing.glob(f"*{constants.JSON_SUFFIX}")):
            try:
                task_id = _safe_task_stem(claimed)
            except ConnectorError:
                continue
            response_path = self.responses / f"{task_id}{constants.JSON_SUFFIX}"
            request_path = self.requests / f"{task_id}{constants.JSON_SUFFIX}"
            if response_path.exists() or request_path.exists():
                claimed.unlink(missing_ok=True)
            else:
                os.replace(claimed, request_path)

    def request_paths(self) -> list[Path]:
        """List the queued request documents that are safe to claim.

        Returns:
            Regular, non-symlink request files with canonical UUID names, in
            stable name order.
        """
        paths: list[Path] = []
        for candidate in sorted(self.requests.glob(f"*{constants.JSON_SUFFIX}")):
            try:
                _safe_task_stem(candidate)
                metadata = candidate.lstat()
            except (ConnectorError, OSError):
                continue
            if stat.S_ISREG(metadata.st_mode) and not stat.S_ISLNK(metadata.st_mode):
                paths.append(candidate)
        return paths

    def claim(self, request_path: Path) -> Path | None:
        """Atomically move one request into the processing directory.

        Args:
            request_path: Queued request file.

        Returns:
            The claimed file, or ``None`` when the request was already
            answered or another process claimed it first.

        Raises:
            ConnectorError: When the filename is not a canonical task name.
        """
        task_id = _safe_task_stem(request_path)
        response_path = self.responses / f"{task_id}{constants.JSON_SUFFIX}"
        if response_path.exists():
            request_path.unlink(missing_ok=True)
            return None
        claimed = self.processing / request_path.name
        try:
            os.replace(request_path, claimed)
        except FileNotFoundError:
            return None
        return claimed

    def read_claim(self, claimed_path: Path) -> Mapping[str, Any]:
        """Read one bounded regular claim without following a symlink.

        Args:
            claimed_path: File returned by ``claim``.

        Returns:
            The decoded request object, still unvalidated.

        Raises:
            ConnectorError: When the file is unsafe, too large, or not a JSON object.
        """
        try:
            raw = _read_bounded_regular(
                claimed_path,
                constants.MAX_REQUEST_BYTES,
            )
            document = json.loads(raw.decode("utf-8"))
        except ConnectorError:
            raise
        except (UnicodeError, json.JSONDecodeError) as exc:
            raise ConnectorError.invalid_request(constants.ERROR_INVALID_REQUEST) from exc
        if not isinstance(document, dict):
            raise ConnectorError.invalid_request(constants.ERROR_INVALID_REQUEST)
        return document

    def publish_response(
        self,
        task_id: str,
        document: Mapping[str, Any],
        claimed_path: Path,
    ) -> None:
        """Atomically publish one owner-only response and remove its claim.

        Args:
            task_id: Canonical UUID that names the response file.
            document: Response content.
            claimed_path: Claim to remove once the response is in place.

        Raises:
            ValueError: When ``task_id`` is not a UUID.
            ConnectorError: When the response cannot be encoded or is too large.
        """
        UUID(task_id)
        target = self.responses / f"{task_id}{constants.JSON_SUFFIX}"
        _atomic_write_json(target, document, constants.MAX_RESPONSE_BYTES)
        claimed_path.unlink(missing_ok=True)

    def write_status(self, document: Mapping[str, Any]) -> None:
        """Atomically publish non-secret connector health state.

        Args:
            document: Status content without configuration or credentials.

        Raises:
            ConnectorError: When the status cannot be encoded or is too large.
        """
        _atomic_write_json(
            self.status_path,
            document,
            constants.MAX_REQUEST_BYTES,
        )

    def read_schedule_document(self) -> Mapping[str, Any] | None:
        """Read the app-owned refresh schedule.

        Returns:
            The schedule when it has exactly the expected fields, the current
            schema version, and an allowed interval; otherwise ``None``.
        """
        if not self.schedule_path.exists():
            return None
        try:
            document = json.loads(
                _read_bounded_regular(
                    self.schedule_path,
                    constants.MAX_REQUEST_BYTES,
                ).decode("utf-8")
            )
        except (ConnectorError, UnicodeError, json.JSONDecodeError):
            return None
        if not isinstance(document, dict) or frozenset(document) != {
            constants.FIELD_SCHEMA_VERSION,
            constants.SCHEDULE_KEY_ENABLED,
            constants.SCHEDULE_KEY_INTERVAL_MINUTES,
        }:
            return None
        if document.get(constants.FIELD_SCHEMA_VERSION) != constants.SCHEMA_VERSION:
            return None
        if not isinstance(document.get(constants.SCHEDULE_KEY_ENABLED), bool):
            return None
        interval = document.get(constants.SCHEDULE_KEY_INTERVAL_MINUTES)
        if interval not in constants.ALLOWED_SCHEDULE_INTERVAL_MINUTES:
            return None
        return document

    def publish_scheduled_snapshot(self, document: Mapping[str, Any]) -> None:
        """Atomically publish the newest timer-originated complete snapshot result.

        Args:
            document: Snapshot response, replacing any result not yet collected.

        Raises:
            ConnectorError: When the response cannot be encoded or is too large.
        """
        _atomic_write_json(
            self.scheduled_snapshot_path,
            document,
            constants.MAX_RESPONSE_BYTES,
        )

    def read_status_text(self) -> str:
        """Read non-secret status without following a caller-planted symlink.

        Returns:
            The status file's text with surrounding whitespace removed.

        Raises:
            ConnectorError: When the file is missing, unsafe, too large, or not UTF-8.
        """
        try:
            return _read_bounded_regular(
                self.status_path,
                constants.MAX_REQUEST_BYTES,
            ).decode("utf-8").strip()
        except ConnectorError:
            raise
        except UnicodeError as exc:
            raise ConnectorError.invalid_request(constants.ERROR_FILE_BOUNDARY) from exc

    def read_status_document(self) -> Mapping[str, Any] | None:
        """Read the status a previous run left behind.

        Returns:
            The prior status object, or ``None`` when it is absent, unsafe, or
            not a JSON object.
        """
        if not self.status_path.exists():
            return None
        try:
            document = json.loads(self.read_status_text())
        except (ConnectorError, json.JSONDecodeError):
            return None
        return document if isinstance(document, dict) else None
