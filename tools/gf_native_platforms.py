"""Build target libraries once and assemble a relocatable GF Native addon from those bytes."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import struct
import tempfile
import tomllib
import zipfile

import gf_native_distribution as dist
from build_asset_store_package import read_plugin_version
from gf_process_supervisor import run_supervised_process

WINDOWS = 'x86_64-pc-windows-msvc'
LINUX = 'x86_64-unknown-linux-gnu'
ANDROID_ARM = 'aarch64-linux-android'
ANDROID_X64 = 'x86_64-linux-android'
MAC = 'aarch64-apple-darwin'
IOS = 'aarch64-apple-ios'
SIM = 'aarch64-apple-ios-sim'
XCFRAMEWORK = 'bin/libgf_native.xcframework'
# Godot feature tag and install path. Both Apple embedded slices share one descriptor entry.
TARGETS = {
    WINDOWS: ('windows.x86_64', dist.DLL),
    LINUX: ('linux.x86_64', 'bin/linux-x86_64/libgf_native.so'),
    ANDROID_ARM: ('android.arm64', 'bin/android-arm64/libgf_native.so'),
    ANDROID_X64: ('android.x86_64', 'bin/android-x86_64/libgf_native.so'),
    MAC: ('macos.arm64', 'bin/macos-arm64/libgf_native.dylib'),
    IOS: ('ios.arm64', XCFRAMEWORK + '/ios-arm64/libgf_native.dylib'),
    SIM: ('ios.arm64', XCFRAMEWORK + '/ios-arm64-simulator/libgf_native.dylib'),
}
STAGE = dist.ROOT / 'build/native-platforms'
CARGO_TARGET = dist.ROOT / 'build/gf_native_target'
TOOLCHAIN = tomllib.loads((dist.CRATE / 'rust-toolchain.toml').read_text(encoding='utf-8'))['toolchain']['channel']


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def invoke(command: list[str], timeout: int = 180, *, cwd: Path = dist.ROOT,
           environment: dict[str, str] | None = None, log: Path | None = None) -> str:
    result = run_supervised_process(command, cwd=cwd, environment=dict(os.environ) if environment is None else environment,
                                    timeout_seconds=timeout, max_stdout_characters=8_000_000, max_stderr_characters=1_000_000,
                                    heartbeat_callback=lambda elapsed, _pid: print(f'{Path(command[0]).name}: {elapsed:.0f}s', flush=True))
    output = result.stdout + '\n' + result.stderr
    if log is not None:
        log.write_text(output, encoding='utf-8')
    if (result.return_code or result.timed_out or result.cancelled or not result.process_boundary_quiescent
            or result.stdout_truncated or result.stderr_truncated):
        raise RuntimeError(f'{command[0]} failed (exit {result.return_code}, {result.notes}): {output[-4000:]}')
    return output


def revision() -> str:
    return invoke(['git', 'rev-parse', 'HEAD']).strip()


def std_notices() -> bytes:
    sysroot = invoke(['rustc', '+' + TOOLCHAIN, '--print', 'sysroot'], cwd=dist.CRATE).strip()
    return (Path(sysroot) / 'share/doc/rust/COPYRIGHT-library.html').read_bytes()


def check_binary(target: str, data: bytes) -> None:
    """Reject swapped ABIs, desktop libc on Android, and simulator/device mixups on every host."""
    if not 64 <= len(data) <= dist.MAX_NATIVE_FILE:
        raise ValueError(f'Invalid library size for {target}.')
    if target == WINDOWS:
        dist.check_dll(data)
        return
    if target in (LINUX, ANDROID_ARM, ANDROID_X64):
        arch = 183 if target == ANDROID_ARM else 62
        if data[:6] != b'\x7fELF\x02\x01' or struct.unpack_from('<HH', data, 16) != (3, arch):
            raise ValueError(f'Expected a little-endian ELF64 shared library for {target}.')
        offset = struct.unpack_from('<Q', data, 32)[0]
        size, count = struct.unpack_from('<HH', data, 54)
        if size < 56 or not count or offset + count * size > len(data):
            raise ValueError(f'Invalid ELF program headers for {target}.')
        headers = [struct.unpack_from('<II6Q', data, offset + i * size) for i in range(count)]
        loads = [h for h in headers if h[0] == 1]
        if not any(h[1] & 1 for h in loads) or any(h[2] + h[5] > len(data) or h[5] > h[6] for h in loads):
            raise ValueError(f'Invalid ELF executable load segments for {target}.')
        if target != LINUX and any(h[7] < 16384 or (h[2] - h[3]) % 16384 for h in loads):
            raise ValueError(f'Invalid ELF load segment alignment for {target}.')
        needed = elf_dependencies(data, headers, loads)
        libc = b'libc.so.6' if target == LINUX else b'libc.so'
        if needed.intersection({b'libc.so', b'libc.so.6'}) != {libc}:
            raise ValueError(f'Wrong target libc dependencies for {target}.')
        return
    platforms = []
    for kind, command in macho_commands(target, data):
        if kind == 0x32 and len(command) >= 24:  # LC_BUILD_VERSION
            platform, minimum = struct.unpack_from('<II', command, 8)
            if target in (IOS, SIM) and not 0 < minimum <= 15 << 16:
                raise ValueError(f'Unsupported iOS deployment minimum for {target}.')
            platforms.append(platform)
    if platforms != [{MAC: 1, IOS: 2, SIM: 7}[target]]:
        raise ValueError(f'Mach-O platform does not match {target}.')


def macho_commands(target: str, data: bytes) -> list[tuple[int, bytes]]:
    if len(data) < 32 or struct.unpack_from('<4I', data) != (0xfeedfacf, 0x100000c, 0, 6):
        raise ValueError(f'Expected an arm64 Mach-O dynamic library for {target}.')
    count, length = struct.unpack_from('<II', data, 16)
    end = 32 + length
    offset = 32
    commands = []
    for _ in range(count):
        if offset + 8 > end or end > len(data):
            raise ValueError(f'Invalid Mach-O commands for {target}.')
        kind, size = struct.unpack_from('<II', data, offset)
        if size < 8 or offset + size > end:
            raise ValueError(f'Invalid Mach-O command size for {target}.')
        commands.append((kind, data[offset:offset + size]))
        offset += size
    if offset != end:
        raise ValueError(f'Invalid Mach-O command length for {target}.')
    return commands


def apple_code_identity(target: str, data: bytes) -> tuple[bytes, str]:
    """Godot changes the install name and Xcode signs the framework. Both preserve the UUID and instructions."""
    uuids = []
    text = []
    for kind, command in macho_commands(target, data):
        if kind == 0x1b and len(command) == 24:  # LC_UUID
            uuids.append(command[8:])
        if kind != 0x19 or command[8:24].rstrip(b'\0') != b'__TEXT':  # LC_SEGMENT_64
            continue
        if len(command) < 72 or len(command) != 72 + 80 * struct.unpack_from('<I', command, 64)[0]:
            raise ValueError(f'Invalid Mach-O section table for {target}.')
        for section in range(72, len(command), 80):
            if command[section:section + 16].rstrip(b'\0') == b'__text':
                size, offset = struct.unpack_from('<QI', command, section + 40)
                if size == 0 or offset + size > len(data):
                    raise ValueError(f'Invalid Mach-O executable section for {target}.')
                text.append(sha(data[offset:offset + size]))
    if len(uuids) != 1 or len(text) != 1:
        raise ValueError(f'Missing or duplicate Mach-O code identity for {target}.')
    return uuids[0], text[0]


def elf_dependencies(data: bytes, headers: list[tuple], loads: list[tuple]) -> set[bytes]:
    # DT_STRTAB is a virtual address. Only file-backed bytes in PT_LOAD can supply its strings.
    dynamic = [h for h in headers if h[0] == 2]
    if len(dynamic) != 1:
        raise ValueError('Expected one ELF dynamic segment.')
    start, length = dynamic[0][2], dynamic[0][5]
    if length % 16 or start + length > len(data):
        raise ValueError('Invalid ELF dynamic segment.')
    entries = []
    for tag, value in struct.iter_unpack('<QQ', data[start:start + length]):
        if tag == 0:
            break
        entries.append((tag, value))
    else:
        raise ValueError('Unterminated ELF dynamic segment.')
    addresses = [v for k, v in entries if k == 5]
    lengths = [v for k, v in entries if k == 10]
    if len(addresses) != 1 or len(lengths) != 1:
        raise ValueError('Missing ELF dynamic string table.')
    address, size = addresses[0], lengths[0]
    offsets = [h[2] + address - h[3] for h in loads if h[3] <= address and address + size <= h[3] + h[5]]
    if len(offsets) != 1:
        raise ValueError('Invalid ELF dynamic string table address.')
    strings = bytes(data[offsets[0]:offsets[0] + size])
    names = set()
    for tag, value in entries:
        if tag == 1:
            end = strings.find(b'\0', value)
            if end <= value:
                raise ValueError('Invalid ELF dependency name.')
            names.add(strings[value:end])
    return names


def xcframework_info() -> bytes:
    libraries = []
    for target in (IOS, SIM):
        binary = Path(TARGETS[target][1])
        entry = dict(LibraryIdentifier=binary.parent.name, LibraryPath=binary.name, BinaryPath=binary.name,
                     SupportedArchitectures=['arm64'], SupportedPlatform='ios')
        if target == SIM:
            entry['SupportedPlatformVariant'] = 'simulator'
        libraries.append(entry)
    return plistlib.dumps(dict(AvailableLibraries=libraries, CFBundlePackageType='XFWK',
                               XCFrameworkFormatVersion='1.0'))


def stage_record(target: str, data: bytes, source_revision: str) -> dict:
    return dict(target=target, sha256=sha(data), native_source_sha256=dist.native_source_digest(),
                source_revision=source_revision, rust_toolchain=TOOLCHAIN)


def check_linux_symbol_versions(library: Path) -> None:
    listing = invoke(['readelf', '--version-info', '--wide', str(library)], environment={**os.environ, 'LC_ALL': 'C'})
    versions = re.findall(r'\bName: GLIBC_([\w.]+)', listing)
    if not versions:
        raise ValueError('Cannot identify the Linux library glibc requirements.')
    for version in versions:
        if not re.fullmatch(r'\d+(\.\d+)+', version) or tuple(map(int, version.split('.'))) > (2, 34):
            raise ValueError(f'Linux library exceeds the glibc 2.34 baseline: GLIBC_{version}')


def build(target: str, stage: Path, ndk: Path | None) -> None:
    environment = os.environ.copy()
    if target in (IOS, SIM):
        # The Godot 4.7 iOS template deploys to iOS 15 or later.
        environment['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    if target in (ANDROID_ARM, ANDROID_X64):
        if ndk is None:
            raise ValueError('Pass --ndk or set ANDROID_NDK_ROOT to an installed Android NDK.')
        candidates = list(ndk.glob(f'toolchains/llvm/prebuilt/*/bin/{target}24-clang' + ('.cmd' if os.name == 'nt' else '')))
        if len(candidates) != 1:
            raise ValueError(f'Cannot find a unique Android API 24 linker for {target} under {ndk}.')
        environment['CARGO_TARGET_' + target.upper().replace('-', '_') + '_LINKER'] = str(candidates[0].resolve())
    source_revision = revision()
    input_digest = dist.native_source_digest()
    print(invoke(['cargo', '+' + TOOLCHAIN, 'build', '--lib', '--locked', '--release', '--target', target,
                  '--target-dir', str(CARGO_TARGET)], 1200, cwd=dist.CRATE, environment=environment).strip())
    name = Path(TARGETS[target][1]).name
    library = CARGO_TARGET / target / 'release' / name
    if target == LINUX:
        check_linux_symbol_versions(library)
    data = library.read_bytes()
    check_binary(target, data)
    record = stage_record(target, data, source_revision)
    if record['native_source_sha256'] != input_digest or revision() != source_revision:
        raise ValueError('Native sources changed during the build.')
    dest = stage / target
    dest.mkdir(parents=True, exist_ok=True)
    (dest / name).write_bytes(data)
    if target == WINDOWS:
        (dest / dist.STD_NOTICES).write_bytes(std_notices())
    (dest / 'build.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')


def staged_binary(stage: Path, target: str, source_revision: str) -> bytes:
    directory = stage / target
    data = (directory / Path(TARGETS[target][1]).name).read_bytes()
    if json.loads((directory / 'build.json').read_text(encoding='utf-8')) != stage_record(target, data, source_revision):
        raise ValueError(f'Native build receipt mismatch for {target}.')
    check_binary(target, data)
    return data


def support_files(targets: set[str], standard: bytes) -> dict[str, bytes]:
    if not targets or not targets <= TARGETS.keys() or (IOS in targets) != (SIM in targets):
        raise ValueError('Select known native targets and include both iOS slices together.')
    result = {dist.LOADER: dist.descriptor({TARGETS[t][0] for t in targets}),
              dist.NOTICES: dist.notice_bytes(), dist.STD_NOTICES: standard}
    if IOS in targets:
        result[XCFRAMEWORK + '/Info.plist'] = xcframework_info()
    for target in targets:
        feature, binary = TARGETS[target]
        path = XCFRAMEWORK if target in (IOS, SIM) else binary
        if f'{feature} = "./{path}"'.encode() not in result[dist.LOADER].splitlines():
            raise ValueError(f'Native descriptor does not reference the packaged {target}.')
    return result


def metadata(targets: set[str], files: dict[str, bytes], version: str, source_revision: str) -> bytes:
    record = dict(schema_version=2, framework_version=version, source_revision=source_revision,
                  native_source_sha256=dist.native_source_digest(), targets=sorted(targets),
                  files={name: sha(data) for name, data in files.items()})
    return (json.dumps(record, sort_keys=True, indent=2) + '\n').encode()


def assemble(path: Path, stage: Path, targets: set[str], version: str, source_revision: str) -> None:
    standard = (stage / WINDOWS / dist.STD_NOTICES).read_bytes() if WINDOWS in targets else std_notices()
    files = support_files(targets, standard)
    for target in sorted(targets):
        files[TARGETS[target][1]] = staged_binary(stage, target, source_revision)
    files[dist.METADATA] = metadata(targets, files, version, source_revision)
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=path.parent) as directory:
        candidate = Path(directory) / 'addon.zip'
        with zipfile.ZipFile(candidate, 'x') as archive:
            for name, data in sorted(files.items()):
                dist.write_entry(archive, dist.ADDON + name, data)
        verify(candidate, targets, version, source_revision)
        os.replace(candidate, path)


def verify(path: Path, targets: set[str], version: str, source_revision: str, windows_package: Path | None = None) -> None:
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            if not 0 < info.file_size <= dist.MAX_NATIVE_FILE:
                raise ValueError(f'Invalid native archive member size: {info.filename}')
        standard = archive.read(dist.ADDON + dist.STD_NOTICES)
        files = support_files(targets, standard)
        names = set(files) | {TARGETS[t][1] for t in targets} | {dist.METADATA}
        if sorted(archive.namelist()) != sorted(dist.ADDON + name for name in names):
            raise ValueError('Unexpected, duplicate or missing native archive member.')
        for name, expected in files.items():
            if archive.read(dist.ADDON + name) != expected:
                raise ValueError(f'Packaged {name} differs from source.')
        for target in sorted(targets):
            name = TARGETS[target][1]
            data = archive.read(dist.ADDON + name)
            check_binary(target, data)
            if target != WINDOWS and (files[dist.NOTICES] not in data or standard.replace(b'\r\n', b'\n') not in data.replace(b'\r\n', b'\n')):
                raise ValueError(f'Missing embedded redistribution notices for {target}.')
            files[name] = data
        if archive.read(dist.ADDON + dist.METADATA) != metadata(targets, files, version, source_revision):
            raise ValueError('Native package hashes, source or version do not match.')
        if windows_package is not None:
            with zipfile.ZipFile(windows_package) as windows:
                for name in (dist.DLL, dist.STD_NOTICES, dist.NOTICES):
                    if files[name] != windows.read(dist.ADDON + name):
                        raise ValueError(f'Windows and multi-platform supplements disagree on {name}.')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('build', 'package', 'verify'))
    parser.add_argument('--targets', nargs='+', choices=TARGETS, default=list(TARGETS))
    parser.add_argument('--stage', type=Path, default=STAGE)
    parser.add_argument('--ndk', type=Path, default=os.environ.get('ANDROID_NDK_ROOT'))
    parser.add_argument('--archive', type=Path)
    args = parser.parse_args()
    if args.command == 'build':
        for target in args.targets:
            build(target, args.stage, args.ndk)
    else:
        if not args.archive:
            parser.error('--archive is required for package and verify.')
        args.archive = args.archive.resolve()
        if args.command == 'package':
            assemble(args.archive, args.stage, set(args.targets), read_plugin_version(), revision())
        else:
            verify(args.archive, set(args.targets), read_plugin_version(), revision())


if __name__ == '__main__':
    main()
