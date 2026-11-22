"""Add the matching arm64 simulator libraries to a copy of Godot's official iOS export template."""
import argparse
import copy
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile


def prepare(template: Path, libraries: Path, output: Path) -> None:
    if output.resolve() == template.resolve():
        raise ValueError("Choose a new template path for the simulator.")
    members = {
        f"{name}.ios.{profile}.xcframework/ios-arm64_x86_64-simulator/{name}.a":
        libraries / f"{name}.ios.template_{profile}.arm64.simulator.a"
        for profile in ("debug", "release") for name in ("libgodot", "libgodot_camera")
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent) as temporary, zipfile.ZipFile(template) as source:
        directory = Path(temporary)
        candidate = directory / "ios.zip"
        for member in members:
            if source.namelist().count(member) != 1:
                raise ValueError(f"Missing or duplicate simulator library: {member}")
        with zipfile.ZipFile(candidate, "w") as destination:
            for entry in source.infolist():
                with source.open(entry) as original, destination.open(copy.copy(entry), "w") as target:
                    if entry.filename not in members:
                        shutil.copyfileobj(original, target)
                        continue
                    intel = directory / "original.a"
                    universal = directory / "universal.a"
                    with intel.open("wb") as stream:
                        shutil.copyfileobj(original, stream)
                    apple = members[entry.filename]
                    subprocess.run(["xcrun", "lipo", "-verify_arch", "arm64", str(apple)], check=True)
                    subprocess.run(["xcrun", "lipo", "-create", str(intel), str(apple), "-output", str(universal)], check=True)
                    subprocess.run(["xcrun", "lipo", "-verify_arch", "arm64", "x86_64", str(universal)], check=True)
                    with universal.open("rb") as stream:
                        shutil.copyfileobj(stream, target)
        candidate.replace(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", required=True, type=Path)
    parser.add_argument("--libraries", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    prepare(args.template, args.libraries, args.output)
