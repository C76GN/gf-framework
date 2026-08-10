#!/usr/bin/env python3
"""Build the GF Asset Store package with addons/gf at the zip root."""

from __future__ import annotations

import argparse
import configparser
import json
import posixpath
import re
import sys
import urllib.parse
import zipfile
from pathlib import Path
from typing import Any

import gf_path_security


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "addons/gf"
BLOCKED_DIR_NAMES = {".git", ".godot", ".import", ".vs", "__pycache__", "node_modules"}
BLOCKED_FILE_NAMES = {".DS_Store", "Thumbs.db"}
BLOCKED_SUFFIXES = {".import", ".pyc", ".pyo", ".tmp", ".log"}
REQUIRED_PACKAGE_PATHS = (
	"addons/gf/plugin.cfg",
	"addons/gf/plugin.gd",
	"addons/gf/README.md",
	"addons/gf/LICENSE.md",
	"addons/gf/icon.png",
)
ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)
MAX_SOURCE_FILE_BYTES = (1 << 63) - 1
README_LINK_RE = re.compile(r"(?<!!)\[[^\]]+\]\(([^)\s]+)(?:\s+[^)]*)?\)")
ALLOWED_README_LINK_HOSTS = {
	"gf-framework.readthedocs.io",
	"github.com",
}


def main() -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(description="Build the GF Asset Store addon zip.")
	parser.add_argument("--version", default="", help="Expected package version. Defaults to addons/gf/plugin.cfg.")
	parser.add_argument("--output", default="", help="Output zip path. Defaults to build/gf-framework-<version>.zip.")
	parser.add_argument("--validate-only", action="store_true", help="Validate an existing --output zip without rebuilding it.")
	parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	args = parser.parse_args()

	plugin_version = read_plugin_version()
	version = args.version.strip() or plugin_version
	if version != plugin_version:
		result = {
			"ok": False,
			"version": version,
			"plugin_version": plugin_version,
			"output": "",
			"issues": [f"Requested version {version!r} does not match addons/gf/plugin.cfg version {plugin_version!r}."],
		}
		print_result(result, args.json)
		return 1

	output = resolve_output_path(args.output, version)
	if not args.validate_only:
		build_package(output)

	result = audit_package(output)
	result["version"] = version
	result["plugin_version"] = plugin_version
	print_result(result, args.json)
	return 0 if result["ok"] else 1


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="replace")


def read_plugin_version() -> str:
	config = configparser.ConfigParser()
	config.read(ROOT / "addons/gf/plugin.cfg", encoding="utf-8")
	if not config.has_section("plugin"):
		return ""
	value = config.get("plugin", "version", fallback="").strip()
	if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
		return value[1:-1]
	return value


def resolve_output_path(output: str, version: str) -> Path:
	path = Path(output) if output else Path("build") / f"gf-framework-{version}.zip"
	if not path.is_absolute():
		path = ROOT / path
	return path


def build_package(output: Path) -> None:
	output.parent.mkdir(parents=True, exist_ok=True)
	if output.exists():
		output.unlink()
	try:
		with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
			for path in iter_package_files():
				write_file(archive, path)
	except BaseException:
		try:
			output.unlink(missing_ok=True)
		except OSError:
			pass
		raise


def iter_package_files() -> list[Path]:
	if (
		not gf_path_security.path_is_inside_lexical(ROOT, ADDON_ROOT)
		or gf_path_security.path_has_reparse_component(ADDON_ROOT)
		or not ADDON_ROOT.is_dir()
	):
		raise OSError("Asset Store source root is missing, linked, or outside the repository root.")
	files: list[Path] = []
	for path in ADDON_ROOT.rglob("*"):
		if gf_path_security.path_has_reparse_component(path):
			raise OSError(
				"Asset Store source crosses a symlink, junction, or reparse point: "
				f"{path.relative_to(ROOT).as_posix()}"
			)
		if not path.is_file():
			continue
		if is_blocked_path(path):
			continue
		files.append(path)
	return sorted(files, key=lambda item: item.relative_to(ROOT).as_posix())


def is_blocked_path(path: Path) -> bool:
	relative_parts = path.relative_to(ROOT).parts
	if any(part in BLOCKED_DIR_NAMES for part in relative_parts):
		return True
	if path.name in BLOCKED_FILE_NAMES:
		return True
	return path.suffix in BLOCKED_SUFFIXES


