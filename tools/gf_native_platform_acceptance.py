"""Qualify an installed GF Native addon in a release-exported Linux, Android or iOS game."""
from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
import secrets
import shutil
import statistics
import time
import zipfile

import build_asset_store_package as portable
import gf_native_acceptance as acceptance
import gf_native_platforms as native
from gf_native_platforms import invoke
from gf_extension_export_acceptance import owned_projects

MARKER = 'GF_NATIVE_DATA_BATCH='
ABIS = {'arm64-v8a': native.ANDROID_ARM, 'x86_64': native.ANDROID_X64}


def report(output: str, token: str, platform: str, architecture: str, profile: str) -> dict:
    lines = [line for line in output.splitlines() if line.startswith(MARKER) and token in line]
    data = acceptance.parse_acceptance('\n'.join(lines))
    if (data.get('run_token'), data.get('platform'), data.get('architecture')) != (token, platform, architecture):
        raise ValueError('Acceptance did not execute on the requested platform and architecture.')
    if data.get('debug_build') is not (profile == 'debug'):
        raise ValueError(f'Exported game did not run the {profile} template.')
    foundation = data.get('foundation')
    if not isinstance(foundation, dict) or set(foundation) != {'terrain_rgb_256', 'wfc_entropy_16'}:
        raise ValueError('Missing public heightfield or WFC performance case.')
    for name, case in foundation.items():
        if not isinstance(case, dict):
            raise ValueError(f'Invalid {name} timing report.')
        for field in ('script_usec', 'native_usec'):
            values = case.get(field)
            if not isinstance(values, list) or len(values) != 5 or any(type(v) is not int or v <= 0 for v in values):
                raise ValueError(f'Incomplete {name} timing samples.')
    for name, case in {**foundation, 'gather_100000': data['samples'][-1]}.items():
        if profile == 'release' and statistics.median(case['native_usec']) >= statistics.median(case['script_usec']):
            raise ValueError(f'Native {name} did not improve the portable median on {platform} {architecture}.')
    return data


def export(godot: str, project: Path, platform: str, options: str, dest: Path, logs: Path, profile: str) -> None:
    (project / 'export_presets.cfg').write_text(
        f'[preset.0]\nname="Acceptance"\nplatform="{platform}"\nrunnable=false\n'
        'export_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\n'
        f'[preset.0.options]\n{options}\n', encoding='utf-8')
    output = acceptance.run([godot, '--headless', '--path', str(project), '--export-' + profile, 'Acceptance', str(dest)],
                            project, 'export', 300, logs, time.monotonic() + 320)
    policy_error = acceptance.export_policy_error(0, output)
    if policy_error or not dest.exists() and platform != 'iOS':
        raise RuntimeError(f'Godot {platform} export failed: {policy_error or dest}')


def linux(godot: str, project: Path, logs: Path, token: str, wsl: str | None, profile: str) -> dict:
    game = logs / 'game.x86_64'
    export(godot, project, 'Linux', 'binary_format/architecture="x86_64"', game, logs, profile)
    binary = Path(native.TARGETS[native.LINUX][1])
    if (logs / binary.name).read_bytes() != (project / native.dist.ADDON / binary).read_bytes():
        raise ValueError('Exported Linux library differs from the installed addon.')
    if wsl:
        prefix = ['wsl.exe', '-d', wsl, '--exec']
        path = invoke([*prefix, 'wslpath', '-a', str(game)]).strip()
        command = [*prefix, path, '--headless']
    else:
        command = [str(game), '--headless']
    output = invoke(command)
    (logs / 'game.log').write_text(output, encoding='utf-8')
    acceptance.check_engine_diagnostics(output, 'Linux release', logs)
    return {'x86_64': report(output, token, 'Linux', 'x86_64', profile)}


