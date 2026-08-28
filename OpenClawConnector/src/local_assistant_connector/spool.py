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
    """Read one regular file descriptor without following a symbolic link."""
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as exc:
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_FILE_BOUNDARY,
            False,
        ) from exc
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            raise ConnectorError(
                constants.ERROR_KIND_INVALID_REQUEST,
                constants.ERROR_FILE_BOUNDARY,
                False,
            )
        if metadata.st_size > maximum_bytes:
            raise ConnectorError(
                constants.ERROR_KIND_INVALID_REQUEST,
                constants.ERROR_TOO_LARGE,
                False,
            )
        with os.fdopen(descriptor, "rb", closefd=True) as handle:
            descriptor = -1
            raw = handle.read(maximum_bytes + 1)
        if len(raw) > maximum_bytes:
            raise ConnectorError(
                constants.ERROR_KIND_INVALID_REQUEST,
                constants.ERROR_TOO_LARGE,
                False,
            )
        return raw
    finally:
        if descriptor >= 0:
            os.close(descriptor)


def _atomic_write_json(
    target: Path,
    document: Mapping[str, Any],
    maximum_bytes: int,
) -> None:
    """Publish bounded JSON through a unique owner-only temporary file."""
    try:
        encoded = (
            json.dumps(document, separators=(",", ":"), ensure_ascii=False) + "\n"
        ).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise ConnectorError(
            constants.ERROR_KIND_OPERATIONAL,
            constants.ERROR_INTERNAL,
            False,
        ) from exc
    if len(encoded) > maximum_bytes:
        raise ConnectorError(
            constants.ERROR_KIND_OPERATIONAL,
            constants.ERROR_REMOTE_RESPONSE,
            False,
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
    """Return the UUID task stem for one expected JSON filename."""
    if path.suffix != constants.JSON_SUFFIX:
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_FILE_BOUNDARY,
            False,
        )
    try:
        identifier = UUID(path.stem)
    except ValueError as exc:
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_FILE_BOUNDARY,
            False,
        ) from exc
    if str(identifier) != path.stem.lower():
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_FILE_BOUNDARY,
            False,
        )
    return path.stem


class SpoolStore:
    """Claims requests and publishes responses through atomic renames."""

    def __init__(self, root: str | Path) -> None:
        """Create and protect the three shared spool directories."""
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
                raise ConnectorError(
                    constants.ERROR_KIND_INVALID_REQUEST,
                    constants.ERROR_FILE_BOUNDARY,
                    False,
                )
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
        """Return only regular, non-symlink request documents in stable order."""
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
        """Atomically move one request into the processing directory."""
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
        """Read one bounded regular claim without following a symlink."""
        try:
            raw = _read_bounded_regular(
                claimed_path,
                constants.MAX_REQUEST_BYTES,
            )
            document = json.loads(raw.decode("utf-8"))
        except ConnectorError:
            raise
        except (UnicodeError, json.JSONDecodeError) as exc:
            raise ConnectorError(
                constants.ERROR_KIND_INVALID_REQUEST,
                constants.ERROR_INVALID_REQUEST,
                False,
            ) from exc
        if not isinstance(document, dict):
            raise ConnectorError(
                constants.ERROR_KIND_INVALID_REQUEST,
                constants.ERROR_INVALID_REQUEST,
                False,
            )
        return document

    def publish_response(
        self,
        task_id: str,
        document: Mapping[str, Any],
        claimed_path: Path,
    ) -> None:
        """Atomically publish one owner-only response and remove its claim."""
        UUID(task_id)
        target = self.responses / f"{task_id}{constants.JSON_SUFFIX}"
        _atomic_write_json(target, document, constants.MAX_RESPONSE_BYTES)
        claimed_path.unlink(missing_ok=True)

    def write_status(self, document: Mapping[str, Any]) -> None:
        """Atomically publish non-secret connector health state."""
        _atomic_write_json(
            self.status_path,
            document,
            constants.MAX_REQUEST_BYTES,
        )

    def read_schedule_document(self) -> Mapping[str, Any] | None:
        """Return the app-owned schedule only when its exact shape is valid."""
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
        """Atomically publish the newest timer-originated complete snapshot result."""
        _atomic_write_json(
            self.scheduled_snapshot_path,
            document,
            constants.MAX_RESPONSE_BYTES,
        )

    def read_status_text(self) -> str:
        """Read non-secret status without following a caller-planted symlink."""
        try:
            return _read_bounded_regular(
                self.status_path,
                constants.MAX_REQUEST_BYTES,
            ).decode("utf-8").strip()
        except ConnectorError:
            raise
        except UnicodeError as exc:
            raise ConnectorError(
                constants.ERROR_KIND_INVALID_REQUEST,
                constants.ERROR_FILE_BOUNDARY,
                False,
            ) from exc

    def read_status_document(self) -> Mapping[str, Any] | None:
        """Return the prior bounded status object when one is safely available."""
        if not self.status_path.exists():
            return None
        try:
            document = json.loads(self.read_status_text())
        except (ConnectorError, json.JSONDecodeError):
            return None
        return document if isinstance(document, dict) else None
