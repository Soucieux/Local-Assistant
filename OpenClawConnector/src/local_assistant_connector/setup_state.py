"""Credential-free setup discovery and exact connector-data removal."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import stat
from typing import TypedDict

from . import constants
from .configuration import (
    application_directory,
    load_config,
    ssh_known_hosts_path,
    ssh_private_key_path,
    ssh_public_key_path,
)
from .keychain import delete_token, token_exists
from .models import ConnectorError


class ExistingSetupState(TypedDict):
    """Credential-free facts used by the packaged setup application."""

    hasExistingData: bool
    configured: bool
    sshHost: str
    sshPort: int
    sshHostKey: str
    sshIdentityReady: bool
    reminderTokenSaved: bool
    agentTokenSaved: bool
    readyForUpgrade: bool


def _is_safe_file(path: Path, *, allow_public_read: bool = False) -> bool:
    """Accept one owned regular file without following a symbolic link."""
    try:
        metadata = path.lstat()
    except OSError:
        return False
    disallowed_mode = 0o022 if allow_public_read else 0o077
    return (
        stat.S_ISREG(metadata.st_mode)
        and not stat.S_ISLNK(metadata.st_mode)
        and metadata.st_uid == os.getuid()
        and metadata.st_mode & disallowed_mode == 0
        and metadata.st_size > 0
    )


def _pinned_host_key() -> str:
    """Return only the public key material from the exact pinned-host record."""
    target = ssh_known_hosts_path()
    if not _is_safe_file(target):
        return ""
    try:
        fields = target.read_text(encoding="utf-8").strip().split()
    except (OSError, UnicodeError):
        return ""
    if (
        len(fields) != constants.SSH_HOST_KEY_FIELD_COUNT
        or fields[0] != constants.SSH_HOST_KEY_ALIAS
        or fields[1] != constants.SSH_KEY_TYPE
    ):
        return ""
    return f"{fields[1]} {fields[2]}"


def existing_setup_state() -> ExistingSetupState:
    """Return reusable non-secret values and credential-presence booleans."""
    configured = False
    ssh_host = ""
    ssh_port = constants.DEFAULT_SSH_PORT
    try:
        config = load_config()
        configured = True
        ssh_host = config.ssh_host
        ssh_port = config.ssh_port
    except ConnectorError:
        pass

    host_key = _pinned_host_key()
    identity_ready = _is_safe_file(ssh_private_key_path()) and _is_safe_file(
        ssh_public_key_path(),
        allow_public_read=True,
    )
    reminder_token_saved = token_exists(constants.KEYCHAIN_REMINDER_ACCOUNT)
    agent_token_saved = token_exists(constants.KEYCHAIN_AGENT_ACCOUNT)
    has_existing_data = (
        application_directory().exists()
        or reminder_token_saved
        or agent_token_saved
    )
    ready_for_upgrade = all(
        (
            configured,
            bool(host_key),
            identity_ready,
            reminder_token_saved,
            agent_token_saved,
        )
    )
    return {
        "hasExistingData": has_existing_data,
        "configured": configured,
        "sshHost": ssh_host,
        "sshPort": ssh_port,
        "sshHostKey": host_key,
        "sshIdentityReady": identity_ready,
        "reminderTokenSaved": reminder_token_saved,
        "agentTokenSaved": agent_token_saved,
        "readyForUpgrade": ready_for_upgrade,
    }


def forget_connector_data() -> None:
    """Remove only Connector Keychain entries and private Application Support data."""
    root = application_directory()
    if root.exists() or root.is_symlink():
        try:
            metadata = root.lstat()
        except OSError as exc:
            raise ConnectorError(
                constants.ERROR_KIND_INVALID_REQUEST,
                constants.ERROR_FILE_BOUNDARY,
                False,
            ) from exc
        if (
            not stat.S_ISDIR(metadata.st_mode)
            or stat.S_ISLNK(metadata.st_mode)
            or metadata.st_uid != os.getuid()
        ):
            raise ConnectorError(
                constants.ERROR_KIND_INVALID_REQUEST,
                constants.ERROR_FILE_BOUNDARY,
                False,
            )

    delete_token(constants.KEYCHAIN_REMINDER_ACCOUNT)
    delete_token(constants.KEYCHAIN_AGENT_ACCOUNT)
    if root.exists():
        shutil.rmtree(root)
