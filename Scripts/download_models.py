#!/usr/bin/env python3
"""Download pinned model assets only on an internet-connected staging Mac."""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import urllib.parse
import urllib.request


USER_AGENT = "LocalAssistant-Offline-Staging/1"
BUFFER_BYTES = 1024 * 1024


def request_json(url: str) -> object:
    """Read JSON from one HTTPS endpoint."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def download(url: str, destination: pathlib.Path) -> None:
    """Download one file atomically into the staging bundle."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_suffix(destination.suffix + ".partial")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request) as response, partial.open("wb") as output:
        while chunk := response.read(BUFFER_BYTES):
            output.write(chunk)
    partial.replace(destination)


def sha256(path: pathlib.Path) -> str:
    """Return a streaming SHA-256 digest."""
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(BUFFER_BYTES):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_url(repository: str, revision: str, path: str) -> str:
    """Build an immutable Hugging Face resolve URL."""
    encoded_path = "/".join(urllib.parse.quote(component, safe="") for component in path.split("/"))
    return f"https://huggingface.co/{repository}/resolve/{revision}/{encoded_path}?download=true"


def download_file_model(model: dict[str, object], output: pathlib.Path) -> None:
    """Download and verify one pinned GGUF file."""
    destination = output / str(model["installedName"])
    download(
        resolve_url(str(model["repository"]), str(model["revision"]), str(model["sourcePath"])),
        destination,
    )
    expected = str(model["sha256"])
    actual = sha256(destination)
    if actual != expected:
        destination.unlink(missing_ok=True)
        raise RuntimeError(f"Checksum mismatch for {destination.name}: {actual}")


def download_directory_model(model: dict[str, object], output: pathlib.Path) -> None:
    """Download every file under one pinned model directory."""
    repository = str(model["repository"])
    revision = str(model["revision"])
    source_path = str(model["sourcePath"])
    api_path = urllib.parse.quote(source_path, safe="/")
    tree_url = (
        f"https://huggingface.co/api/models/{repository}/tree/{revision}/{api_path}"
        "?recursive=true&expand=false&limit=1000"
    )
    entries = request_json(tree_url)
    if not isinstance(entries, list):
        raise RuntimeError(f"Unexpected model tree response for {repository}")
    destination_root = output / str(model["installedName"])
    for entry in entries:
        if not isinstance(entry, dict) or entry.get("type") != "file":
            continue
        remote_path = str(entry["path"])
        relative = pathlib.PurePosixPath(remote_path).relative_to(source_path)
        destination = destination_root.joinpath(*relative.parts)
        download(resolve_url(repository, revision, remote_path), destination)


def main() -> int:
    """Download all manifest models into a staging output directory."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    arguments = parser.parse_args()
    manifest = json.loads(arguments.manifest.read_text())
    arguments.output.mkdir(parents=True, exist_ok=True)
    for model in manifest["models"]:
        if "sha256" in model:
            download_file_model(model, arguments.output)
        else:
            download_directory_model(model, arguments.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
