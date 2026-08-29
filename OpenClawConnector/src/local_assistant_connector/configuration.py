"""Owner-only non-secret connector configuration."""

from __future__ import annotations

import base64
import binascii
import json
import os
import re
import stat
from pathlib import Path
from typing import Any

from . import constants
from .models import ConnectorConfig, ConnectorError


def application_directory() -> Path:
    """Return the connector's private Application Support directory."""
    return (
        Path.home()
        / constants.USER_LIBRARY_DIRECTORY_NAME
        / constants.APPLICATION_SUPPORT_DIRECTORY_NAME
        / constants.APPLICATION_DIRECTORY_NAME
    )


def config_path() -> Path:
    """Return the default non-secret configuration path."""
    return application_directory() / constants.CONFIG_FILE_NAME


def checkpoint_path() -> Path:
    """Return the durable LangGraph checkpoint path."""
    return application_directory() / constants.CHECKPOINT_FILE_NAME


def ssh_directory() -> Path:
    """Return the owner-only directory holding the dedicated forwarding identity."""
    return application_directory() / constants.SSH_DIRECTORY_NAME


def ssh_private_key_path() -> Path:
    """Return the dedicated private-key path used only for OpenClaw forwarding."""
    return ssh_directory() / constants.SSH_PRIVATE_KEY_NAME


def ssh_public_key_path() -> Path:
    """Return the public half of the dedicated OpenClaw forwarding identity."""
    return ssh_directory() / constants.SSH_PUBLIC_KEY_NAME


def ssh_known_hosts_path() -> Path:
    """Return the pinned host-key file for the OpenClaw SSH server."""
    return ssh_directory() / constants.SSH_KNOWN_HOSTS_NAME


def save_ssh_host_key(value: object) -> None:
    """Validate and atomically pin one Ed25519 server host key."""
    if not isinstance(value, str):
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_SSH_HOST_KEY,
            False,
        )
    fields = value.strip().split()
    if len(fields) != 2 or fields[0] != constants.SSH_KEY_TYPE:
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_SSH_HOST_KEY,
            False,
        )
    try:
        decoded = base64.b64decode(fields[1], validate=True)
    except (ValueError, binascii.Error) as exc:
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_SSH_HOST_KEY,
            False,
        ) from exc
    if len(decoded) < constants.SSH_HOST_KEY_MINIMUM_BYTES:
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_SSH_HOST_KEY,
            False,
        )
    directory = ssh_directory()
    directory.mkdir(
        parents=True,
        exist_ok=True,
        mode=constants.OWNER_DIRECTORY_MODE,
    )
    os.chmod(directory, constants.OWNER_DIRECTORY_MODE)
    target = ssh_known_hosts_path()
    temporary = target.with_suffix(target.suffix + constants.TEMPORARY_SUFFIX)
    temporary.write_text(
        f"{constants.SSH_HOST_KEY_ALIAS} {fields[0]} {fields[1]}\n",
        encoding="utf-8",
    )
    os.chmod(temporary, constants.OWNER_FILE_MODE)
    os.replace(temporary, target)
    os.chmod(target, constants.OWNER_FILE_MODE)


def _validated_ssh_host(value: object) -> str:
    """Validate one DNS name or IP literal without accepting a URL or command text."""
    if not isinstance(value, str):
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_SSH_HOST,
            False,
        )
    normalized = value.strip()
    if (
        not normalized
        or len(normalized) > constants.SSH_HOST_MAXIMUM_LENGTH
        or normalized.startswith("-")
        or any(character.isspace() for character in normalized)
        or any(character in normalized for character in "/@?#")
        or "://" in normalized
        or re.fullmatch(r"[A-Za-z0-9._:-]+", normalized) is None
    ):
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_SSH_HOST,
            False,
        )
    return normalized


def _validated_ssh_port(value: object) -> int:
    """Validate one explicit TCP port without accepting booleans or strings."""
    if type(value) is not int or not (
        constants.SSH_PORT_MINIMUM <= value <= constants.SSH_PORT_MAXIMUM
    ):
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_SSH_PORT,
            False,
        )
    return value


