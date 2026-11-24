"""Build GF Native once and exercise the installable archives in isolated Windows projects."""
from __future__ import annotations

import argparse
from dataclasses import asdict
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import time
import re
import tomllib
import zipfile

import build_asset_store_package
import gf_extension_export_acceptance
from gf_extension_export_check import export_policy_error
import gf_native_distribution as dist
from gf_godot_process import resolve_godot_executable
from gf_process_supervisor import run_supervised_process

ROOT = Path(__file__).resolve().parents[1]
CRATE = dist.CRATE
EXTENSION = Path(dist.ADDON) / dist.LOADER


def parse_acceptance(output: str) -> dict:
    """Accept exactly one complete differential report, never a stray success marker."""
    reports = [json.loads(line.split('=', 1)[1]) for line in output.splitlines()
               if line.startswith('GF_NATIVE_DATA_BATCH=')]
    if len(reports) != 1 or not isinstance(reports[0], dict):
        raise RuntimeError('Expected exactly one native acceptance report.')
    report = reports[0]
    if report.get('ok') is not True or report.get('failures') != []:
        raise RuntimeError('Native differential acceptance failed.')
    samples = report.get('samples')
    if not isinstance(samples, list) or len(samples) != 3:
        raise RuntimeError('Missing native performance cases.')
    for sample, rows in zip(samples, (16, 1000, 100000), strict=True):
        if (not isinstance(sample, dict) or sample.get('source_rows') != rows
                or sample.get('selected_rows') != rows // 2 or sample.get('int64_columns') != 4):
            raise RuntimeError('Native benchmark shape changed.')
        require_timings(sample, ('script_usec', 'native_usec'), 10)
    matches = report.get('row_match_samples')
    shapes = [(rows, reordered) for rows in (16, 4096, 65536) for reordered in (False, True)]
    if not isinstance(matches, list) or len(matches) != len(shapes):
        raise RuntimeError('Missing row-match performance cases.')
    for sample, (rows, reordered) in zip(matches, shapes, strict=True):
        if (not isinstance(sample, dict) or sample.get('rows') != rows or sample.get('reordered') is not reordered
                or type(sample.get('calls_per_sample')) is not int or sample['calls_per_sample'] != (64 if rows == 16 else 1)):
            raise RuntimeError('Row-match benchmark shape changed.')
        require_timings(sample, ('script_usec', 'automatic_usec'), 9)
    return report


def require_timings(sample: dict, fields: tuple[str, str], count: int) -> None:
    for field in fields:
        values = sample.get(field)
        if (not isinstance(values, list) or len(values) != count
                or any(type(value) is not int or value < 0 for value in values)):
            raise RuntimeError('Incomplete native timing samples.')


def file_digest(path: Path, deadline: float) -> str:
    """Read bounded file chunks and reject deadline expiry or identity drift."""
    digest = hashlib.sha256()
    before = path.stat()
    if before.st_size > 64 * 1024 * 1024:
        raise RuntimeError(f'Acceptance input is too large: {path}')
    with path.open('rb') as stream:
        opened = os.fstat(stream.fileno())
        if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (
                opened.st_dev, opened.st_ino, opened.st_size, opened.st_mtime_ns):
            raise RuntimeError(f'Acceptance input changed before read: {path}')
        while True:
            if time.monotonic() >= deadline:
                raise RuntimeError('Acceptance digest exhausted its overall deadline.')
            chunk = stream.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    after = path.stat()
    if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (
            after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
        raise RuntimeError(f'Acceptance input changed during read: {path}')
    return digest.hexdigest()


def source_digest(deadline: float) -> str:
    """Bind native results to the exact runtime, crate, fixture and runner bytes."""
    paths = [*(CRATE / name for name in ('Cargo.toml', 'Cargo.lock', 'build.rs', '.cargo/config.toml', 'rust-toolchain.toml',
                                       EXTENSION.name, 'THIRD_PARTY_NOTICES.txt', '.gdignore')),
             ROOT / 'addons/gf/standard/foundation/math/gf_heightfield_3d.gd',
             ROOT / 'addons/gf/standard/foundation/math/gf_wave_function_collapse_2d.gd',
             ROOT / 'addons/gf/standard/foundation/deterministic/gf_deterministic_random.gd',
             ROOT / 'addons/gf/standard/foundation/variant/gf_variant_data.gd',
             ROOT / 'addons/gf/kernel/core/gf_variant_access.gd',
             *CRATE.glob('src/**/*.rs'), *ROOT.glob('addons/gf/extensions/data_batch/runtime/*.gd'),
             *ROOT.glob('tests/native/**/*.gd'),
             *ROOT.glob('tests/native/test_*.py'), ROOT / 'LICENSE.md',
             ROOT / 'tools/gf_native_acceptance.py', ROOT / 'tools/gf_native_distribution.py',
             ROOT / 'tools/gf_extension_export_acceptance.py', ROOT / 'tools/gf_extension_export_check.py']
    digest = hashlib.sha256()
    for path in sorted(paths):
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(b'\0')
        digest.update(file_digest(path, deadline).encode())
        digest.update(b'\0')
    return digest.hexdigest()


def run(command: list[str], cwd: Path, name: str, timeout: float, logs: Path,
        deadline: float) -> str:
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise RuntimeError('Native acceptance exhausted its overall deadline.')
    result = run_supervised_process(
        command, cwd=cwd, environment=dict(os.environ), timeout_seconds=min(timeout, remaining),
        max_stdout_characters=300_000, max_stderr_characters=100_000,
    )
    (logs / f'{name}.stdout.log').write_text(result.stdout, encoding='utf-8')
    (logs / f'{name}.stderr.log').write_text(result.stderr, encoding='utf-8')
    metadata = asdict(result)
    metadata.pop('stdout', None)
    metadata.pop('stderr', None)
    (logs / f'{name}.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    if (result.return_code or result.timed_out or result.cancelled or not result.process_boundary_quiescent
            or result.stdout_truncated or result.stderr_truncated):
        raise RuntimeError(f'{name} failed; see {logs}')
    combined = re.sub(r'\x1b\[[0-9;]*m', '', result.stdout + '\n' + result.stderr)
    check_engine_diagnostics(combined, name, logs)
    return result.stdout


def check_engine_diagnostics(output: str, name: str, logs: Path) -> None:
    if re.search(r'(?m)^(?:SCRIPT ERROR|ERROR|WARNING):|Parse Error|ObjectDB instances leaked|panicked at', output):
        raise RuntimeError(f'{name} reported an engine/compiler diagnostic; see {logs}')


def run_fresh_import(godot: str, workspace: Path, logs: Path, deadline: float) -> None:
    """Require successful first discovery by Godot in a project with no import cache."""
    cache = workspace / '.godot'
    if cache.exists():
        raise RuntimeError('Fresh import requires a project without a .godot cache.')
    run([godot, '--headless', '--path', str(workspace), '--import'], workspace, 'import', 120, logs, deadline)
    registry = cache / 'extension_list.cfg'
    expected = 'res://' + EXTENSION.as_posix()
    if not registry.is_file() or registry.read_text(encoding='utf-8').splitlines() != [expected]:
        raise RuntimeError(f'First import did not register the fixture extension: {expected}')


def prepare_project(workspace: Path, *, standard_only: bool = False, platform_token: str = '') -> None:
    workspace.mkdir()
    for capability in ('terrain_rgb', 'wfc_entropy'):
        fixture = Path('tests/native') / capability / 'acceptance.gd'
        (workspace / fixture).parent.mkdir(parents=True)
        shutil.copy2(ROOT / fixture, workspace / fixture)
    if standard_only:
        shutil.copy2(ROOT / 'tests/native/standard_only.gd', workspace / 'acceptance.gd')
    else:
        fixture = ROOT / 'tests/native/packed_gather'
        shutil.copy2(fixture / 'acceptance.gd', workspace / 'acceptance.gd')
        shutil.copy2(fixture / 'selection.gd', workspace / 'selection.gd')
        row_match = Path('tests/native/row_match/acceptance.gd')
        (workspace / row_match).parent.mkdir(parents=True)
        shutil.copy2(ROOT / row_match, workspace / row_match)
    enabled = '[]' if standard_only else '["gf.data_batch"]'
    (workspace / 'project.godot').write_text(
        'config_version=5\n[application]\nconfig/name="GF native acceptance"\nrun/main_scene="res://main.tscn"\n'
        'run/flush_stdout_on_print=true\nconfig/icon="res://addons/gf/icon.png"\n[autoload]\nGf="*res://addons/gf/kernel/core/gf.gd"\n'
        '[editor_plugins]\nenabled=PackedStringArray("res://addons/gf/plugin.cfg")\n'
        f'[gf]\nextensions/selection_mode="explicit"\nextensions/enabled=Array[String]({enabled})\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n'
        'textures/vram_compression/import_etc2_astc=true\n'
        '[debug]\nfile_logging/enable_file_logging=true\n'
        f'[gf_native_acceptance]\nrun_token="{platform_token}"\n', encoding='utf-8')
    (workspace / 'main.tscn').write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://acceptance.gd" id="1"]\n'
        '[node name="Acceptance" type="Node"]\nscript = ExtResource("1")\n', encoding='utf-8')


def verify_upgrade(portable: Path, supplement: Path, workspace: Path, godot: str,
                   logs: Path, deadline: float) -> None:
    prepare_project(workspace)
    with zipfile.ZipFile(portable) as archive:
        archive.extractall(workspace)
    command = [godot, '--headless', '--path', str(workspace)]
    run([*command, '--import'], workspace, 'portable-import', 180, logs, deadline)
    selection = [*command, '--script', 'res://selection.gd']
    output = run(selection, workspace, 'portable-selection', 60, logs, deadline)
    if output.splitlines().count('GF_NATIVE_SELECTION=script') != 1:
        raise RuntimeError('Portable project did not exercise automatic script gather.')
    # Install only the supplement into an existing project, at a different location.
    relocated = workspace / 'addons/vendor/acceleration'
    with zipfile.ZipFile(supplement) as archive:
        for info in archive.infolist():
            path = relocated / Path(info.filename).relative_to(dist.ADDON)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(archive.read(info))
    run([*command, '--import'], workspace, 'relocated-import', 180, logs, deadline)
    registry = (workspace / '.godot/extension_list.cfg').read_text(encoding='utf-8').splitlines()
    if registry != ['res://addons/vendor/acceleration/' + dist.LOADER]:
        raise RuntimeError('Godot did not register the relocated native addon.')
    output = run([*selection, '--', '--native'], workspace, 'relocated-selection', 60, logs, deadline)
    if output.splitlines().count('GF_NATIVE_SELECTION=native') != 1:
        raise RuntimeError('The relocated native supplement did not gather through the public API.')


def verify_standard_only_export(bundle: Path, fixture: Path, presets: Path, godot: str, logs: Path, deadline: float) -> None:
    """Export the standard heightfield and WFC APIs from the complete Windows installation with no GF extensions enabled."""
    workspace = fixture / 'standard-only'
    prepare_project(workspace, standard_only=True)
    with zipfile.ZipFile(bundle) as archive:
        archive.extractall(workspace)
    standard_logs = logs / 'standard-only'
    standard_logs.mkdir()
    run_fresh_import(godot, workspace, standard_logs, deadline)
    shutil.copy2(presets, workspace / 'export_presets.cfg')
    output_dir = fixture / 'standard-only-release'
    output_dir.mkdir()
    game = output_dir / 'standard.exe'
    output = run([godot, '--headless', '--path', str(workspace), '--export-release', 'Windows', str(game)],
                 workspace, 'export', 180, standard_logs, deadline)
    error = export_policy_error(0, output)
    if error:
        raise RuntimeError(f'Standard-only export: {error}')
    logfile = standard_logs / 'engine.log'
    stdout = run([str(game), '--headless', '--log-file', str(logfile)], output_dir, 'runtime', 60, standard_logs, deadline)
    engine_log = logfile.read_text(encoding='utf-8')
    check_engine_diagnostics(engine_log, 'standard-only', standard_logs)
    if not any(text.splitlines().count('GF_NATIVE_STANDARD_ONLY=passed') == 1 for text in (stdout, engine_log)):
        raise RuntimeError('Exported standard capabilities failed with an empty extension selection')


def check_windows_dependencies(dll: Path, logs: Path, deadline: float) -> list[str]:
    """Inspect the shipped binary even when the build machine has the VC++ redistributable."""
    dumpbin = shutil.which('dumpbin.exe')
    if not dumpbin:
        vswhere = Path(os.environ['ProgramFiles(x86)']) / 'Microsoft Visual Studio/Installer/vswhere.exe'
        found = run([str(vswhere), '-latest', '-products', '*', '-requires',
                     'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-find',
                     r'VC\Tools\MSVC\**\bin\Hostx64\x64\dumpbin.exe'], CRATE, 'locate-dumpbin', 30, logs, deadline)
        dumpbin = next((line for line in found.splitlines() if Path(line).is_file()), None)
    if not dumpbin:
        raise ValueError('The MSVC build tools must provide dumpbin for Windows dependency verification.')
    output = run([dumpbin, '/NOLOGO', '/DEPENDENTS', str(dll)], CRATE, 'dll-dependencies', 30, logs, deadline)
    return check_dependency_report(output)


def check_dependency_report(output: str) -> list[str]:
    imports = sorted(set(re.findall(r'(?im)^\s*([\w.-]+\.dll)\s*$', output)), key=str.lower)
    if not imports or any(name.lower().startswith(('vcruntime', 'msvcp', 'concrt', 'vcomp')) for name in imports):
        raise ValueError(f'Expected a Windows DLL with a statically linked MSVC runtime, found {imports}.')
    return imports


def qualify(portable: Path, supplement: Path, bundle: Path, version: str, revision: str, *,
            export: bool, skip_build: bool = False, cargo_name: str = 'cargo',
            timeout: float = 900, candidate_library: bytes | None = None) -> dict:
    if sys.platform != 'win32':
        raise ValueError('Building GF Native requires a Windows x64 MSVC toolchain.')
    deadline = time.monotonic() + timeout
    initial_digest = source_digest(deadline)
    logs_parent = ROOT / 'ai_analysis/godot_logs/gf_native'
    logs_parent.mkdir(parents=True, exist_ok=True)
    logs = Path(tempfile.mkdtemp(prefix='run-', dir=logs_parent))
    run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests/native', '-p', 'test_*.py'],
        ROOT, 'runner-tests', 60, logs, deadline)
    target = ROOT / 'build/gf_native_target'
    toolchain = tomllib.loads((CRATE / 'rust-toolchain.toml').read_text(encoding='utf-8'))['toolchain']['channel']
    godot = str(resolve_godot_executable(environment=dict(os.environ), cwd=ROOT))
    cargo = shutil.which(cargo_name)
    if not cargo:
        raise ValueError('GF Native requires Cargo and the pinned MSVC toolchain.')
    common = [cargo, f'+{toolchain}']
    if not skip_build:
        run([*common, 'fmt', '--check'], CRATE, 'rustfmt', 60, logs, deadline)
        commands = [('rust-tests', ['test']), ('clippy', ['clippy'])]
        if candidate_library is None:
            commands.append(('release-build', ['build']))
        for name, args in commands:
            cmd = [*common, *args, '--release', '--locked', '--target', 'x86_64-pc-windows-msvc', '--target-dir', str(target)]
            if name == 'clippy':
                cmd.extend(['--', '-D', 'warnings'])
            run(cmd, CRATE, name, 600, logs, deadline)
    dll = target / 'x86_64-pc-windows-msvc/release/gf_native.dll'
    if candidate_library is not None:
        dll = logs / 'gf_native.dll'
        dll.write_bytes(candidate_library)
    imports = check_windows_dependencies(dll, logs, deadline)
    rustc = str(Path(cargo).with_name('rustc.exe'))
    sysroot = run([rustc, f'+{toolchain}', '--print', 'sysroot'], CRATE, 'rust-sysroot', 30, logs, deadline).strip()
    std_notices = (Path(sysroot) / 'share/doc/rust/COPYRIGHT-library.html').read_bytes()
    dist.assemble(portable, supplement, bundle, dll.read_bytes(), std_notices, version, revision)
    dist.verify(portable, supplement, bundle, version, revision)
    archives = (portable, supplement, bundle)
    # Whole-framework archives can exceed the per-source input budget.
    archive_digests = {p.name: archive_digest(p, deadline) for p in archives}
    fixture = Path(tempfile.mkdtemp(prefix='gf-native-', dir=ROOT / 'build'))
    workspace = fixture / 'project'
    prepare_project(workspace)
    with zipfile.ZipFile(bundle) as archive:
        archive.extractall(workspace)
    tested_dll = workspace / dist.ADDON / dist.DLL
    tested_dll_digest = file_digest(tested_dll, deadline)
    run_fresh_import(godot, workspace, logs, deadline)
    command = [godot, '--headless', '--path', str(workspace)]
    runtime_report = parse_acceptance(run(command, workspace, 'runtime', 120, logs, deadline))
    verify_upgrade(portable, supplement, fixture / 'upgrade', godot, logs, deadline)
    export_reports = {}
    extension_exports = {}
    if export:
        extension_exports = gf_extension_export_acceptance.run_acceptance(godot, portable, deadline=deadline)
        (workspace / 'export_presets.cfg').write_text(
            '[preset.0]\nname="Windows"\nplatform="Windows Desktop"\nrunnable=true\n'
            'export_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\n'
            '[preset.0.options]\nbinary_format/architecture="x86_64"\nbinary_format/embed_pck=true\n', encoding='utf-8')
        for profile in ('debug', 'release'):
            export_dir = fixture / profile
            export_dir.mkdir()
            executable = export_dir / 'acceptance.exe'
            output = run([*command, f'--export-{profile}', 'Windows', str(executable)],
                         workspace, f'export-{profile}', 180, logs, deadline)
            policy_error = export_policy_error(0, output)
            if policy_error:
                raise RuntimeError(f'{profile}: {policy_error} See {logs}')
            for name in (dist.DLL, dist.NOTICES, dist.STD_NOTICES):
                source = workspace / dist.ADDON / name
                if file_digest(export_dir / Path(name).name, deadline) != file_digest(source, deadline):
                    raise RuntimeError(f'{profile} export did not contain the tested {name}.')
            exported = run([str(executable), '--headless'], export_dir, f'run-{profile}', 120, logs, deadline)
            export_reports[profile] = parse_acceptance(exported)
        verify_standard_only_export(bundle, fixture, workspace / 'export_presets.cfg', godot, logs, deadline)
    if source_digest(deadline) != initial_digest or file_digest(tested_dll, deadline) != tested_dll_digest:
        raise RuntimeError('Native acceptance inputs changed during execution.')
    if {p.name: archive_digest(p, deadline) for p in archives} != archive_digests:
        raise RuntimeError('Installable archives changed during acceptance.')
    summary = {'ok': True, 'toolchain': toolchain, 'dll_sha256': tested_dll_digest, 'dll_imports': imports,
               'exports_verified': export, 'standard_only_export_verified': export, 'height_only_export_verified': export,
               'source_sha256': initial_digest, 'archives_sha256': archive_digests,
               'fresh_discovery_verified': True, 'relocation_verified': True, 'portable_verified': True,
               'build_verified': not skip_build, 'logs': str(logs),
               'runtime': runtime_report, 'exports': export_reports, 'extension_exports': extension_exports}
    remove_completed_fixture(fixture)
    (logs / 'acceptance.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    return summary


def remove_completed_fixture(path: Path) -> None:
    build = (ROOT / 'build').resolve(strict=True)
    resolved = path.resolve(strict=True)
    if path.is_symlink() or path != resolved or resolved.parent != build or not resolved.name.startswith('gf-native-'):
        raise ValueError(f'Unexpected native fixture directory: {path}')
    shutil.rmtree(resolved)


def archive_digest(path: Path, deadline: float) -> str:
    with path.open('rb') as stream:
        digest = hashlib.sha256()
        while block := stream.read(1024 * 1024):
            if time.monotonic() >= deadline:
                raise RuntimeError('Archive verification exhausted its deadline.')
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cargo', default='cargo')
    parser.add_argument('--skip-build', action='store_true', help='Use the existing DLL for a local diagnostic.')
    parser.add_argument('--export', action='store_true', help='Require both Windows debug and release exports.')
    parser.add_argument('--timeout', type=float, default=900)
    args = parser.parse_args()
    if not 0 < args.timeout <= 3600:
        parser.error('--timeout must be in (0, 3600].')
    from build_gf_release_artifacts import git_head
    from gf_process_authority import freeze_process_authority, FrozenProcessEnvironment
    revision = git_head(freeze_process_authority(FrozenProcessEnvironment.capture(os.environ), cwd=ROOT).git)
    version = build_asset_store_package.read_plugin_version()
    (ROOT / 'build').mkdir(exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix='gf-native-packages-', dir=ROOT / 'build'))
    portable = output / f'gf-framework-{version}.zip'
    build_asset_store_package.build_package(portable)
    summary = qualify(portable, output / f'gf-native-{dist.TARGET}-{version}.zip',
                      output / f'gf-framework-{dist.TARGET}-{version}.zip', version, revision,
                      export=args.export, skip_build=args.skip_build, cargo_name=args.cargo, timeout=args.timeout)
    remove_completed_fixture(output)
    print(json.dumps(summary))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
