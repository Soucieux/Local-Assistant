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
    """Locate the connector's private Application Support directory.

    Returns:
        Absolute directory beneath the current user's Library folder.
    """
    return (
        Path.home()
        / constants.USER_LIBRARY_DIRECTORY_NAME
        / constants.APPLICATION_SUPPORT_DIRECTORY_NAME
        / constants.APPLICATION_DIRECTORY_NAME
    )


def config_path() -> Path:
    """Locate the default non-secret configuration file.

    Returns:
        Path of the configuration document inside the application directory.
    """
    return application_directory() / constants.CONFIG_FILE_NAME


def checkpoint_path() -> Path:
    """Locate the durable LangGraph checkpoint database.

    Returns:
        Path of the checkpoint file inside the application directory.
    """
    return application_directory() / constants.CHECKPOINT_FILE_NAME


def ssh_directory() -> Path:
    """Locate the owner-only directory holding the dedicated forwarding identity.

    Returns:
        Path of the SSH directory inside the application directory.
    """
    return application_directory() / constants.SSH_DIRECTORY_NAME


def ssh_private_key_path() -> Path:
    """Locate the dedicated private key used only for OpenClaw forwarding.

    Returns:
        Path of the Ed25519 private key inside the SSH directory.
    """
    return ssh_directory() / constants.SSH_PRIVATE_KEY_NAME


def ssh_public_key_path() -> Path:
    """Locate the public half of the dedicated OpenClaw forwarding identity.

    Returns:
        Path of the Ed25519 public key inside the SSH directory.
    """
    return ssh_directory() / constants.SSH_PUBLIC_KEY_NAME


def ssh_known_hosts_path() -> Path:
    """Locate the pinned host-key file for the OpenClaw SSH server.

    Returns:
        Path of the single-entry known-hosts file inside the SSH directory.
    """
    return ssh_directory() / constants.SSH_KNOWN_HOSTS_NAME


def save_ssh_host_key(value: object) -> None:
    """Validate and atomically pin one Ed25519 server host key.

    Args:
        value: Host-key line as the server installer prints it: the key type
            followed by its base64 body.

    Raises:
        ConnectorError: When the value is not a well-formed Ed25519 host key.
    """
    if not isinstance(value, str):
        raise ConnectorError.invalid_request(constants.ERROR_SSH_HOST_KEY)
    fields = value.strip().split()
    if (
        len(fields) != constants.SSH_HOST_KEY_INPUT_FIELD_COUNT
        or fields[0] != constants.SSH_KEY_TYPE
    ):
        raise ConnectorError.invalid_request(constants.ERROR_SSH_HOST_KEY)
    try:
        decoded = base64.b64decode(fields[1], validate=True)
    except (ValueError, binascii.Error) as exc:
        raise ConnectorError.invalid_request(constants.ERROR_SSH_HOST_KEY) from exc
    if len(decoded) < constants.SSH_HOST_KEY_MINIMUM_BYTES:
        raise ConnectorError.invalid_request(constants.ERROR_SSH_HOST_KEY)
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
    """Validate one DNS name or IP literal without accepting a URL or command text.

    The allowed characters already exclude whitespace, URL punctuation, and a
    ``user@host`` form, so only a leading option dash needs its own check.

    Args:
        value: Untrusted server address from configuration or setup input.

    Returns:
        The address with surrounding whitespace removed.

    Raises:
        ConnectorError: When the value is not a bare host name or IP literal.
    """
    if not isinstance(value, str):
        raise ConnectorError.invalid_request(constants.ERROR_SSH_HOST)
    normalized = value.strip()
    if (
        len(normalized) > constants.SSH_HOST_MAXIMUM_LENGTH
        or normalized.startswith(constants.SSH_OPTION_PREFIX)
        or re.fullmatch(constants.SSH_HOST_PATTERN, normalized) is None
    ):
        raise ConnectorError.invalid_request(constants.ERROR_SSH_HOST)
    return normalized


def _validated_ssh_port(value: object) -> int:
    """Validate one explicit TCP port without accepting booleans or strings.

    Args:
        value: Untrusted port from configuration or setup input.

    Returns:
        The port when it is a plain integer inside the valid TCP range.

    Raises:
        ConnectorError: When the value is not an integer port in range.
    """
    if type(value) is not int or not (
        constants.SSH_PORT_MINIMUM <= value <= constants.SSH_PORT_MAXIMUM
    ):
        raise ConnectorError.invalid_request(constants.ERROR_SSH_PORT)
    return value


def _validated_ssh_user(value: object) -> str:
    """Validate the dedicated forwarding-only Unix account name.

    Args:
        value: Untrusted account name from configuration or setup input.

    Returns:
        The unchanged account name when it is a portable Unix login name.

    Raises:
        ConnectorError: When the value is not a portable Unix login name.
    """
    if (
        not isinstance(value, str)
        or re.fullmatch(constants.SSH_USER_PATTERN, value) is None
    ):
        raise ConnectorError.invalid_request(constants.ERROR_SSH_USER)
    return value


def _bounded_number(
    value: object,
    default: float,
    minimum: float,
    maximum: float,
) -> float:
    """Read one numeric configuration value inside its safety bound.

    Args:
        value: Untrusted number, or ``None`` when the field is absent.
        default: Value used when the field is absent.
        minimum: Smallest accepted value.
        maximum: Largest accepted value.

    Returns:
        The value as a float, or ``default`` when the field is absent.

    Raises:
        ConnectorError: When the value is not a number inside the bound.
    """
    if value is None:
        return default
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ConnectorError.invalid_request(constants.ERROR_INVALID_CONFIG)
    converted = float(value)
    if not minimum <= converted <= maximum:
        raise ConnectorError.invalid_request(constants.ERROR_INVALID_CONFIG)
    return converted


def parse_config(document: object) -> ConnectorConfig:
    """Validate one configuration document and reject unknown fields.

    Args:
        document: Untrusted decoded JSON value.

    Returns:
        The validated non-secret connector configuration.

    Raises:
        ConnectorError: When a field is missing, unknown, or invalid.
    """
    if not isinstance(document, dict):
        raise ConnectorError.invalid_request(constants.ERROR_INVALID_CONFIG)
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
        raise ConnectorError.invalid_request(constants.ERROR_INVALID_CONFIG)
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
    """Load the owner-only non-secret connector configuration.

    Args:
        path: Configuration file to read; the default location when omitted.

    Returns:
        The validated configuration.

    Raises:
        ConnectorError: When the file is missing, readable by other users,
            not a regular file, or invalid.
    """
    target = path or config_path()
    if not target.is_file():
        raise ConnectorError.not_configured(constants.ERROR_CONFIG_MISSING)
    try:
        metadata = target.lstat()
        if (
            not stat.S_ISREG(metadata.st_mode)
            or stat.S_ISLNK(metadata.st_mode)
            or metadata.st_mode & constants.GROUP_AND_OTHER_ACCESS_MASK
        ):
            raise ConnectorError.invalid_request(constants.ERROR_INVALID_CONFIG)
        return parse_config(json.loads(target.read_text(encoding="utf-8")))
    except ConnectorError:
        raise
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ConnectorError.invalid_request(constants.ERROR_INVALID_CONFIG) from exc


def save_config(config: ConnectorConfig, path: Path | None = None) -> None:
    """Atomically save non-secret configuration with owner-only permissions.

    Args:
        config: Validated configuration to persist.
        path: Destination file; the default location when omitted.
    """
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
