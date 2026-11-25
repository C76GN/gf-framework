"""从已构建的 DLL 和给定的便携包组装 Windows 原生发布归档，并校验实际交付字节。"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import struct
import tomllib
import zipfile

from build_asset_store_package import ZIP_TIMESTAMP, read_package_source_bytes

ROOT = Path(__file__).resolve().parents[1]
CRATE = ROOT / 'native/gf_native'
TARGET = 'windows-x86_64'
ADDON = 'addons/gf_native/'
LOADER = 'gf_native.gdextension'
DLL = 'bin/gf_native.dll'
NOTICES = 'GF-NATIVE-NOTICES.txt'
STD_NOTICES = 'RUST-STDLIB-NOTICES.html'
METADATA = 'native-build.json'
MAX_NATIVE_FILE = 64 * 1024 * 1024


def native_inputs() -> list[Path]:
    """返回决定原生源码身份的文件，按相对 crate 的 POSIX 路径排序。"""
    paths = [*(CRATE / name for name in (
        'Cargo.toml', 'Cargo.lock', 'build.rs', '.cargo/config.toml', 'rust-toolchain.toml', LOADER, 'THIRD_PARTY_NOTICES.txt',
    )), *CRATE.glob('src/**/*.rs')]
    # Windows 与 POSIX 对大小写混合的路径排序不同，使用同一种文本顺序计算摘要。
    return sorted(paths, key=lambda path: path.relative_to(CRATE).as_posix())


def native_source_digest() -> str:
    """把路径名和内容一同计入源码摘要，使移动或修改文件都能被发现。"""
    digest = hashlib.sha256()
    digest.update(b'../../LICENSE.md\0' + hashlib.sha256(read_package_source_bytes(ROOT / 'LICENSE.md')).digest())
    for path in native_inputs():
        digest.update(path.relative_to(CRATE).as_posix().encode() + b'\0')
        digest.update(hashlib.sha256(read_package_source_bytes(path)).digest())
    return digest.hexdigest()


def notice_bytes() -> bytes:
    """从仓库许可证及固定依赖信息构造随库交付的声明字节。"""
    notices = read_package_source_bytes(CRATE / 'THIRD_PARTY_NOTICES.txt')
    packages = tomllib.loads(read_package_source_bytes(CRATE / 'Cargo.lock').decode())['package']
    sources = {f'https://static.crates.io/crates/{p["name"]}/{p["name"]}-{p["version"]}.crate'
               for p in packages if 'source' in p}
    listed = {line for line in notices.decode().splitlines() if line.startswith('https://static.crates.io/')}
    if sources != listed:
        raise ValueError('Update third-party notices for the exact dependencies in Cargo.lock.')
    return b'GF Framework\n\n' + read_package_source_bytes(ROOT / 'LICENSE.md') + b'\n\n' + notices


def descriptor(features: set[str]) -> bytes:
    """仅为本次安装包实际包含的原生库生成 Godot 加载条目。"""
    template = read_package_source_bytes(CRATE / LOADER).decode()
    config, libraries = template.split('[libraries]\n')
    mappings, windows_dependencies = libraries.split('\n[dependencies]\n')
    lines = [line for line in mappings.splitlines() if line.partition(' = ')[0] in features]
    if {line.partition(' = ')[0] for line in lines} != features:
        raise ValueError(f'Missing native library mappings for {features}.')
    result = config + '[libraries]\n' + '\n'.join(lines) + '\n'
    if 'windows.x86_64' in features:
        result += '\n[dependencies]\n' + windows_dependencies
    return result.encode()


def check_dll(data: bytes) -> None:
    """核对 DLL 的文件头与 x86-64 目标，不符合 Windows 分发要求时抛出 ValueError。"""
    if len(data) < 64 or data[:2] != b'MZ':
        raise ValueError('Expected a Windows x86_64 DLL.')
    offset = struct.unpack_from('<I', data, 60)[0]
    if (offset > len(data) - 26 or data[offset:offset + 4] != b'PE\0\0'
            or struct.unpack_from('<H', data, offset + 4)[0] != 0x8664
            or not struct.unpack_from('<H', data, offset + 22)[0] & 0x2000
            or struct.unpack_from('<H', data, offset + 24)[0] != 0x20b):
        raise ValueError('Expected a Windows x86_64 PE32+ DLL.')


def build_metadata(version: str, revision: str, contents: dict[str, bytes]) -> bytes:
    record = {'schema_version': 1, 'framework_version': version, 'source_revision': revision,
              'native_source_sha256': native_source_digest(), 'target': TARGET,
              'files': {name: hashlib.sha256(data).hexdigest() for name, data in contents.items()}}
    return (json.dumps(record, sort_keys=True, indent=2) + '\n').encode()


def write_entry(archive: zipfile.ZipFile, name: str, data: bytes) -> None:
    """用分发约定的 ZIP 元数据写入给定名称和原始字节。"""
    info = zipfile.ZipInfo(name, ZIP_TIMESTAMP)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    archive.writestr(info, data)


def assemble(portable: Path, supplement: Path, bundle: Path, library: bytes,
             std_notices: bytes, version: str, revision: str) -> None:
    """从现有便携归档、DLL 和许可证组装补充包与整包，沿用相同的原生载荷。"""
    check_dll(library)
    contents = {LOADER: descriptor({'windows.x86_64'}), DLL: library,
                NOTICES: notice_bytes(), STD_NOTICES: std_notices}
    contents[METADATA] = build_metadata(version, revision, contents)
    with zipfile.ZipFile(supplement, 'x') as archive:
        for name in sorted(contents):
            write_entry(archive, ADDON + name, contents[name])
    # 保留便携归档已有条目的压缩字节，再追加同一份原生补充内容。
    shutil.copyfile(portable, bundle)
    with zipfile.ZipFile(bundle, 'a') as archive:
        for name in sorted(contents):
            write_entry(archive, ADDON + name, contents[name])


def verify(portable: Path, supplement: Path, bundle: Path, version: str, revision: str) -> None:
    """核对便携版、补充包和整包之间的成员、元数据及载荷一致性，差异以 ValueError 报告。"""
    with (zipfile.ZipFile(portable) as base, zipfile.ZipFile(supplement) as extra,
          zipfile.ZipFile(bundle) as complete):
        native_names = {ADDON + name for name in (LOADER, DLL, NOTICES, STD_NOTICES, METADATA)}
        if set(extra.namelist()) != native_names or len(extra.infolist()) != len(native_names):
            raise ValueError('Native supplement must contain exactly the declared addon files.')
        for info in extra.infolist():
            if info.file_size <= 0 or info.file_size > MAX_NATIVE_FILE:
                raise ValueError(f'Invalid native file size: {info.filename}')
        contents = {name: extra.read(ADDON + name) for name in (LOADER, DLL, NOTICES, STD_NOTICES)}
        check_dll(contents[DLL])
        if contents[LOADER] != descriptor({'windows.x86_64'}) or contents[NOTICES] != notice_bytes():
            raise ValueError('Packaged native descriptor or license notices differ from source.')
        if extra.read(ADDON + METADATA) != build_metadata(version, revision, contents):
            raise ValueError('Native package version, source or file hashes do not match.')
        expected = set(base.namelist()) | native_names
        if (len(expected) != len(base.infolist()) + len(native_names)
                or set(complete.namelist()) != expected or len(complete.infolist()) != len(expected)):
            raise ValueError('Windows framework must contain exactly the portable framework and native supplement.')
        for source in (base, extra):
            for info in source.infolist():
                target = complete.getinfo(info.filename)
                if target.file_size != info.file_size or target.CRC != info.CRC:
                    raise ValueError(f'Windows framework file differs: {info.filename}')
                with source.open(info) as first, complete.open(target) as second:
                    if hashlib.file_digest(first, 'sha256').digest() != hashlib.file_digest(second, 'sha256').digest():
                        raise ValueError(f'Windows framework file differs: {info.filename}')
