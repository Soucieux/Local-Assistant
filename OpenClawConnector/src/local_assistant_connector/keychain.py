"""macOS Keychain access through the system keyring backend."""

from __future__ import annotations

import subprocess

import keyring
from keyring.errors import PasswordDeleteError

from . import constants
from .models import ConnectorError


def save_token(account: str, token: str) -> None:
    """Store one non-empty connector credential in macOS Keychain.

    Args:
        account: Keychain account that names the credential.
        token: Credential text; surrounding whitespace is removed.

    Raises:
        ConnectorError: When the credential is empty.
    """
    normalized = token.strip()
    if not normalized:
        raise ConnectorError.invalid_request(constants.ERROR_TOKEN_MISSING)
    keyring.set_password(constants.KEYCHAIN_SERVICE, account, normalized)


def load_token(account: str) -> str:
    """Load one connector credential without exposing it to configuration.

    Args:
        account: Keychain account that names the credential.

    Returns:
        The stored credential with surrounding whitespace removed.

    Raises:
        ConnectorError: When no usable credential is stored.
    """
    token = keyring.get_password(constants.KEYCHAIN_SERVICE, account)
    if not isinstance(token, str) or not token.strip():
        raise ConnectorError.not_configured(constants.ERROR_TOKEN_MISSING)
    return token.strip()


def token_exists(account: str) -> bool:
    """Report whether one connector credential exists without returning it.

    Args:
        account: Keychain account that names the credential.

    Returns:
        Whether Keychain holds an entry; a failed or slow lookup counts as absent.
    """
    try:
        result = subprocess.run(
            [
                constants.KEYCHAIN_SECURITY_EXECUTABLE,
                constants.KEYCHAIN_FIND_GENERIC_PASSWORD,
                constants.KEYCHAIN_SERVICE_OPTION,
                constants.KEYCHAIN_SERVICE,
                constants.KEYCHAIN_ACCOUNT_OPTION,
                account,
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=constants.KEYCHAIN_METADATA_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0


def delete_token(account: str) -> None:
    """Delete one exact connector credential while tolerating an absent entry.

    Args:
        account: Keychain account that names the credential.
    """
    try:
        keyring.delete_password(constants.KEYCHAIN_SERVICE, account)
    except PasswordDeleteError:
        return
