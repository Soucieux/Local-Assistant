"""Existing-install discovery and exact cleanup tests."""

from __future__ import annotations

import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from local_assistant_connector import constants
from local_assistant_connector.models import ConnectorConfig, ConnectorError
from local_assistant_connector.setup_state import (
    existing_setup_state,
    forget_connector_data,
)


class SetupStateTests(unittest.TestCase):
    """Keep setup reuse credential-free and cleanup narrowly bounded."""

    @patch("local_assistant_connector.setup_state.token_exists")
    @patch("local_assistant_connector.setup_state.load_config")
    @patch("local_assistant_connector.setup_state.application_directory")
    @patch("local_assistant_connector.setup_state.ssh_private_key_path")
    @patch("local_assistant_connector.setup_state.ssh_public_key_path")
    @patch("local_assistant_connector.setup_state.ssh_known_hosts_path")
    def test_existing_state_returns_only_nonsecret_values_and_presence_flags(
        self,
        known_hosts_path,
        public_key_path,
        private_key_path,
        application_directory,
        load_config,
        token_exists,
    ) -> None:
        """The Swift UI can reuse setup without receiving either token.

        Args:
            known_hosts_path: Replacement locating the pinned host-key file.
            public_key_path: Replacement locating the public key.
            private_key_path: Replacement locating the private key.
            application_directory: Replacement locating the connector's data.
            load_config: Replacement returning a saved configuration.
            token_exists: Replacement reporting that both tokens are stored.
        """
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            private_key = root / "id_ed25519"
            public_key = root / "id_ed25519.pub"
            known_hosts = root / "known_hosts"
            private_key.write_text("private", encoding="utf-8")
            public_key.write_text("public", encoding="utf-8")
            known_hosts.write_text(
                "local-assistant-openclaw-server ssh-ed25519 AAAATEST\n",
                encoding="utf-8",
            )
            os.chmod(private_key, 0o600)
            os.chmod(public_key, 0o644)
            os.chmod(known_hosts, 0o600)
            application_directory.return_value = root
            private_key_path.return_value = private_key
            public_key_path.return_value = public_key
            known_hosts_path.return_value = known_hosts
            load_config.return_value = ConnectorConfig(
                ssh_host="openclaw.example.test",
                ssh_port=2222,
                ssh_user="local-assistant-tunnel",
                spool_directory="/tmp/local-assistant-spool",
                request_timeout_seconds=20,
            )
            token_exists.side_effect = [True, True]

            state = existing_setup_state()

        self.assertTrue(state["readyForUpgrade"])
        self.assertEqual(state["sshHost"], "openclaw.example.test")
        self.assertEqual(state["sshPort"], 2222)
        self.assertEqual(state["sshHostKey"], "ssh-ed25519 AAAATEST")
        self.assertTrue(state["reminderTokenSaved"])
        self.assertTrue(state["agentTokenSaved"])
        serialized = json.dumps(state)
        self.assertNotIn("reminder-secret", serialized)
        self.assertNotIn("agent-secret", serialized)

    @patch("local_assistant_connector.setup_state.delete_token")
    @patch("local_assistant_connector.setup_state.application_directory")
    def test_forget_removes_exact_connector_root_and_both_tokens(
        self,
        application_directory,
        delete_token,
    ) -> None:
        """Cleanup leaves sibling Local Assistant data untouched.

        Args:
            application_directory: Replacement locating the connector's data.
            delete_token: Replacement that records each Keychain deletion.
        """
        with tempfile.TemporaryDirectory() as temporary_directory:
            parent = Path(temporary_directory)
            root = parent / constants.APPLICATION_DIRECTORY_NAME
            sibling = parent / "LocalAssistant"
            root.mkdir()
            sibling.mkdir()
            (root / "config.json").write_text("{}", encoding="utf-8")
            (sibling / "reminders.sqlite3").write_text("keep", encoding="utf-8")
            application_directory.return_value = root

            forget_connector_data()

            self.assertFalse(root.exists())
            self.assertTrue((sibling / "reminders.sqlite3").exists())
        self.assertEqual(
            [call.args[0] for call in delete_token.call_args_list],
            [constants.KEYCHAIN_REMINDER_ACCOUNT, constants.KEYCHAIN_AGENT_ACCOUNT],
        )

    @patch("local_assistant_connector.setup_state.delete_token")
    @patch("local_assistant_connector.setup_state.application_directory")
    def test_forget_rejects_a_symbolic_link_root(
        self,
        application_directory,
        delete_token,
    ) -> None:
        """Cleanup never follows a replaced Application Support path.

        Args:
            application_directory: Replacement locating a symbolic link.
            delete_token: Replacement that must never be called.
        """
        with tempfile.TemporaryDirectory() as temporary_directory:
            parent = Path(temporary_directory)
            target = parent / "target"
            target.mkdir()
            root = parent / constants.APPLICATION_DIRECTORY_NAME
            root.symlink_to(target, target_is_directory=True)
            application_directory.return_value = root

            with self.assertRaises(ConnectorError):
                forget_connector_data()

        delete_token.assert_not_called()


if __name__ == "__main__":
    unittest.main()
