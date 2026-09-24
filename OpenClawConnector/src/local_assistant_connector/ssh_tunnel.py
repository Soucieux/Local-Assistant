"""One-request OpenSSH tunnel to the loopback-only OpenClaw Gateway."""

from __future__ import annotations

from contextlib import AbstractContextManager
import os
from pathlib import Path
import socket
import stat
import subprocess
import tempfile
import time
from typing import BinaryIO

from . import constants
from .configuration import ssh_known_hosts_path, ssh_private_key_path
from .models import ConnectorConfig, ConnectorError


def _safe_ssh_error(stderr: bytes) -> str:
    """Map bounded OpenSSH diagnostics to credential-free user messages.

    Args:
        stderr: Bounded raw output captured from the OpenSSH child.

    Returns:
        One allowlisted message; the raw output is never passed on.
    """
    normalized = stderr.decode("utf-8", errors="ignore").casefold()
    if "host key verification failed" in normalized \
            or "remote host identification has changed" in normalized:
        return constants.ERROR_SSH_HOST_KEY_MISMATCH
    if "permission denied" in normalized or "no mutual signature algorithm" in normalized:
        return constants.ERROR_SSH_PUBLIC_KEY_REJECTED
    if "could not resolve hostname" in normalized or "nodename nor servname" in normalized:
        return constants.ERROR_SSH_HOST_UNRESOLVED
    if "connection refused" in normalized:
        return constants.ERROR_SSH_CONNECTION_REFUSED
    if "connection timed out" in normalized or "operation timed out" in normalized:
        return constants.ERROR_SSH_CONNECTION_TIMEOUT
    if "no route to host" in normalized or "network is unreachable" in normalized:
        return constants.ERROR_SSH_NETWORK_UNREACHABLE
    return constants.ERROR_UNREACHABLE


def _require_owner_file(path: Path) -> None:
    """Require one non-linked owner-only regular credential file.

    Args:
        path: Private key or pinned host-key file handed to OpenSSH.

    Raises:
        ConnectorError: When the file is missing, linked, owned by another
            user, or accessible to anyone but its owner.
    """
    try:
        metadata = path.lstat()
    except OSError as exc:
        raise ConnectorError.not_configured(constants.ERROR_SSH_IDENTITY) from exc
    if (
        not stat.S_ISREG(metadata.st_mode)
        or stat.S_ISLNK(metadata.st_mode)
        or metadata.st_uid != os.getuid()
        or metadata.st_mode & constants.GROUP_AND_OTHER_ACCESS_MASK
    ):
        raise ConnectorError.invalid_request(constants.ERROR_SSH_IDENTITY)