def write_file(archive: zipfile.ZipFile, path: Path) -> None:
	archive_path = path.relative_to(ROOT).as_posix()
	info = zipfile.ZipInfo(archive_path, ZIP_TIMESTAMP)
	info.compress_type = zipfile.ZIP_DEFLATED
	info.external_attr = 0o644 << 16
	archive.writestr(info, read_package_source_bytes(path))


def read_package_source_bytes(path: Path) -> bytes:
	try:
		relative_path = path.relative_to(ROOT).as_posix()
	except ValueError:
		raise OSError("Asset Store source is outside the repository root.") from None
	try:
		return gf_path_security.read_pinned_regular_file(
			ROOT,
			relative_path,
			max_bytes=MAX_SOURCE_FILE_BYTES,
		)
	except gf_path_security.PinnedReadError as error:
		raise OSError(f"Asset Store source is not a stable contained regular file: {error.rule_id}") from None


def audit_package(output: Path) -> dict[str, Any]:
	issues: list[str] = []
	if not output.is_file():
		return {
			"ok": False,
			"output": output.as_posix(),
			"file_count": 0,
			"size_bytes": 0,
			"top_level_entries": [],
			"issues": [f"Package zip was not found: {output.as_posix()}"],
		}

	readme_text = ""
	with zipfile.ZipFile(output, "r") as archive:
		names = sorted(name for name in archive.namelist() if name and not name.endswith("/"))
		if "addons/gf/README.md" in names:
			try:
				readme_text = archive.read("addons/gf/README.md").decode("utf-8", errors="strict")
			except (KeyError, UnicodeDecodeError):
				issues.append("Package README must be valid UTF-8.")

	top_level_entries = sorted({name.split("/", 1)[0] for name in names})
	if top_level_entries != ["addons"]:
		issues.append("Package root must contain only addons/, without a repository or version wrapper directory.")

	for name in names:
		if not name.startswith("addons/gf/"):
			issues.append(f"Package entry is outside addons/gf: {name}")
		parts = name.split("/")
		if any(part in BLOCKED_DIR_NAMES for part in parts):
			issues.append(f"Package entry contains blocked directory: {name}")
		if Path(name).name in BLOCKED_FILE_NAMES or Path(name).suffix in BLOCKED_SUFFIXES:
			issues.append(f"Package entry contains blocked generated file: {name}")

	for required_path in REQUIRED_PACKAGE_PATHS:
		if required_path not in names:
			issues.append(f"Package is missing required file: {required_path}")
	if readme_text:
		issues.extend(audit_readme_links(readme_text, set(names)))

	return {
		"ok": len(issues) == 0,
		"output": output.relative_to(ROOT).as_posix() if output.is_relative_to(ROOT) else output.as_posix(),
		"file_count": len(names),
		"size_bytes": output.stat().st_size,
		"top_level_entries": top_level_entries,
		"issues": issues,
	}


def audit_readme_links(readme_text: str, package_names: set[str]) -> list[str]:
	issues: list[str] = []
	for raw_target in README_LINK_RE.findall(readme_text):
		target = raw_target.strip()
		if not target or target.startswith("#"):
			continue
		parsed = urllib.parse.urlsplit(target)
		if parsed.scheme:
			if parsed.scheme != "https" or (parsed.hostname or "").lower() not in ALLOWED_README_LINK_HOSTS:
				issues.append(f"Package README link must use an allowed HTTPS host: {target}")
			continue
		if parsed.netloc or "\\" in target or "\0" in target or parsed.path.startswith("/"):
			issues.append(f"Package README link is outside the distributable addon: {target}")
			continue
		decoded_path = urllib.parse.unquote(parsed.path)
		resolved = posixpath.normpath(posixpath.join("addons/gf", decoded_path))
		if not resolved.startswith("addons/gf/") or resolved not in package_names:
			issues.append(f"Package README link is outside or missing from the distributable addon: {target}")
	return issues


def print_result(result: dict[str, Any], as_json: bool) -> None:
	if as_json:
		print(json.dumps(result, ensure_ascii=False, indent=2))
		return
	print(f"ok={result['ok']} version={result.get('version', '')} output={result.get('output', '')}")
	print(f"files={result.get('file_count', 0)} size={result.get('size_bytes', 0)} top={result.get('top_level_entries', [])}")
	if result.get("issues"):
		print("issues:")
		for issue in result["issues"]:
			print(f"- {issue}")


if __name__ == "__main__":
	raise SystemExit(main())
