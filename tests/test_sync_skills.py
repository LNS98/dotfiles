"""Generated skill content must not inherit a host-specific plugin namespace."""

import importlib.util
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "sync", Path(__file__).resolve().parents[1] / "scripts/sync-skills.py"
)
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)


class ExportTests(unittest.TestCase):
    def test_export_keeps_references_and_metadata_without_plugin_manifests(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            checkout = root / "agents/.vendor/upstream/revision"
            for name in [
                ".git",
                ".claude-plugin",
                "nested/.cursor-plugin",
                ".codex-plugin",
            ]:
                directory = checkout / name
                directory.mkdir(parents=True)
                (directory / "plugin.json").write_text("{}")
            skill = checkout / "skills/example"
            skill.mkdir(parents=True)
            (skill / "SKILL.md").write_text("Read reference.md")
            (skill / "reference.md").write_text("Useful reference")
            (checkout / "LICENSE").write_text("License text")
            overlay = (
                root / "agents/overlays/upstream/skills/example/agents/openai.yaml"
            )
            overlay.parent.mkdir(parents=True)
            overlay.write_text("policy:\n  allow_implicit_invocation: false\n")
            sync.export_shared(root, "upstream", checkout)
            exported = root / "agents/.shared/upstream/revision"
            self.assertEqual(
                (exported / "skills/example/reference.md").read_text(),
                "Useful reference",
            )
            self.assertEqual((exported / "LICENSE").read_text(), "License text")
            self.assertTrue((exported / "skills/example/agents/openai.yaml").exists())
            self.assertEqual(list(exported.rglob("plugin.json")), [])
            self.assertTrue((checkout / ".claude-plugin/plugin.json").exists())
            self.assertFalse((checkout / "skills/example/agents/openai.yaml").exists())
            sync.export_shared(root, "upstream", checkout)
            self.assertTrue((exported / "skills/example/reference.md").exists())


if __name__ == "__main__":
    unittest.main()
