# 通用节点树操作

`GFNodeTreeOps` 是纯静态节点树操作集合，不需要注册到 `GFArchitecture`。它适合编辑器工具、运行时装配、能力容器、对象池或场景工厂中复用一些容易写散的操作。

常见能力包括：

- 安全添加子节点并设置 `owner`。
- 重挂节点。
- 替换子节点。
- 按类型向上或向下查找。
- 收集节点树、直接子节点、后代、祖先和前后同级节点。
- 递归设置 owner。
- 释放直接子节点。

`free_children()` 会先把直接子节点从父节点移除，再调用 `queue_free()`，因此调用后父节点同帧就不再持有旧子节点。

节点收集 API 返回的是当次调用的快照数组，不会创建查询对象或持有场景树引用。`collect_descendants()` 和 `collect_node_tree()` 支持 `max_depth` 与 `limit`，适合编辑器工具或运行时装配代码在大场景里收窄遍历范围。需要频繁读取同一 `SceneTree` group 时，可改用 `GFNodeGroupCache` 缓存 group 快照。

```gdscript
var capability := HitboxCapability.new()
GFNodeTreeOps.add_child_with_owner(container, capability, get_tree().current_scene)

var camera := GFNodeTreeOps.find_first_child_of_type(root, Camera3D, true) as Camera3D
var all_controls := GFNodeTreeOps.collect_node_tree(root, Control)
var direct_buttons := GFNodeTreeOps.collect_children(panel, Button)
var parent_chain := GFNodeTreeOps.collect_ancestors(button, Control, true, 3)
var later_buttons := GFNodeTreeOps.collect_next_siblings(button, Button)
```

类型过滤可以传脚本类型、原生类或类名字符串；字符串形式会同时检查原生 `is_class()`、GDScript `class_name` 和脚本资源路径。

这个工具只处理通用 Node 结构，不判断节点是否应该属于某种业务容器。需要注册能力、同步存档、创建 UI 栈或切换场景时，仍应使用对应的 `GFCapabilityUtility`、`GFSaveGraphUtility`、`GFUIUtility` 或 `GFSceneUtility`。
