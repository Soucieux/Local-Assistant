#!/usr/bin/env python3
"""Fetch exact source revisions on a connected staging Mac."""

from __future__ import annotations

import json
import pathlib
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.parse
import urllib.request


ARCHIVE_SOCKET_TIMEOUT_SECONDS = 120

def checkout(repository: str, revision: str, destination: pathlib.Path) -> None:
    """Create or reuse one immutable dependency source archive."""
    revision_file = destination / ".local-assistant-revision"
    if destination.exists() and (destination / ".git").exists():
        try:
            actual = subprocess.check_output(
                ["git", "rev-parse", "HEAD"],
                cwd=destination,
                text=True,
                stderr=subprocess.DEVNULL,
            ).strip()
        except subprocess.CalledProcessError:
            shutil.rmtree(destination)
        else:
            if actual == revision:
                revision_file.write_text(revision + "\n")
                return
            raise RuntimeError(f"Refusing to overwrite dependency checkout at revision {actual}: {destination}")
    if destination.exists():
        if revision_file.exists() and revision_file.read_text().strip() == revision:
            return
        raise RuntimeError(f"Refusing to overwrite non-managed directory: {destination}")
    download_archive(repository, revision, destination)


def download_archive(repository: str, revision: str, destination: pathlib.Path) -> None:
    """Download and safely unpack an immutable GitHub commit archive."""
    parsed = urllib.parse.urlparse(repository)
    if parsed.scheme != "https" or parsed.netloc != "github.com":
        raise RuntimeError(f"Archive fallback only supports GitHub HTTPS repositories: {repository}")
    repository_path = parsed.path.removesuffix(".git").strip("/")
    if len(repository_path.split("/")) != 2:
        raise RuntimeError(f"Unexpected GitHub repository path: {repository}")
    archive_url = f"https://codeload.github.com/{repository_path}/tar.gz/{revision}"
    request = urllib.request.Request(
        archive_url,
        headers={"User-Agent": "LocalAssistant-Offline-Staging/1"},
    )
    with tempfile.TemporaryDirectory(prefix="local-assistant-dependency-") as temporary:
        temporary_path = pathlib.Path(temporary)
        archive_path = temporary_path / "source.tar.gz"
        with urllib.request.urlopen(
            request,
            timeout=ARCHIVE_SOCKET_TIMEOUT_SECONDS,
        ) as response, archive_path.open("wb") as output:
            shutil.copyfileobj(response, output)
        extraction_root = temporary_path / "source"
        extraction_root.mkdir()
        with tarfile.open(archive_path, mode="r:gz") as archive:
            safe_extract(archive, extraction_root)
        extracted = [path for path in extraction_root.iterdir() if path.is_dir()]
        if len(extracted) != 1:
            raise RuntimeError(f"Unexpected archive layout for {repository}")
        shutil.move(str(extracted[0]), destination)
    (destination / ".local-assistant-revision").write_text(revision + "\n")


def safe_extract(archive: tarfile.TarFile, destination: pathlib.Path) -> None:
    """Extract a trusted-source archive while preventing path traversal."""
    destination_resolved = destination.resolve()
    for member in archive.getmembers():
        member_path = (destination / member.name).resolve()
        if destination_resolved not in member_path.parents and member_path != destination_resolved:
            raise RuntimeError(f"Unsafe archive path: {member.name}")
    try:
        archive.extractall(destination, filter="data")
    except TypeError:
        validate_legacy_tar_members(archive)
        archive.extractall(destination)


def validate_legacy_tar_members(archive: tarfile.TarFile) -> None:
    """Validate paths and link targets before extraction on older Python versions."""
    for member in archive.getmembers():
        member_path = pathlib.PurePosixPath(member.name)
        validated_archive_path(member_path, member.name)
        if member.isdev() or member.isfifo():
            raise RuntimeError(f"Unsafe archive member type: {member.name}")
        if member.issym():
            validated_archive_path(member_path.parent / member.linkname, member.name)
        elif member.islnk():
            validated_archive_path(pathlib.PurePosixPath(member.linkname), member.name)


def validated_archive_path(path: pathlib.PurePosixPath, member_name: str) -> None:
    """Reject absolute paths and any parent traversal that leaves the archive root."""
    if path.is_absolute():
        raise RuntimeError(f"Unsafe archive path: {member_name}")
    depth = 0
    for component in path.parts:
        if component in ("", "."):
            continue
        if component == "..":
            depth -= 1
            if depth < 0:
                raise RuntimeError(f"Unsafe archive path: {member_name}")
        else:
            depth += 1


def main() -> int:
    """Fetch dependency pins and generate the sqlite-vec amalgamation."""
    project = pathlib.Path(__file__).resolve().parents[1]
    manifest = json.loads((project / "Config" / "DependencyPins.json").read_text())
    vendor = project / "Vendor"
    vendor.mkdir(parents=True, exist_ok=True)
    directory_names = {
        "llama.cpp": "llama.cpp",
        "WhisperKit": "WhisperKit",
        "ZIPFoundation": "ZIPFoundation",
        "sqlite-vec": "sqlite-vec-source",
    }
    for name, dependency in manifest["dependencies"].items():
        checkout(
            dependency["repository"],
            dependency["revision"],
            vendor / directory_names[name],
        )

    # A refreshed checkout restores upstream sources, so the offline patches that keep
    # vendored code off the network are re-applied and verified on every run.
    subprocess.check_call(
        [sys.executable, str(pathlib.Path(__file__).resolve().parent / "apply_offline_patches.py")]
    )

    sqlite_source = vendor / "sqlite-vec-source"
    generated = subprocess.check_output(
        [sys.executable, str(sqlite_source / "scripts" / "amalgamate.py"), str(sqlite_source / "sqlite-vec.c")]
    )
    destination = project / "LocalAssistant" / "VendorBridge" / "sqlite-vec.c"
    destination.write_bytes(generated)
    shutil.copystat(sqlite_source / "sqlite-vec.c", destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
