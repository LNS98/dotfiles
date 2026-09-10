#!/usr/bin/env python3
"""Fetch the pinned upstream repositories without requiring either agent CLI."""
import io
import json
import re
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def tree_contents(directory):
    """Compare generated content without letting timestamps trigger rewrites."""
    result = {}
    for path in directory.rglob("*"):
        relative = str(path.relative_to(directory))
        if path.is_symlink():
            result[relative] = ("link", str(path.readlink()))
        elif path.is_file():
            result[relative] = ("file", path.read_bytes(), path.stat().st_mode & 0o777)
        else:
            result[relative] = ("directory",)
    return result


def export_shared(root, name, checkout):
    destination = root / "agents/.shared" / name / checkout.name
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=destination.parent) as temporary:
        temporary = Path(temporary)
        committed = temporary / "committed"
        committed.mkdir()
        archive = subprocess.check_output(
            ["git", "-C", str(checkout), "archive", "--format=tar", checkout.name]
        )
        with tarfile.open(fileobj=io.BytesIO(archive)) as source:
            source.extractall(committed, filter="data")
        exported = temporary / "content"
        shutil.copytree(
            committed,
            exported,
            symlinks=True,
            ignore=shutil.ignore_patterns(
                ".git",
                ".claude-plugin",
                ".cursor-plugin",
                ".codex-plugin",
                "node_modules",
            ),
        )
        overlay = root / "agents/overlays" / name
        if overlay.exists():
            for source in overlay.rglob("*"):
                if source.is_file():
                    target = exported / source.relative_to(overlay)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, target)
        if destination.exists() and tree_contents(destination) == tree_contents(
            exported
        ):
            return
        previous = temporary / "previous"
        if destination.exists():
            destination.rename(previous)
        try:
            exported.rename(destination)
        except OSError:
            if previous.exists():
                previous.rename(destination)
            raise


def sync(root=ROOT):
    sources = json.loads((root / "agents/sources.json").read_text())
    vendor = root / "agents/.vendor"
    vendor.mkdir(parents=True, exist_ok=True)
    for name, source in sources.items():
        commit = source["commit"]
        if not re.fullmatch(r"[0-9a-f]{40}", commit):
            raise ValueError(f"{name}: pin a full Git commit SHA")
        destination = vendor / name / commit
        if destination.exists():
            actual = subprocess.check_output(
                ["git", "-C", str(destination), "rev-parse", "HEAD"], text=True
            ).strip()
            if actual != commit:
                raise ValueError(
                    f"{destination}: unexpected revision; inspect it before continuing"
                )
            print(f"{name}: already at {commit}")
            export_shared(root, name, destination)
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=destination.parent) as temporary:

            def git(*args):
                subprocess.run(["git", "-C", temporary, *args], check=True)

            git("init", "--quiet")
            git("remote", "add", "origin", source["repository"])
            git("fetch", "--quiet", "--depth=1", "origin", commit)
            git("checkout", "--quiet", "--detach", commit)
            Path(temporary).rename(destination)
        export_shared(root, name, destination)
        print(f"{name}: fetched {commit}")


if __name__ == "__main__":
    sync()