def _available_loopback_port() -> int:
    """Reserve and release one ephemeral loopback port for the child tunnel.

    Returns:
        A port that was free on the loopback interface a moment ago.
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind((constants.SSH_LOOPBACK_HOST, 0))
        return int(listener.getsockname()[1])


class OpenClawSSHTunnel(AbstractContextManager[str]):
    """Starts one forwarding-only SSH child and always closes it after use."""

    def __init__(self, config: ConnectorConfig) -> None:
        """Store validated connection identity without opening a socket.

        Args:
            config: Validated server address, port, and restricted account.
        """
        self._config = config
        self._process: subprocess.Popen[bytes] | None = None
        self._stderr: BinaryIO | None = None
        self._local_port = 0

    def __enter__(self) -> str:
        """Open the restricted tunnel for one request.

        Returns:
            The exact local HTTP origin that forwards to the Gateway.

        Raises:
            ConnectorError: When the identity files are unsafe or the tunnel
                cannot be established.
        """
        private_key = ssh_private_key_path()
        known_hosts = ssh_known_hosts_path()
        _require_owner_file(private_key)
        _require_owner_file(known_hosts)
        self._local_port = _available_loopback_port()
        forwarding = (
            f"{constants.SSH_LOOPBACK_HOST}:{self._local_port}:"
            f"{constants.SSH_REMOTE_GATEWAY_HOST}:"
            f"{constants.SSH_REMOTE_GATEWAY_PORT}"
        )
        arguments = [
            constants.SSH_EXECUTABLE,
            "-F",
            "/dev/null",
            "-N",
            "-T",
            "-p",
            str(self._config.ssh_port),
            "-l",
            self._config.ssh_user,
            "-i",
            str(private_key),
            "-L",
            forwarding,
            "-o",
            "BatchMode=yes",
            "-o",
            "IdentitiesOnly=yes",
            "-o",
            "IdentityAgent=none",
            "-o",
            "StrictHostKeyChecking=yes",
            "-o",
            f'UserKnownHostsFile="{known_hosts}"',
            "-o",
            "GlobalKnownHostsFile=/dev/null",
            "-o",
            f"HostKeyAlias={constants.SSH_HOST_KEY_ALIAS}",
            "-o",
            "CheckHostIP=no",
            "-o",
            "ExitOnForwardFailure=yes",
            "-o",
            "ForwardAgent=no",
            "-o",
            "ForwardX11=no",
            "-o",
            "RequestTTY=no",
            "-o",
            "PermitLocalCommand=no",
            "-o",
            f"ConnectTimeout={constants.SSH_CONNECT_TIMEOUT_SECONDS}",
            self._config.ssh_host,
        ]
        try:
            self._stderr = tempfile.TemporaryFile()
            self._process = subprocess.Popen(
                arguments,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=self._stderr,
                close_fds=True,
            )
            self._wait_until_ready()
        except ConnectorError:
            self.close()
            raise
        except OSError:
            self.close()
            raise ConnectorError.operational(constants.ERROR_UNREACHABLE, retryable=True)
        return (
            f"{constants.LOOPBACK_URL_SCHEME}://"
            f"{constants.SSH_LOOPBACK_HOST}:{self._local_port}"
        )

    def _wait_until_ready(self) -> None:
        """Wait until OpenSSH owns the local forwarding port or exits.

        Raises:
            ConnectorError: When the child exits first or the port never opens.
        """
        deadline = (
            time.monotonic()
            + constants.SSH_CONNECT_TIMEOUT_SECONDS
            + constants.SSH_READY_GRACE_SECONDS
        )
        while time.monotonic() < deadline:
            if self._process is None or self._process.poll() is not None:
                raise ConnectorError.operational(self._diagnostic_message(), retryable=True)
            try:
                with socket.create_connection(
                    (constants.SSH_LOOPBACK_HOST, self._local_port),
                    timeout=constants.SSH_READY_POLL_SECONDS,
                ):
                    return
            except OSError:
                time.sleep(constants.SSH_READY_POLL_SECONDS)
        raise ConnectorError.operational(constants.ERROR_UNREACHABLE, retryable=True)

    def _diagnostic_message(self) -> str:
        """Diagnose a failed tunnel without exposing raw OpenSSH output.

        Returns:
            One allowlisted message chosen from the child's bounded output.
        """
        if self._stderr is None:
            return constants.ERROR_UNREACHABLE
        try:
            self._stderr.flush()
            self._stderr.seek(0)
            return _safe_ssh_error(self._stderr.read(constants.MAX_REQUEST_BYTES))
        except OSError:
            return constants.ERROR_UNREACHABLE

    def close(self) -> None:
        """Terminate only the child tunnel started by this context."""
        process = self._process
        self._process = None
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=constants.SSH_SHUTDOWN_TIMEOUT_SECONDS)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=constants.SSH_SHUTDOWN_TIMEOUT_SECONDS)
        if self._stderr is not None:
            self._stderr.close()
            self._stderr = None

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        """Close the child tunnel even when the HTTP request fails.

        Args:
            exc_type: Exception class raised inside the context, if any.
            exc_value: Exception raised inside the context, if any.
            traceback: Traceback of that exception, if any.
        """
        self.close()
