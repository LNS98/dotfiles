#!/usr/bin/env python3
"""Git clean filter: exclude Claude's machine-local security context."""
import json
import sys

settings = json.load(sys.stdin)
settings.pop("autoMode", None)
json.dump(settings, sys.stdout, indent=2, ensure_ascii=False)
sys.stdout.write("\n")