def android(godot: str, project: Path, logs: Path, token: str, serial: str, adb_path: str, required: set[str],
            profile: str) -> dict:
    adb = [adb_path, '-s', serial]
    package = 'org.godotengine.gfnative.t' + token
    keystore = logs / 'fixture.keystore'
    keytool = Path(os.environ['JAVA_HOME']) / 'bin' / ('keytool.exe' if os.name == 'nt' else 'keytool')
    invoke([str(keytool), '-genkeypair', '-alias', 'fixture', '-keyalg', 'RSA', '-keysize', '2048',
            '-validity', '10', '-storepass', 'android', '-keypass', 'android', '-keystore', str(keystore),
            '-dname', 'CN=GF Native Fixture'])
    # These are disposable fixture credentials and apply only to this runner's subprocesses.
    for kind in ('DEBUG', 'RELEASE'):
        for key, value in [('PATH', str(keystore)), ('USER', 'fixture'), ('PASSWORD', 'android')]:
            os.environ[f'GODOT_ANDROID_KEYSTORE_{kind}_{key}'] = value
    options = (f'package/unique_name="{package}"\narchitectures/armeabi-v7a=false\n'
               'architectures/arm64-v8a=true\narchitectures/x86=false\narchitectures/x86_64=true')
    apk = logs / 'game.apk'
    export(godot, project, 'Android', options, apk, logs, profile)
    with zipfile.ZipFile(apk) as archive:
        for abi, target in ABIS.items():
            library = Path(native.TARGETS[target][1])
            if archive.read(f'lib/{abi}/{library.name}') != (project / native.dist.ADDON / library).read_bytes():
                raise ValueError(f'Exported Android library differs for {abi}.')
    invoke([*adb, 'wait-for-device'], timeout=60)
    supported = invoke([*adb, 'shell', 'getprop', 'ro.product.cpu.abilist']).strip().split(',')
    if missing := required.difference(supported):
        raise ValueError(f'The Android qualification device lacks required ABIs: {sorted(missing)}.')
    results = {}
    for abi in (a for a in supported if a in ABIS):
        installed = invoke([*adb, 'install', '--abi', abi, str(apk)])
        if 'Success' not in installed:
            raise RuntimeError(f'Could not install the {abi} fixture: {installed}')
        device_log = ''
        log_command = []
        try:
            details = invoke([*adb, 'shell', 'pm', 'list', 'packages', '-U', package])
            uid = re.fullmatch(r'package:' + re.escape(package) + r' uid:(\d+)', details.strip())
            if not uid:
                raise RuntimeError(f'Could not resolve fixture application UID: {details}')
            # Only collect logs from the time of this launch. A previous ABI run has the same token.
            start = invoke([*adb, 'shell', 'date', "'+%m-%d %H:%M:%S.000'"]).strip()
            invoke([*adb, 'shell', 'am', 'start', '-a', 'android.intent.action.MAIN',
                    '-c', 'android.intent.category.LAUNCHER', '-p', package])
            log_command = [*adb, 'logcat', '-d', '-t', start, '--uid=' + uid[1], '-v', 'raw',
                           'godot:V', 'AndroidRuntime:E', '*:S']
            deadline = time.monotonic() + 150
            architecture = 'arm64' if abi == 'arm64-v8a' else 'x86_64'
            while time.monotonic() < deadline:
                device_log = invoke(log_command)
                acceptance.check_engine_diagnostics(device_log, 'Android release', logs)
                if 'FATAL EXCEPTION:' in device_log:
                    raise RuntimeError(f'Android {abi} crashed. See {logs}.')
                lines = [line for line in device_log.splitlines() if line.startswith(MARKER) and token in line
                         and json.loads(line[len(MARKER):]).get('architecture') == architecture]
                if lines and 'GF_NATIVE_FINISHED=' + token in device_log.splitlines():
                    results[abi] = report('\n'.join(lines), token, 'Android', architecture, profile)
                    break
                time.sleep(1)
            else:
                raise RuntimeError(f'No complete Android {abi} runtime report. See {logs}.')
        finally:
            invoke([*adb, 'uninstall', package])
            if log_command:
                device_log = invoke(log_command)
            (logs / f'android-{abi}.log').write_text(device_log, encoding='utf-8')
            acceptance.check_engine_diagnostics(device_log, 'Android shutdown', logs)
            if 'FATAL EXCEPTION:' in device_log:
                raise RuntimeError(f'Android {abi} crashed. See {logs}.')
    if not results:
        raise ValueError(f'No packaged ABI can run on {serial}: {supported}.')
    return results


