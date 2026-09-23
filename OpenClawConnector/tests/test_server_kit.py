"""The server setup kit must satisfy its own imports.

The kit is installed onto a server whose workspace may be older than anything in
this repository, so every module its files import has to travel with them. Two
defects of exactly this shape have already reached a live server: the kit shipped
the reminder bridge without ``runtime_support``, and later without ``config``.
Both failed at import time, on the server, and the setup script reported only a
readiness timeout.
"""

from __future__ import annotations

import ast
import re
import sys
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[3]
BUILDER = REPOSITORY / "Local Assistant" / "Scripts" / "build_openclaw_server_kit.sh"
OPENCLAW = REPOSITORY / "OpenClaw"
SOURCE_REFERENCE = re.compile(r"\$\{OPENCLAW_DIR\}/scripts/([^\"\s]+)")


def shipped_python_files() -> list[Path]:
    """Resolve the workspace Python files the kit builder copies.

    Returns:
        Every existing ``.py`` file the builder names under ``scripts/``,
        expanding the ``*.py`` package globs it uses.
    """
    text = BUILDER.read_text(encoding="utf-8")
    files: list[Path] = []
    for reference in SOURCE_REFERENCE.findall(text):
        candidate = OPENCLAW / "scripts" / reference
        if reference.endswith("/"):
            # The builder globs a package as "…/runtime_support/"*.py, closing
            # the quote before the glob, so the captured reference is the
            # directory itself.
            files.extend(sorted(candidate.glob("*.py")))
        elif reference.endswith("*.py"):
            files.extend(sorted(candidate.parent.glob("*.py")))
        elif candidate.suffix == ".py" and candidate.is_file():
            files.append(candidate)
    return files


def shipped_module_names(files: list[Path]) -> set[str]:
    """Name every module importable from the installed kit alone.

    Args:
        files: The Python files the kit ships.

    Returns:
        Top-level module and package names the installed workspace will hold.
    """
    names: set[str] = set()
    for path in files:
        if path.parent.name == "scripts":
            names.add(path.stem)
        else:
            names.add(path.parent.name)
    return names


def imported_roots(path: Path) -> set[str]:
    """Collect the top-level modules a file imports.

    Args:
        path: Python file to parse.

    Returns:
        Root module names. Relative imports stay inside their package and
        therefore travel with it, so they are ignored.
    """
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    roots: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            roots.add(node.module.split(".")[0])
    return roots


@unittest.skipUnless(
    (OPENCLAW / "scripts").is_dir(),
    "the OpenClaw sources the kit is built from are absent; the kit can only be "
    "built, and therefore only checked, from the full repository",
)
class ServerKitImportClosureTests(unittest.TestCase):
    """Every import a shipped file makes must resolve from the kit or the stdlib."""

    def test_builder_ships_files(self) -> None:
        """The parser must find the payload, or the closure test proves nothing."""
        self.assertTrue(BUILDER.is_file(), f"missing kit builder: {BUILDER}")
        self.assertGreater(len(shipped_python_files()), 0)

    def test_every_import_resolves_from_the_kit(self) -> None:
        """No shipped file may import a module the kit leaves behind."""
        files = shipped_python_files()
        available = shipped_module_names(files) | set(
            getattr(sys, "stdlib_module_names", ())
        )
        missing: list[str] = []
        for path in files:
            for root in sorted(imported_roots(path) - available):
                missing.append(f"{path.relative_to(REPOSITORY)} imports {root!r}")
        self.assertEqual(
            missing,
            [],
            "the kit ships files whose imports it does not satisfy; add the "
            "module to build_openclaw_server_kit.sh beside its callers",
        )

    def test_known_shared_dependencies_travel(self) -> None:
        """Pin the two dependencies that have already failed on a live server."""
        names = shipped_module_names(shipped_python_files())
        self.assertIn("config", names)
        self.assertIn("runtime_support", names)


if __name__ == "__main__":
    unittest.main()
