"""The server setup kit must satisfy its own imports.

The kit is installed onto a server whose workspace may be older than anything in
this repository, so every module its files import has to travel with them. Two
defects of exactly this shape have already reached a live server: the kit shipped
the reminder bridge without ``runtime_support``, and later without ``config``.
Both failed at import time, on the server, and the setup script reported only a
readiness timeout. A third stayed hidden because it sat in a shell script: the
store manager's duplicate check, a heredoc program, imported a package the kit
never shipped, so the Python a shipped script embeds is checked too.
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
SHELL_REFERENCE = re.compile(r"\$\{OPENCLAW_DIR\}/([^\"\s]+\.sh)")
# A Python program a shell script feeds python3 through a quoted heredoc,
# `python3 … << 'PYEOF'` up to the line that closes it. The body starts after
# the whole command, so a line the command continues with a backslash, such as
# setup-server.sh's `<<'PYEOF' \` followed by `|| fail …`, is skipped first.
EMBEDDED_PYTHON = re.compile(
    r"python3\b[^\n]*<<-?\s*'(?P<marker>[A-Za-z_][A-Za-z0-9_]*)'(?:[^\n]*\\\n)*[^\n]*\n"
    r"(?P<body>.*?)\n(?P=marker)$",
    re.DOTALL | re.MULTILINE,
)


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


def shipped_shell_files() -> list[Path]:
    """Resolve the shell scripts the kit builder copies from OpenClaw.

    Returns:
        Every existing ``.sh`` file the builder names, the setup script included.
    """
    text = BUILDER.read_text(encoding="utf-8")
    return [
        OPENCLAW / reference
        for reference in sorted(set(SHELL_REFERENCE.findall(text)))
        if (OPENCLAW / reference).is_file()
    ]


def embedded_python_programs(path: Path) -> list[str]:
    """Extract the Python programs a shell script runs from quoted heredocs.

    A shipped script's embedded programs import modules exactly as a shipped
    ``.py`` file does, and the store manager's once imported a package the kit
    never carried while every ``.py`` file passed.

    Args:
        path: Shell script to scan.

    Returns:
        Each program's source, in file order.
    """
    return [match.group("body") for match in EMBEDDED_PYTHON.finditer(path.read_text(encoding="utf-8"))]


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


def imported_roots(source: str, filename: str) -> set[str]:
    """Collect the top-level modules a Python program imports.

    Args:
        source: Program text, from a shipped file or a script's heredoc.
        filename: Where the program came from, for a parse error.

    Returns:
        Root module names. Relative imports stay inside their package and
        therefore travel with it, so they are ignored.
    """
    tree = ast.parse(source, filename=filename)
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
        self.assertGreater(
            sum(len(embedded_python_programs(path)) for path in shipped_shell_files()), 0
        )

    def test_every_import_resolves_from_the_kit(self) -> None:
        """No shipped file, nor a program a shipped script embeds, may import a module the kit leaves behind."""
        files = shipped_python_files()
        available = shipped_module_names(files) | set(
            getattr(sys, "stdlib_module_names", ())
        )
        missing: list[str] = []
        for path in files:
            source = path.read_text(encoding="utf-8")
            for root in sorted(imported_roots(source, str(path)) - available):
                missing.append(f"{path.relative_to(REPOSITORY)} imports {root!r}")
        for path in shipped_shell_files():
            for index, program in enumerate(embedded_python_programs(path), 1):
                for root in sorted(imported_roots(program, f"{path}, program {index}") - available):
                    missing.append(
                        f"{path.relative_to(REPOSITORY)} embedded program {index} imports {root!r}"
                    )
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
