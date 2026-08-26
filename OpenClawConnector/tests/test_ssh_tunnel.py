"""Restricted one-shot SSH tunnel tests."""

from __future__ import annotations

import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import MagicMock, patch

from local_assistant_connector import constants
from local_assistant_connector.models import ConnectorConfig
from local_assistant_connector.ssh_tunnel import OpenClawSSHTunnel, _safe_ssh_error


def connector_config() -> ConnectorConfig:
    """Build one non-secret restricted SSH configuration."""
    return ConnectorConfig(
        ssh_host="openclaw.example.test",
        ssh_port=22,
        ssh_user="local-assistant-tunnel",
        spool_directory="/tmp/local-assistant-test-spool",
        request_timeout_seconds=5.0,
    )


class SSHTunnelTests(unittest.TestCase):
    """Verify every tunnel is local-only, noninteractive, and short-lived."""

    def test_uses_only_restricted_local_forwarding_and_closes_child(self) -> None:
        """The child receives no shell, PTY, agent, X11, remote, or dynamic forwarding."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            private_key = Path(temporary_directory) / "id_ed25519"
            known_hosts = Path(temporary_directory) / "known_hosts"
            private_key.write_text("private", encoding="utf-8")
            known_hosts.write_text("host key", encoding="utf-8")
            os.chmod(private_key, 0o600)
            os.chmod(known_hosts, 0o600)
            process = MagicMock()
            process.poll.return_value = None
            process.wait.return_value = 0
            connection = MagicMock()

            with (
                patch(
                    "local_assistant_connector.ssh_tunnel.ssh_private_key_path",
                    return_value=private_key,
                ),
                patch(
                    "local_assistant_connector.ssh_tunnel.ssh_known_hosts_path",
                    return_value=known_hosts,
                ),
                patch(
                    "local_assistant_connector.ssh_tunnel._available_loopback_port",
                    return_value=49_321,
                ),
                patch(
                    "local_assistant_connector.ssh_tunnel.socket.create_connection",
                    return_value=connection,
                ),
                patch(
                    "local_assistant_connector.ssh_tunnel.subprocess.Popen",
                    return_value=process,
                ) as popen,
            ):
                with OpenClawSSHTunnel(connector_config()) as origin:
                    self.assertEqual(origin, "http://127.0.0.1:49321")

            arguments = popen.call_args.args[0]
            self.assertIn("-N", arguments)
            self.assertIn("-T", arguments)
            self.assertIn(
                "127.0.0.1:49321:127.0.0.1:23116",
                arguments,
            )
            self.assertIn("ForwardAgent=no", arguments)
            self.assertIn("ForwardX11=no", arguments)
            self.assertIn("RequestTTY=no", arguments)
            self.assertNotIn("-R", arguments)
            self.assertNotIn("-D", arguments)
            self.assertNotIn("shell", popen.call_args.kwargs)
            process.terminate.assert_called_once_with()

    def test_quotes_known_hosts_path_for_open_ssh_option_parsing(self) -> None:
        """A standard Application Support path remains one pinned-host file."""
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory) / "Application Support" / "Connector"
            root.mkdir(parents=True)
            private_key = root / "id_ed25519"
            known_hosts = root / "known_hosts"
            private_key.write_text("private", encoding="utf-8")
            known_hosts.write_text("host key", encoding="utf-8")
            os.chmod(private_key, 0o600)
            os.chmod(known_hosts, 0o600)
            process = MagicMock()
            process.poll.return_value = None
            process.wait.return_value = 0

            with (
                patch(
                    "local_assistant_connector.ssh_tunnel.ssh_private_key_path",
                    return_value=private_key,
                ),
                patch(
                    "local_assistant_connector.ssh_tunnel.ssh_known_hosts_path",
                    return_value=known_hosts,
                ),
                patch(
                    "local_assistant_connector.ssh_tunnel._available_loopback_port",
                    return_value=49_321,
                ),
                patch(
                    "local_assistant_connector.ssh_tunnel.socket.create_connection",
                    return_value=MagicMock(),
                ),
                patch(
                    "local_assistant_connector.ssh_tunnel.subprocess.Popen",
                    return_value=process,
                ) as popen,
            ):
                with OpenClawSSHTunnel(connector_config()):
                    pass

            self.assertIn(
                f'UserKnownHostsFile="{known_hosts}"',
                popen.call_args.args[0],
            )

    def test_maps_open_ssh_failures_without_returning_raw_output(self) -> None:
        """Setup receives a precise allowlisted reason, never raw SSH output."""
        cases = {
            b"Host key verification failed.": constants.ERROR_SSH_HOST_KEY_MISMATCH,
            b"Permission denied (publickey).": constants.ERROR_SSH_PUBLIC_KEY_REJECTED,
            b"Could not resolve hostname example.invalid":
                constants.ERROR_SSH_HOST_UNRESOLVED,
            b"connect to host example port 22: Connection refused":
                constants.ERROR_SSH_CONNECTION_REFUSED,
            b"connect to host example port 22: Operation timed out":
                constants.ERROR_SSH_CONNECTION_TIMEOUT,
            b"ssh: connect to host example port 22: No route to host":
                constants.ERROR_SSH_NETWORK_UNREACHABLE,
        }
        for raw, expected in cases.items():
            with self.subTest(expected=expected):
                self.assertEqual(_safe_ssh_error(raw), expected)
        self.assertEqual(
            _safe_ssh_error(b"unexpected secret-looking diagnostic"),
            constants.ERROR_UNREACHABLE,
        )


if __name__ == "__main__":
    unittest.main()
