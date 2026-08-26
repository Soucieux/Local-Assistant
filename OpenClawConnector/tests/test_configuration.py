"""Configuration boundary tests for the separately installed connector."""

from __future__ import annotations

import unittest
from unittest.mock import patch

from local_assistant_connector import cli, constants
from local_assistant_connector.configuration import parse_config
from local_assistant_connector.models import ConnectorError


def config_document(**overrides):
    """Build one minimal non-secret connector configuration."""
    document = {
        constants.CONFIG_SSH_HOST: "openclaw.example.test",
        constants.CONFIG_SSH_PORT: 22,
        constants.CONFIG_SSH_USER: "local-assistant-tunnel",
        constants.CONFIG_SPOOL_DIRECTORY: "/tmp/local-assistant-spool",
    }
    document.update(overrides)
    return document


class ConfigurationTests(unittest.TestCase):
    """Verify the restricted SSH endpoint and local spool boundary."""

    def test_accepts_one_ssh_server_and_restricted_account(self) -> None:
        """Both connector lanes use one validated SSH server identity."""
        config = parse_config(config_document())
        self.assertEqual(config.ssh_host, "openclaw.example.test")
        self.assertEqual(config.ssh_port, 22)
        self.assertEqual(config.ssh_user, "local-assistant-tunnel")

    def test_rejects_ssh_host_with_url_or_path(self) -> None:
        """Configuration never treats shell or URL syntax as a server name."""
        with self.assertRaises(ConnectorError):
            parse_config(config_document(sshHost="https://openclaw.example.test/path"))

    def test_rejects_ssh_host_that_looks_like_an_open_ssh_option(self) -> None:
        """The positional host cannot inject another OpenSSH option."""
        with self.assertRaises(ConnectorError):
            parse_config(config_document(sshHost="-V"))

    def test_rejects_legacy_public_origin_fields(self) -> None:
        """A public HTTP origin cannot reappear beside the SSH endpoint."""
        with self.assertRaises(ConnectorError):
            parse_config(config_document(openclawOrigin="https://other.example.test"))

    def test_rejects_relative_spool_directory(self) -> None:
        """The service never resolves its data boundary from its launch directory."""
        with self.assertRaises(ConnectorError):
            parse_config(config_document(spoolDirectory="relative/spool"))

    @patch("local_assistant_connector.cli.save_config")
    @patch("local_assistant_connector.cli.save_token")
    @patch("local_assistant_connector.cli.save_ssh_host_key")
    def test_packaged_setup_saves_tokens_before_enabling_configuration(
        self,
        save_ssh_host_key,
        save_token,
        save_config,
    ) -> None:
        """The one-shot job cannot observe new config before both tokens exist."""
        manager = unittest.mock.Mock()
        manager.attach_mock(save_ssh_host_key, "host_key")
        manager.attach_mock(save_token, "token")
        manager.attach_mock(save_config, "config")
        cli._save_setup_document(
            {
                constants.CONFIG_SSH_HOST: "openclaw.example.test",
                constants.CONFIG_SSH_PORT: 22,
                constants.CONFIG_SSH_USER: "local-assistant-tunnel",
                constants.CONFIG_SPOOL_DIRECTORY: "/tmp/local-assistant-spool",
                constants.SETUP_SSH_HOST_KEY: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEa0MQd13yrpoY5UFpgBI5XZpVhPcN0nqk9fgYvYNx7G",
                constants.SETUP_REMINDER_TOKEN: "reminder-secret",
                constants.SETUP_AGENT_TOKEN: "agent-secret",
            }
        )
        self.assertEqual(
            [call[0] for call in manager.mock_calls],
            ["host_key", "token", "token", "config"],
        )

    @patch("local_assistant_connector.cli.save_config")
    @patch("local_assistant_connector.cli.save_token")
    @patch("local_assistant_connector.cli.save_ssh_host_key")
    def test_packaged_setup_rejects_unknown_fields(
        self,
        save_ssh_host_key,
        save_token,
        save_config,
    ) -> None:
        """The companion cannot widen the packaged setup contract."""
        with self.assertRaises(ValueError):
            cli._save_setup_document(
                {
                    constants.CONFIG_SSH_HOST: "openclaw.example.test",
                    constants.CONFIG_SSH_PORT: 22,
                    constants.CONFIG_SSH_USER: "local-assistant-tunnel",
                    constants.CONFIG_SPOOL_DIRECTORY: "/tmp/local-assistant-spool",
                    constants.SETUP_SSH_HOST_KEY: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEa0MQd13yrpoY5UFpgBI5XZpVhPcN0nqk9fgYvYNx7G",
                    constants.SETUP_REMINDER_TOKEN: "reminder-secret",
                    constants.SETUP_AGENT_TOKEN: "agent-secret",
                    "unexpected": True,
                }
            )
        save_token.assert_not_called()
        save_ssh_host_key.assert_not_called()
        save_config.assert_not_called()

    @patch("local_assistant_connector.cli.save_config")
    @patch("local_assistant_connector.cli.save_ssh_host_key")
    def test_reconfigure_retains_keychain_credentials(
        self,
        save_ssh_host_key,
        save_config,
    ) -> None:
        """Editing public server values never reads or replaces saved tokens."""
        cli._save_reconfigure_document(
            {
                constants.CONFIG_SSH_HOST: "new.example.test",
                constants.CONFIG_SSH_PORT: 2222,
                constants.CONFIG_SSH_USER: "local-assistant-tunnel",
                constants.CONFIG_SPOOL_DIRECTORY: "/tmp/local-assistant-spool",
                constants.SETUP_SSH_HOST_KEY:
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEa0MQd13yrpoY5UFpgBI5XZpVhPcN0nqk9fgYvYNx7G",
            }
        )
        save_ssh_host_key.assert_called_once()
        save_config.assert_called_once()


if __name__ == "__main__":
    unittest.main()
