"""Measure public foundation operations and optional native capabilities in a Windows release export."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import statistics
import sys
import tempfile
import time
import tomllib
from pathlib import Path

from gf_godot_process import resolve_godot_executable
from gf_native_acceptance import check_engine_diagnostics, run

ROOT = Path(__file__).resolve().parents[1]
CRATE = ROOT / "native/gf_native"
FIXTURE = ROOT / "tests/gf_core/benchmarks/foundation/foundation_probe.gd.fixture"
SOURCE_DIRS = {
    "kernel/core": ("cancellation_token", "data_value_capture", "report_value_codec", "variant_access"),
    "standard/foundation/collections": ("priority_queue",),
    "standard/foundation/deterministic": ("deterministic_random",),
    "standard/foundation/variant": ("variant_data",),
    "standard/foundation/math": ("graph_math", "graph_path_search_state", "grid_coordinate_math_2d",
                                 "grid_path_math_2d", "grid_transform_2d", "heightfield_3d", "wave_function_collapse_2d",
                                 "surface_scatter_sampler_3d", "transform_3d_math", "noise_field_tools", "voronoi_2d",
                                 "segment_visibility_2d"),
}
CASES = {
    "terrain_rgb8_256": ("native", "portable"), "terrain_rgb8_512": ("native", "portable"),
    "height_queries_64": ("public",), "height_queries_512": ("public",), "surface_scatter_512": ("public",),
    "noise_96": ("public",), "noise_256": ("public",),
    "voronoi_64": ("public", "insertion"), "voronoi_256": ("public", "insertion"),
    "voronoi_512": ("public", "insertion"),
    "flow_open_32": ("public", "native_probe"), "flow_open_64": ("public", "native_probe"),
    "wfc_entropy_8": ("native", "portable", "mrv"), "wfc_entropy_16": ("native", "portable", "mrv"),
    "wfc_weighted_fixed_12": ("native", "portable"), "wfc_128_tiles_8": ("native", "portable"),
    **{f"visibility_84x{walls}": ("native", "portable", "native_handoff", "portable_handoff", "main_native", "main_portable")
       for walls in (8, 14)},
}
MATH_DIR = Path("addons/gf/standard/foundation/math")
BASELINES = {"height": ("heightfield_3d", "GFHeightfield3D"), "flow": ("grid_path_math_2d", "GFGridPathMath2D"),
             "noise": ("noise_field_tools", "GFNoiseFieldTools"), "voronoi": ("voronoi_2d", "GFVoronoi2D"),
             "flow_coordinates": ("grid_coordinate_math_2d", "GFGridCoordinateMath2D"),
             "scatter": ("surface_scatter_sampler_3d", "GFSurfaceScatterSampler3D")}


def profile_voronoi(source_path: Path, target: Path) -> None:
    """在所选实现的独立副本中测量站点插入循环，隔离其他 Voronoi 构建阶段。"""
    source = source_path.read_text(encoding="utf-8-sig")
    source, classes = re.subn(r"(?m)^class_name \w+$", "", source)
    source, bases = re.subn(r"(?m)^extends RefCounted$", "extends RefCounted\n\nstatic var insert_usec: int = 0", source)
    loop = r"(?m)^(\tfor point_index: int in range\(points\.size\(\)\):\n\t\t_insert_point\(\n(?:\t\t\t[^\n]*\n)+\t\t\)\n)"
    source, loops = re.subn(loop, lambda match: "\tvar started: int = Time.get_ticks_usec()\n" + match[0]
                            + "\tinsert_usec = Time.get_ticks_usec() - started\n", source)
    if (classes, bases, loops) != (1, 1, 1):
        raise ValueError(f"Cannot locate the Voronoi insertion loop in {source_path.name}")
    target.write_text(source, encoding="utf-8")


def runtime_sources() -> list[Path]:
    return [*(ROOT / "addons/gf" / folder / f"gf_{name}.gd"
              for folder, names in SOURCE_DIRS.items() for name in names),
            ROOT / "tests/native/segment_visibility/acceptance.gd"]


def stage(project: Path, probe: Path, native: Path) -> None:
    """在隔离工程中放入实际运行时、探针和原生库，使工作线程能够对照脚本与原生路径。"""
    for source in runtime_sources():
        target = project / source.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    shutil.copyfile(FIXTURE, project / "probe.gd")
    for dll, entry in ((probe, "gdext_rust_init"), (native, "gf_native_init")):
        shutil.copyfile(dll, project / dll.name)
        (project / f"{dll.stem}.gdextension").write_text(
            f'[configuration]\nentry_symbol="{entry}"\ncompatibility_minimum="4.6"\n'
            f'[libraries]\nwindows.x86_64="./{dll.name}"\n', encoding="utf-8")
    profile_voronoi(project / MATH_DIR / 'gf_voronoi_2d.gd', project / 'profile_voronoi.gd')
    # 在同一发布二进制的同一工作线程上，只把能力查询指向缺席的类，以测量真实脚本适配层。
    # 打包验收另测纯脚本安装。
    visibility = (project / MATH_DIR / 'gf_segment_visibility_2d.gd').read_text(encoding="utf-8")
    service = '&"GfSegmentVisibilityBackend"'
    if visibility.count(service) != 1:
        raise ValueError("Expected one visibility capability lookup in the staged facade")
    (project / "portable_visibility.gd").write_text(
        visibility.replace("GFSegmentVisibility2D", "GFPortableVisibilityBenchmark")
        .replace(service, '&"GfAbsentVisibilityBenchmarkBackend"'), encoding="utf-8")
    (project / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="GF Foundation Benchmark"\nrun/main_scene="res://main.tscn"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
    (project / "main.tscn").write_text(
        '[gd_scene format=3]\n[ext_resource type="Script" path="res://probe.gd" id="1"]\n'
        '[node name="Benchmark" type="Node"]\nscript=ExtResource("1")\n', encoding="utf-8")
    (project / "export_presets.cfg").write_text(
        '[preset.0]\nname="Windows"\nplatform="Windows Desktop"\nrunnable=true\nexport_filter="all_resources"\n'
        'include_filter=""\nexclude_filter=""\n[preset.0.options]\nbinary_format/architecture="x86_64"\n'
        'binary_format/embed_pck=false\napplication/modify_resources=false\n', encoding="utf-8")


def stage_baseline(project: Path, kind: str, path: Path) -> str:
    """将指定版本的实现装入基准工程并返回原始源码摘要，拒绝类型声明不符的文件。"""
    data = path.read_bytes()
    source = data.decode("utf-8-sig").replace("\r\n", "\n")
    _, class_name = BASELINES[kind]
    if not re.search(rf"(?m)^class_name {class_name}\s*$", source):
        raise ValueError(f"{path} must declare {class_name}")
    if kind == "scatter":
        source = re.sub(r"\bGFHeightfield3D\b", "GfBenchmarkGFHeightfield3DBaseline", source)
    if kind == "flow":
        source = re.sub(r"\bGFGridCoordinateMath2D\b", "GfBenchmarkGFGridCoordinateMath2DBaseline", source)
    (project / f"{kind}_baseline.gd").write_text(
        re.sub(rf"\b{class_name}\b", f"GfBenchmark{class_name}Baseline", source), encoding="utf-8")
    return hashlib.sha256(data).hexdigest()


def summarize(output: str, baselines: dict[str, str]) -> dict:
    """要求输出中只有一份基准报告，并核对对照组身份、测量与结果。"""
    prefix = "GF_FOUNDATION_BENCHMARK="
    records = [json.loads(line[len(prefix):]) for line in output.splitlines() if line.startswith(prefix)]
    if len(records) != 1:
        raise ValueError("Expected exactly one benchmark report")
    report = records[0]
    if (report["release"] is not True or report["failures"] or report["warmups"] != 2
            or report["samples"] != 9 or [case["name"] for case in report["cases"]] != list(CASES)):
        raise ValueError(f"Incomplete differential run: {report}")
    if report.get("geometry_comparisons") != (504 if "voronoi" in baselines else 0):
        raise ValueError("Incomplete geometry differential corpus")
    medians = {}
    for case in report["cases"]:
        name = case["name"]
        kind = name.split("_", 1)[0]
        required = set(CASES[name])
        baseline_kind = {"terrain": "height", "surface": "scatter"}.get(kind, kind)
        if baseline_kind in baselines and baseline_kind in {"height", "noise", "voronoi", "flow", "scatter"}:
            required.add("previous")
        if kind == "voronoi" and "voronoi" in baselines:
            required.add("previous_insertion")
        if set(case["usec"]) != required:
            raise ValueError(f"Incomplete measurements for {name}")
        medians[name] = case["median_ms"] = {}
        for mode, samples in case["usec"].items():
            if len(samples) != report["samples"] or any(type(value) is not int or value <= 0 for value in samples):
                raise ValueError(f"Invalid {mode} samples for {name}")
            medians[name][mode] = statistics.median(samples) / 1000
    # 两条路径用同一组有效像素调用公开解码器，主线程退回脚本仍可能给出相同数值，耗时须单独检验。
    terrain = medians["terrain_rgb8_512"]
    if terrain["native"] > terrain["portable"] * 0.5:
        raise ValueError("Installed Terrain-RGB decoder is not accelerating the public entry point")
    for workload, fraction in (("wfc_entropy_16", 0.5), ("wfc_weighted_fixed_12", 0.8),
                               ("wfc_128_tiles_8", 0.8)):
        wfc = medians[workload]
        if wfc["native"] > wfc["portable"] * fraction:
            raise ValueError(f"Installed WFC backend did not accelerate {workload}")
    for workload in ("visibility_84x8", "visibility_84x14"):
        if medians[workload]["native"] > medians[workload]["portable"] * 0.5:
            raise ValueError(f"Installed segment visibility backend did not accelerate {workload}")
    # 地图面积扩大 64 倍后，八次读取耗时应大致不变。计时下限和宽松比例容纳调度波动，仍可识别全图扫描。
    if medians["height_queries_512"]["public"] > max(0.020, medians["height_queries_64"]["public"]) * 8:
        raise ValueError("Eight height queries scale with grid area")
    if "voronoi" in baselines and medians["voronoi_512"]["public"] > medians["voronoi_512"]["previous"] * 1.5:
        raise ValueError("Building the 512-site Voronoi diagram regressed against the reference")
    return report


def fingerprint(paths: list[Path], base: Path = ROOT) -> dict[str, str]:
    """返回相对基准根目录的路径到文件内容 SHA-256 的映射。"""
    return {p.relative_to(base).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def main() -> None:
    """在 Windows 发布导出中运行基础能力基准，并核实本轮测量前后输入一致。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Godot editor with the matching Windows export template")
    parser.add_argument("--height-baseline", type=Path, help="Older trusted gf_heightfield_3d.gd for a paired comparison")
    parser.add_argument("--baseline-root", type=Path, help="Trusted reference worktree for paired public operations")
    parser.add_argument("--voronoi-baseline", type=Path, help="Reference geometry implementation for differential tests")
    args = parser.parse_args()
    if sys.platform != "win32":
        parser.error("This fixture qualifies Windows x86_64")
    godot = resolve_godot_executable(args.godot, environment=os.environ, cwd=ROOT)
    channel = tomllib.loads((CRATE / "rust-toolchain.toml").read_text(encoding="utf-8"))["toolchain"]["channel"]
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    log_root = ROOT / "ai_analysis/godot_logs/foundation_benchmark"
    log_root.mkdir(parents=True, exist_ok=True)
    logs = Path(tempfile.mkdtemp(prefix="run-", dir=log_root))
    deadline = time.monotonic() + 900
    target = build / "gf_native_target"
    inputs = [*runtime_sources(), FIXTURE, Path(__file__).resolve(), CRATE / "Cargo.lock", CRATE / "Cargo.toml", CRATE / "build.rs",
              CRATE / ".cargo/config.toml", CRATE / "rust-toolchain.toml",
              *sorted((CRATE / "examples/foundation_probe").glob("*.rs")), *sorted((CRATE / "src").rglob("*.rs"))]
    source_hashes = fingerprint(inputs)
    run(["cargo", f"+{channel}", "build", "--lib", "--example", "foundation_probe", "--release", "--locked",
         "--target", "x86_64-pc-windows-msvc", "--target-dir", str(target)], CRATE, "build", 600, logs, deadline)
    release = target / "x86_64-pc-windows-msvc/release"
    probe, native = release / "examples/foundation_probe.dll", release / "gf_native.dll"
    binary_hashes = fingerprint([native, probe], release)
    with tempfile.TemporaryDirectory(prefix="foundation-benchmark-", dir=build) as directory:
        sandbox = Path(directory)
        project = sandbox / "project"
        project.mkdir()
        stage(project, probe, native)
        baselines = {}
        if args.baseline_root:
            for kind, (filename, _) in BASELINES.items():
                baselines[kind] = stage_baseline(project, kind, args.baseline_root / MATH_DIR / f"gf_{filename}.gd")
        if args.height_baseline:
            baselines["height"] = stage_baseline(project, "height", args.height_baseline)
        if args.voronoi_baseline:
            baselines["voronoi"] = stage_baseline(project, "voronoi", args.voronoi_baseline)
        if "voronoi" in baselines:
            profile_voronoi(project / "voronoi_baseline.gd", project / "profile_previous_voronoi.gd")
        game = sandbox / "export/game.exe"
        game.parent.mkdir()
        editor = [str(godot), "--headless", "--path", str(project)]
        run([*editor, "--import"], project, "import", 120, logs, deadline)
        run([*editor, "--export-release", "Windows", str(game)], project, "export", 120, logs, deadline)
        engine_log = logs / "release-engine.log"
        output = run([str(game), "--headless", "--log-file", str(engine_log)], game.parent, "release", 150, logs, deadline)
        logged = engine_log.read_text(encoding="utf-8")
        check_engine_diagnostics(logged, "release", logs)
        report = summarize(output if "GF_FOUNDATION_BENCHMARK=" in output else logged, baselines)
        report["baseline_sha256"] = baselines
    report["platform"] = platform.platform()
    report["toolchain"] = channel
    if fingerprint(inputs) != source_hashes or fingerprint([native, probe], release) != binary_hashes:
        raise RuntimeError("Benchmark inputs changed during execution")
    report["source_sha256"] = source_hashes
    report["dll_sha256"] = binary_hashes
    reports = build / "foundation-benchmark-results"
    reports.mkdir(exist_ok=True)
    report_path = reports / f"{logs.name}.json"
    with report_path.open("x", encoding="utf-8") as stream:
        stream.write(json.dumps(report, indent=2) + "\n")
    for case in report["cases"]:
        print(case["name"], "  ".join(f"{mode} {value:.3f} ms" for mode, value in case["median_ms"].items()))
    print(report_path)


if __name__ == "__main__":
    main()