def ios(godot: str, project: Path, logs: Path, token: str, simulator: str, profile: str) -> dict:
    package = 'org.godotengine.gfnative.t' + token
    options = (f'application/bundle_identifier="{package}"\napplication/app_store_team_id="GFFIXTURE1"\n'
               'application/export_project_only=true\narchitectures/arm64=true')
    export(godot, project, 'iOS', options, logs / 'Game.ipa', logs, profile)
    xcode = logs / 'Game.xcodeproj'
    common = ['xcodebuild', '-project', str(xcode), '-scheme', 'Game', '-configuration', profile.capitalize(),
              '-derivedDataPath', str(logs / 'derived'), 'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO']
    for sdk, destination in [('iphoneos', 'generic/platform=iOS'), ('iphonesimulator', 'id=' + simulator)]:
        output = invoke([*common, '-sdk', sdk, '-destination', destination, 'build'], 900)
        (logs / (sdk + '.log')).write_text(output, encoding='utf-8')
        app, = (logs / f'derived/Build/Products/{profile.capitalize()}-{sdk}').glob('*.app')
        framework = app / 'Frameworks/libgf_native.framework/libgf_native'
        native.check_binary(native.IOS if sdk == 'iphoneos' else native.SIM, framework.read_bytes())
    simctl = ['xcrun', 'simctl']
    invoke([*simctl, 'install', simulator, str(app)])
    try:
        container = Path(invoke([*simctl, 'get_app_container', simulator, package, 'data']).strip())
        launch = invoke([*simctl, 'launch', simulator, package]).strip()
        pid = int(launch.rsplit(':', 1)[1])
        deadline = time.monotonic() + 150
        while time.monotonic() < deadline:
            for path in container.rglob(f'gf-native-{token}.json'):
                encoded = path.read_text(encoding='utf-8')
                if encoded.endswith('}'):
                    for engine_log in container.rglob('godot.log'):
                        output = engine_log.read_text(encoding='utf-8')
                        if 'GF_NATIVE_FINISHED=' + token not in output or MARKER + encoded not in output:
                            continue
                        # iOS may keep the app alive after its scene exits. Stop it before reading the final log.
                        try:
                            os.kill(pid, 0)
                        except ProcessLookupError:
                            pass
                        else:
                            invoke([*simctl, 'terminate', simulator, package])
                        output = engine_log.read_text(encoding='utf-8')
                        (logs / 'simulator.log').write_text(output, encoding='utf-8')
                        acceptance.check_engine_diagnostics(output, 'iOS simulator', logs)
                        return {'arm64-simulator': report(MARKER + encoded, token, 'iOS', 'arm64', profile)}
            time.sleep(1)
        raise RuntimeError('The installed iOS Simulator app did not produce its runtime report.')
    finally:
        invoke([*simctl, 'uninstall', simulator, package])


