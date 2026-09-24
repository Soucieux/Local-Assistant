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
METADATA_TIMEOUT_SECONDS = 30
DOWNLOAD_TIMEOUT_SECONDS = 300
TREE_PAGE_LIMIT = 1000


def request_json(url: str) -> object:
    """Read JSON from one HTTPS endpoint.

    Args:
        url: Metadata endpoint to query.

    Returns:
        The decoded JSON value, still unvalidated.
    """
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=METADATA_TIMEOUT_SECONDS) as response:
        return json.load(response)


def download(url: str, destination: pathlib.Path) -> None:
    """Download one file atomically into the staging bundle.

    Args:
        url: Immutable source address.
        destination: Final path; a partial download never appears under it.
    """
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_suffix(destination.suffix + ".partial")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=DOWNLOAD_TIMEOUT_SECONDS) as response, partial.open("wb") as output:
            while chunk := response.read(BUFFER_BYTES):
                output.write(chunk)
    except BaseException:
        partial.unlink(missing_ok=True)
        raise
    partial.replace(destination)


def download_verified(url: str, destination: pathlib.Path, expected: str) -> None:
    """Download one file and keep it only when it matches its pinned digest.

    Args:
        url: Immutable source address.
        destination: Final path of the verified file.
        expected: Pinned lowercase SHA-256 digest.

    Raises:
        RuntimeError: When the downloaded content has another digest.
    """
    download(url, destination)
    actual = sha256(destination)
    if actual != expected:
        destination.unlink(missing_ok=True)
        raise RuntimeError(f"Checksum mismatch for {destination.name}: {actual}")


def sha256(path: pathlib.Path) -> str:
    """Hash one file without loading it into memory.

    Args:
        path: File to hash.

    Returns:
        The lowercase hexadecimal SHA-256 digest.
    """
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(BUFFER_BYTES):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_url(repository: str, revision: str, path: str) -> str:
    """Build an immutable Hugging Face resolve URL.

    Args:
        repository: Owner and model name.
        revision: Pinned commit revision.
        path: File path inside the repository.

    Returns:
        A download address that always serves that revision's bytes.
    """
    encoded_path = "/".join(urllib.parse.quote(component, safe="") for component in path.split("/"))
    return f"https://huggingface.co/{repository}/resolve/{revision}/{encoded_path}?download=true"


def download_file_model(model: dict[str, object], output: pathlib.Path) -> None:
    """Download and verify one pinned GGUF file.

    Args:
        model: Manifest entry describing a single-file model.
        output: Staging directory that receives the installed filename.

    Raises:
        RuntimeError: When the downloaded file fails its digest.
    """
    download_verified(
        resolve_url(str(model["repository"]), str(model["revision"]), str(model["sourcePath"])),
        output / str(model["installedName"]),
        str(model["sha256"]),
    )


def download_additional_files(model: dict[str, object], destination_root: pathlib.Path) -> None:
    """Download pinned companion files into an already-downloaded model directory.

    WhisperKit loads its tokenizer from the model directory and otherwise reaches out to
    the Hugging Face Hub at first use, so these files must ship with the model.

    Args:
        model: Manifest entry that may list pinned companion files.
        destination_root: Installed model directory that receives them.

    Raises:
        RuntimeError: When an entry is malformed or a file fails its digest.
    """
    for entry in model.get("additionalFiles", []):
        if not isinstance(entry, dict):
            raise RuntimeError(f"Malformed additionalFiles entry for {model['installedName']}")
        download_verified(
            resolve_url(str(entry["repository"]), str(entry["revision"]), str(entry["sourcePath"])),
            destination_root / str(entry["installedName"]),
            str(entry["sha256"]),
        )


def download_directory_model(model: dict[str, object], output: pathlib.Path) -> None:
    """Download every file under one pinned model directory.

    Args:
        model: Manifest entry describing a directory model.
        output: Staging directory that receives the installed directory.

    Raises:
        RuntimeError: When the file listing is unexpected, possibly truncated,
            or empty, or a companion file fails its digest.
    """
    repository = str(model["repository"])
    revision = str(model["revision"])
    source_path = str(model["sourcePath"])
    api_path = urllib.parse.quote(source_path, safe="/")
    tree_url = (
        f"https://huggingface.co/api/models/{repository}/tree/{revision}/{api_path}"
        f"?recursive=true&expand=false&limit={TREE_PAGE_LIMIT}"
    )
    entries = request_json(tree_url)
    if not isinstance(entries, list):
        raise RuntimeError(f"Unexpected model tree response for {repository}")
    if len(entries) >= TREE_PAGE_LIMIT:
        raise RuntimeError(
            f"Model tree for {repository}/{source_path} may be truncated at "
            f"{TREE_PAGE_LIMIT} entries; refusing to ship a partial model directory"
        )
    destination_root = output / str(model["installedName"])
    downloaded = 0
    for entry in entries:
        if not isinstance(entry, dict) or entry.get("type") != "file":
            continue
        remote_path = str(entry["path"])
        relative = pathlib.PurePosixPath(remote_path).relative_to(source_path)
        destination = destination_root.joinpath(*relative.parts)
        download(resolve_url(repository, revision, remote_path), destination)
        downloaded += 1
    if downloaded == 0:
        raise RuntimeError(f"No files found for {repository}/{source_path}")
    download_additional_files(model, destination_root)


def main() -> int:
    """Download all manifest models into a staging output directory.

    Returns:
        Zero once every model is downloaded.
    """
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
