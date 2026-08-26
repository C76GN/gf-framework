#!/usr/bin/env python3
"""Check maintainable documentation shape for hand-authored MkDocs pages."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote


DEFAULT_MAX_LINES = 300
DEFAULT_MAX_CHANGELOG_LINES = 800
DEFAULT_MAX_PARAGRAPH_CHARS = 1800
DEFAULT_MIN_BODY_LINES = 12
DEFAULT_MIN_STRUCTURED_BODY_LINES = 34
DEFAULT_FRAGMENT_REPORT_LIMIT = 200
DEFAULT_ASSET_LIBRARY_DESCRIPTION_CHARS = 1000


LIST_ITEM_PATTERN = re.compile(r"^(\s*[-*+]\s+|\s*\d+\.\s+)")
MARKDOWN_LINK_PATTERN = re.compile(r"!?\[[^\]\n]*\]\(([^)\n]+)\)")
APPROVED_EXTERNAL_LINK_PATTERN = re.compile(r"^(?:https?://|mailto:)", re.IGNORECASE)
WINDOWS_DRIVE_PATH_PATTERN = re.compile(r"^[A-Za-z]:[\\/]")
HEADING_PATTERN = re.compile(r"^(#{1,6})\s+(.+?)\s*#*\s*$")
HEADING_ATTRIBUTE_ID_PATTERN = re.compile(r"\s+\{[^}\n]*#(?P<id>[A-Za-z][\w:.-]*)[^}\n]*\}\s*$")
FENCE_PATTERN = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
MERMAID_START_PATTERN = re.compile(
    r"^(graph\s+(?:TB|TD|BT|RL|LR)\b|flowchart\s+(?:TB|TD|BT|RL|LR)\b|"
    r"sequenceDiagram\b|classDiagram\b|stateDiagram(?:-v2)?\b|erDiagram\b|"
    r"journey\b|gantt\b|pie\b|mindmap\b|timeline\b|gitGraph\b|"
    r"requirementDiagram\b|C4(?:Context|Container|Component|Dynamic)\b|"
    r"block-beta\b|xychart-beta\b|sankey-beta\b)"
)
PUBLIC_MAINTENANCE_LEAK_PATTERNS = (
    "维护约定",
    "源码目录速查",
    "面向维护者",
    "docs/maintainers",
    "AI_MAINTENANCE",
    "GitHub Wiki",
    "旧 Wiki",
    "不要混入这些用户正文页",
)
EXTENSION_API_REFERENCES = {
    "action-queue": ("extensions-action-queue.md",),
    "asset-metadata": ("extensions-asset-metadata.md",),
    "behavior-tree": ("extensions-behavior-tree.md",),
    "camera": ("extensions-camera.md",),
    "capability": ("extensions-capability.md",),
    "combat": ("extensions-combat.md",),
    "dialogue": ("extensions-dialogue.md",),
    "domain": ("extensions-domain.md",),
    "feedback": ("extensions-feedback.md",),
    "flow": ("extensions-flow.md",),
    "interaction": ("extensions-interaction.md",),
    "network-turnbased": ("extensions-network.md", "extensions-turn-based.md"),
    "physics": ("extensions-physics.md",),
    "save-graph": ("extensions-save.md",),
}
ENTRY_TEMPLATE_ROOTS = ("kernel", "standard", "extensions")
SECTION_API_REFERENCES = {
    "kernel/index.md": ("kernel.md",),
    "standard/index.md": ("standard.md",),
}


@dataclass(frozen=True)
class MarkdownFenceBlock:
    marker: str
    opening_length: int
    info: str
    start_line: int
    content: tuple[str, ...]
    end_line: int | None


@dataclass(frozen=True)
class MarkdownStructure:
    visible_lines: tuple[tuple[int, str], ...]
    fences: tuple[MarkdownFenceBlock, ...]
    unclosed_fence_line: int | None


def scan_markdown_structure(text: str) -> MarkdownStructure:
    """Parse reader-visible lines with CommonMark-compatible fence boundaries."""
    visible_lines: list[tuple[int, str]] = []
    fences: list[MarkdownFenceBlock] = []
    in_html_comment = False
    fence_marker = ""
    fence_length = 0
    fence_info = ""
    fence_start = 0
    fence_content: list[str] = []

    for line_number, raw_line in enumerate(text.splitlines(), start=1):
        if fence_marker:
            if is_markdown_fence_close(raw_line, fence_marker, fence_length):
                fences.append(MarkdownFenceBlock(
                    marker=fence_marker,
                    opening_length=fence_length,
                    info=fence_info,
                    start_line=fence_start,
                    content=tuple(fence_content),
                    end_line=line_number,
                ))
                fence_marker = ""
                fence_length = 0
                fence_info = ""
                fence_start = 0
                fence_content = []
            else:
                fence_content.append(raw_line)
            visible_lines.append((line_number, ""))
            continue

        visible_line, in_html_comment = strip_html_comments_from_line(
            raw_line,
            in_html_comment,
        )
        fence_match = FENCE_PATTERN.match(visible_line)
        if fence_match is not None:
            marker_run = fence_match.group(1)
            info = fence_match.group(2).strip()
            if marker_run[0] == "`" and "`" in info:
                visible_lines.append((line_number, visible_line))
                continue
            fence_marker = marker_run[0]
            fence_length = len(marker_run)
            fence_info = info
            fence_start = line_number
            fence_content = []
            visible_lines.append((line_number, ""))
            continue
        visible_lines.append((line_number, visible_line))

    unclosed_fence_line = fence_start or None
    if fence_marker:
        fences.append(MarkdownFenceBlock(
            marker=fence_marker,
            opening_length=fence_length,
            info=fence_info,
            start_line=fence_start,
            content=tuple(fence_content),
            end_line=None,
        ))
    return MarkdownStructure(
        visible_lines=tuple(visible_lines),
        fences=tuple(fences),
        unclosed_fence_line=unclosed_fence_line,
    )


def strip_html_comments_from_line(line: str, in_comment: bool) -> tuple[str, bool]:
    visible = list(line)
    index = 0
    while index < len(line):
        if in_comment:
            end = line.find("-->", index)
            if end == -1:
                for offset in range(index, len(line)):
                    visible[offset] = " "
                return "".join(visible), True
            for offset in range(index, end + 3):
                visible[offset] = " "
            index = end + 3
            in_comment = False
            continue
        start = line.find("<!--", index)
        if start == -1:
            break
        end = line.find("-->", start + 4)
        if end == -1:
            for offset in range(start, len(line)):
                visible[offset] = " "
            return "".join(visible), True
        for offset in range(start, end + 3):
            visible[offset] = " "
        index = end + 3
    return "".join(visible), in_comment


def is_markdown_fence_close(line: str, marker: str, opening_length: int) -> bool:
    return re.fullmatch(
        rf" {{0,3}}{re.escape(marker)}{{{opening_length},}}[ \t]*",
        line,
    ) is not None


def visible_markdown_headings(text: str) -> list[tuple[int, int, str]]:
    headings: list[tuple[int, int, str]] = []
    structure = scan_markdown_structure(text)
    for line_number, line in structure.visible_lines:
        match = HEADING_PATTERN.match(line)
        if match is not None:
            headings.append((line_number, len(match.group(1)), match.group(2)))
    return headings


def has_visible_heading(text: str, level: int, title: str) -> bool:
    return any(
        heading_level == level and heading_title == title
        for _line_number, heading_level, heading_title in visible_markdown_headings(text)
    )


def visible_markdown_text(text: str) -> str:
    return "\n".join(
        line
        for _line_number, line in scan_markdown_structure(text).visible_lines
    )


def gdscript_fence_contents(text: str) -> list[str]:
    """Return normalized GDScript fence bodies in reader order."""
    return [
        "\n".join(block.content).rstrip()
        for block in scan_markdown_structure(text).fences
        if block.info.split(maxsplit=1)[0].lower() == "gdscript"
    ]


def check_readme_quickstart_contracts(
    english_text: str,
    chinese_text: str,
) -> list[str]:
    """Keep both root quickstarts executable, failure-aware, and identical."""
    errors: list[str] = []
    english_blocks = gdscript_fence_contents(english_text)
    chinese_blocks = gdscript_fence_contents(chinese_text)
    if english_blocks != chinese_blocks:
        errors.append("README.md and README.zh.md must use identical GDScript quickstarts")
    if len(english_blocks) != 2:
        errors.append("README.md must contain exactly two GDScript quickstart blocks")
        return errors

    manual_quickstart, installer_quickstart = english_blocks
    manual_requirements = (
        "if not await Gf.register_model(",
        "if not await Gf.register_utility(",
        "if not await Gf.register_system(",
        "if not await Gf.init():",
        "if player_model == null or battle_system == null:",
    )
    for fragment in manual_requirements:
        if fragment not in manual_quickstart:
            errors.append(f"README quickstart must observe `{fragment}`")

    installer_requirements = (
        "func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:",
        "await architecture.register_model_instance(",
        "await architecture.register_utility_instance(",
        "await architecture.register_system_instance(",
        "if scope.is_cancel_requested():",
        "architecture.fail_initialization(",
    )
    for fragment in installer_requirements:
        if fragment not in installer_quickstart:
            errors.append(f"README installer quickstart must contain `{fragment}`")
    return errors


def check_public_entry_contracts(repository_root: Path) -> list[str]:
    """Validate public entry-point facts that are owned outside docs/zh."""
    required_paths = {
        "README.md": repository_root / "README.md",
        "README.zh.md": repository_root / "README.zh.md",
        "ASSET_STORE.md": repository_root / "ASSET_STORE.md",
        "ASSET_LIBRARY.md": repository_root / "ASSET_LIBRARY.md",
        "extension installation": repository_root / "docs/zh/extensions/installation.md",
        "installation guide": repository_root / "docs/zh/overview/quickstart/install-autoload.md",
        "uninstall guide": repository_root / "docs/zh/overview/quickstart/uninstall.md",
        "FAQ": repository_root / "docs/zh/faq.md",
        "maintainer guide": repository_root / "docs/maintainers/index.md",
    }
    errors: list[str] = []
    texts: dict[str, str] = {}
    for label, path in required_paths.items():
        if not path.is_file():
            errors.append(f"{label}: required public entry file is missing")
            continue
        try:
            texts[label] = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            errors.append(f"{label}: cannot read UTF-8 content: {error}")

    if "README.md" in texts and "README.zh.md" in texts:
        errors.extend(
            check_readme_quickstart_contracts(
                texts["README.md"],
                texts["README.zh.md"],
            )
        )
        for label in ("README.md", "README.zh.md"):
            if "docs/zh/overview/quickstart/uninstall.md" not in texts[label]:
                errors.append(f"{label} must link the complete uninstall journey")

    store_text = texts.get("ASSET_STORE.md", "")
    if store_text and "does not replace checking the awaited result" not in store_text:
        errors.append(
            "ASSET_STORE.md must state that a project installer does not replace "
            "checking the awaited Gf.init() result"
        )

    extension_text = texts.get("extension installation", "")
    extension_requirements = (
        "`GFExtensionPreset`",
        "只写本地扩展启用设置",
        "不下载、更新、卸载或覆盖文件",
        "`gf.save`",
    )
    for fragment in extension_requirements:
        if extension_text and fragment not in extension_text:
            errors.append(f"extension installation must distinguish `{fragment}`")

    uninstall_text = texts.get("uninstall guide", "")
    uninstall_requirements = (
        "先禁用插件，再删除文件",
        "只移除由 GF 插件登记的 `Gf` AutoLoad",
        "不会删除同名但不指向 GF 的 AutoLoad",
        "`.gf/packages.lock.json`",
        "恢复同一版本",
    )
    for fragment in uninstall_requirements:
        if uninstall_text and fragment not in uninstall_text:
            errors.append(f"uninstall guide must contain `{fragment}`")

    install_text = texts.get("installation guide", "")
    if install_text and "uninstall.md" not in install_text:
        errors.append("installation guide must link the complete uninstall journey")
    if install_text and "GF 11 只提供完整框架 ZIP" not in install_text:
        errors.append("installation guide must state the complete-framework ZIP boundary")
    if install_text and "package-manager-migration.md" not in install_text:
        errors.append("installation guide must link the GF 10 migration guide")

    faq_text = texts.get("FAQ", "")
    if faq_text and not has_visible_heading(faq_text, 2, "按主题查找"):
        errors.append("docs/zh/faq.md must expose a task-grouped `## 按主题查找` index")
    if faq_text and "overview/quickstart/uninstall.md" not in faq_text:
        errors.append("docs/zh/faq.md must link the complete uninstall journey")

    library_text = texts.get("ASSET_LIBRARY.md", "")
    if library_text:
        description_blocks = [
            "\n".join(block.content).strip()
            for block in scan_markdown_structure(library_text).fences
            if block.info.split(maxsplit=1)[0].lower() == "text"
            and block.content
            and block.content[0].startswith("GF Framework is")
        ]
        if len(description_blocks) != 1:
            errors.append("ASSET_LIBRARY.md must contain one canonical long description")
        elif len(description_blocks[0]) > DEFAULT_ASSET_LIBRARY_DESCRIPTION_CHARS:
            errors.append(
                "ASSET_LIBRARY.md long description exceeds "
                f"{DEFAULT_ASSET_LIBRARY_DESCRIPTION_CHARS} characters"
            )

    maintainer_text = texts.get("maintainer guide", "")
    manifest_paths = sorted(
        (repository_root / "addons/gf/extensions").glob("*/gf_extension.json")
    )
    enabled_by_default: list[str] = []
    for manifest_path in manifest_paths:
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            errors.append(f"{manifest_path.as_posix()}: cannot verify extension default: {error}")
            continue
        if manifest.get("enabled_by_default") is True:
            enabled_by_default.append(str(manifest.get("id", manifest_path.parent.name)))
    if manifest_paths and not enabled_by_default:
        if "GF 内置可选扩展默认关闭" not in maintainer_text:
            errors.append(
                "docs/maintainers/index.md must derive the all-disabled extension default "
                "from manifests"
            )
        if "GF 内置扩展默认随 GF 启用" in maintainer_text:
            errors.append("docs/maintainers/index.md contradicts extension manifest defaults")
    return errors


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate page size, heading shape, and code fence metadata.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help=(
            "Enable all optional fail-mode checks for hand-authored docs: "
            "page granularity, entry templates, local links, and rendering syntax."
        ),
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("docs/zh"),
        help="Documentation root to scan. Defaults to docs/zh.",
    )
    parser.add_argument(
        "--max-lines",
        type=int,
        default=DEFAULT_MAX_LINES,
        help=f"Maximum lines per hand-authored page. Defaults to {DEFAULT_MAX_LINES}.",
    )
    parser.add_argument(
        "--max-changelog-lines",
        type=int,
        default=DEFAULT_MAX_CHANGELOG_LINES,
        help=(
            "Maximum lines for docs/zh/changelog.md. "
            f"Defaults to {DEFAULT_MAX_CHANGELOG_LINES}."
        ),
    )
    parser.add_argument(
        "--max-paragraph-chars",
        type=int,
        default=DEFAULT_MAX_PARAGRAPH_CHARS,
        help=(
            "Maximum characters in one prose paragraph. "
            f"Defaults to {DEFAULT_MAX_PARAGRAPH_CHARS}."
        ),
    )
    parser.add_argument(
        "--include-reference-api",
        action="store_true",
        help="Also scan generated docs/zh/reference/api pages.",
    )
    parser.add_argument(
        "--min-body-lines",
        type=int,
        default=DEFAULT_MIN_BODY_LINES,
        help=(
            "Minimum line count for non-index hand-authored body pages when "
            f"reporting page granularity. Defaults to {DEFAULT_MIN_BODY_LINES}."
        ),
    )
    parser.add_argument(
        "--report-fragments",
        action="store_true",
        help=(
            "Report body pages that are probably too small to stand alone. "
            "This does not fail unless --fail-fragments is also passed."
        ),
    )
    parser.add_argument(
        "--fail-fragments",
        action="store_true",
        help=(
            "Fail when body pages are below --min-body-lines. Use after the "
            "current over-split pages have been merged back."
        ),
    )
    parser.add_argument(
        "--fragment-report-limit",
        type=int,
        default=DEFAULT_FRAGMENT_REPORT_LIMIT,
        help=(
            "Maximum number of fragment candidates to print. Defaults to "
            f"{DEFAULT_FRAGMENT_REPORT_LIMIT}."
        ),
    )
    parser.add_argument(
        "--min-structured-body-lines",
        type=int,
        default=DEFAULT_MIN_STRUCTURED_BODY_LINES,
        help=(
            "Minimum non-index page length that requires at least one H2. "
            f"Defaults to {DEFAULT_MIN_STRUCTURED_BODY_LINES}."
        ),
    )
    parser.add_argument(
        "--report-entry-templates",
        action="store_true",
        help=(
            "Report entry pages that do not expose the required "
            "reader-facing sections."
        ),
    )
    parser.add_argument(
        "--fail-entry-templates",
        action="store_true",
        help="Fail when entry pages miss required reader-facing sections.",
    )
    parser.add_argument(
        "--report-local-links",
        action="store_true",
        help="Report local Markdown links whose targets do not exist.",
    )
    parser.add_argument(
        "--fail-local-links",
        action="store_true",
        help="Fail when local Markdown links point to missing files.",
    )
    parser.add_argument(
        "--report-link-anchors",
        action="store_true",
        help="Report local Markdown links whose #fragment does not match a target heading anchor.",
    )
    parser.add_argument(
        "--fail-link-anchors",
        action="store_true",
        help="Fail when local Markdown links point to missing heading anchors.",
    )
    parser.add_argument(
        "--report-render-syntax",
        action="store_true",
        help="Report rendering-sensitive Markdown syntax issues, such as Mermaid fences.",
    )
    parser.add_argument(
        "--fail-render-syntax",
        action="store_true",
        help="Fail on rendering-sensitive Markdown syntax issues.",
    )
    parser.add_argument(
        "--report-public-maintenance-leaks",
        action="store_true",
        help="Report maintainer-only wording that leaked into public docs.",
    )
    parser.add_argument(
        "--fail-public-maintenance-leaks",
        action="store_true",
        help="Fail when maintainer-only wording appears in public docs.",
    )
    parser.add_argument(
        "--report-public-entry-contracts",
        action="store_true",
        help=(
            "Report drift in root README quickstarts, install/uninstall facts, "
            "extension/package terminology, FAQ navigation, and store metadata."
        ),
    )
    parser.add_argument(
        "--fail-public-entry-contracts",
        action="store_true",
        help="Fail when public entry-point facts contradict executable authorities.",
    )
    parser.add_argument(
        "--report-unstructured-body-pages",
        action="store_true",
        help="Report longer non-index pages that have no H2 sections.",
    )
    parser.add_argument(
        "--fail-unstructured-body-pages",
        action="store_true",
        help="Fail when longer non-index pages have no H2 sections.",
    )
    return parser.parse_args(argv)


def should_skip(path: Path, root: Path, include_reference_api: bool) -> bool:
    if include_reference_api:
        return False
    relative = path.relative_to(root)
    return len(relative.parts) >= 2 and relative.parts[0] == "reference" and relative.parts[1] == "api"


def is_paragraph_boundary(stripped: str) -> bool:
    if stripped == "":
        return True
    if stripped.startswith(("#", ">", "|", "<", "```", "~~~")):
        return True
    return LIST_ITEM_PATTERN.match(stripped) is not None


def max_lines_for_file(path: Path, root: Path, max_lines: int, max_changelog_lines: int) -> int:
    relative = path.relative_to(root).as_posix()
    if relative == "changelog.md":
        return max_changelog_lines
    return max_lines


def check_file(
    path: Path,
    root: Path,
    max_lines: int,
    max_changelog_lines: int,
    max_paragraph_chars: int,
) -> list[str]:
    relative_path = path.relative_to(root.parent).as_posix()
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    structure = scan_markdown_structure(text)
    errors: list[str] = []
    file_max_lines = max_lines_for_file(path, root, max_lines, max_changelog_lines)

    if len(lines) > file_max_lines:
        errors.append(
            f"{relative_path}: page has {len(lines)} lines, limit is {file_max_lines}"
        )

    h1_lines: list[int] = []
    paragraph_lines: list[str] = []
    paragraph_start = 0

    def flush_paragraph() -> None:
        nonlocal paragraph_lines, paragraph_start
        if not paragraph_lines:
            return
        paragraph = " ".join(paragraph_lines)
        if len(paragraph) > max_paragraph_chars:
            errors.append(
                f"{relative_path}:{paragraph_start}: paragraph has "
                f"{len(paragraph)} characters, limit is {max_paragraph_chars}"
            )
        paragraph_lines = []
        paragraph_start = 0

    for fence in structure.fences:
        if fence.info == "":
            errors.append(f"{relative_path}:{fence.start_line}: code fence has no language")

    for line_number, line in structure.visible_lines:
        stripped = line.strip()

        if stripped.startswith("# ") and not stripped.startswith("## "):
            h1_lines.append(line_number)

        if is_paragraph_boundary(stripped):
            flush_paragraph()
            continue

        if not paragraph_lines:
            paragraph_start = line_number
        paragraph_lines.append(stripped)

    flush_paragraph()

    if structure.unclosed_fence_line is not None:
        errors.append(f"{relative_path}: unclosed code fence")

    if len(h1_lines) != 1:
        locations = ", ".join(str(line) for line in h1_lines) or "none"
        errors.append(f"{relative_path}: expected exactly one H1, found {locations}")

    return errors


def find_fragment_candidates(
    path: Path,
    root: Path,
    min_body_lines: int,
) -> list[str]:
    """Return warnings for body pages that are too small to justify a page."""
    if path.name == "index.md":
        return []

    relative_path = path.relative_to(root.parent).as_posix()
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    line_count = len(lines)
    if line_count >= min_body_lines:
        return []

    return [
        (
            f"{relative_path}: body page has {line_count} lines, below "
            f"minimum split threshold {min_body_lines}; merge into a sibling "
            "unless it is an independent task/concept with a durable URL need"
        )
    ]


def find_unstructured_body_page(
    path: Path,
    root: Path,
    min_structured_body_lines: int,
) -> list[str]:
    """Return warnings for longer body pages that lack scannable H2 sections."""
    if path.name == "index.md":
        return []

    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if len(lines) < min_structured_body_lines:
        return []

    has_h2 = any(
        level == 2
        for _line_number, level, _title in visible_markdown_headings(text)
    )
    if has_h2:
        return []

    relative_path = path.relative_to(root.parent).as_posix()
    return [
        (
            f"{relative_path}: body page has {len(lines)} lines and no H2 "
            "sections; add a small structure such as core model, example, "
            "or usage boundary"
        )
    ]


def split_link_target(raw_target: str) -> str:
    """Return the actual Markdown link destination without an optional title."""
    target = raw_target.strip()
    if target.startswith("<"):
        end = target.find(">")
        if end != -1:
            return target[1:end].strip()
        return target[1:].strip()
    return target.split()[0] if target else ""


def is_external_link(target: str) -> bool:
    return APPROVED_EXTERNAL_LINK_PATTERN.match(target) is not None


def check_local_links(path: Path, root: Path) -> list[str]:
    """Validate local Markdown link targets outside code fences."""
    relative_path = path.relative_to(root.parent).as_posix()
    text = path.read_text(encoding="utf-8")
    errors: list[str] = []

    for line_number, line in scan_markdown_structure(text).visible_lines:

        for match in MARKDOWN_LINK_PATTERN.finditer(line):
            target = unquote(split_link_target(match.group(1)))
            if not target or target.startswith("#") or is_external_link(target):
                continue

            path_part = target.split("#", 1)[0].split("?", 1)[0]
            if not path_part:
                continue

            target_path = resolve_local_link_path(path, root, path_part)
            if target_path is None:
                errors.append(
                    f"{relative_path}:{line_number}: local link escapes documentation root: "
                    f"{target}"
                )
            elif not target_path.exists():
                errors.append(
                    f"{relative_path}:{line_number}: local link target does not exist: "
                    f"{target}"
                )

    return errors


def check_local_link_anchors(path: Path, root: Path) -> list[str]:
    """Validate local Markdown link fragments against target page headings."""
    relative_path = path.relative_to(root.parent).as_posix()
    text = path.read_text(encoding="utf-8")
    errors: list[str] = []
    anchor_cache: dict[Path, set[str]] = {}

    for line_number, line in scan_markdown_structure(text).visible_lines:

        for match in MARKDOWN_LINK_PATTERN.finditer(line):
            target = unquote(split_link_target(match.group(1)))
            if not target or is_external_link(target):
                continue

            path_part, fragment = split_target_fragment(target)
            if not fragment:
                continue
            target_path = resolve_local_link_path(path, root, path_part)
            if target_path is None or not target_path.exists() or target_path.suffix.lower() != ".md":
                continue

            if target_path not in anchor_cache:
                anchor_cache[target_path] = collect_markdown_heading_anchors(target_path)
            if fragment not in anchor_cache[target_path]:
                errors.append(
                    f"{relative_path}:{line_number}: local link anchor does not exist: "
                    f"{target}"
                )

    return errors


def split_target_fragment(target: str) -> tuple[str, str]:
    without_query = target.split("?", 1)[0]
    if "#" not in without_query:
        return without_query, ""
    path_part, fragment = without_query.split("#", 1)
    return path_part, fragment.strip()


def resolve_local_link_path(source_path: Path, root: Path, path_part: str) -> Path | None:
    normalized_path_part = path_part.replace("\\", "/")
    if WINDOWS_DRIVE_PATH_PATTERN.match(path_part) or normalized_path_part.lower().startswith("file:"):
        return None
    if not normalized_path_part:
        candidate = source_path.resolve()
    elif normalized_path_part.startswith("/"):
        candidate = (root / normalized_path_part.lstrip("/")).resolve()
    else:
        candidate = (source_path.parent / normalized_path_part).resolve()
    try:
        candidate.relative_to(root.resolve())
    except ValueError:
        return None
    return candidate


def collect_markdown_heading_anchors(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    anchors: set[str] = set()
    counts: dict[str, int] = {}
    for _line_number, _level, title in visible_markdown_headings(text):
        explicit_id_match = HEADING_ATTRIBUTE_ID_PATTERN.search(title)
        base_slug = (
            explicit_id_match.group("id")
            if explicit_id_match is not None
            else slugify_heading(title)
        )
        if not base_slug:
            continue
        count = counts.get(base_slug, 0)
        counts[base_slug] = count + 1
        anchors.add(base_slug if count == 0 else f"{base_slug}_{count}")
    return anchors


def slugify_heading(text: str) -> str:
    stripped = re.sub(r"<[^>]+>", "", text)
    stripped = re.sub(r"`([^`]+)`", r"\1", stripped)
    stripped = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", stripped)
    stripped = stripped.replace("*", "").replace("_", "").strip().lower()
    chars: list[str] = []
    previous_dash = False
    for char in stripped:
        if char.isalnum():
            chars.append(char)
            previous_dash = False
        elif not previous_dash:
            chars.append("-")
            previous_dash = True
    return "".join(chars).strip("-")


def mermaid_first_content_line(lines: list[str]) -> str:
    for line in lines:
        stripped = line.strip()
        if stripped == "" or stripped.startswith("%%"):
            continue
        return stripped
    return ""


def check_rendering_syntax(path: Path, root: Path) -> tuple[list[str], bool]:
    """Validate syntax that can silently render incorrectly in MkDocs."""
    relative_path = path.relative_to(root.parent).as_posix()
    structure = scan_markdown_structure(path.read_text(encoding="utf-8"))
    errors: list[str] = []
    has_mermaid = False

    for fence in structure.fences:
        if fence.end_line is None:
            continue
        language = fence.info.split()[0].lower() if fence.info else ""
        first_content = mermaid_first_content_line(list(fence.content))
        looks_like_mermaid = (
            MERMAID_START_PATTERN.match(first_content) is not None
            if first_content
            else False
        )

        if language == "mermaid":
            has_mermaid = True
            if not first_content:
                errors.append(f"{relative_path}:{fence.start_line}: empty Mermaid diagram")
            elif not looks_like_mermaid:
                errors.append(
                    f"{relative_path}:{fence.start_line}: Mermaid diagram starts with "
                    f"unsupported syntax: {first_content}"
                )
        elif looks_like_mermaid:
            errors.append(
                f"{relative_path}:{fence.start_line}: Mermaid diagram must use "
                "a mermaid-language fence"
            )

    return errors, has_mermaid


def check_public_maintenance_leaks(path: Path, root: Path) -> list[str]:
    """Detect explicit maintainer-process wording in public reader docs."""
    relative_path = path.relative_to(root.parent).as_posix()
    errors: list[str] = []

    structure = scan_markdown_structure(path.read_text(encoding="utf-8"))
    for line_number, line in structure.visible_lines:

        for pattern in PUBLIC_MAINTENANCE_LEAK_PATTERNS:
            if pattern in line:
                errors.append(
                    f"{relative_path}:{line_number}: maintainer-only wording "
                    f"belongs in docs/maintainers, not public docs: {pattern}"
                )

    return errors


def check_mkdocs_mermaid_config(root: Path) -> list[str]:
    """Ensure MkDocs is configured to render Mermaid fenced diagrams."""
    config_candidates = [
        Path("mkdocs.yml"),
        root.parent.parent / "mkdocs.yml",
    ]
    config_path = next((candidate for candidate in config_candidates if candidate.exists()), None)
    if config_path is None:
        return ["mkdocs.yml: missing MkDocs config; Mermaid rendering cannot be verified"]

    text = config_path.read_text(encoding="utf-8")
    missing: list[str] = []
    if "pymdownx.superfences" not in text:
        missing.append("pymdownx.superfences")
    if "name: mermaid" not in text:
        missing.append("custom fence name: mermaid")
    if "class: mermaid" not in text:
        missing.append("custom fence class: mermaid")

    if missing:
        return [
            f"{config_path.as_posix()}: missing Mermaid rendering config: "
            + ", ".join(missing)
        ]
    return []


def check_section_entry_templates(root: Path) -> list[str]:
    """Validate the minimum public shape of high-level section entries."""
    errors: list[str] = []
    for section in ENTRY_TEMPLATE_ROOTS:
        section_root = root / section
        if not section_root.exists():
            continue

        for path in sorted(section_root.rglob("index.md")):
            has_child_pages = any(
                child.name != "index.md" and child.suffix == ".md"
                for child in path.parent.iterdir()
                if child.is_file()
            )
            has_child_sections = any(
                child.is_dir() and (child / "index.md").exists()
                for child in path.parent.iterdir()
            )
            if not has_child_pages and not has_child_sections:
                continue

            text = path.read_text(encoding="utf-8")
            missing_sections: list[str] = []
            if not has_visible_heading(text, 2, "阅读入口"):
                missing_sections.append("## 阅读入口")
            if not has_visible_heading(text, 2, "使用边界"):
                missing_sections.append("## 使用边界")

            if missing_sections:
                relative_path = path.relative_to(root.parent).as_posix()
                errors.append(
                    f"{relative_path}: missing entry template item(s): "
                    + ", ".join(missing_sections)
                )

    for relative_name, api_files in sorted(SECTION_API_REFERENCES.items()):
        path = root / relative_name
        relative_path = path.relative_to(root.parent).as_posix()
        if not path.exists():
            errors.append(f"{relative_path}: missing section entry page")
            continue

        text = path.read_text(encoding="utf-8")
        visible_text = visible_markdown_text(text)
        missing_sections: list[str] = []
        for api_file in api_files:
            if not has_visible_heading(text, 2, "API Reference"):
                missing_sections.append("## API Reference")
            if f"reference/api/{api_file}" not in visible_text:
                missing_sections.append(f"link to {api_file}")

        if missing_sections:
            errors.append(
                f"{relative_path}: missing entry template item(s): "
                + ", ".join(missing_sections)
            )

    return errors


def check_extension_entry_templates(root: Path) -> list[str]:
    """Validate the minimum public shape of top-level extension entry pages."""
    extensions_root = root / "extensions"
    if not extensions_root.exists():
        return []

    errors: list[str] = []
    for extension_id, api_files in sorted(EXTENSION_API_REFERENCES.items()):
        path = extensions_root / extension_id / "index.md"
        relative_path = path.relative_to(root.parent).as_posix()
        if not path.exists():
            errors.append(f"{relative_path}: missing extension entry page")
            continue

        text = path.read_text(encoding="utf-8")
        visible_text = visible_markdown_text(text)
        missing_sections: list[str] = []
        if not has_visible_heading(text, 2, "使用边界"):
            missing_sections.append("## 使用边界")
        if not has_visible_heading(text, 2, "API Reference"):
            missing_sections.append("## API Reference")
        for api_file in api_files:
            if f"reference/api/{api_file}" not in visible_text:
                missing_sections.append(f"link to {api_file}")

        has_child_pages = any(
            child.name != "index.md" and child.suffix == ".md"
            for child in path.parent.rglob("*.md")
        )
        if has_child_pages and not has_visible_heading(text, 2, "阅读入口"):
            missing_sections.append("## 阅读入口")

        if missing_sections:
            errors.append(
                f"{relative_path}: missing entry template item(s): "
                + ", ".join(missing_sections)
            )

    return errors


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.strict:
        args.fail_fragments = True
        args.fail_entry_templates = True
        args.fail_local_links = True
        args.fail_link_anchors = True
        args.fail_render_syntax = True
        args.fail_public_maintenance_leaks = True
        args.fail_public_entry_contracts = True
        args.fail_unstructured_body_pages = True

    root = args.root

    if not root.exists():
        print(f"Docs root does not exist: {root}", file=sys.stderr)
        return 2

    errors: list[str] = []
    fragment_candidates: list[str] = []
    unstructured_body_pages: list[str] = []
    local_link_errors: list[str] = []
    local_link_anchor_errors: list[str] = []
    render_syntax_errors: list[str] = []
    public_maintenance_errors: list[str] = []
    public_entry_contract_errors: list[str] = []
    has_mermaid_diagrams = False
    scanned = 0
    for path in sorted(root.rglob("*.md")):
        if should_skip(path, root, args.include_reference_api):
            continue
        scanned += 1
        errors.extend(
            check_file(
                path,
                root,
                args.max_lines,
                args.max_changelog_lines,
                args.max_paragraph_chars,
            )
        )
        if args.report_fragments or args.fail_fragments:
            fragment_candidates.extend(
                find_fragment_candidates(
                    path,
                    root,
                    args.min_body_lines,
                )
            )
        if args.report_unstructured_body_pages or args.fail_unstructured_body_pages:
            unstructured_body_pages.extend(
                find_unstructured_body_page(
                    path,
                    root,
                    args.min_structured_body_lines,
                )
            )
        if args.report_local_links or args.fail_local_links:
            local_link_errors.extend(check_local_links(path, root))
        if args.report_link_anchors or args.fail_link_anchors:
            local_link_anchor_errors.extend(check_local_link_anchors(path, root))
        if args.report_render_syntax or args.fail_render_syntax:
            file_render_errors, file_has_mermaid = check_rendering_syntax(path, root)
            render_syntax_errors.extend(file_render_errors)
            has_mermaid_diagrams = has_mermaid_diagrams or file_has_mermaid
        if args.report_public_maintenance_leaks or args.fail_public_maintenance_leaks:
            public_maintenance_errors.extend(check_public_maintenance_leaks(path, root))

    canonical_docs_root = (Path.cwd() / "docs/zh").resolve()
    if (
        args.report_public_entry_contracts
        or args.fail_public_entry_contracts
    ) and root.resolve() == canonical_docs_root:
        public_entry_contract_errors = check_public_entry_contracts(Path.cwd())

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print(f"Docs quality check failed with {len(errors)} issue(s).", file=sys.stderr)
        return 1

    if fragment_candidates:
        limit = max(args.fragment_report_limit, 0)
        printed_candidates = fragment_candidates[:limit] if limit else []
        for candidate in printed_candidates:
            print(candidate, file=sys.stderr)
        remaining = len(fragment_candidates) - len(printed_candidates)
        if remaining > 0:
            print(
                f"... {remaining} more fragment candidate(s) omitted.",
                file=sys.stderr,
            )

        message = (
            f"Docs granularity check found {len(fragment_candidates)} "
            "fragment candidate(s)."
        )
        if args.fail_fragments:
            print(message, file=sys.stderr)
            return 1
        if args.report_fragments:
            print(message)

    if unstructured_body_pages:
        for page in unstructured_body_pages:
            print(page, file=sys.stderr)
        message = (
            "Docs body structure check found "
            f"{len(unstructured_body_pages)} issue(s)."
        )
        if args.fail_unstructured_body_pages:
            print(message, file=sys.stderr)
            return 1
        if args.report_unstructured_body_pages:
            print(message)

    if args.report_entry_templates or args.fail_entry_templates:
        entry_template_errors = (
            check_section_entry_templates(root)
            + check_extension_entry_templates(root)
        )
        if entry_template_errors:
            for error in entry_template_errors:
                print(error, file=sys.stderr)
            message = (
                f"Docs entry template check found {len(entry_template_errors)} "
                "issue(s)."
            )
            if args.fail_entry_templates:
                print(message, file=sys.stderr)
                return 1
            print(message)

    if local_link_errors:
        for error in local_link_errors:
            print(error, file=sys.stderr)
        message = f"Docs local link check found {len(local_link_errors)} issue(s)."
        if args.fail_local_links:
            print(message, file=sys.stderr)
            return 1
        if args.report_local_links:
            print(message)

    if local_link_anchor_errors:
        for error in local_link_anchor_errors:
            print(error, file=sys.stderr)
        message = (
            "Docs local link anchor check found "
            f"{len(local_link_anchor_errors)} issue(s)."
        )
        if args.fail_link_anchors:
            print(message, file=sys.stderr)
            return 1
        if args.report_link_anchors:
            print(message)

    if has_mermaid_diagrams:
        render_syntax_errors.extend(check_mkdocs_mermaid_config(root))

    if render_syntax_errors:
        for error in render_syntax_errors:
            print(error, file=sys.stderr)
        message = (
            f"Docs rendering syntax check found {len(render_syntax_errors)} issue(s)."
        )
        if args.fail_render_syntax:
            print(message, file=sys.stderr)
            return 1
        if args.report_render_syntax:
            print(message)

    if public_maintenance_errors:
        for error in public_maintenance_errors:
            print(error, file=sys.stderr)
        message = (
            "Docs public maintenance leak check found "
            f"{len(public_maintenance_errors)} issue(s)."
        )
        if args.fail_public_maintenance_leaks:
            print(message, file=sys.stderr)
            return 1
        if args.report_public_maintenance_leaks:
            print(message)

    if public_entry_contract_errors:
        for error in public_entry_contract_errors:
            print(error, file=sys.stderr)
        message = (
            "Docs public entry contract check found "
            f"{len(public_entry_contract_errors)} issue(s)."
        )
        if args.fail_public_entry_contracts:
            print(message, file=sys.stderr)
            return 1
        if args.report_public_entry_contracts:
            print(message)

    print(f"Docs quality check passed for {scanned} page(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
