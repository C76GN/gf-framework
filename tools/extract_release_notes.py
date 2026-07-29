#!/usr/bin/env python3
"""Extract GF release notes from docs/zh/changelog.md for a SemVer tag."""

from __future__ import annotations

import argparse
import configparser
import json
import os
import re
import sys
from pathlib import Path

import gf_changelog


SEMVER_RE = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
MARKDOWN_FIELD_RE = re.compile(r"^-\s+(?P<name>[^:]+):\s+`(?P<value>[^`]+)`\s*$")


def main() -> int:
	parser = argparse.ArgumentParser(
		description="Extract a version section from docs/zh/changelog.md and validate release metadata."
	)
	parser.add_argument("--tag", default=os.environ.get("GITHUB_REF_NAME", ""), help="Release tag, for example 3.5.0.")
	parser.add_argument("--changelog", default="docs/zh/changelog.md", help="Changelog path.")
	parser.add_argument("--output", required=True, help="Output release notes path.")
	parser.add_argument("--check-plugin", default="addons/gf/plugin.cfg", help="Godot plugin.cfg path.")
	parser.add_argument("--check-extensions", default="addons/gf/extensions", help="GF extensions root path.")
	parser.add_argument("--check-asset-library", default="ASSET_LIBRARY.md", help="Asset Library metadata path.")
	parser.add_argument("--check-asset-store", default="ASSET_STORE.md", help="Asset Store metadata path.")
	args = parser.parse_args()

	tag = normalize_tag(args.tag)
	plugin_version = read_plugin_version(Path(args.check_plugin))
	if plugin_version != tag:
		raise SystemExit(f"plugin.cfg version {plugin_version!r} does not match tag {tag!r}.")

	check_extension_versions(Path(args.check_extensions), tag)
	check_asset_library(Path(args.check_asset_library), tag)
	check_asset_store(Path(args.check_asset_store), tag)

	notes = extract_release_notes(Path(args.changelog), tag)
	output_path = Path(args.output)
	output_path.parent.mkdir(parents=True, exist_ok=True)
	output_path.write_text(notes + "\n", encoding="utf-8", newline="\n")
	return 0


def normalize_tag(raw_tag: str) -> str:
	tag = raw_tag.strip()
	if tag.startswith("refs/tags/"):
		tag = tag.removeprefix("refs/tags/")
	if not tag:
		raise SystemExit("Release tag is empty.")
	if tag.startswith(("v", "V")):
		raise SystemExit(f"Release tag {tag!r} must not use a leading v.")
	if SEMVER_RE.match(tag) is None:
		raise SystemExit(f"Release tag {tag!r} must use MAJOR.MINOR.PATCH, for example 3.5.0.")
	return tag


def read_plugin_version(path: Path) -> str:
	if not path.exists():
		raise SystemExit(f"plugin.cfg not found: {path}")
	config = configparser.ConfigParser()
	config.read(path, encoding="utf-8")
	if not config.has_section("plugin") or not config.has_option("plugin", "version"):
		raise SystemExit(f"plugin.cfg is missing [plugin] version: {path}")
	return strip_quotes(config.get("plugin", "version").strip())


def check_extension_versions(root: Path, version: str) -> None:
	if not root.exists():
		raise SystemExit(f"Extension root not found: {root}")
	mismatches: list[str] = []
	manifest_paths = sorted(root.glob("*/gf_extension.json"))
	if not manifest_paths:
		raise SystemExit(f"No extension manifests found under {root}.")
	for manifest_path in manifest_paths:
		data = json.loads(manifest_path.read_text(encoding="utf-8"))
		manifest_version = str(data.get("version", "")).strip()
		if manifest_version != version:
			mismatches.append(f"{manifest_path}: version {manifest_version!r}")
	if mismatches:
		raise SystemExit("Extension manifest versions do not match tag:\n" + "\n".join(mismatches))


