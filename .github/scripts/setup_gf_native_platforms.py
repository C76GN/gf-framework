"""为 Linux 或 Apple 原生验收安装版本匹配的 Godot 编辑器与导出模板。"""
import os
from pathlib import Path
import subprocess
import sys
import zipfile

from setup_gf_native_windows import VERSION, TEMPLATES_SHA256, download, extract

EDITORS = {
    'linux': ('linux.x86_64', 'cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4'),
    'darwin': ('macos.universal', 'c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e'),
}


def main() -> None:
    """准备当前 CI 目标使用的 Godot 编辑器及其导出模板。"""
    tag, checksum = EDITORS[sys.platform]
    directory = Path(os.environ['RUNNER_TEMP']) / 'gf-native-editor'
    directory.mkdir(exist_ok=True)
    name = f'Godot_v{VERSION}_{tag}'
    editor = download(directory, name + '.zip', checksum)
    if sys.platform == 'darwin':
        subprocess.run(['ditto', '-x', '-k', str(editor), str(directory)], check=True)
        executable = directory / 'Godot.app/Contents/MacOS/Godot'
        data = Path.home() / 'Library/Application Support/Godot'
        templates = ['ios.zip']
    else:
        executable = directory / name
        with zipfile.ZipFile(editor) as archive:
            extract(archive, name, executable)
        executable.chmod(0o755)
        data = Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share') / 'godot'
        templates = ['linux_debug.x86_64', 'linux_release.x86_64', 'android_debug.apk', 'android_release.apk']
    destination = data / 'export_templates' / VERSION.replace('-', '.')
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(download(directory, f'Godot_v{VERSION}_export_templates.tpz', TEMPLATES_SHA256)) as archive:
        for template in [*templates, 'version.txt']:
            extract(archive, 'templates/' + template, destination / template)
    subprocess.run([str(executable), '--version'], check=True)
    with Path(os.environ['GITHUB_ENV']).open('a', encoding='utf-8') as stream:
        stream.write(f'GF_GODOT_EXECUTABLE={executable}\n')


if __name__ == '__main__':
    main()
