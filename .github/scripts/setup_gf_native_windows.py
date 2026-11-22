"""Provision the compiler and verified Windows editor/templates used to qualify GF release ZIPs."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tomllib
import zipfile


VERSION = "4.7.2-stable"
EDITOR = f"Godot_v{VERSION}_win64.exe"
EDITOR_SHA256 = "731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953"
TEMPLATES_SHA256 = "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011"


def download(directory: Path, filename: str, expected: str) -> Path:
    path = directory / filename
    url = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}/{filename}"
    subprocess.run(["curl.exe" if os.name == "nt" else "curl", "--fail", "--silent", "--show-error", "--location", "--retry", "3",
                    "--max-time", "600", "--output", str(path), url], check=True, timeout=900)
    with path.open("rb") as stream:
        if hashlib.file_digest(stream, "sha256").hexdigest() != expected:
            raise ValueError(f"Unexpected SHA-256 for {filename}")
    return path


def extract(archive: zipfile.ZipFile, member: str, target: Path) -> None:
    with archive.open(member) as source, target.open("wb") as output:
        shutil.copyfileobj(source, output)


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    toolchain = tomllib.loads((root / "native/gf_native/rust-toolchain.toml").read_text(encoding="utf-8"))["toolchain"]
    subprocess.run(["rustup", "toolchain", "install", toolchain["channel"], "--profile", toolchain["profile"],
                    "--component", ",".join(toolchain["components"])], check=True, timeout=600)
    directory = Path(os.environ["RUNNER_TEMP"]) / "gf-native-godot"
    directory.mkdir(exist_ok=True)
    with zipfile.ZipFile(download(directory, EDITOR + ".zip", EDITOR_SHA256)) as archive:
        extract(archive, EDITOR, directory / EDITOR)
    target = Path(os.environ["APPDATA"]) / "Godot/export_templates" / VERSION.replace("-", ".")
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(download(directory, f"Godot_v{VERSION}_export_templates.tpz", TEMPLATES_SHA256)) as archive:
        for profile in ("debug", "release"):
            for suffix in ("", "_console"):
                name = f"windows_{profile}_x86_64{suffix}.exe"
                extract(archive, "templates/" + name, target / name)
        extract(archive, "templates/version.txt", target / "version.txt")
    with Path(os.environ["GITHUB_ENV"]).open("a", encoding="utf-8") as stream:
        stream.write(f"GF_GODOT_EXECUTABLE={directory / EDITOR}\n")


if __name__ == "__main__":
    main()
