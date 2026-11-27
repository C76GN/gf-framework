"""Package the optional Godot materials independently of the GF addon."""

from __future__ import annotations

import argparse
import tempfile
import zipfile
from pathlib import Path

import build_asset_store_package as addon_package


SOURCE_ROOT = addon_package.ROOT / "libraries/ui_motion"
INSTALL_ROOT = "addons/gf_ui_motion_assets"


def archive_name(version: str) -> str:
	return f"gf-ui-motion-assets-{version}.zip"


def archive_sources() -> dict[str, Path]:
	"""Map installed names to the original, individually selectable effect directories."""
	files = {
		f"{INSTALL_ROOT}/{path.relative_to(SOURCE_ROOT).as_posix()}": path
		for path in addon_package.iter_package_files(SOURCE_ROOT)
	}
	files[f"{INSTALL_ROOT}/LICENSE.md"] = addon_package.ROOT / "LICENSE.md"
	return files


def build_archive(output: Path) -> None:
	output.parent.mkdir(parents=True, exist_ok=True)
	with tempfile.TemporaryDirectory(dir=output.parent) as temporary:
		candidate = Path(temporary) / output.name
		with zipfile.ZipFile(candidate, "w", compression=zipfile.ZIP_DEFLATED) as archive:
			for name, path in sorted(archive_sources().items()):
				addon_package.write_file(archive, path, name)
		candidate.replace(output)


if __name__ == "__main__":
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--output", type=Path, help="Output ZIP. Defaults to build/ in the repository.")
	args = parser.parse_args()
	output = args.output or addon_package.ROOT / "build" / archive_name(addon_package.read_plugin_version())
	build_archive(output)
	print(output.resolve())
