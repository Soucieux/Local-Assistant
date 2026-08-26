"""Command-line setup and service entry point."""

from __future__ import annotations

import argparse
import getpass
import json
from pathlib import Path
import sys

from . import constants
from .configuration import load_config, parse_config, save_config, save_ssh_host_key
from .keychain import save_token
from .models import ConnectorError
from .service import ConnectorService
from .setup_state import existing_setup_state, forget_connector_data
from .spool import SpoolStore
from .transport import OpenClawTransport


def _parser() -> argparse.ArgumentParser:
    """Build the connector's explicit subcommand parser."""
    parser = argparse.ArgumentParser(description=constants.CLI_DESCRIPTION)
    commands = parser.add_subparsers(
        dest=constants.CLI_ARGUMENT_COMMAND,
        required=True,
    )
    configure = commands.add_parser(constants.CLI_CONFIGURE)
    configure.add_argument(constants.CLI_ARGUMENT_SSH_HOST, required=True)
    configure.add_argument(
        constants.CLI_ARGUMENT_SSH_PORT,
        type=int,
        default=constants.DEFAULT_SSH_PORT,
    )
    configure.add_argument(constants.CLI_ARGUMENT_SSH_USER, required=True)
    configure.add_argument(constants.CLI_ARGUMENT_SPOOL, required=True)
    configure.add_argument(
        constants.CLI_ARGUMENT_REQUEST_TIMEOUT,
        type=float,
        default=constants.DEFAULT_REQUEST_TIMEOUT_SECONDS,
    )
    commands.add_parser(constants.CLI_SET_REMINDER_TOKEN)
    commands.add_parser(constants.CLI_SET_AGENT_TOKEN)
    commands.add_parser(constants.CLI_SET_SSH_HOST_KEY)
    commands.add_parser(constants.CLI_SETUP_STDIN)
    commands.add_parser(constants.CLI_RECONFIGURE_STDIN)
    commands.add_parser(constants.CLI_ONCE)
    commands.add_parser(constants.CLI_STATUS)
    commands.add_parser(constants.CLI_VERIFY)
    commands.add_parser(constants.CLI_SETUP_STATE)
    commands.add_parser(constants.CLI_FORGET)
    return parser


def _configure(arguments: argparse.Namespace) -> None:
    """Validate and save non-secret connector configuration."""
    document = {
        constants.CONFIG_SSH_HOST: arguments.ssh_host,
        constants.CONFIG_SSH_PORT: arguments.ssh_port,
        constants.CONFIG_SSH_USER: arguments.ssh_user,
        constants.CONFIG_SPOOL_DIRECTORY: str(Path(arguments.spool).expanduser()),
        constants.CONFIG_REQUEST_TIMEOUT_SECONDS: arguments.request_timeout,
    }
    save_config(parse_config(document))
    print(constants.CLI_CONFIGURED)


def _save_prompted_token(account: str, prompt: str) -> None:
    """Prompt without echo and store one credential in Keychain."""
    save_token(account, getpass.getpass(prompt))
    print(constants.CLI_TOKEN_SAVED)


def _save_setup_document(document: object) -> None:
    """Validate and save one complete packaged-app setup document."""
    if not isinstance(document, dict) or frozenset(document) != constants.SETUP_REQUIRED_FIELDS:
        raise ValueError(constants.ERROR_INVALID_CONFIG)
    config = parse_config(
        {
            constants.CONFIG_SSH_HOST: document[constants.CONFIG_SSH_HOST],
            constants.CONFIG_SSH_PORT: document[constants.CONFIG_SSH_PORT],
            constants.CONFIG_SSH_USER: document[constants.CONFIG_SSH_USER],
            constants.CONFIG_SPOOL_DIRECTORY: document[constants.CONFIG_SPOOL_DIRECTORY],
        }
    )
    reminder_token = document[constants.SETUP_REMINDER_TOKEN]
    agent_token = document[constants.SETUP_AGENT_TOKEN]
    if not isinstance(reminder_token, str) or not isinstance(agent_token, str):
        raise ValueError(constants.ERROR_TOKEN_MISSING)
    save_ssh_host_key(document[constants.SETUP_SSH_HOST_KEY])
    save_token(constants.KEYCHAIN_REMINDER_ACCOUNT, reminder_token)
    save_token(constants.KEYCHAIN_AGENT_ACCOUNT, agent_token)
    save_config(config)
    print(constants.CLI_SETUP_SAVED)