def verify_delivery(directory: Path, version: str, revision: str) -> tuple[Path, str]:
    """Release only the exact overlay for which all required exported games reported success."""
    archive = directory / 'overlay.zip'
    native.verify(archive, set(native.TARGETS), version, revision)
    digest = native.sha(archive.read_bytes())
    source = native.dist.native_source_digest()
    required = {'linux': ('Linux', {'x86_64': 'x86_64'}),
                'android': ('Android', {'arm64-v8a': 'arm64', 'x86_64': 'x86_64'}),
                'ios': ('iOS', {'arm64-simulator': 'arm64'})}
    for platform, (engine_os, architectures) in required.items():
        for profile in ('debug', 'release'):
            receipt = directory / f'{platform}-{profile}.json'
            if receipt.stat().st_size > 1024 * 1024:
                raise ValueError(f'Oversized runtime evidence: {receipt.name}')
            proof = json.loads(receipt.read_text(encoding='utf-8'))
            if not isinstance(proof, dict):
                raise ValueError(f'Invalid runtime evidence: {receipt.name}')
            expected = dict(archive_sha256=digest, native_source_sha256=source, source_revision=revision,
                            platform=platform, profile=profile)
            if any(proof.get(key) != value for key, value in expected.items()):
                raise ValueError(f'Runtime evidence differs from this native release: {receipt.name}')
            results = proof.get('runtime')
            if not isinstance(results, dict) or set(results) != set(architectures):
                raise ValueError(f'Incomplete exported architectures in {receipt.name}.')
            for abi, arch in architectures.items():
                data = results[abi]
                if not isinstance(data, dict):
                    raise ValueError(f'Invalid runtime result in {receipt.name}.')
                token = data.get('run_token', '')
                if not isinstance(token, str) or not re.fullmatch('[a-f0-9]{24}', token):
                    raise ValueError(f'Invalid runtime identity in {receipt.name}.')
                report(MARKER + json.dumps(data), token, engine_os, arch, profile)
    return archive, digest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=('linux', 'android', 'ios'))
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--profile', choices=('debug', 'release'), default='release')
    parser.add_argument('--receipts', type=Path, help='Also save the release handoff report in this directory.')
    parser.add_argument('--godot', default=os.environ.get('GF_GODOT_EXECUTABLE') or shutil.which('godot'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--wsl', help='Linux only: name of a WSL distribution on the Windows export host.')
    parser.add_argument('--device', help='Android adb serial or booted iOS simulator UDID.')
    parser.add_argument('--adb', default=shutil.which('adb') or 'adb')
    parser.add_argument('--require-android-abis', nargs='+', choices=ABIS, default=[])
    args = parser.parse_args()
    if not args.godot or args.platform != 'linux' and not args.device:
        parser.error('Provide Godot and an explicit device for mobile exports.')
    logs = args.output.resolve()
    logs.mkdir(parents=True, exist_ok=False)
    archive_hash = native.sha(args.archive.read_bytes())
    with zipfile.ZipFile(args.archive) as archive:
        record = json.loads(archive.read(native.dist.ADDON + native.dist.METADATA))
    targets = set(record['targets'])
    version = portable.read_plugin_version()
    source_revision = native.revision()
    native.verify(args.archive, targets, version, source_revision)
    token = secrets.token_hex(12)
    with owned_projects(logs.parent) as tmp:
        project = tmp / 'project'
        acceptance.prepare_project(project, platform_token=token)
        for source in portable.iter_package_files():
            destination = project / source.relative_to(portable.ROOT)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(portable.read_package_source_bytes(source))
        with zipfile.ZipFile(args.archive) as archive:
            archive.extractall(project)
        acceptance.run_fresh_import(args.godot, project, logs, time.monotonic() + 150)
        if args.platform == 'linux':
            results = linux(args.godot, project, logs, token, args.wsl, args.profile)
        elif args.platform == 'android':
            results = android(args.godot, project, logs, token, args.device, args.adb, set(args.require_android_abis), args.profile)
        else:
            results = ios(args.godot, project, logs, token, args.device, args.profile)
    if native.sha(args.archive.read_bytes()) != archive_hash:
        raise ValueError('Overlay changed during acceptance.')
    summary = dict(archive_sha256=archive_hash, native_source_sha256=record['native_source_sha256'],
                   source_revision=source_revision, platform=args.platform, profile=args.profile, runtime=results)
    encoded = json.dumps(summary, indent=2) + '\n'
    (logs / 'acceptance.json').write_text(encoded, encoding='utf-8')
    if args.receipts:
        args.receipts.mkdir(parents=True, exist_ok=True)
        (args.receipts / f'{args.platform}-{args.profile}.json').write_text(encoded, encoding='utf-8')
    print(f'{args.platform}: {", ".join(results)} passed; {logs / "acceptance.json"}')


if __name__ == '__main__':
    main()
