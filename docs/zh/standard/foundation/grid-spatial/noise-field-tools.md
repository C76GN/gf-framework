# 2D 噪声场采样

`GFNoiseFieldTools` 用于把 Godot 原生 `FastNoiseLite` 或项目提供的采样回调转换成行优先 `PackedFloat32Array`，并返回最小值、最大值、平均值和归一化样本。它适合程序化地形草图、权重图、刷点候选、编辑器预览和配置生成前的数据准备。

它不创建节点、贴图、材质、地形、碰撞或具体内容对象。鱼、飞船、植被、敌人、地图房间等内容语义应由项目层读取采样报告后自行解释。

## 基本用法

使用默认 `FastNoiseLite`：

```gdscript
var report := GFNoiseFieldTools.sample_grid_2d(
	Vector2i(64, 64),
	{
		"seed": 123,
		"frequency": 0.04,
		"origin": Vector2.ZERO,
		"step": Vector2.ONE,
	}
)

if report["ok"]:
	var samples: PackedFloat32Array = report["samples"]
	var normalized: PackedFloat32Array = report["normalized_samples"]
```

需要接入项目自有采样规则时，传入 `sampler`：

```gdscript
var report := GFNoiseFieldTools.sample_grid_2d(
	Vector2i(8, 8),
	{
		"metadata": { "scale": 2.0 },
		"sampler": func(position: Vector2, cell: Vector2i, metadata: Dictionary) -> float:
			var scale: float = GFVariantData.get_option_float(metadata, "scale", 1.0)
			return position.x * scale + float(cell.y),
	}
)
```

`sampler` 只应返回可由 `PackedFloat32Array` 表示的有限 `int` 或 `float`。返回 `NaN`、`Infinity`、非数字值，或写入 float32 后变成非有限值，都会让报告失败且不保留部分样本。成功报告的最小值、最大值与平均值均按实际返回的 float32 样本计算；请求归一化时，归一化失败也会传播到外层报告。

## 返回结构

`sample_grid_2d()` 返回一个 Dictionary：

- `ok` / `error`：采样是否成功。
- `source`：`callable` 或 `fast_noise_lite`。
- `grid_size`、`origin`、`step`：采样网格与坐标映射。
- `sample_count`：样本数量。
- `samples`：行优先原始浮点样本。
- `min_value`、`max_value`、`average`：原始样本统计。
- `normalized_samples`：默认生成的 0.0 到 1.0 归一化样本。
- `constant_range`：样本范围是否为常量。

`normalize_samples()` 可单独归一化已有 `PackedFloat32Array`，并支持 `minimum`、`maximum`、`constant_value` 和 `clamp` 选项。

## 选项

- `sampler`：可选 `Callable(position: Vector2, cell: Vector2i, metadata: Dictionary) -> int|float`。存在时优先使用。
- `metadata`：传给 `sampler` 的项目侧元数据副本。
- `noise`：可选 `FastNoiseLite` 实例。未提供 `sampler` 时使用。
- `seed`、`frequency`、`noise_type`、`fractal_octaves`：未提供 `noise` 时创建默认 `FastNoiseLite` 的基础参数。
- `origin`、`step`：把网格坐标映射为采样坐标。
- `include_normalized`：是否生成归一化样本，默认 `true`。
- `constant_value`：常量范围归一化时填入的值，默认 `0.0`。
- `max_samples`：最大样本数量，默认 `GFNoiseFieldTools.DEFAULT_MAX_GRID_SAMPLES`。

## 分块采样与共享边缘

连续世界中的各块应使用相同的噪声配置、seed 和世界采样坐标。`origin + cell * step` 决定实际采样位置；不要让每块都从 `Vector2.ZERO` 开始，也不要为相邻块重新随机 seed。

下面用同一个噪声资源采样两块高度顶点。每块有 65 × 65 个顶点，相邻块共享一列，因此原点相差 64 个采样间隔：

```gdscript
var noise := FastNoiseLite.new()
noise.seed = 123
noise.frequency = 0.04

var grid_size := Vector2i(65, 65)
var step := Vector2.ONE
var left_report := GFNoiseFieldTools.sample_grid_2d(grid_size, {
	"noise": noise,
	"origin": Vector2.ZERO,
	"step": step,
	"include_normalized": false,
})
var right_report := GFNoiseFieldTools.sample_grid_2d(grid_size, {
	"noise": noise,
	"origin": Vector2(float(grid_size.x - 1) * step.x, 0.0),
	"step": step,
	"include_normalized": false,
})

if left_report["ok"] and right_report["ok"]:
	var left: PackedFloat32Array = left_report["samples"]
	var right: PackedFloat32Array = right_report["samples"]
	for row: int in range(grid_size.y):
		assert(left[row * grid_size.x + grid_size.x - 1] == right[row * grid_size.x])
```

共享边缘的顶点网格沿每个轴按 `(grid_size - 1) * step` 推进；互不重叠的格子数据按 `grid_size * step` 推进。需要两轴分块时，分别计算 X/Y 原点。自定义 `sampler` 也应以世界 `position` 为连续场的坐标；`cell` 是每块内部从零开始的索引。

`samples` 保留原始采样值；默认 `normalized_samples` 则按**本次网格自己的最小值与最大值**归一化。即使两块边缘的原始值相同，分别归一化也可能产生接缝。例如左块 `[0, 1, 2]` 和右块 `[2, 3, 4]` 的公共边缘都是 `2`，逐块归一化后却分别为 `1` 和 `0`。

高度场可以直接消费原始 `samples`。确需归一化时，先用 `include_normalized=false` 采样，再让所有块通过 `normalize_samples()` 使用同一组 `minimum` / `maximum`。例如对上述数列统一使用 `[0, 4]`，两边公共边缘都会得到 `0.5`：

```gdscript
var shared_range := { "minimum": 0.0, "maximum": 4.0 }
var left := GFNoiseFieldTools.normalize_samples(PackedFloat32Array([0.0, 1.0, 2.0]), shared_range)
var right := GFNoiseFieldTools.normalize_samples(PackedFloat32Array([2.0, 3.0, 4.0]), shared_range)
```

这里的 `[0, 4]` 只属于数列示例。真实范围应来自项目的采样规则或全域统计，不要假定所有噪声模式都落在 `[-1, 1]`。多个请求使用共享资源时，也应保持其配置不变，直到这一批采样结束。

## 与其他模块的关系

- `GFHeightfield3D.from_samples()` 可消费 `samples`，把二维噪声场解释为 X/Z 高度场。
- `GFPoissonDisc2D` 负责最小间距点集；`GFNoiseFieldTools` 可为点集后续筛选提供权重。
- `GFSeedUtility` 负责项目级 seed 派生；本工具只读取显式 `seed` 或调用方提供的 `FastNoiseLite`。
- `GFVariantJsonCodec` 可用于需要保留特殊 Variant 类型的存储；本工具自身会拒绝非有限采样值，避免普通 JSON 入口出现 `NaN` 警告。
