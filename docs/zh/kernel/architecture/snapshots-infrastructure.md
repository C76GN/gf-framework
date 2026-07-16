# Kernel 全局快照与内核基础设施

这一页说明 `GFArchitecture` 的全局快照能力，以及 Kernel 中可复用的脚本类型检查、对象属性访问和时间提供者协议。

## `GFArchitecture` 全局状态快照

`GFArchitecture` 提供了全局状态快照入口，用于收集所有已注册 `GFModel` 的 `to_dict()` 结果，并在存在实现命令历史序列化方法的 Utility 时附带命令历史：

```gdscript
var global_snapshot: Dictionary = Gf.architecture.get_global_snapshot()

Gf.architecture.restore_global_snapshot(global_snapshot, func(data):
	# 将命令历史中的字典恢复为项目自己的 Command 实例。
	pass
)
```

大型项目应优先使用分帧快照入口，再交给 Storage 的异步写入线程：

```gdscript
var snapshot := await Gf.architecture.get_global_snapshot_async({
	"max_models_per_frame": 8,
})
storage.save_data_async("profile.json", snapshot)
```

快照只负责框架层状态聚合。架构通过内部 `GFArchitectureSnapshotCoordinator` 调用 `GFModel.to_dict()` / `from_dict()` 强类型虚方法收集和恢复数据；恢复时每个 Model 条目必须是 `Dictionary`，否则会被跳过并记录 warning。`get_all_models_state_async()`、`restore_all_models_state_async()`、`get_global_snapshot_async()` 与 `restore_global_snapshot_async()` 会按 `max_models_per_frame` 分帧处理 Model；传 `0` 可关闭主动让帧。`Model` 的字段如何序列化、命令字典如何恢复成具体实例、以及最终写入哪个存档文件，仍由项目层决定。

快照返回值会先转换为 JSON 兼容数据，避免 `NaN`、对象引用、资源或不可表示类型在后续 `JSON.stringify()` 时才暴露问题。GF 只保证快照字典适合交给项目存储层继续处理；版本号、压缩、加密、签名和存档迁移仍属于项目策略。

Model 快照键优先使用 `GFModel.get_save_key()`，其次使用脚本声明的全局 `class_name`。GF 不再把脚本资源路径当作长期存档键；没有 `class_name` 的可序列化 Model 应重写 `get_save_key()`，并保证同一架构内唯一。

## 内核基础设施

### `GFScriptTypeInspector`

GDScript 脚本类型关系辅助，用于判断一个脚本是否等于或继承另一个脚本，并可读取从自身到根脚本的继承链。它适合编辑器索引、类型注册、能力查询和项目自己的轻量反射工具复用；它只处理 GDScript `Script` 继承关系，不替代 Godot 的节点类 `is_class()` 判断。

```gdscript
if GFScriptTypeInspector.script_extends_or_equals(player_script, GFController):
	print("This script is a GF controller.")

var chain := GFScriptTypeInspector.get_inheritance_chain(player_script)
```

### `GFObjectPropertyTools`

Godot `Object` 属性访问辅助，用于集中查询 `get_property_list()` 元信息、读取/写入 `NodePath` 属性路径、判断只读属性，并在写入前做基础 `Variant.Type` 校验和少量安全转换。它适合框架级编辑器工具、调试工具和通用序列化器复用同一套属性边界判断。

```gdscript
if GFObjectPropertyTools.can_write_property(node, ^"position:x"):
	var result := GFObjectPropertyTools.write_property(node, ^"position:x", 120.0)
	if not result["ok"]:
		push_warning(result["error"])
```

需要把一组声明属性作为工具状态、编辑器草稿或轻量配置暂存时，可以用字典快照入口。默认只导出 `PROPERTY_USAGE_STORAGE` 属性，并复制集合值；写回时会逐项返回报告，未知字段或只读字段不会静默吞掉：

```gdscript
var snapshot := GFObjectPropertyTools.object_to_dictionary(node, {
	"include_properties": ["name", "position", "visible"],
})

var report := GFObjectPropertyTools.apply_dictionary(node, snapshot, {
	"ignore_unknown_properties": true,
})
if not report["ok"]:
	push_warning(str(report["issues"]))
```

`GFObjectPropertyTools` 只处理 Godot 属性机制本身，不做属性绑定、自动派发、表达式执行、转换管线或业务字段解释。需要长期监听属性变化、把属性映射到玩法数据，或定义复杂编辑器表单时，应在项目自己的模块或更高层工具中组合它，而不是把这些语义写入内核。

### `GFTimeProvider`

`GFTimeProvider` 是 `GFArchitecture.tick()` / `physics_tick()` 识别的时间控制协议。标准库的 `GFTimeUtility` 继承该协议来提供全局暂停、时间缩放和物理子步；项目也可以实现自己的时间提供者，只要继承 `GFTimeProvider` 并注册为 Utility。

局部 `GFArchitecture` 未注册自己的 `GFTimeProvider` 时，会在非严格依赖查询模式下动态回退到父级架构的时间提供者。父级后续注册、替换或注销时间提供者时，子架构下一帧会按当前父级状态重新解析，不需要重新初始化局部上下文。