def check_asset_library(path: Path, version: str) -> None:
	if not path.exists():
		raise SystemExit(f"Asset Library metadata not found: {path}")
	fields = read_markdown_fields(path)
	for field_name in ("Asset Version", "Download Commit/URL"):
		value = fields.get(field_name, "")
		if value != version:
			raise SystemExit(f"ASSET_LIBRARY.md {field_name} {value!r} does not match tag {version!r}.")


def check_asset_store(path: Path, version: str) -> None:
	if not path.exists():
		raise SystemExit(f"Asset Store metadata not found: {path}")
	fields = read_markdown_fields(path)
	for field_name in ("Current release version", "Release tag"):
		value = fields.get(field_name, "")
		if value != version:
			raise SystemExit(f"ASSET_STORE.md {field_name} {value!r} does not match tag {version!r}.")
	tags = read_comma_separated_fenced_field(path, "Tags")
	if not tags or len(tags) > 5:
		raise SystemExit("ASSET_STORE.md Tags must contain 1 to 5 tags.")
	if fields.get("Self disclose AI usage", "").lower() == "enabled" and not read_fenced_field(path, "AI disclose reason").strip():
		raise SystemExit("ASSET_STORE.md AI disclose reason is empty while AI usage disclosure is enabled.")


def read_markdown_fields(path: Path) -> dict[str, str]:
	fields: dict[str, str] = {}
	for line in path.read_text(encoding="utf-8").splitlines():
		match = MARKDOWN_FIELD_RE.match(line)
		if match:
			fields[match.group("name")] = match.group("value").strip()
	return fields


def read_comma_separated_fenced_field(path: Path, field_name: str) -> list[str]:
	text = read_fenced_field(path, field_name)
	values: list[str] = []
	for item in re.split(r"[,\n]", text):
		value = item.strip()
		if value:
			values.append(value)
	return values


def read_fenced_field(path: Path, field_name: str) -> str:
	lines = path.read_text(encoding="utf-8").splitlines()
	marker = f"- {field_name}:"
	for index, line in enumerate(lines):
		if line.strip() != marker:
			continue
		fence_start = -1
		for candidate_index in range(index + 1, len(lines)):
			if lines[candidate_index].strip().startswith("```"):
				fence_start = candidate_index
				break
		if fence_start < 0:
			return ""
		for candidate_index in range(fence_start + 1, len(lines)):
			if lines[candidate_index].strip().startswith("```"):
				return "\n".join(lines[fence_start + 1:candidate_index]).strip()
		return ""
	return ""


def extract_release_notes(path: Path, version: str) -> str:
	if not path.exists():
		raise SystemExit(f"Changelog not found: {path}")
	text = path.read_text(encoding="utf-8")
	syntax_issues = gf_changelog.markdown_syntax_issues(text)
	if syntax_issues:
		raise SystemExit(
			f"Changelog contains unsupported Markdown syntax in {path}:\n"
			+ "\n".join(syntax_issues)
		)
	sections = gf_changelog.parse_changelog_sections(text)
	matching_sections = [
		section
		for section in sections
		if str(section["version"]) == version
	]
	if not matching_sections:
		raise SystemExit(f"Changelog section for [{version}] was not found in {path}.")
	if len(matching_sections) != 1:
		raise SystemExit(
			f"Changelog must contain exactly one section for [{version}] in {path}; "
			f"found {len(matching_sections)}."
		)
	contract_issues = gf_changelog.validate_document_layout(
		text,
		str(matching_sections[0]["heading"]),
		str(path),
	)
	contract_issues.extend(
		gf_changelog.validate_formal_section(
			matching_sections[0],
			str(path),
		)
	)
	if contract_issues:
		raise SystemExit(
			f"Changelog release candidate is invalid in {path}:\n"
			+ "\n".join(contract_issues)
		)

	section = str(matching_sections[0]["body"]).strip()
	if not section:
		raise SystemExit(f"Changelog section for [{version}] is empty.")
	return section


def strip_quotes(value: str) -> str:
	if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", "\""}:
		return value[1:-1]
	return value


if __name__ == "__main__":
	sys.exit(main())
