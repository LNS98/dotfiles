"""Generated skill content comes from committed source and current overlays."""

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "sync", Path(__file__).resolve().parents[1] / "scripts/sync-skills.py"
)
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        checkout = self.root / "agents/.vendor/upstream/initial"
        checkout.mkdir(parents=True)
        subprocess.run(["git", "init", "--quiet", str(checkout)], check=True)
        for name in [".claude-plugin", "nested/.cursor-plugin", ".codex-plugin"]:
            directory = checkout / name
            directory.mkdir(parents=True)
            (directory / "plugin.json").write_text("{}")
        skill = checkout / "skills/example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("Read reference.md")
        (skill / "reference.md").write_text("Useful reference")
        (checkout / "LICENSE").write_text("License text")
        subprocess.run(["git", "-C", str(checkout), "add", "."], check=True)
        subprocess.run(
            [
                "git",
                "-C",
                str(checkout),
                "-c",
                "user.name=Installer Test",
                "-c",
                "user.email=installer@example.invalid",
                "-c",
                "commit.gpgsign=false",
                "commit",
                "--quiet",
                "-m",
                "fixture",
            ],
            check=True,
        )
        commit = subprocess.check_output(
            ["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True
        ).strip()
        self.checkout = checkout.with_name(commit)
        checkout.rename(self.checkout)
        self.exported = self.root / "agents/.shared/upstream" / commit
        self.overlay = (
            self.root / "agents/overlays/upstream/skills/example/agents/openai.yaml"
        )
        self.overlay.parent.mkdir(parents=True)
        self.overlay.write_text("policy:\n  allow_implicit_invocation: false\n")

    def export(self):
        sync.export_shared(self.root, "upstream", self.checkout)

    def test_export_keeps_references_and_metadata_without_plugin_manifests(self):
        self.export()
        self.assertEqual(
            (self.exported / "skills/example/reference.md").read_text(),
            "Useful reference",
        )
        self.assertEqual((self.exported / "LICENSE").read_text(), "License text")
        self.assertTrue((self.exported / "skills/example/agents/openai.yaml").exists())
        self.assertEqual(list(self.exported.rglob("plugin.json")), [])
        self.assertFalse((self.exported / ".git").exists())
        self.assertTrue((self.checkout / ".claude-plugin/plugin.json").exists())
        self.assertFalse((self.checkout / "skills/example/agents/openai.yaml").exists())
        before = self.exported.stat().st_mtime_ns
        self.export()
        self.assertEqual(self.exported.stat().st_mtime_ns, before)

    def test_deleted_overlay_does_not_survive_rerun(self):
        self.export()
        self.overlay.unlink()
        self.export()
        self.assertFalse((self.exported / "skills/example/agents/openai.yaml").exists())

    def test_exports_committed_content_and_repairs_modified_export(self):
        (self.checkout / "skills/example/SKILL.md").write_text("uncommitted change")
        self.export()
        result = self.exported / "skills/example/SKILL.md"
        self.assertEqual(result.read_text(), "Read reference.md")
        result.write_text("modified export")
        self.export()
        self.assertEqual(result.read_text(), "Read reference.md")
        self.assertEqual(
            (self.checkout / "skills/example/SKILL.md").read_text(),
            "uncommitted change",
        )


if __name__ == "__main__":
    unittest.main()
