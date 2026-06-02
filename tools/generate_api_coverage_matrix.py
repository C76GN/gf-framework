#!/usr/bin/env python3
"""Generate a planning matrix for GF public API guide, test, and example coverage."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from gdscript_api_parser import ApiClass
from gdscript_api_parser import ApiMember
from gdscript_api_parser import flatten_api_classes
from gdscript_api_parser import full_api_class_name
from gdscript_api_parser import top_level_class_name
from generate_api_reference import collect_api_classes
from generate_api_reference import module_label
from generate_api_reference import module_slug


ROOT = Path(__file__).resolve().parents[1]
MEMBER_GROUPS = {
	"signals": "signals",
	"enums": "enums",
	"constants": "constants",
	"properties": "properties",
	"methods": "methods",
}


def main() -> int:
	parser = argparse.ArgumentParser(description="Generate GF API coverage planning matrix.")
	parser.add_argument("--source", default="addons/gf", help="GDScript source root.")
	parser.add_argument("--docs", default="docs/zh", help="Guide documentation root.")
	parser.add_argument("--tests", default="tests/gf_core", help="GUT test root.")
	parser.add_argument(
		"--examples",
		action="append",
		default=[],
		help="Example project root. Can be passed multiple times.",
	)
	parser.add_argument("--output", default="ai_analysis/api_coverage", help="Output directory.")
	parser.add_argument("--check", action="store_true", help="Fail if existing outputs are stale.")
	args = parser.parse_args()

	source_root = (ROOT / args.source).resolve()
	docs_root = (ROOT / args.docs).resolve()
	tests_root = (ROOT / args.tests).resolve()
	output_root = (ROOT / args.output).resolve()
	example_roots = [(ROOT / item).resolve() for item in args.examples]

	if not source_root.exists():
		print(f"source root not found: {source_root}", file=sys.stderr)
		return 2
	if not docs_root.exists():
		print(f"docs root not found: {docs_root}", file=sys.stderr)
		return 2
	if not tests_root.exists():
		print(f"tests root not found: {tests_root}", file=sys.stderr)
		return 2

	api_classes = collect_api_classes(source_root)
	matrix = build_matrix(api_classes, docs_root, tests_root, example_roots)
	desired = render_outputs(matrix)

	if args.check:
		return check_outputs(output_root, desired)

	write_outputs(output_root, desired)
	print_summary(matrix, output_root)
	return 0


def build_matrix(
	api_classes: list[ApiClass],
	docs_root: Path,
	tests_root: Path,
	example_roots: list[Path],
) -> dict[str, Any]:
	all_classes = flatten_api_classes(api_classes)
	guide_docs = collect_text_files(
		docs_root,
		{ ".md" },
		exclude=lambda path: is_reference_api_path(docs_root, path) or is_changelog_page(path),
	)
	tests = collect_text_files(tests_root, { ".gd", ".tscn", ".tres", ".res", ".json", ".md" })
	examples = []
	for root in example_roots:
		if root.exists():
			examples.extend(collect_text_files(
				root,
				{ ".gd", ".tscn", ".tres", ".res", ".json", ".md" },
				exclude=lambda path, example_root=root: is_generated_example_path(example_root, path),
			))

	class_entries: list[dict[str, Any]] = []
	for api_class in sorted(all_classes, key=lambda item: full_api_class_name(item)):
		class_entries.append(build_class_entry(api_class, guide_docs, tests, examples))

	modules: dict[str, dict[str, Any]] = {}
	for entry in class_entries:
		module = entry["module"]
		stats = modules.setdefault(module, {
			"label": module_label(module),
			"class_count": 0,
			"member_count": 0,
			"guide_class_count": 0,
			"test_class_count": 0,
			"example_class_count": 0,
			"guide_member_count": 0,
			"test_member_count": 0,
			"example_member_count": 0,
		})
		stats["class_count"] += 1
		stats["member_count"] += entry["member_count"]
		stats["guide_class_count"] += 1 if entry["guide_docs"] else 0
		stats["test_class_count"] += 1 if entry["tests"] else 0
		stats["example_class_count"] += 1 if entry["examples"] else 0
		stats["guide_member_count"] += entry["guide_member_count"]
		stats["test_member_count"] += entry["test_member_count"]
		stats["example_member_count"] += entry["example_member_count"]

	member_count = sum(entry["member_count"] for entry in class_entries)
	return {
		"source_root": "addons/gf",
		"guide_docs_root": relative_to_root(docs_root),
		"tests_root": relative_to_root(tests_root),
		"example_roots": [relative_to_root(path) for path in example_roots if path.exists()],
		"class_count": len(class_entries),
		"member_count": member_count,
		"guide_class_count": sum(1 for entry in class_entries if entry["guide_docs"]),
		"test_class_count": sum(1 for entry in class_entries if entry["tests"]),
		"example_class_count": sum(1 for entry in class_entries if entry["examples"]),
		"guide_member_count": sum(entry["guide_member_count"] for entry in class_entries),
		"test_member_count": sum(entry["test_member_count"] for entry in class_entries),
		"example_member_count": sum(entry["example_member_count"] for entry in class_entries),
		"modules": modules,
		"classes": class_entries,
	}


def build_class_entry(
	api_class: ApiClass,
	guide_docs: list[dict[str, str]],
	tests: list[dict[str, str]],
	examples: list[dict[str, str]],
) -> dict[str, Any]:
	class_terms = api_class_terms(api_class)
	guide_hits = find_class_hits(guide_docs, class_terms)
	test_hits = find_class_hits(tests, class_terms)
	example_hits = find_class_hits(examples, class_terms)
	members = []
	for member in api_class_members(api_class):
		member_entry = build_member_entry(api_class, member, guide_docs, tests, examples)
		members.append(member_entry)

	return {
		"name": full_api_class_name(api_class),
		"top_level": top_level_class_name(api_class),
		"module": api_class.module,
		"module_label": module_label(api_class.module),
		"path": api_class.path,
		"reference_page": f"docs/zh/reference/api/classes/{top_level_class_name(api_class)}.md",
		"guide_docs": guide_hits,
		"tests": test_hits,
		"examples": example_hits,
		"member_count": len(members),
		"guide_member_count": sum(1 for member in members if member["guide_docs"]),
		"test_member_count": sum(1 for member in members if member["tests"]),
		"example_member_count": sum(1 for member in members if member["examples"]),
		"members": members,
	}


def build_member_entry(
	api_class: ApiClass,
	member: ApiMember,
	guide_docs: list[dict[str, str]],
	tests: list[dict[str, str]],
	examples: list[dict[str, str]],
) -> dict[str, Any]:
	class_terms = api_class_terms(api_class)
	member_terms = [member.name, member.signature]
	return {
		"kind": member.kind,
		"name": member.name,
		"signature": member.signature,
		"guide_docs": find_member_hits(guide_docs, class_terms, member_terms),
		"tests": find_member_hits(tests, class_terms, member_terms),
		"examples": find_member_hits(examples, class_terms, member_terms),
	}


def api_class_terms(api_class: ApiClass) -> list[str]:
	terms = [full_api_class_name(api_class), top_level_class_name(api_class)]
	if api_class.name not in terms:
		terms.append(api_class.name)
	return dedupe_non_empty(terms)


def find_class_hits(files: list[dict[str, str]], terms: list[str]) -> list[str]:
	hits: list[str] = []
	for item in files:
		if any(term in item["text"] for term in terms):
			hits.append(item["path"])
	return hits


def find_member_hits(
	files: list[dict[str, str]],
	class_terms: list[str],
	member_terms: list[str],
) -> list[str]:
	hits: list[str] = []
	for item in files:
		text = item["text"]
		if not any(term in text for term in class_terms):
			continue
		if any(term in text for term in member_terms):
			hits.append(item["path"])
	return hits


def collect_text_files(
	root: Path,
	suffixes: set[str],
	exclude: Any | None = None,
) -> list[dict[str, str]]:
	result: list[dict[str, str]] = []
	if not root.exists():
		return result
	for path in sorted(root.rglob("*")):
		if not path.is_file() or path.suffix.lower() not in suffixes:
			continue
		if exclude != None and exclude(path):
			continue
		try:
			text = path.read_text(encoding="utf-8", errors="replace")
		except OSError:
			continue
		result.append({
			"path": relative_to_root(path),
			"text": text,
		})
	return result


def is_generated_example_path(example_root: Path, path: Path) -> bool:
	try:
		relative_path = path.relative_to(example_root)
	except ValueError:
		return False
	parts = relative_path.parts
	if parts and parts[0] == "ai_analysis":
		return True
	if len(parts) >= 2 and parts[0] == "addons" and parts[1] == "gf":
		return True
	if any(part in { ".godot", ".import" } for part in parts):
		return True
	if path.suffix == ".import":
		return True
	return False


def render_outputs(matrix: dict[str, Any]) -> dict[str, str]:
	outputs = {
		"api_coverage.json": json.dumps(matrix, ensure_ascii=False, indent=2) + "\n",
		"index.md": render_index(matrix),
	}
	for module in sorted(matrix["modules"], key=module_sort_key):
		classes = [entry for entry in matrix["classes"] if entry["module"] == module]
		outputs[f"modules/{module_slug(module)}.md"] = render_module(module, matrix["modules"][module], classes)
	return outputs


def render_index(matrix: dict[str, Any]) -> str:
	lines = [
		"# GF API Coverage Matrix",
		"",
		"本报告用于规划公开 API 的指南、测试和未来示例覆盖。它是维护清单，不是正式用户文档。",
		"",
		"## Summary",
		"",
		"| Item | Count |",
		"|---|---:|",
		f"| Public classes | {matrix['class_count']} |",
		f"| Public members | {matrix['member_count']} |",
		f"| Classes mentioned in guide docs | {matrix['guide_class_count']} |",
		f"| Classes mentioned in tests | {matrix['test_class_count']} |",
		f"| Classes mentioned in examples | {matrix['example_class_count']} |",
		f"| Members mentioned in guide docs | {matrix['guide_member_count']} |",
		f"| Members mentioned in tests | {matrix['test_member_count']} |",
		f"| Members mentioned in examples | {matrix['example_member_count']} |",
		"",
		"## Reading The Matrix",
		"",
		"- API Reference 覆盖由 `tools/generate_api_reference.py --check` 负责，本报告不重复判定。",
		"- Guide docs 覆盖表示非 Reference 正文中出现了类名，或同一文件同时出现类名和成员名。",
		"- Test / example 覆盖表示测试或示例文件中出现了对应名称；这是排查入口，不等同于行为断言。",
		"- 当前没有示例项目时，examples 覆盖为 0 是预期状态。",
		"",
		"## Modules",
		"",
		"| Module | Classes | Members | Guide Classes | Test Classes | Example Classes | Page |",
		"|---|---:|---:|---:|---:|---:|---|",
	]
	for module in sorted(matrix["modules"], key=module_sort_key):
		stats = matrix["modules"][module]
		page = f"modules/{module_slug(module)}.md"
		lines.append(
			f"| {stats['label']} | {stats['class_count']} | {stats['member_count']} "
			f"| {stats['guide_class_count']} | {stats['test_class_count']} "
			f"| {stats['example_class_count']} | [{page}]({page}) |"
		)

	missing_tests = [entry for entry in matrix["classes"] if not entry["tests"]]
	if missing_tests:
		lines.extend(["", "## Classes Without Test Mentions", ""])
		for entry in missing_tests[:80]:
			lines.append(f"- `{entry['name']}` | {entry['module']} | {entry['path']}")
		if len(missing_tests) > 80:
			lines.append(f"- ... {len(missing_tests) - 80} more")

	return "\n".join(lines) + "\n"


def render_module(module: str, stats: dict[str, Any], classes: list[dict[str, Any]]) -> str:
	lines = [
		f"# {stats['label']} API Coverage",
		"",
		"| Class | Members | Guide | Tests | Examples | Reference |",
		"|---|---:|---:|---:|---:|---|",
	]
	for entry in sorted(classes, key=lambda item: item["name"]):
		lines.append(
			f"| `{entry['name']}` | {entry['member_count']} "
			f"| {coverage_cell(len(entry['guide_docs']), entry['guide_member_count'], entry['member_count'])} "
			f"| {coverage_cell(len(entry['tests']), entry['test_member_count'], entry['member_count'])} "
			f"| {coverage_cell(len(entry['examples']), entry['example_member_count'], entry['member_count'])} "
			f"| `{entry['reference_page']}` |"
		)
	return "\n".join(lines) + "\n"


def coverage_cell(file_count: int, member_hits: int, member_count: int) -> str:
	if member_count == 0:
		return str(file_count)
	return f"{file_count} files / {member_hits} members"


def write_outputs(output_root: Path, desired: dict[str, str]) -> None:
	if output_root.exists():
		for path in output_root.rglob("*"):
			if path.is_file():
				path.unlink()
		for path in sorted(output_root.rglob("*"), reverse=True):
			if path.is_dir():
				path.rmdir()
	output_root.mkdir(parents=True, exist_ok=True)
	for relative, content in desired.items():
		path = output_root / relative
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(content, encoding="utf-8", newline="\n")


def check_outputs(output_root: Path, desired: dict[str, str]) -> int:
	mismatches: list[str] = []
	for relative, content in desired.items():
		path = output_root / relative
		if not path.exists():
			mismatches.append(f"missing: {relative}")
			continue
		if path.read_text(encoding="utf-8") != content:
			mismatches.append(f"stale: {relative}")

	existing = {
		path.relative_to(output_root).as_posix()
		for path in output_root.rglob("*")
		if path.is_file()
	} if output_root.exists() else set()
	for extra in sorted(existing - set(desired.keys())):
		mismatches.append(f"extra: {extra}")

	if not mismatches:
		print("API coverage matrix is current.")
		return 0
	print("API coverage matrix is stale:")
	for mismatch in mismatches:
		print(f"- {mismatch}")
	return 1


def print_summary(matrix: dict[str, Any], output_root: Path) -> None:
	print(
		"generated API coverage matrix: "
		f"{matrix['class_count']} classes, {matrix['member_count']} members"
	)
	print(
		"guide/test/example classes: "
		f"{matrix['guide_class_count']}/{matrix['test_class_count']}/{matrix['example_class_count']}"
	)
	print(f"output: {output_root}")


def api_class_members(api_class: ApiClass) -> list[ApiMember]:
	members: list[ApiMember] = []
	members.extend(api_class.signals)
	members.extend(api_class.enums)
	members.extend(api_class.constants)
	members.extend(api_class.properties)
	members.extend(api_class.methods)
	return members


def is_reference_api_path(docs_root: Path, path: Path) -> bool:
	return path.relative_to(docs_root).as_posix().startswith("reference/api/")


def is_changelog_page(path: Path) -> bool:
	return "changelog" in path.name.lower() or "更新日志" in path.name


def module_sort_key(module: str) -> tuple[int, str]:
	if module == "kernel":
		return (0, module)
	if module == "standard":
		return (1, module)
	return (2, module)


def dedupe_non_empty(values: list[str]) -> list[str]:
	result: list[str] = []
	for value in values:
		if value and value not in result:
			result.append(value)
	return result


def relative_to_root(path: Path) -> str:
	try:
		return path.resolve().relative_to(ROOT).as_posix()
	except ValueError:
		return path.as_posix()


if __name__ == "__main__":
	raise SystemExit(main())
