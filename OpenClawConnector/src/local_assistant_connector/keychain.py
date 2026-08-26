"""macOS Keychain access through the system keyring backend."""

from __future__ import annotations

import keyring
from keyring.errors import PasswordDeleteError

from . import constants
from .models import ConnectorError


def save_token(account: str, token: str) -> None:
    """Store one non-empty connector credential in macOS Keychain."""
    normalized = token.strip()
    if not normalized:
        raise ConnectorError(
            constants.ERROR_KIND_INVALID_REQUEST,
            constants.ERROR_TOKEN_MISSING,
            False,
        )
    keyring.set_password(constants.KEYCHAIN_SERVICE, account, normalized)


def load_token(account: str) -> str:
    """Load one connector credential without exposing it to configuration."""
    token = keyring.get_password(constants.KEYCHAIN_SERVICE, account)
    if not isinstance(token, str) or not token.strip():
        raise ConnectorError(
            constants.ERROR_KIND_NOT_CONFIGURED,
            constants.ERROR_TOKEN_MISSING,
            False,
        )
    return token.strip()


def token_exists(account: str) -> bool:
    """Report whether one connector credential exists without returning it."""
    token = keyring.get_password(constants.KEYCHAIN_SERVICE, account)
    return isinstance(token, str) and bool(token.strip())


def delete_token(account: str) -> None:
    """Delete one exact connector credential while tolerating an absent entry."""
    try:
        keyring.delete_password(constants.KEYCHAIN_SERVICE, account)
    except PasswordDeleteError:
        return
