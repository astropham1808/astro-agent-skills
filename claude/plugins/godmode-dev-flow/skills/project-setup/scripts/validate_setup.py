#!/usr/bin/env python3
"""Validate the completeness of project setup artifacts."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


REQUIRED = (
    "docs/PROJECT_PROFILE.md",
    "docs/PRODUCT_PLAN.md",
    "docs/BACKLOG.md",
    "docs/ENGINEERING_GUIDE.md",
    "specs/_TEMPLATE.md",
    "notes/_TEMPLATE.md",
)

# Codex reads AGENTS.md, Claude Code reads CLAUDE.md. Either one satisfies the
# requirement; a project serving both agents usually has one plus a symlink.
INSTRUCTIONS_FILES = ("AGENTS.md", "CLAUDE.md")

CONTENT_FILES = (
    "docs/PROJECT_PROFILE.md",
    "docs/PRODUCT_PLAN.md",
    "docs/BACKLOG.md",
    "docs/ENGINEERING_GUIDE.md",
    "docs/DESIGN_SPEC.md",
) + INSTRUCTIONS_FILES

PLACEHOLDER = re.compile(r"\{\{[A-Z][A-Z0-9_]*\}\}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check required setup files and unresolved template placeholders."
    )
    parser.add_argument("--target", required=True, type=Path)
    parser.add_argument(
        "--allow-placeholders",
        action="store_true",
        help="Report placeholders without failing.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    target = args.target.resolve()
    if not target.exists() or not target.is_dir():
        print(f"ERROR target is not an existing directory: {target}", file=sys.stderr)
        return 2

    failures = 0
    for relative in REQUIRED:
        path = target / relative
        if not path.is_file():
            print(f"MISSING {relative}")
            failures += 1

    if not any((target / relative).is_file() for relative in INSTRUCTIONS_FILES):
        print(f"MISSING {' or '.join(INSTRUCTIONS_FILES)}")
        failures += 1

    placeholder_count = 0
    seen: set[Path] = set()
    for relative in CONTENT_FILES:
        path = target / relative
        if not path.is_file():
            continue
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        matches = PLACEHOLDER.findall(path.read_text(encoding="utf-8", errors="replace"))
        if matches:
            placeholder_count += len(matches)
            print(f"PLACEHOLDER {relative} {len(matches)}")

    if placeholder_count and not args.allow_placeholders:
        failures += placeholder_count

    if failures:
        print(f"Validation failed with {failures} issue(s).")
        return 1

    print("Validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
