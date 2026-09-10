#!/usr/bin/env python3
"""Link a single skill catalog and instruction file into each selected agent."""
import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MATT_PLUGIN = "mattpocock-skills@claude-plugins-official"


def patch_upstream(root, destination_home):
    """Apply reviewed edits only when the pinned upstream text still matches."""
    patches = root / "agents/patches.json"
    if not patches.exists():
        return
    changes = []
    for patch in json.loads(patches.read_text()):
        path = destination_home / ".agents/skills" / patch["skill"] / "SKILL.md"
        text = path.read_text()
        if text.count(patch["before"]) != 1:
            raise ValueError(f"{path}: compatibility patch no longer matches upstream")
        changes.append((path, text.replace(patch["before"], patch["after"], 1)))
    for path, text in changes:
        path.write_text(text)


def read_claude_settings(path):
    data = json.loads(path.read_text())
    if not isinstance(data, dict) or not isinstance(
        data.get("enabledPlugins", {}), dict
    ):
        raise ValueError(f"{path}: settings and enabledPlugins must be JSON objects")
    return data


def preserve_claude_settings(root, path, archive, dry_run):
    """Keep local preferences active; manage only the duplicate skill plugin."""
    data = read_claude_settings(path)
    if data.get("enabledPlugins", {}).get(MATT_PLUGIN) is False:
        return
    print(f"Disable duplicate skill plugin in {path}")
    if dry_run:
        return
    archive.mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix="settings-", dir=archive))
    # Snapshot bytes, including when the destination is a link to another checkout.
    shutil.copy2(path, backup / "settings.json")
    data.setdefault("enabledPlugins", {})[MATT_PLUGIN] = False
    # Detach external links so migration cannot modify another checkout.
    # Existing links to this checkout stay live and use its required clean filter.
    destination = path
    if (
        path.is_symlink()
        and path.resolve() == (root / "claude/settings.json").resolve()
    ):
        destination = path.resolve()
    with tempfile.NamedTemporaryFile(
        mode="w", dir=destination.parent, delete=False
    ) as f:
        temporary = Path(f.name)
        try:
            f.write(json.dumps(data, indent=2) + "\n")
            f.close()
            temporary.replace(destination)
        finally:
            temporary.unlink(missing_ok=True)


def catalog(root, installed_home=None):
    result = {}
    paths = list(sorted((root / "agents/skills").iterdir()))
    if installed_home is not None:
        paths.extend(
            installed_home / ".agents/skills" / name for name in upstream_names(root)
        )
    for path in paths:
        text = (path / "SKILL.md").read_text()
        frontmatter = text.split("---", 2)[1]
        match = re.search(r"^name:\s*([a-z0-9-]+)\s*$", frontmatter, re.M)
        if not match or match[1] != path.name:
            raise ValueError(f"{path}: name must match the skill directory")
        if path.name in result:
            raise ValueError(f"Duplicate skill: {path.name}")
        # Check invocation parity before touching the installation.
        explicit = bool(
            re.search(r"^disable-model-invocation:\s*true\s*$", frontmatter, re.M)
        )
        metadata = path / "agents/openai.yaml"
        codex_explicit = metadata.exists() and bool(
            re.search(r"allow_implicit_invocation:\s*false", metadata.read_text())
        )
        if explicit != codex_explicit:
            raise ValueError(f"{path}: Claude and Codex invocation policies differ")
        result[path.name] = path
    return result


def upstream_names(root):
    manifest = json.loads((root / "agents/sources.json").read_text())
    names = [name for source in manifest["sources"] for name in source["skills"]]
    if len(names) != len(set(names)) or any(
        not re.fullmatch(r"[a-z0-9-]+", name) for name in names
    ):
        raise ValueError("Upstream skill names must be unique lowercase names")
    return names


