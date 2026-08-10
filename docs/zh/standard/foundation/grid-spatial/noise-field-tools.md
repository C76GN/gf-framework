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

## 与其他模块的关系

- `GFHeightfield3D.from_samples()` 可消费 `samples`，把二维噪声场解释为 X/Z 高度场。
- `GFPoissonDisc2D` 负责最小间距点集；`GFNoiseFieldTools` 可为点集后续筛选提供权重。
- `GFSeedUtility` 负责项目级 seed 派生；本工具只读取显式 `seed` 或调用方提供的 `FastNoiseLite`。
- `GFVariantJsonCodec` 可用于需要保留特殊 Variant 类型的存储；本工具自身会拒绝非有限采样值，避免普通 JSON 入口出现 `NaN` 警告。
