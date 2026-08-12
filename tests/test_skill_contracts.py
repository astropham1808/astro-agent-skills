from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[1]
GODMODE = ROOT / "claude" / "plugins" / "godmode-dev-flow"
CLAUDE_SKILL = GODMODE / "skills" / "start-story-multi-agent"
CODEX_FLOW = ROOT / "codex" / "skills" / "codex-multi-agents-flow"
AGENT_TOAST = ROOT / "claude" / "plugins" / "agent-toast"
# The shell under test. macOS ships Bash 3.2, so CI runs the suite against it
# explicitly to keep the scripts free of Bash 4 syntax.
BASH = os.environ.get("ASTRO_BASH", "bash")
# Skills that ship on both platforms sharing a single payload, as
# (codex skill directory, Claude skill directory under godmode-dev-flow).
PORTED_SKILLS = (
    ("project-setup", "project-setup"),
    ("close-story-worktree", "close-story"),
    ("disciplined-coding", "disciplined-coding"),
)


def run(
    args: list[str],
    *,
    cwd: Path,
    env: dict[str, str] | None = None,
    input_text: str | None = None,
    check: bool = False,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        args,
        cwd=cwd,
        env=env,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and result.returncode != 0:
        raise AssertionError(
            f"command failed ({result.returncode}): {args}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result


def write_executable(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def normalized_copy(source: Path, target: Path) -> Path:
    write_executable(target, source.read_text(encoding="utf-8").replace("\r\n", "\n"))
    return target


class StaticContractTests(unittest.TestCase):
    def test_json_manifests_parse(self) -> None:
        paths = [ROOT / ".claude-plugin" / "marketplace.json"]
        paths.extend(ROOT.glob("claude/plugins/*/.claude-plugin/plugin.json"))
        paths.extend(ROOT.glob("claude/plugins/*/hooks/hooks.json"))
        paths.append(CLAUDE_SKILL / "assets" / "settings.hooks.json")
        for path in paths:
            with self.subTest(path=path):
                json.loads(path.read_text(encoding="utf-8"))

    def test_plugin_release_metadata_has_one_version_source(self) -> None:
        marketplace = json.loads(
            (ROOT / ".claude-plugin" / "marketplace.json").read_text(encoding="utf-8")
        )
        entries = {entry["name"]: entry for entry in marketplace["plugins"]}
        self.assertNotIn("version", entries["agent-toast"])
        self.assertNotIn("version", entries["godmode-dev-flow"])

        toast = json.loads(
            (AGENT_TOAST / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8")
        )
        flow = json.loads(
            (GODMODE / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8")
        )
        self.assertEqual(toast["version"], "0.4.1")
        self.assertEqual(flow["version"], "1.0.0")
        self.assertNotIn("category", toast)
        self.assertNotIn("category", flow)
        self.assertEqual(entries["agent-toast"]["category"], "integration")
        self.assertEqual(entries["godmode-dev-flow"]["category"], "workflow")

        # Same rule for every plugin: version in plugin.json, category in the catalog.
        for name, entry in entries.items():
            with self.subTest(plugin=name):
                self.assertNotIn("version", entry)
                self.assertIn("category", entry)
                self.assertEqual(entry["source"], f"./claude/plugins/{name}")
                manifest = json.loads(
                    (
                        ROOT / "claude" / "plugins" / name / ".claude-plugin" / "plugin.json"
                    ).read_text(encoding="utf-8")
                )
                self.assertEqual(manifest["name"], name)
                self.assertIn("version", manifest)
                self.assertNotIn("category", manifest)

    def test_claude_skill_uses_installed_paths_and_hook_stdin(self) -> None:
        skill = (CLAUDE_SKILL / "SKILL.md").read_text(encoding="utf-8")
        settings = (CLAUDE_SKILL / "assets" / "settings.hooks.json").read_text(
            encoding="utf-8"
        )
        hook = (CLAUDE_SKILL / "assets" / "format-hook.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("${CLAUDE_SKILL_DIR}/scripts/new-story.sh", skill)
        self.assertIn("${CLAUDE_SKILL_DIR}/assets/format-hook.sh", skill)
        self.assertIn("${CLAUDE_PROJECT_DIR}/.claude/hooks/format-file.sh", settings)
        self.assertNotIn("CLAUDE_FILE_PATH", settings)
        self.assertIn(".tool_input.file_path", hook)

    def test_removed_hardcoded_runtime_assumptions(self) -> None:
        claude_story = (CLAUDE_SKILL / "scripts" / "story.sh").read_text(
            encoding="utf-8"
        )
        claude_new = (CLAUDE_SKILL / "scripts" / "new-story.sh").read_text(
            encoding="utf-8"
        )
        codex_story = (CODEX_FLOW / "scripts" / "story.sh").read_text(
            encoding="utf-8"
        )
        for forbidden in ("SOT_COLLECTION", "Run ONE SQL", "git checkout main"):
            self.assertNotIn(forbidden, claude_story + claude_new)
        self.assertNotIn("\n  gh pr create ", claude_story)
        self.assertNotIn("codex review --base", codex_story)
        self.assertNotIn("${BASE_BRANCH:-main}", codex_story)
        self.assertIn("-s read-only", codex_story)

    def test_every_skill_has_minimal_frontmatter(self) -> None:
        skills = list(ROOT.glob("codex/skills/*/SKILL.md"))
        skills.extend(ROOT.glob("claude/plugins/*/skills/*/SKILL.md"))
        self.assertEqual(len(skills), 8)
        for path in skills:
            with self.subTest(path=path):
                text = path.read_text(encoding="utf-8")
                self.assertTrue(text.startswith("---\n"))
                frontmatter = text.split("---", 2)[1]
                self.assertIn("\nname:", "\n" + frontmatter)
                self.assertIn("\ndescription:", "\n" + frontmatter)

    def test_skill_name_matches_its_directory(self) -> None:
        skills = list(ROOT.glob("codex/skills/*/SKILL.md"))
        skills.extend(ROOT.glob("claude/plugins/*/skills/*/SKILL.md"))
        for path in skills:
            with self.subTest(path=path):
                frontmatter = path.read_text(encoding="utf-8").split("---", 2)[1]
                declared = re.search(r"^name:\s*(\S+)", frontmatter, re.M)
                self.assertIsNotNone(declared)
                self.assertEqual(declared.group(1), path.parent.name)

    def test_ported_skills_share_one_payload(self) -> None:
        """A skill shipped on both platforms duplicates prose, never behavior."""
        for name, claude_name in PORTED_SKILLS:
            codex_skill = ROOT / "codex" / "skills" / name
            claude_skill = GODMODE / "skills" / claude_name
            for payload in ("scripts", "assets", "references"):
                source = codex_skill / payload
                if not source.is_dir():
                    continue
                mirror = claude_skill / payload
                with self.subTest(skill=name, payload=payload):
                    self.assertTrue(mirror.is_dir(), f"missing {mirror}")
                    expected = sorted(p.name for p in source.iterdir())
                    self.assertEqual(expected, sorted(p.name for p in mirror.iterdir()))
                    for original in source.iterdir():
                        copy = mirror / original.name
                        self.assertEqual(
                            original.read_bytes(),
                            copy.read_bytes(),
                            f"{copy} drifted from {original}",
                        )
                        self.assertEqual(
                            original.stat().st_mode & 0o111,
                            copy.stat().st_mode & 0o111,
                            f"{copy} executable bit differs from {original}",
                        )

    def test_delivery_flows_share_one_verifier(self) -> None:
        """Verification is stack-neutral, so both flows ship the same resolver."""
        claude_verify = CLAUDE_SKILL / "scripts" / "verify.sh"
        codex_verify = CODEX_FLOW / "scripts" / "verify.sh"
        self.assertEqual(
            codex_verify.read_bytes(),
            claude_verify.read_bytes(),
            f"{claude_verify} drifted from {codex_verify}",
        )
        self.assertEqual(
            codex_verify.stat().st_mode & 0o111,
            claude_verify.stat().st_mode & 0o111,
        )
        text = codex_verify.read_text(encoding="utf-8")
        for contract in ("PROJECT_VERIFIER", "scripts/verify-project.sh", "init-verifier.sh"):
            self.assertIn(contract, text)

    def test_project_setup_ships_a_verifier_scaffold(self) -> None:
        for skill in (
            ROOT / "codex" / "skills" / "project-setup",
            GODMODE / "skills" / "project-setup",
        ):
            scaffold = skill / "scripts" / "init-verifier.sh"
            with self.subTest(skill=skill.name):
                self.assertTrue(scaffold.is_file(), f"missing {scaffold}")
                self.assertTrue(scaffold.stat().st_mode & 0o111, f"{scaffold} is not executable")
                self.assertIn(
                    "init-verifier.sh",
                    (skill / "SKILL.md").read_text(encoding="utf-8"),
                )

    @unittest.skipIf(shutil.which("git") is None, "git is unavailable")
    def test_skill_scripts_are_executable_in_git(self) -> None:
        """Skill scripts are invoked directly, so the mode must survive a clone.

        A checkout on a filesystem without permission bits, such as a Windows
        drive under WSL, silently stages them as 100644.
        """
        listing = run(["git", "ls-files", "-s"], cwd=ROOT)
        if listing.returncode != 0:
            self.skipTest("not a Git checkout")
        for line in listing.stdout.splitlines():
            mode, _, remainder = line.partition(" ")
            path = remainder.split("\t", 1)[-1]
            if "/scripts/" not in path or not path.endswith(".sh"):
                continue
            with self.subTest(path=path):
                self.assertEqual(mode, "100755", f"{path} is not executable in the index")

    def test_taxonomy_represents_every_artifact(self) -> None:
        taxonomy = (ROOT / "docs" / "SKILL_TAXONOMY.md").read_text(encoding="utf-8")
        expected = {
            "disciplined-coding",
            "project-setup",
            "codex-multi-agents-flow",
            "close-story-worktree",
            "start-story-multi-agent",
            "close-story",
            "godmode-dev-flow",
            "agent-toast",
        }
        for name in expected:
            with self.subTest(name=name):
                self.assertIn(f"[{name}]", taxonomy)
        for _, claude_name in PORTED_SKILLS:
            with self.subTest(name=claude_name, platform="claude"):
                self.assertIn(
                    f"](../claude/plugins/godmode-dev-flow/skills/{claude_name}/)",
                    taxonomy,
                )

    def test_local_markdown_links_resolve(self) -> None:
        pattern = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
        for markdown in ROOT.rglob("*.md"):
            text = markdown.read_text(encoding="utf-8")
            for raw_target in pattern.findall(text):
                target = raw_target.split("#", 1)[0]
                if not target or target.startswith(("http://", "https://")):
                    continue
                resolved = (markdown.parent / target).resolve()
                with self.subTest(markdown=markdown, target=target):
                    self.assertTrue(resolved.exists(), f"missing local link: {resolved}")

    @unittest.skipIf(shutil.which(BASH) is None, f"{BASH} is unavailable")
    def test_shell_syntax(self) -> None:
        scripts = list(ROOT.rglob("*.sh"))
        scripts.extend(ROOT.rglob("pre-commit"))
        for path in scripts:
            with self.subTest(path=path):
                result = run([BASH, "-n", str(path)], cwd=ROOT)
                self.assertEqual(result.returncode, 0, result.stderr)


@unittest.skipIf(os.name == "nt", "run shell behavior tests under WSL or POSIX")
class ShellBehaviorTests(unittest.TestCase):
    def init_repo(self, verifier_exit: int = 0, with_verifier: bool = True) -> Path:
        temp = tempfile.TemporaryDirectory(prefix="astro-skill-test-")
        self.addCleanup(temp.cleanup)
        repo = Path(temp.name)
        run(["git", "init", "-b", "trunk"], cwd=repo, check=True)
        run(["git", "config", "user.name", "Skill Test"], cwd=repo, check=True)
        run(
            ["git", "config", "user.email", "skill-test@example.invalid"],
            cwd=repo,
            check=True,
        )
        (repo / "README.md").write_text("# Fixture\n", encoding="utf-8")
        if with_verifier:
            write_executable(
                repo / "scripts" / "verify-project.sh",
                "#!/usr/bin/env bash\n"
                f"echo fixture-verifier\nexit {verifier_exit}\n",
            )
        run(["git", "add", "."], cwd=repo, check=True)
        run(["git", "commit", "-m", "fixture"], cwd=repo, check=True)
        return repo

    def create_story(
        self, repo: Path, flow: Path, story_id: str = "AL-101"
    ) -> Path:
        env = os.environ.copy()
        env["FETCH_BASE"] = "0"
        result = run(
            [BASH, str(flow / "scripts" / "new-story.sh"), story_id, "trunk"],
            cwd=repo,
            env=env,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        if flow == CLAUDE_SKILL:
            worktree = repo / ".claude" / "worktrees" / story_id
        else:
            worktree = repo / ".agent-worktrees" / story_id
        (worktree / "specs" / f"{story_id}.md").write_text(
            f"# {story_id}\n\n## Done-when\n\n"
            "- [ ] scripts/verify-project.sh exits 0\n",
            encoding="utf-8",
        )
        run(["git", "add", "specs"], cwd=worktree, check=True)
        run(["git", "commit", "-m", f"spec {story_id}"], cwd=worktree, check=True)
        return worktree

    def mock_commands(self) -> tuple[Path, dict[str, str]]:
        temp = tempfile.TemporaryDirectory(prefix="astro-skill-mocks-")
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        bin_dir = root / "bin"
        bin_dir.mkdir()
        env = os.environ.copy()
        env["PATH"] = str(bin_dir) + os.pathsep + env["PATH"]
        env["ASTRO_CLAUDE_LOG"] = str(root / "claude.log")
        env["ASTRO_CODEX_LOG"] = str(root / "codex.log")
        env["ASTRO_GH_LOG"] = str(root / "gh.log")
        env["ASTRO_CLAUDE_EXIT"] = "0"
        env["ASTRO_BUILDER_COMMITS"] = "1"
        env["ASTRO_REVIEW_VERDICT"] = "VERDICT: PASS"

        write_executable(
            bin_dir / "claude",
            "#!/usr/bin/env bash\n"
            "printf '%s\\n' \"$*\" >> \"$ASTRO_CLAUDE_LOG\"\n"
            "if [ \"$ASTRO_CLAUDE_EXIT\" -ne 0 ]; then\n"
            "  exit \"$ASTRO_CLAUDE_EXIT\"\n"
            "fi\n"
            "if [ \"$ASTRO_BUILDER_COMMITS\" = 1 ]; then\n"
            "  printf '%s\\n' implemented >> mock-implementation.txt\n"
            "  git add mock-implementation.txt\n"
            "  git commit -m 'mock claude implementation' >/dev/null\n"
            "fi\n"
            "printf '%s\\n' '{\"type\":\"result\",\"total_cost_usd\":0,\"num_turns\":1}'\n"
            "exit 0\n",
        )
        write_executable(
            bin_dir / "codex",
            "#!/usr/bin/env bash\n"
            "printf '%s\\n' \"$*\" >> \"$ASTRO_CODEX_LOG\"\n"
            "output=''\nreview=0\nworktree=''\n"
            "while [ \"$#\" -gt 0 ]; do\n"
            "  case \"$1\" in\n"
            "    -C) worktree=$2; shift 2 ;;\n"
            "    -o) output=$2; shift 2 ;;\n"
            "    -s) [ \"$2\" = read-only ] && review=1; shift 2 ;;\n"
            "    *) shift ;;\n"
            "  esac\n"
            "done\n"
            "if [ \"$review\" -eq 0 ] && [ \"$ASTRO_BUILDER_COMMITS\" = 1 ]; then\n"
            "  printf '%s\\n' implemented >> \"$worktree/mock-implementation.txt\"\n"
            "  git -C \"$worktree\" add mock-implementation.txt\n"
            "  git -C \"$worktree\" commit -m 'mock codex implementation' >/dev/null\n"
            "fi\n"
            "if [ -n \"$output\" ]; then\n"
            "  mkdir -p \"$(dirname \"$output\")\"\n"
            "  if [ \"$review\" -eq 1 ]; then\n"
            "    printf '%s\\n' \"$ASTRO_REVIEW_VERDICT\" > \"$output\"\n"
            "  else\n"
            "    printf '%s\\n' 'BUILD COMPLETE' > \"$output\"\n"
            "  fi\n"
            "fi\n"
            "printf '%s\\n' '{\"type\":\"mock\"}'\n",
        )
        write_executable(bin_dir / "jq", "#!/usr/bin/env bash\ncat\n")
        write_executable(
            bin_dir / "gh",
            "#!/usr/bin/env bash\n"
            "printf '%s\\n' \"$*\" >> \"$ASTRO_GH_LOG\"\n"
            "exit 99\n",
        )
        return root, env

    def test_format_hook_forwards_post_tool_path(self) -> None:
        repo = self.init_repo()
        log = repo / "format.log"
        write_executable(
            repo / "scripts" / "format-file.sh",
            "#!/usr/bin/env bash\nprintf '%s' \"$1\" > \"$ASTRO_FORMAT_LOG\"\n",
        )
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = str(repo)
        env["ASTRO_FORMAT_LOG"] = str(log)
        touched = repo / "src" / "file with spaces.py"
        payload = json.dumps({"tool_input": {"file_path": str(touched)}})
        result = run(
            [BASH, str(CLAUDE_SKILL / "assets" / "format-hook.sh")],
            cwd=repo,
            env=env,
            input_text=payload,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.read_text(encoding="utf-8"), str(touched))

    def test_claude_worktree_does_not_switch_primary_branch(self) -> None:
        repo = self.init_repo()
        worktree = self.create_story(repo, CLAUDE_SKILL)
        branch = run(["git", "branch", "--show-current"], cwd=repo, check=True)
        self.assertEqual(branch.stdout.strip(), "trunk")
        story_branch = run(
            ["git", "branch", "--show-current"], cwd=worktree, check=True
        )
        self.assertEqual(story_branch.stdout.strip(), "worktree-AL-101")
        status = run(["git", "status", "--porcelain"], cwd=repo, check=True)
        self.assertEqual(status.stdout, "")

    def test_flows_resolve_current_branch_when_base_is_omitted(self) -> None:
        for flow in (CLAUDE_SKILL, CODEX_FLOW):
            with self.subTest(flow=flow.name):
                repo = self.init_repo()
                env = os.environ.copy()
                env["FETCH_BASE"] = "0"
                result = run(
                    [BASH, str(flow / "scripts" / "new-story.sh"), "AL-102"],
                    cwd=repo,
                    env=env,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("base: trunk", result.stdout)

    def test_claude_story_stops_before_pr(self) -> None:
        repo = self.init_repo()
        self.create_story(repo, CLAUDE_SKILL)
        mock_root, env = self.mock_commands()
        env["BASE_BRANCH"] = "trunk"
        result = run(
            [BASH, str(CLAUDE_SKILL / "scripts" / "story.sh"), "AL-101", "trunk"],
            cwd=repo,
            env=env,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ready for human PR gate", result.stdout)
        self.assertFalse((mock_root / "gh.log").exists())
        codex_log = (mock_root / "codex.log").read_text(encoding="utf-8")
        self.assertIn("-s read-only", codex_log)

    def test_claude_build_failure_stops_review(self) -> None:
        repo = self.init_repo()
        self.create_story(repo, CLAUDE_SKILL)
        mock_root, env = self.mock_commands()
        env["ASTRO_CLAUDE_EXIT"] = "7"
        result = run(
            [BASH, str(CLAUDE_SKILL / "scripts" / "story.sh"), "AL-101", "trunk"],
            cwd=repo,
            env=env,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((mock_root / "codex.log").exists())
        self.assertFalse((mock_root / "gh.log").exists())

    def test_builder_must_create_new_commit_in_both_flows(self) -> None:
        for flow in (CLAUDE_SKILL, CODEX_FLOW):
            with self.subTest(flow=flow.name):
                repo = self.init_repo()
                self.create_story(repo, flow)
                mock_root, env = self.mock_commands()
                env["ASTRO_BUILDER_COMMITS"] = "0"
                result = run(
                    [BASH, str(flow / "scripts" / "story.sh"), "AL-101", "trunk"],
                    cwd=repo,
                    env=env,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("produced no new commit", result.stderr)
                self.assertFalse((mock_root / "gh.log").exists())
                if flow == CLAUDE_SKILL:
                    self.assertFalse((mock_root / "codex.log").exists())
                else:
                    codex_log = (mock_root / "codex.log").read_text(encoding="utf-8")
                    self.assertNotIn("-s read-only", codex_log)

    def test_codex_story_uses_read_only_exec_reviewer(self) -> None:
        repo = self.init_repo()
        self.create_story(repo, CODEX_FLOW)
        mock_root, env = self.mock_commands()
        env["BASE_BRANCH"] = "trunk"
        result = run(
            [BASH, str(CODEX_FLOW / "scripts" / "story.sh"), "AL-101", "trunk"],
            cwd=repo,
            env=env,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        log = (mock_root / "codex.log").read_text(encoding="utf-8")
        self.assertIn("-s read-only", log)
        self.assertNotIn("review --base", log)
        self.assertIn("ready for human PR gate", result.stdout)

    def test_codex_verifier_failure_stops_before_review(self) -> None:
        repo = self.init_repo(verifier_exit=9)
        self.create_story(repo, CODEX_FLOW)
        mock_root, env = self.mock_commands()
        result = run(
            [BASH, str(CODEX_FLOW / "scripts" / "story.sh"), "AL-101", "trunk"],
            cwd=repo,
            env=env,
        )
        self.assertNotEqual(result.returncode, 0)
        log = (mock_root / "codex.log").read_text(encoding="utf-8")
        self.assertNotIn("-s read-only", log)

    def test_malformed_review_verdict_stops_both_flows(self) -> None:
        for flow in (CLAUDE_SKILL, CODEX_FLOW):
            with self.subTest(flow=flow.name):
                repo = self.init_repo()
                self.create_story(repo, flow)
                mock_root, env = self.mock_commands()
                env["ASTRO_REVIEW_VERDICT"] = "review looks fine"
                result = run(
                    [BASH, str(flow / "scripts" / "story.sh"), "AL-101", "trunk"],
                    cwd=repo,
                    env=env,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("invalid reviewer verdict", result.stderr)
                self.assertFalse((mock_root / "gh.log").exists())
                if flow == CLAUDE_SKILL:
                    claude_log = (mock_root / "claude.log").read_text(
                        encoding="utf-8"
                    )
                    self.assertEqual(len(claude_log.splitlines()), 1)
                else:
                    codex_log = (mock_root / "codex.log").read_text(encoding="utf-8")
                    self.assertEqual(codex_log.count("-s read-only"), 1)

    def verify_scripts(self) -> tuple[Path, ...]:
        return (CLAUDE_SKILL / "scripts" / "verify.sh", CODEX_FLOW / "scripts" / "verify.sh")

    def test_verify_prefers_the_project_verifier_override(self) -> None:
        for verify in self.verify_scripts():
            with self.subTest(flow=verify.parent.parent.name):
                repo = self.init_repo()
                write_executable(
                    repo / "ci" / "check.sh",
                    "#!/usr/bin/env bash\necho override-verifier\n",
                )
                env = os.environ.copy()
                env["PROJECT_VERIFIER"] = "ci/check.sh"
                result = run([BASH, str(verify), str(repo)], cwd=repo, env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("override-verifier", result.stdout)
                self.assertNotIn("fixture-verifier", result.stdout)

    def test_verify_rejects_a_non_executable_project_verifier(self) -> None:
        """A checkout that lost the executable bit must say so, not silently skip."""
        for verify in self.verify_scripts():
            with self.subTest(flow=verify.parent.parent.name):
                repo = self.init_repo()
                target = repo / "scripts" / "verify-project.sh"
                target.chmod(target.stat().st_mode & ~0o111)
                result = run([BASH, str(verify), str(repo)], cwd=repo)
                self.assertEqual(result.returncode, 2)
                self.assertIn("not executable", result.stderr)

    def test_verify_falls_back_to_a_detected_stack(self) -> None:
        for verify in self.verify_scripts():
            with self.subTest(flow=verify.parent.parent.name):
                repo = self.init_repo(with_verifier=False)
                (repo / "Cargo.toml").write_text("[package]\n", encoding="utf-8")
                log = repo / "cargo.log"
                write_executable(
                    repo / "bin" / "cargo",
                    "#!/usr/bin/env bash\nprintf '%s\\n' \"$*\" >> \"$ASTRO_CARGO_LOG\"\n",
                )
                env = os.environ.copy()
                env["PATH"] = str(repo / "bin") + os.pathsep + env["PATH"]
                env["ASTRO_CARGO_LOG"] = str(log)
                result = run([BASH, str(verify), str(repo)], cwd=repo, env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("VERIFY PASSED", result.stdout)
                invoked = log.read_text(encoding="utf-8")
                self.assertIn("fmt", invoked)
                self.assertIn("test", invoked)

    def test_verify_prefers_a_build_wrapper_over_a_global_tool(self) -> None:
        """A JVM project pins its build through ./gradlew or ./mvnw."""
        for verify in self.verify_scripts():
            with self.subTest(flow=verify.parent.parent.name):
                repo = self.init_repo(with_verifier=False)
                (repo / "build.gradle").write_text("apply plugin: 'java'\n", encoding="utf-8")
                log = repo / "build.log"
                write_executable(
                    repo / "gradlew",
                    "#!/usr/bin/env bash\nprintf 'wrapper %s\\n' \"$*\" >> \"$ASTRO_BUILD_LOG\"\n",
                )
                write_executable(
                    repo / "bin" / "gradle",
                    "#!/usr/bin/env bash\nprintf 'global %s\\n' \"$*\" >> \"$ASTRO_BUILD_LOG\"\n",
                )
                env = os.environ.copy()
                env["PATH"] = str(repo / "bin") + os.pathsep + env["PATH"]
                env["ASTRO_BUILD_LOG"] = str(log)
                result = run([BASH, str(verify), str(repo)], cwd=repo, env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                invoked = log.read_text(encoding="utf-8")
                self.assertIn("wrapper", invoked)
                self.assertNotIn("global", invoked)

    def test_verify_runs_a_maven_project(self) -> None:
        for verify in self.verify_scripts():
            with self.subTest(flow=verify.parent.parent.name):
                repo = self.init_repo(with_verifier=False)
                (repo / "pom.xml").write_text("<project/>\n", encoding="utf-8")
                log = repo / "maven.log"
                write_executable(
                    repo / "bin" / "mvn",
                    "#!/usr/bin/env bash\nprintf '%s\\n' \"$*\" >> \"$ASTRO_BUILD_LOG\"\n",
                )
                env = os.environ.copy()
                env["PATH"] = str(repo / "bin") + os.pathsep + env["PATH"]
                env["ASTRO_BUILD_LOG"] = str(log)
                result = run([BASH, str(verify), str(repo)], cwd=repo, env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("VERIFY PASSED", result.stdout)
                self.assertIn("verify", log.read_text(encoding="utf-8"))

    def test_init_verifier_scaffolds_a_jvm_wrapper(self) -> None:
        scaffold = ROOT / "codex" / "skills" / "project-setup" / "scripts" / "init-verifier.sh"
        repo = self.init_repo(with_verifier=False)
        (repo / "build.gradle.kts").write_text("plugins { java }\n", encoding="utf-8")
        write_executable(repo / "gradlew", "#!/usr/bin/env bash\nexit 0\n")
        result = run([BASH, str(scaffold)], cwd=repo)
        self.assertEqual(result.returncode, 0, result.stderr)
        generated = (repo / "scripts" / "verify-project.sh").read_text(encoding="utf-8")
        self.assertIn("./gradlew --no-daemon build", generated)

    def test_verify_reports_when_no_checks_are_discoverable(self) -> None:
        for verify in self.verify_scripts():
            with self.subTest(flow=verify.parent.parent.name):
                repo = self.init_repo(with_verifier=False)
                result = run([BASH, str(verify), str(repo)], cwd=repo)
                self.assertEqual(result.returncode, 2)
                self.assertIn("init-verifier.sh", result.stderr)

    def test_init_verifier_scaffolds_without_clobbering(self) -> None:
        scaffold = ROOT / "codex" / "skills" / "project-setup" / "scripts" / "init-verifier.sh"
        repo = self.init_repo(with_verifier=False)
        (repo / "package.json").write_text(
            '{"name":"fixture","scripts":{"lint":"true","test":"true"}}',
            encoding="utf-8",
        )
        (repo / "pnpm-lock.yaml").write_text("lockfileVersion: 9\n", encoding="utf-8")

        created = run([BASH, str(scaffold)], cwd=repo)
        self.assertEqual(created.returncode, 0, created.stderr)
        target = repo / "scripts" / "verify-project.sh"
        self.assertTrue(target.is_file())
        self.assertTrue(target.stat().st_mode & 0o111, "scaffolded verifier is not executable")
        generated = target.read_text(encoding="utf-8")
        self.assertIn("pnpm run lint", generated)
        self.assertIn("pnpm run test", generated)
        self.assertIn("# pnpm run typecheck", generated)
        syntax = run([BASH, "-n", str(target)], cwd=repo)
        self.assertEqual(syntax.returncode, 0, syntax.stderr)

        target.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
        kept = run([BASH, str(scaffold)], cwd=repo)
        self.assertEqual(kept.returncode, 0, kept.stderr)
        self.assertEqual(target.read_text(encoding="utf-8"), "#!/usr/bin/env bash\nexit 0\n")

        preview = run([BASH, str(scaffold), "--print"], cwd=repo)
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertIn("pnpm run lint", preview.stdout)
        self.assertEqual(target.read_text(encoding="utf-8"), "#!/usr/bin/env bash\nexit 0\n")

        forced = run([BASH, str(scaffold), "--force"], cwd=repo)
        self.assertEqual(forced.returncode, 0, forced.stderr)
        self.assertIn("pnpm run lint", target.read_text(encoding="utf-8"))

    def test_init_verifier_accepts_an_explicit_root(self) -> None:
        """Paths stay dynamic, so scaffolding works from any working directory."""
        scaffold = ROOT / "codex" / "skills" / "project-setup" / "scripts" / "init-verifier.sh"
        repo = self.init_repo(with_verifier=False)
        (repo / "go.mod").write_text("module fixture\n", encoding="utf-8")
        result = run([BASH, str(scaffold), "--root", str(repo)], cwd=ROOT)
        self.assertEqual(result.returncode, 0, result.stderr)
        generated = (repo / "scripts" / "verify-project.sh").read_text(encoding="utf-8")
        self.assertIn("go test ./...", generated)

    def test_agent_toast_notifies_through_mocked_os_command(self) -> None:
        temp = tempfile.TemporaryDirectory(prefix="agent-toast-test-")
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        bin_dir = root / "bin"
        bin_dir.mkdir()
        start = normalized_copy(
            AGENT_TOAST / "hooks" / "session-start.sh", root / "session-start.sh"
        )
        stop = normalized_copy(
            AGENT_TOAST / "hooks" / "notify-stop.sh", root / "notify-stop.sh"
        )
        log = root / "notify.log"
        write_executable(bin_dir / "uname", "#!/usr/bin/env bash\necho Linux\n")
        write_executable(bin_dir / "grep", "#!/usr/bin/env bash\nexit 1\n")
        write_executable(
            bin_dir / "notify-send",
            "#!/usr/bin/env bash\nprintf '%s\\n' \"$*\" >> \"$ASTRO_NOTIFY_LOG\"\n",
        )
        env = os.environ.copy()
        env.pop("WSL_DISTRO_NAME", None)
        env["PATH"] = str(bin_dir) + os.pathsep + env["PATH"]
        env["ASTRO_NOTIFY_LOG"] = str(log)
        env["CLAUDE_PLUGIN_ROOT"] = str(AGENT_TOAST)
        env["CLAUDE_CODE_SESSION_ID"] = "test-" + uuid.uuid4().hex
        env["CLAUDE_PLUGIN_OPTION_AGENT_NAME"] = "Astro Agent"
        env["CLAUDE_PLUGIN_OPTION_SESSION_LABEL"] = "fixture"
        env["CLAUDE_PLUGIN_OPTION_ICON_PATH"] = ""
        env["CLAUDE_PLUGIN_OPTION_BEEP_ENABLED"] = "no"
        run([BASH, str(start)], cwd=root, env=env, check=True)
        run([BASH, str(stop)], cwd=root, env=env, check=True)
        notification = log.read_text(encoding="utf-8")
        self.assertIn("fixture", notification)
        self.assertIn(root.name, notification)


if __name__ == "__main__":
    unittest.main(verbosity=2)