def _validated_ssh_user(value: object) -> str:
    """Validate the dedicated forwarding-only Unix account name."""
    if not isinstance(value, str) or re.fullmatch(r"[a-z_][a-z0-9_-]{0,31}", value) is None:
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_SSH_USER,
            False,
        )
    return value


def _bounded_number(
    value: object,
    default: float,
    minimum: float,
    maximum: float,
) -> float:
    """Return one finite numeric configuration value inside its safety bound."""
    if value is None:
        return default
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_INVALID_CONFIG,
            False,
        )
    converted = float(value)
    if not minimum <= converted <= maximum:
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_INVALID_CONFIG,
            False,
        )
    return converted


def parse_config(document: object) -> ConnectorConfig:
    """Validate one configuration document and reject unknown fields."""
    if not isinstance(document, dict):
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_INVALID_CONFIG,
            False,
        )
    fields = frozenset(document)
    if (
        not constants.CONFIG_REQUIRED_FIELDS.issubset(fields)
        or not fields.issubset(
            constants.CONFIG_REQUIRED_FIELDS | constants.CONFIG_OPTIONAL_FIELDS
        )
        or not isinstance(document[constants.CONFIG_SPOOL_DIRECTORY], str)
        or not document[constants.CONFIG_SPOOL_DIRECTORY]
        or "\0" in document[constants.CONFIG_SPOOL_DIRECTORY]
        or not Path(document[constants.CONFIG_SPOOL_DIRECTORY]).is_absolute()
    ):
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_INVALID_CONFIG,
            False,
        )
    return ConnectorConfig(
        ssh_host=_validated_ssh_host(document[constants.CONFIG_SSH_HOST]),
        ssh_port=_validated_ssh_port(document[constants.CONFIG_SSH_PORT]),
        ssh_user=_validated_ssh_user(document[constants.CONFIG_SSH_USER]),
        spool_directory=document[constants.CONFIG_SPOOL_DIRECTORY],
        request_timeout_seconds=_bounded_number(
            document.get(constants.CONFIG_REQUEST_TIMEOUT_SECONDS),
            constants.DEFAULT_REQUEST_TIMEOUT_SECONDS,
            constants.MINIMUM_REQUEST_TIMEOUT_SECONDS,
            constants.MAXIMUM_REQUEST_TIMEOUT_SECONDS,
        ),
    )


def load_config(path: Path | None = None) -> ConnectorConfig:
    """Load the owner-only non-secret connector configuration."""
    target = path or config_path()
    if not target.is_file():
        raise ConnectorError(
            constants.ERROR_KIND_NOT_CONFIGURED,
            constants.ERROR_CONFIG_MISSING,
            False,
        )
    try:
        metadata = target.lstat()
        if (
            not stat.S_ISREG(metadata.st_mode)
            or stat.S_ISLNK(metadata.st_mode)
            or metadata.st_mode & 0o077
        ):
            raise ConnectorError(
                constants.ERROR_KIND_INVALID_REQUEST,
                constants.ERROR_INVALID_CONFIG,
                False,
            )
        return parse_config(json.loads(target.read_text(encoding="utf-8")))
    except ConnectorError:
        raise
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_INVALID_CONFIG,
            False,
        ) from exc


def save_config(config: ConnectorConfig, path: Path | None = None) -> None:
    """Atomically save non-secret configuration with owner-only permissions."""
    target = path or config_path()
    target.parent.mkdir(parents=True, exist_ok=True, mode=constants.OWNER_DIRECTORY_MODE)
    os.chmod(target.parent, constants.OWNER_DIRECTORY_MODE)
    document: dict[str, Any] = {
        constants.CONFIG_SSH_HOST: config.ssh_host,
        constants.CONFIG_SSH_PORT: config.ssh_port,
        constants.CONFIG_SSH_USER: config.ssh_user,
        constants.CONFIG_SPOOL_DIRECTORY: config.spool_directory,
        constants.CONFIG_REQUEST_TIMEOUT_SECONDS: config.request_timeout_seconds,
    }
    temporary = target.with_suffix(target.suffix + constants.TEMPORARY_SUFFIX)
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(document, handle, separators=(",", ":"), ensure_ascii=False)
        handle.write("\n")
    os.chmod(temporary, constants.OWNER_FILE_MODE)
    os.replace(temporary, target)
    os.chmod(target, constants.OWNER_FILE_MODE)