def _setup_from_stdin() -> None:
    """Save packaged-app setup received only through bounded standard input."""
    raw = sys.stdin.buffer.read(constants.MAX_SETUP_STDIN_BYTES + 1)
    if len(raw) > constants.MAX_SETUP_STDIN_BYTES:
        raise ValueError(constants.ERROR_TOO_LARGE)
    _save_setup_document(json.loads(raw.decode("utf-8")))


def _save_reconfigure_document(document: object) -> None:
    """Save changed non-secret values while retaining existing Keychain tokens."""
    if (
        not isinstance(document, dict)
        or frozenset(document) != constants.RECONFIGURE_REQUIRED_FIELDS
    ):
        raise ValueError(constants.ERROR_INVALID_CONFIG)
    config = parse_config(
        {
            constants.CONFIG_SSH_HOST: document[constants.CONFIG_SSH_HOST],
            constants.CONFIG_SSH_PORT: document[constants.CONFIG_SSH_PORT],
            constants.CONFIG_SSH_USER: document[constants.CONFIG_SSH_USER],
            constants.CONFIG_SPOOL_DIRECTORY: document[constants.CONFIG_SPOOL_DIRECTORY],
        }
    )
    save_ssh_host_key(document[constants.SETUP_SSH_HOST_KEY])
    save_config(config)
    print(constants.CLI_CONFIGURED)


def _reconfigure_from_stdin() -> None:
    """Receive changed non-secret setup only through bounded standard input."""
    raw = sys.stdin.buffer.read(constants.MAX_SETUP_STDIN_BYTES + 1)
    if len(raw) > constants.MAX_SETUP_STDIN_BYTES:
        raise ValueError(constants.ERROR_TOO_LARGE)
    _save_reconfigure_document(json.loads(raw.decode("utf-8")))


def main() -> int:
    """Execute one configuration, credential, status, or service command."""
    arguments = _parser().parse_args()
    if arguments.command == constants.CLI_CONFIGURE:
        _configure(arguments)
        return 0
    if arguments.command == constants.CLI_SET_REMINDER_TOKEN:
        _save_prompted_token(
            constants.KEYCHAIN_REMINDER_ACCOUNT,
            constants.CLI_PROMPT_REMINDER_TOKEN,
        )
        return 0
    if arguments.command == constants.CLI_SET_AGENT_TOKEN:
        _save_prompted_token(
            constants.KEYCHAIN_AGENT_ACCOUNT,
            constants.CLI_PROMPT_AGENT_TOKEN,
        )
        return 0
    if arguments.command == constants.CLI_SET_SSH_HOST_KEY:
        save_ssh_host_key(input(constants.CLI_PROMPT_SSH_HOST_KEY))
        print(constants.CLI_SSH_HOST_KEY_SAVED)
        return 0
    if arguments.command == constants.CLI_SETUP_STDIN:
        _setup_from_stdin()
        return 0
    if arguments.command == constants.CLI_RECONFIGURE_STDIN:
        _reconfigure_from_stdin()
        return 0
    if arguments.command == constants.CLI_STATUS:
        config = load_config()
        print(SpoolStore(config.spool_directory).read_status_text())
        return 0
    if arguments.command == constants.CLI_VERIFY:
        try:
            OpenClawTransport(load_config()).verify_reminder_snapshot()
        except ConnectorError as error:
            print(str(error), file=sys.stderr)
            if str(error) == constants.ERROR_AUTHENTICATION:
                return constants.CLI_EXIT_AUTHENTICATION
            if str(error) in constants.SSH_DIAGNOSTIC_ERRORS:
                return constants.CLI_EXIT_UNREACHABLE
            if str(error) == constants.ERROR_VERIFICATION:
                return constants.CLI_EXIT_SNAPSHOT
            return constants.CLI_EXIT_FAILURE
        print(constants.CLI_VERIFIED)
        return 0
    if arguments.command == constants.CLI_SETUP_STATE:
        print(json.dumps(existing_setup_state(), separators=(",", ":")))
        return 0
    if arguments.command == constants.CLI_FORGET:
        forget_connector_data()
        print(constants.CLI_FORGOTTEN)
        return 0

    service = ConnectorService()
    try:
        service.process_once()
    finally:
        service.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
