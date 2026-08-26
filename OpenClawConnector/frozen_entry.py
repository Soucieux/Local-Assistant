"""Frozen executable entry point for the separately distributed connector."""

from local_assistant_connector.cli import main


if __name__ == "__main__":
    raise SystemExit(main())