def install_upstream(root, destination_home, targets, dry_run):
    manifest = json.loads((root / "agents/sources.json").read_text())
    names = upstream_names(root)
    if set(names) & set(catalog(root)):
        raise ValueError("Personal and upstream skill names must be distinct")
    cli = [
        "npx",
        "--yes",
        "--package=node@22",
        f"--package=skills@{manifest['cli_version']}",
        "--",
        "skills",
    ]
    agents = ["claude-code" if target == "claude" else target for target in targets]
    for source in manifest["sources"]:
        command = cli + [
            "add",
            source["source"],
            "--agent",
            *agents,
            "--skill",
            *source["skills"],
            "--yes",
        ]
        # Project scope gives isolated --home tests the same .agents/.claude layout.
        # Real installs use the upstream CLI's global scope and lockfile.
        if destination_home == Path.home():
            command.append("--global")
        print(shlex.join(command))
        if dry_run:
            continue
        destination_home.mkdir(parents=True, exist_ok=True)
        existing = [
            destination_home / ".agents/skills" / name for name in source["skills"]
        ]
        if "claude" in targets:
            existing.extend(
                destination_home / ".claude/skills" / name for name in source["skills"]
            )
        existing = [path for path in existing if os.path.lexists(path)]
        if existing:
            archives = destination_home / ".local/share/dotfiles/backups"
            archives.mkdir(parents=True, exist_ok=True)
            backup = Path(tempfile.mkdtemp(prefix="upstream-", dir=archives))
            for path in existing:
                saved = backup / path.relative_to(destination_home)
                saved.parent.mkdir(parents=True, exist_ok=True)
                if path.is_symlink():
                    saved.symlink_to(path.resolve())
                elif path.is_dir():
                    shutil.copytree(path, saved, symlinks=True)
                else:
                    shutil.copy2(path, saved)
            print(f"Previous skill installation saved in {backup}")
        env = os.environ.copy()
        if destination_home == Path.home() and "claude" in targets:
            env["CLAUDE_CONFIG_DIR"] = str(destination_home / ".claude")
        if destination_home != Path.home():
            env["XDG_STATE_HOME"] = str(destination_home / ".skills-state")
        subprocess.run(command, cwd=destination_home, env=env, check=True)
    if not dry_run:
        patch_upstream(root, destination_home)
        for name in names:
            overlay = root / "agents/overlays" / name
            if overlay.exists():
                shutil.copytree(
                    overlay,
                    destination_home / ".agents/skills" / name,
                    dirs_exist_ok=True,
                )
        catalog(root, destination_home)


def configure_claude_filter(root):
    # Git attributes do not require an undefined filter. Set this before the
    # live settings link can cause machine-local values to enter this repo.
    command = "python3 " + shlex.quote(str(root / "scripts/clean-claude-settings.py"))
    for key, value in {
        "clean": command,
        "smudge": "cat",
        "required": "true",
    }.items():
        subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "config",
                "--local",
                f"filter.stripAutoMode.{key}",
                value,
            ],
            check=True,
        )


