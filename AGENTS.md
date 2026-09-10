# Dotfiles maintenance

Read README.md before changing installation behavior. Shared instructions and
personal skills belong under agents/. Native adapters belong under claude/ and
codex/. Keep shared skill versions and invocation policies identical across both
targets. Read agents/sources.json before changing upstream dependencies.

Preserve existing local changes, especially claude/settings.json, which is also
the live settings target. Never print or commit its machine-local autoMode data.
The stripAutoMode clean filter in .gitattributes must remain required.

Test installer changes with temporary destination directories. Do not run the
full workstation installer merely to test agent configuration. Run:

    python3 -m unittest discover -s tests -v
    bash -n install.sh
    bash -n scripts/install-claude.sh

Do not commit or push unless the user asks.
