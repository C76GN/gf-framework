# 节点 Group 查询缓存

`GFNodeGroupCache` 用于缓存 `SceneTree.get_nodes_in_group()` 的节点快照，适合相机 Rig、交互候选、物理探针、编辑器预览或项目侧注册表这类会频繁读取同一 group 的场景。它只处理 Godot group 和可选类型过滤，不规定节点业务语义。

```gdscript
var cache := GFNodeGroupCache.from_tree(get_tree(), &"interactable", Area3D)

for node in cache.get_nodes():
	var area := node as Area3D
	# 项目层自行处理 area。
```

缓存会监听 `SceneTree.node_added` 和 `SceneTree.node_removed`，节点进入或离开树时自动标记为脏。下一次 `get_nodes()` 会重建快照；缓存干净时读取会复用上一次结果，并在返回前剪掉已释放、离树、移出 group 或不再匹配类型过滤的旧节点。

Godot 没有通用的 group membership 变化信号。运行时如果对已经在树内的节点调用 `add_to_group()` 或 `remove_from_group()`，并且希望立刻被缓存看见，应在项目代码里调用：

```gdscript
cache.invalidate(&"group_membership_changed")
```

`get_nodes()` 返回的是快照数组，调用方修改该数组不会影响缓存内部状态。需要观察缓存行为时可以读 `get_debug_snapshot()`，其中包含 group 名、脏标记、节点数量、类型过滤文本和 `GFCacheDiagnostics` 统计。

`GFNodeGroupCache` 不替代显式注册表。需要 owner/token 生命周期、优先级、候选打分或跨场景持久化时，应在项目层或对应 Utility 中组合它，而不是把业务注册规则塞进 group cache。