def install(root, destination_home, target="all", dry_run=False, codex_home=None):
    skills = catalog(root)
    codex_home = codex_home or destination_home / ".codex"
    archive = destination_home / ".local/share/dotfiles/backups"
    targets = ["claude", "codex"] if target == "all" else [target]
    configured_claude = os.environ.get("CLAUDE_CONFIG_DIR", "").strip()
    if "claude" in targets and destination_home == Path.home() and configured_claude:
        if (
            Path(configured_claude).expanduser().resolve()
            != (destination_home / ".claude").resolve()
        ):
            raise ValueError(
                "This dotfiles setup uses ~/.claude; unset CLAUDE_CONFIG_DIR or set it to ~/.claude before installing Claude"
            )
    settings = destination_home / ".claude/settings.json"
    if "claude" in targets and os.path.lexists(settings):
        read_claude_settings(settings)
    install_upstream(root, destination_home, targets, dry_run)
    upstream = set(upstream_names(root))
    links = []
    for agent in targets:
        skill_dir = destination_home / (
            ".claude/skills" if agent == "claude" else ".agents/skills"
        )
        links.extend((source, skill_dir / name) for name, source in skills.items())
        instructions = (
            destination_home / ".claude/CLAUDE.md"
            if agent == "claude"
            else codex_home / "AGENTS.md"
        )
        links.append((root / "agents/AGENTS.md", instructions))
    if "claude" in targets:
        links.extend(
            (root / "claude" / name, destination_home / ".claude" / name)
            for name in ["statusline-command.sh"]
        )
        if not os.path.lexists(settings):
            links.append((root / "claude/settings.json", settings))
    if "claude" in targets and not dry_run:
        configure_claude_filter(root)
    if "claude" in targets and os.path.lexists(settings):
        preserve_claude_settings(root, settings, archive, dry_run)
    # Seed native preferences only on a fresh Codex installation.
    config = codex_home / "config.toml"
    if "codex" in targets and not os.path.lexists(config):
        print(f"Seed {config}")
        if not dry_run:
            config.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / "codex/config.toml", config)
    if "codex" in targets and (codex_home / "AGENTS.override.md").exists():
        print(
            f'Note: {codex_home / "AGENTS.override.md"} takes precedence over shared instructions'
        )

    def backup(path):
        print(f"Archive {path}")
        if not dry_run:
            archive.mkdir(parents=True, exist_ok=True)
            folder = Path(tempfile.mkdtemp(prefix="migration-", dir=archive))
            path.rename(folder / path.name)

    for source, destination in links:
        if destination.is_symlink() and destination.resolve() == source.resolve():
            continue
        print(f"Link {destination} -> {source}")
        if os.path.lexists(destination):
            backup(destination)
        if not dry_run:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.symlink_to(source, target_is_directory=source.is_dir())

    # Only retire links that our prior manifest owns, and only if still unchanged.
    state_dir = destination_home / ".local/share/dotfiles"
    for agent in targets:
        state_file = state_dir / f"{agent}-skills.json"
        previous = json.loads(state_file.read_text()) if state_file.exists() else {}
        skill_dir = destination_home / (
            ".claude/skills" if agent == "claude" else ".agents/skills"
        )
        for name, old_source in previous.items():
            old_link = skill_dir / name
            if (
                name not in skills
                and name not in upstream
                and old_link.is_symlink()
                and os.readlink(old_link) == old_source
            ):
                backup(old_link)
        current = {name: str(source) for name, source in skills.items()}
        if not dry_run and previous != current:
            state_dir.mkdir(parents=True, exist_ok=True)
            state_file.write_text(json.dumps(current, indent=2) + "\n")

    # Remove only a known obsolete, broken dotfiles link. Leave unrelated skills alone.
    old = destination_home / ".claude/skills/show-me-your-work"
    if "claude" in targets and old.is_symlink() and not old.exists():
        if Path(os.readlink(old)) == root / "claude/skills/show-me-your-work":
            backup(old)
    print(
        f'{"Would install" if dry_run else "Installed"} {len(skills) + len(upstream)} shared skills for {", ".join(targets)}'
    )
    return skills


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=["all", "claude", "codex"], default="all")
    parser.add_argument(
        "--home",
        type=Path,
        default=Path.home(),
        help="Destination home, also useful for isolated tests",
    )
    parser.add_argument(
        "--codex-home", type=Path, help="Defaults to CODEX_HOME, or <home>/.codex"
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    selected_codex_home = args.codex_home
    if (
        selected_codex_home is None
        and args.home == Path.home()
        and os.environ.get("CODEX_HOME")
    ):
        selected_codex_home = Path(os.environ["CODEX_HOME"])
    try:
        install(
            ROOT,
            args.home.expanduser().absolute(),
            args.target,
            args.dry_run,
            selected_codex_home,
        )
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(
            1,
            f"{error}\n",
        )
