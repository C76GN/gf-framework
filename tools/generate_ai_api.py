#!/usr/bin/env python3
"""Generate a compact AI-facing API index for GF GDScript files."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

from gdscript_api_parser import ApiDocs
from gdscript_api_parser import ApiMember
from gdscript_api_parser import ApiScript
from gdscript_api_parser import collect_api_scripts


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
	parser = argparse.ArgumentParser(description="Generate GF AI API docs.")
	parser.add_argument("--source", default="addons/gf", help="GDScript source root.")
	parser.add_argument("--output", default="ai_analysis/generated_api", help="Output directory.")
	parser.add_argument("--check", action="store_true", help="Fail if existing generated files are stale.")
	parser.add_argument("--wiki", default="docs/zh", help="Documentation root used by --check-wiki-coverage.")
	parser.add_argument(
		"--check-wiki-coverage",
		action="store_true",
		help="Fail if public class_name entries are not mentioned in non-changelog documentation pages.",
	)
	args = parser.parse_args()

	source_root = (ROOT / args.source).resolve()
	output_dir = (ROOT / args.output).resolve()
	if not source_root.exists():
		print(f"source root not found: {source_root}", file=sys.stderr)
		return 2

	api_files = collect_api(source_root)
	desired = render_outputs(api_files, source_root)
	coverage_status = 0
	if args.check_wiki_coverage:
		coverage_status = check_wiki_coverage(api_files, (ROOT / args.wiki).resolve())
	if args.check:
		check_status = check_outputs(output_dir, desired)
		return max(check_status, coverage_status)

	write_outputs(output_dir, desired)
	class_count = sum(1 for item in api_files if item.class_name)
	method_count = sum(len(item.methods) for item in api_files)
	print(f"generated {len(api_files)} files, {class_count} classes, {method_count} public methods")
	print(f"output: {output_dir}")
	return coverage_status


def collect_api(source_root: Path) -> list[ApiScript]:
	return collect_api_scripts(source_root, ROOT)


def render_outputs(api_files: list[ApiScript], source_root: Path) -> dict[str, str]:
	files_payload = [api_file_to_dict(item) for item in api_files]
	source_digest = hashlib.sha256(
		json.dumps(files_payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
	).hexdigest()
	payload = {
		"source_digest": source_digest,
		"source_root": source_root.relative_to(ROOT).as_posix(),
		"file_count": len(api_files),
		"class_count": sum(1 for item in api_files if item.class_name),
		"public_method_count": sum(len(item.methods) for item in api_files),
		"files": files_payload,
	}
	outputs = {
		"api.json": json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
		"index.md": render_index(api_files, payload),
	}
	for module in sorted({item.module for item in api_files}):
		module_files = [item for item in api_files if item.module == module]
		outputs[f"modules/{safe_file_name(module)}.md"] = render_module(module, module_files)
	return outputs


def api_file_to_dict(api_file: ApiScript) -> dict[str, Any]:
	return {
		"path": api_file.path,
		"module": api_file.module,
		"class_name": api_file.class_name,
		"extends": api_file.extends,
		"summary": docs_to_ai_lines(api_file.docs),
		"signals": [api_item_to_dict(item) for item in api_file.signals],
		"enums": [api_item_to_dict(item) for item in api_file.enums],
		"constants": [api_item_to_dict(item) for item in api_file.constants],
		"variables": [api_item_to_dict(item) for item in api_file.properties],
		"methods": [api_item_to_dict(item) for item in api_file.methods],
	}


def api_item_to_dict(item: ApiMember) -> dict[str, Any]:
	return {
		"kind": ai_member_kind(item),
		"name": item.name,
		"signature": item.signature,
		"line": item.line,
		"docs": docs_to_ai_lines(item.docs),
		"decorators": item.decorators,
	}


def ai_member_kind(item: ApiMember) -> str:
	if item.kind == "property":
		return "var"
	if item.kind == "method":
		return "func"
	return item.kind


def docs_to_ai_lines(docs: ApiDocs) -> list[str]:
	lines = docs.description[:]
	for tag_name in sorted(docs.tags):
		for value in docs.tags[tag_name]:
			lines.append(f"@{tag_name} {value}".strip())
	return lines


def render_index(api_files: list[ApiScript], payload: dict[str, Any]) -> str:
	lines = [
		"# GF AI API Index",
		"",
		f"source_digest: {payload['source_digest']}",
		f"source_root: {payload['source_root']}",
		f"file_count: {payload['file_count']}",
		f"class_count: {payload['class_count']}",
		f"public_method_count: {payload['public_method_count']}",
		"",
		"## Modules",
		"",
	]
	for module in sorted({item.module for item in api_files}):
		module_files = [item for item in api_files if item.module == module]
		lines.append(f"- {module}: {len(module_files)} files -> modules/{safe_file_name(module)}.md")
	lines.extend(["", "## Classes", ""])
	for item in api_files:
		display_name = item.class_name or Path(item.path).name
		lines.append(f"- {display_name} | {item.extends} | {item.module} | {item.path}")
	return "\n".join(lines) + "\n"


def render_module(module: str, api_files: list[ApiScript]) -> str:
	lines = [f"# Module {module}", ""]
	for api_file in api_files:
		title = api_file.class_name or Path(api_file.path).name
		lines.extend([
			f"## {title}",
			f"path: {api_file.path}",
			f"extends: {api_file.extends}",
			f"summary: {' '.join(docs_to_ai_lines(api_file.docs))}",
			"",
		])
		append_items(lines, "signals", api_file.signals)
		append_items(lines, "enums", api_file.enums)
		append_items(lines, "constants", api_file.constants)
		append_items(lines, "variables", api_file.properties)
		append_items(lines, "methods", api_file.methods)
	return "\n".join(lines) + "\n"


def append_items(lines: list[str], title: str, items: list[ApiMember]) -> None:
	lines.append(f"### {title}")
	if not items:
		lines.extend(["- none", ""])
		return
	for item in items:
		docs = " ".join(docs_to_ai_lines(item.docs))
		decorators = " ".join(item.decorators)
		prefix = f"{decorators} " if decorators else ""
		lines.append(f"- line {item.line}: `{prefix}{item.signature}`")
		if docs:
			lines.append(f"  docs: {docs}")
	lines.append("")


def safe_file_name(module: str) -> str:
	return module.replace("/", "__").replace("\\", "__")


def write_outputs(output_dir: Path, desired: dict[str, str]) -> None:
	(output_dir / "modules").mkdir(parents=True, exist_ok=True)
	for old_file in (output_dir / "modules").glob("*.md"):
		old_file.unlink()
	for relative, content in desired.items():
		path = output_dir / relative
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(content, encoding="utf-8", newline="\n")


def check_outputs(output_dir: Path, desired: dict[str, str]) -> int:
	mismatches: list[str] = []
	for relative, content in desired.items():
		path = output_dir / relative
		if not path.exists():
			mismatches.append(f"missing: {relative}")
			continue
		if path.read_text(encoding="utf-8") != content:
			mismatches.append(f"stale: {relative}")
	existing = {
		path.relative_to(output_dir).as_posix()
		for path in output_dir.rglob("*")
		if path.is_file()
	}
	expected = set(desired.keys())
	for extra in sorted(existing - expected):
		mismatches.append(f"extra: {extra}")
	if mismatches:
		print("AI API docs are stale:")
		for mismatch in mismatches:
			print(f"- {mismatch}")
		return 1
	print("AI API docs are current.")
	return 0


def check_wiki_coverage(api_files: list[ApiScript], wiki_root: Path) -> int:
	if not wiki_root.exists():
		print(f"documentation root not found: {wiki_root}", file=sys.stderr)
		return 2

	doc_text_parts: list[str] = []
	for path in sorted(wiki_root.rglob("*.md")):
		if is_changelog_page(path) or is_reference_api_page(wiki_root, path):
			continue
		doc_text_parts.append(path.read_text(encoding="utf-8"))
	doc_text = "\n".join(doc_text_parts)

	missing: list[ApiScript] = []
	checked_count = 0
	for api_file in api_files:
		if not api_file.class_name:
			continue
		checked_count += 1
		if api_file.class_name not in doc_text:
			missing.append(api_file)

	if missing:
		print("Documentation coverage is missing public class entries:")
		for api_file in missing:
			print(f"- {api_file.module} | {api_file.class_name} | {api_file.path}")
		return 1

	print(f"Documentation coverage is complete: {checked_count} public classes mentioned outside changelog.")
	return 0


def is_changelog_page(path: Path) -> bool:
	name = path.name.lower()
	return "changelog" in name or "更新日志" in name


def is_reference_api_page(wiki_root: Path, path: Path) -> bool:
	try:
		relative = path.relative_to(wiki_root).as_posix()
	except ValueError:
		return False
	return relative.startswith("reference/api/")


if __name__ == "__main__":
	raise SystemExit(main())
