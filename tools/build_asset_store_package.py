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
MAX_PLUGIN_CONFIG_BYTES = 64 * 1024
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

	result = audit_package(output, expected_version=version)
	result["version"] = version
	result["workspace_plugin_version"] = plugin_version
	result["plugin_version"] = result.get("archive_plugin_version", "")
	print_result(result, args.json)
	return 0 if result["ok"] else 1


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="replace")


def read_plugin_version() -> str:
	try:
		config_text = (ROOT / "addons/gf/plugin.cfg").read_text(encoding="utf-8")
	except FileNotFoundError:
		return ""
	return _parse_plugin_version(config_text)


def _parse_plugin_version(config_text: str) -> str:
	config = configparser.ConfigParser(interpolation=None, delimiters=("=",))
	config.optionxform = str
	config.read_string(config_text)
	# Godot looks up exact section/key names and uses '=' assignments.
	# ConfigFile has no DEFAULT inheritance; release metadata must be explicit.
	config.defaults().clear()
	value = config.get("plugin", "version", fallback="").strip()
	if not value:
		return ""
	# Release versions use one literal string; numeric Variants, escapes and
	# extra declarations must not be certified as the original version text.
	match = re.fullmatch(r'"([^"\\\r\n]*)"', value)
	if match is None:
		raise ValueError("plugin.cfg version must be one quoted literal string")
	return match.group(1)


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


def audit_package(output: Path, *, expected_version: str = "") -> dict[str, Any]:
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
	archive_plugin_version = ""
	with zipfile.ZipFile(output, "r") as archive:
		names = sorted(name for name in archive.namelist() if name and not name.endswith("/"))
		plugin_path = "addons/gf/plugin.cfg"
		if names.count(plugin_path) != 1:
			issues.append("Package must contain exactly one addons/gf/plugin.cfg.")
		else:
			try:
				with archive.open(plugin_path) as stream:
					config_bytes = stream.read(MAX_PLUGIN_CONFIG_BYTES + 1)
				if len(config_bytes) > MAX_PLUGIN_CONFIG_BYTES:
					raise ValueError("plugin.cfg exceeds its read budget")
				archive_plugin_version = _parse_plugin_version(config_bytes.decode("utf-8", errors="strict"))
				if not archive_plugin_version:
					raise ValueError("plugin.cfg version is empty")
			except (configparser.Error, UnicodeError, ValueError, zipfile.BadZipFile) as error:
				issues.append(f"Package plugin.cfg is invalid: {error}.")
		if expected_version and archive_plugin_version != expected_version:
			issues.append(f"Package plugin.cfg version {archive_plugin_version!r} does not match expected version {expected_version!r}.")
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
		"archive_plugin_version": archive_plugin_version,
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
