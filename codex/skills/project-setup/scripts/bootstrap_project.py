#!/usr/bin/env python3
"""Safely copy project setup templates into a software repository."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


PRODUCT_TYPES = (
    "web",
    "saas",
    "desktop",
    "mobile",
    "backend-api",
    "developer-tool",
    "cli",
    "sdk-library",
    "data-ai",
    "browser-extension",
    "hybrid",
)

UI_TYPES = {
    "web",
    "saas",
    "desktop",
    "mobile",
    "browser-extension",
    "hybrid",
}

COMMON_FILES = {
    "project-profile-template.md": "docs/PROJECT_PROFILE.md",
    "product-plan-template.md": "docs/PRODUCT_PLAN.md",
    "backlog-template.md": "docs/BACKLOG.md",
    "engineering-guide-template.md": "docs/ENGINEERING_GUIDE.md",
    "story-spec-template.md": "specs/_TEMPLATE.md",
    "story-notes-template.md": "notes/_TEMPLATE.md",
}

# Codex reads AGENTS.md, Claude Code reads CLAUDE.md. "both" writes one real file
# and links the other at it so a single set of rules serves both agents.
INSTRUCTIONS_FILES = {
    "agents": "AGENTS.md",
    "claude": "CLAUDE.md",
    "both": "CLAUDE.md",
}
INSTRUCTIONS_LINK = {"both": ("AGENTS.md", "CLAUDE.md")}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Preview or create missing project setup files without overwriting."
    )
    parser.add_argument("--target", required=True, type=Path)
    parser.add_argument("--project-name", required=True)
    parser.add_argument("--mode", required=True, choices=("greenfield", "existing"))
    parser.add_argument("--product-type", required=True, choices=PRODUCT_TYPES)
    parser.add_argument(
        "--design-spec",
        choices=("auto", "yes", "no"),
        default="auto",
        help="Create a Design Spec automatically for UI product types.",
    )
    parser.add_argument(
        "--instructions",
        choices=("agents", "claude", "both"),
        default="agents",
        help=(
            "Repository instruction file to create: AGENTS.md (Codex), CLAUDE.md "
            "(Claude Code), or CLAUDE.md plus an AGENTS.md symlink pointing at it."
        ),
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def should_include_design_spec(product_type: str, setting: str) -> bool:
    if setting == "yes":
        return True
    if setting == "no":
        return False
    return product_type in UI_TYPES


def render(source: Path, project_name: str, mode: str, product_type: str) -> str:
    content = source.read_text(encoding="utf-8")
    replacements = {
        "{{PROJECT_NAME}}": project_name,
        "{{MODE}}": mode,
        "{{PRODUCT_TYPE}}": product_type,
    }
    for old, new in replacements.items():
        content = content.replace(old, new)
    return content


def main() -> int:
    args = parse_args()
    target = args.target.resolve()
    if not target.exists() or not target.is_dir():
        print(f"ERROR target is not an existing directory: {target}", file=sys.stderr)
        return 2

    skill_dir = Path(__file__).resolve().parent.parent
    assets_dir = skill_dir / "assets"
    files = dict(COMMON_FILES)
    files["agents-template.md"] = INSTRUCTIONS_FILES[args.instructions]
    if should_include_design_spec(args.product_type, args.design_spec):
        files["design-spec-template.md"] = "docs/DESIGN_SPEC.md"

    conflicts: list[Path] = []
    planned: list[tuple[Path, Path]] = []
    for source_name, relative_target in files.items():
        source = assets_dir / source_name
        destination = target / relative_target
        if destination.exists():
            conflicts.append(destination)
        else:
            planned.append((source, destination))

    link: tuple[Path, str] | None = None
    if args.instructions in INSTRUCTIONS_LINK:
        link_name, link_target = INSTRUCTIONS_LINK[args.instructions]
        link_path = target / link_name
        if link_path.exists() or link_path.is_symlink():
            conflicts.append(link_path)
        else:
            link = (link_path, link_target)

    action = "WOULD_CREATE" if args.dry_run else "CREATE"
    for _, destination in planned:
        print(f"{action} {destination}")
    if link is not None:
        print(f"{action}_SYMLINK {link[0]} -> {link[1]}")
    for destination in conflicts:
        print(f"SKIP_EXISTS {destination}")

    if args.dry_run:
        return 0

    for source, destination in planned:
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(
            render(source, args.project_name, args.mode, args.product_type),
            encoding="utf-8",
        )

    created = len(planned)
    if link is not None:
        link[0].symlink_to(link[1])
        created += 1

    print(f"Created {created} file(s); preserved {len(conflicts)} existing file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
