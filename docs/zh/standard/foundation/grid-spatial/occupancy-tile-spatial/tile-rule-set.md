# Tile 规则表

`GFTileRuleSet` 是基于邻域值序列解析结果的资源化规则表。它只接收 `Variant` 邻域值并返回 `Variant` 结果，不绑定 Godot `TileSet` terrain、source id 或任何具体地图语义。

```gdscript
var rules := GFTileRuleSet.new()
rules.fallback_neighbor_value = 0
rules.default_result = &"plain"

# 例如按上、右、下、左四邻域状态选择结果。
rules.register_rule([1, 1, 1, 1], &"center")
rules.register_rule([1, 0, 1, 0], &"vertical")

var variant_id := rules.resolve([1, 0, 1, 0], Vector2i(4, 8))
```

同一规则可以注册多个带权重结果，并通过格坐标和 `selection_seed` 做 GF 固定算法选择。规则表内部使用 `GFDeterministicRandom` 派生单次选择，不依赖 Godot `hash()` 或 `RandomNumberGenerator` 的内部序列。

项目层仍负责定义邻域采样顺序、值含义和最终如何应用到 TileMap。
