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
        (self.root / "agents/sources.json").write_text("{}\n")
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

    def test_missing_source_fails_before_writing(self):
        (self.root / "agents/sources.json").write_text(
            json.dumps({"upstream": {"commit": "a" * 40, "skills": ["missing"]}})
        )
        with self.assertRaises(FileNotFoundError):
            self.install()
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
