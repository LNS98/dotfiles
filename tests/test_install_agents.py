"""Offline migration tests. No agent CLIs, network, or real home-directory writes."""

import contextlib
import importlib.util
import io
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "installer", Path(__file__).resolve().parents[1] / "scripts/install-agents.py"
)
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / "dotfiles with spaces"
        self.home = self.base / "home"
        self.root.mkdir()
        subprocess.run(["git", "init", "--quiet", str(self.root)], check=True)
        (self.root / ".gitattributes").write_text(
            "claude/settings.json filter=stripAutoMode\n"
        )
        (self.root / "scripts").mkdir()
        shutil.copy2(
            Path(__file__).resolve().parents[1] / "scripts/clean-claude-settings.py",
            self.root / "scripts/clean-claude-settings.py",
        )
        skill = self.root / "agents/skills/example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text(
            "---\nname: example\ndescription: Example\n---\nBody\n"
        )
        (self.root / "agents/sources.json").write_text(
            '{"cli_version":"1.5.25","sources":[]}\n'
        )
        (self.root / "agents/AGENTS.md").write_text("Shared instructions\n")
        (self.root / "claude").mkdir()
        (self.root / "claude/settings.json").write_text(
            '{"enabledPlugins": {"mattpocock-skills@claude-plugins-official": false}}\n'
        )
        (self.root / "claude/statusline-command.sh").write_text("echo status\n")
        (self.root / "codex").mkdir()
        (self.root / "codex/config.toml").write_text(
            'project_doc_fallback_filenames = ["CLAUDE.md"]\n'
        )

    def install(self, **kwargs):
        with contextlib.redirect_stdout(io.StringIO()):
            return installer.install(self.root, self.home, **kwargs)

    def test_same_sources_and_idempotent(self):
        self.install()
        claude = self.home / ".claude/skills/example"
        codex = self.home / ".agents/skills/example"
        self.assertEqual(claude.resolve(), codex.resolve())
        self.assertEqual(
            (self.home / ".claude/CLAUDE.md").resolve(),
            (self.home / ".codex/AGENTS.md").resolve(),
        )
        before = {p: p.lstat().st_mtime_ns for p in self.home.rglob("*")}
        self.install()
        self.assertEqual(
            before, {p: p.lstat().st_mtime_ns for p in self.home.rglob("*")}
        )
        self.assertFalse((self.home / ".local/share/dotfiles/backups").exists())

    def test_migration_preserves_files_config_and_unrelated_skills(self):
        old = self.home / ".claude/skills/example"
        old.mkdir(parents=True)
        (old / "SKILL.md").write_text("user work")
        unrelated = old.parent / "unrelated"
        unrelated.mkdir()
        (unrelated / "SKILL.md").write_text("keep")
        config = self.home / ".codex/config.toml"
        config.parent.mkdir()
        config.write_text('model = "user-choice"\n')
        self.install()
        self.assertEqual(config.read_text(), 'model = "user-choice"\n')
        self.assertEqual((unrelated / "SKILL.md").read_text(), "keep")
        backups = list(
            (self.home / ".local/share/dotfiles/backups").glob("*/example/SKILL.md")
        )
        self.assertEqual([p.read_text() for p in backups], ["user work"])

    def test_fresh_claude_install_filters_machine_local_security_data(self):
        self.install(target="claude")
        settings = self.home / ".claude/settings.json"
        data = json.loads(settings.read_text())
        data["autoMode"] = {"environment": ["TEST_SENTINEL"]}
        settings.write_text(json.dumps(data))
        subprocess.run(
            ["git", "-C", str(self.root), "add", "claude/settings.json"], check=True
        )
        staged = subprocess.check_output(
            ["git", "-C", str(self.root), "show", ":claude/settings.json"]
        )
        self.assertNotIn("autoMode", json.loads(staged))
        self.assertIn("autoMode", json.loads(settings.read_text()))
        required = subprocess.check_output(
            [
                "git",
                "-C",
                str(self.root),
                "config",
                "--get",
                "filter.stripAutoMode.required",
            ],
            text=True,
        )
        self.assertEqual(required.strip(), "true")
        # If the filter cannot run, staging must fail rather than leaking data.
        (self.root / "scripts/clean-claude-settings.py").unlink()
        data["autoMode"]["environment"].append("SECOND_SENTINEL")
        settings.write_text(json.dumps(data))
        result = subprocess.run(
            ["git", "-C", str(self.root), "add", "claude/settings.json"],
            capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)

    def test_codex_only_does_not_create_claude(self):
        self.install(target="codex")
        self.assertTrue((self.home / ".agents/skills/example/SKILL.md").exists())
        self.assertFalse((self.home / ".claude").exists())

    def test_claude_only_does_not_create_codex(self):
        self.install(target="claude")
        self.assertFalse((self.home / ".codex").exists())
        self.assertFalse((self.home / ".agents").exists())

    def test_dry_run_has_no_side_effects(self):
        self.install(dry_run=True)
        self.assertFalse(self.home.exists())

    def test_custom_codex_home(self):
        custom = self.base / "custom-codex"
        self.install(target="codex", codex_home=custom)
        self.assertTrue((custom / "AGENTS.md").is_symlink())
        self.assertFalse((self.home / ".codex").exists())

    def test_policy_mismatch_fails_before_writing(self):
        path = self.root / "agents/skills/example/SKILL.md"
        path.write_text(
            path.read_text().replace(
                "description: Example",
                "description: Example\ndisable-model-invocation: true",
            )
        )
        with self.assertRaisesRegex(ValueError, "policies differ"):
            self.install()
        self.assertFalse(self.home.exists())
        metadata = path.parent / "agents/openai.yaml"
        metadata.parent.mkdir()
        metadata.write_text("policy:\n  allow_implicit_invocation: false\n")
        self.install()

    def add_upstream_fixture(self):
        (self.root / "agents/sources.json").write_text(
            json.dumps(
                {
                    "cli_version": "1.5.25",
                    "sources": [
                        {
                            "source": "https://github.com/example/skills.git#"
                            + "a" * 40,
                            "skills": ["upstream"],
                        }
                    ],
                }
            )
        )

    def test_invalid_selection_fails_before_writing(self):
        self.add_upstream_fixture()
        path = self.root / "agents/sources.json"
        path.write_text(path.read_text().replace('"upstream"', '"../escape"'))
        with self.assertRaises(ValueError):
            self.install()
        self.assertFalse(self.home.exists())

    def test_upstream_cli_owns_download_installation_and_links(self):
        self.add_upstream_fixture()

        def run(command, **kwargs):
            self.assertEqual(command[:3], ["npx", "--yes", "--package=node@22"])
            self.assertIn("--package=skills@1.5.25", command)
            self.assertIn("codex", command)
            self.assertNotIn("claude-code", command)
            canonical = self.home / ".agents/skills/upstream"
            canonical.mkdir(parents=True)
            (canonical / "SKILL.md").write_text(
                "---\nname: upstream\ndescription: Test\n---\n"
            )

        with patch.object(installer.subprocess, "run", side_effect=run) as mocked:
            self.install(target="codex")
        self.assertEqual(mocked.call_count, 1)
        self.assertFalse((self.home / ".claude").exists())

    def test_upstream_failure_preserves_existing_installation_and_configuration(self):
        self.add_upstream_fixture()
        old = self.home / ".agents/skills/upstream"
        old.mkdir(parents=True)
        (old / "SKILL.md").write_text("old skill")
        with patch.object(
            installer.subprocess,
            "run",
            side_effect=subprocess.CalledProcessError(1, "npx"),
        ):
            with self.assertRaises(subprocess.CalledProcessError):
                self.install()
        self.assertEqual((old / "SKILL.md").read_text(), "old skill")
        self.assertFalse((self.home / ".claude/settings.json").exists())
        backups = list(
            (self.home / ".local/share/dotfiles/backups").glob(
                "upstream-*/.agents/skills/upstream/SKILL.md"
            )
        )
        self.assertEqual([path.read_text() for path in backups], ["old skill"])

    def test_custom_claude_directory_is_rejected_before_any_writes(self):
        self.add_upstream_fixture()
        with patch.object(Path, "home", return_value=self.home), patch.dict(
            installer.os.environ,
            {"CLAUDE_CONFIG_DIR": str(self.base / "custom-claude")},
        ):
            with patch.object(installer.subprocess, "run") as mocked:
                with self.assertRaisesRegex(ValueError, "CLAUDE_CONFIG_DIR"):
                    self.install()
            mocked.assert_not_called()
        self.assertFalse(self.home.exists())

    def test_global_cli_receives_absolute_default_claude_directory(self):
        self.add_upstream_fixture()

        def run(command, **kwargs):
            self.assertIn("--global", command)
            self.assertEqual(
                kwargs["env"]["CLAUDE_CONFIG_DIR"], str(self.home / ".claude")
            )
            canonical = self.home / ".agents/skills/upstream"
            canonical.mkdir(parents=True)
            (canonical / "SKILL.md").write_text(
                "---\nname: upstream\ndescription: Test\n---\n"
            )

        with patch.object(Path, "home", return_value=self.home), patch.dict(
            installer.os.environ, {"CLAUDE_CONFIG_DIR": "~/.claude"}
        ), patch.object(installer.subprocess, "run", side_effect=run):
            installer.install_upstream(self.root, self.home, ["claude"], False)

    def test_upstream_dry_run_does_not_launch_cli(self):
        self.add_upstream_fixture()
        with patch.object(installer.subprocess, "run") as mocked:
            self.install(dry_run=True)
        mocked.assert_not_called()
        self.assertFalse(self.home.exists())

    def test_removed_owned_skills_are_retired_but_user_replacements_survive(self):
        self.install()
        replacement = self.base / "user-skill"
        replacement.mkdir()
        codex = self.home / ".agents/skills/example"
        codex.unlink()
        codex.symlink_to(replacement)
        import shutil

        shutil.rmtree(self.root / "agents/skills/example")
        self.install()
        self.assertFalse((self.home / ".claude/skills/example").is_symlink())
        self.assertEqual(codex.resolve(), replacement.resolve())

    def test_obsolete_owned_broken_link_is_archived(self):
        old = self.home / ".claude/skills/show-me-your-work"
        old.parent.mkdir(parents=True)
        old.symlink_to(self.root / "claude/skills/show-me-your-work")
        self.install()
        self.assertFalse(old.is_symlink())
        self.assertEqual(
            len(
                list(
                    (self.home / ".local/share/dotfiles/backups").glob(
                        "*/show-me-your-work"
                    )
                )
            ),
            1,
        )


if __name__ == "__main__":
    unittest.main()
