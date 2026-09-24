"""Keychain access tests."""

from __future__ import annotations

import subprocess
import unittest
from unittest.mock import Mock, patch

from local_assistant_connector import constants
from local_assistant_connector.keychain import token_exists


class KeychainTests(unittest.TestCase):
    """Keep setup discovery bounded and credential-free."""

    @patch("local_assistant_connector.keychain.subprocess.run")
    def test_token_exists_uses_metadata_only_query(self, run: Mock) -> None:
        """Presence checks never request or capture the Keychain secret.

        Args:
            run: Replacement for the ``security`` subprocess call.
        """
        run.return_value = Mock(returncode=0)

        self.assertTrue(token_exists(constants.KEYCHAIN_REMINDER_ACCOUNT))

        run.assert_called_once_with(
            [
                constants.KEYCHAIN_SECURITY_EXECUTABLE,
                constants.KEYCHAIN_FIND_GENERIC_PASSWORD,
                constants.KEYCHAIN_SERVICE_OPTION,
                constants.KEYCHAIN_SERVICE,
                constants.KEYCHAIN_ACCOUNT_OPTION,
                constants.KEYCHAIN_REMINDER_ACCOUNT,
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=constants.KEYCHAIN_METADATA_TIMEOUT_SECONDS,
        )

    @patch("local_assistant_connector.keychain.subprocess.run")
    def test_token_exists_returns_false_for_missing_item(self, run: Mock) -> None:
        """A missing Keychain item is reported without raising an error.

        Args:
            run: Replacement for the ``security`` subprocess call.
        """
        run.return_value = Mock(returncode=44)

        self.assertFalse(token_exists(constants.KEYCHAIN_AGENT_ACCOUNT))

    @patch("local_assistant_connector.keychain.subprocess.run")
    def test_token_exists_returns_false_when_query_times_out(self, run: Mock) -> None:
        """Setup discovery cannot wait indefinitely for Keychain metadata.

        Args:
            run: Replacement for the ``security`` subprocess call.
        """
        run.side_effect = subprocess.TimeoutExpired(
            constants.KEYCHAIN_SECURITY_EXECUTABLE,
            constants.KEYCHAIN_METADATA_TIMEOUT_SECONDS,
        )

        self.assertFalse(token_exists(constants.KEYCHAIN_AGENT_ACCOUNT))


if __name__ == "__main__":
    unittest.main()
