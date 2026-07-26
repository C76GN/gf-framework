# Kernel 全局快照与内核基础设施

这一页说明 `GFArchitecture` 的全局快照能力，以及 Kernel 中可复用的脚本类型检查、对象属性访问和时间提供者协议。

## `GFArchitecture` 全局状态快照

`GFArchitecture` 提供了全局状态快照入口，用于收集所有已注册 `GFModel` 的 `to_dict()` 结果，并在存在实现命令历史序列化方法的 Utility 时附带命令历史。捕获入口返回显式 Result；只有 `ok == true` 时才存在可持久化的 `snapshot`：

```gdscript
var capture_result: Dictionary = Gf.architecture.get_global_snapshot()
if not capture_result["ok"]:
	push_error(capture_result["error"])
	return

var global_snapshot: Dictionary = capture_result["snapshot"]
var restore_result: Dictionary = Gf.architecture.restore_global_snapshot(global_snapshot, func(data):
	# 将命令历史中的字典恢复为项目自己的 Command 实例。
	pass
)
if not restore_result["ok"]:
	push_error(
		"快照恢复在 %s 阶段失败（rolled_back=%s）：%s"
		% [
			restore_result["phase"],
			restore_result["rolled_back"],
			restore_result["error"],
		]
	)
```

大型项目应优先使用分帧快照入口，再交给 Storage 的异步写入线程：

```gdscript
var capture_result := await Gf.architecture.get_global_snapshot_async({
	"max_models_per_frame": 8,
})
if capture_result["ok"]:
	storage.save_data_async("profile.json", capture_result["snapshot"])
```

快照只负责框架层状态聚合。架构通过内部 `GFArchitectureSnapshotCoordinator` 调用 `GFModel.to_dict()` / `from_dict()` 强类型虚方法收集和恢复数据。捕获失败与“合法的空 Model 集合”不再共享 `{}`：`get_all_models_state()` / `get_global_snapshot()` 及其 async 版本都返回 `{ ok, snapshot?, error }`，失败结果不包含 `snapshot`。

恢复采用 `validate → apply → commit` 事务。输入格式、稳定 Model key、命令历史能力或 `command_builder` 不合法时在 `validate` 阶段失败且不写状态；`restore_all_models_state*()` 与全局 restore 都要求快照 Model key 集合和当前可序列化 Model 精确一致，缺项、未知项或非 `String` key 均拒绝，不提供 partial restore。任一 Model 的 `from_dict()` 结果与目标不一致时，已经应用的 Model 会按相反顺序恢复到捕获的基线；命令历史提交失败时会同时回滚历史和所有 Model。每个业务回调之后以及全部 Model/历史回调完成后，事务都会重新核对 registry identity、save key 和整组最终状态，后序 Model 或历史回调不能回写已验证的前序 Model 后仍让 restore 成功。

四个 capture 与四个 restore 入口共享同一个 single-flight snapshot transaction gate：同步、异步、Model-only 与全局操作不能交错，`Model.to_dict()`、`Model.from_dict()` 或命令历史 callback 中重入任意 capture/restore 入口也会在继续读写前失败。restore 的 busy Result 保持 `{ ok = false, phase = &"busy", rolled_back = false, error }`；capture 的 busy Result 保持原有 `{ ok = false, error }` 契约并附加稳定的 `phase = &"busy"`，且绝不包含 `snapshot`。持有 gate 的全局操作只调用内部无锁 helper，不会把自己的 Model/历史步骤误判为新事务。事务完成后 generation owner 会统一释放，后续 capture 或 restore 可再次进入。

capture 使用固定的两次观察协议，而不是“重试直到稳定”：先按注册顺序冻结 Model，并在全局捕获中随后冻结命令历史；再按相反顺序重新读取命令历史和所有 Model，要求两次 JSON 状态完全相同，同时在每个 callback 前后复核 registry identity 与稳定 key。这样，后序 `Model.to_dict()` 改写已经捕获的前序 Model，或 History serializer 改写任何 Model 时，捕获都会显式失败且不返回 `snapshot`。复核 callback 仍处于同一 snapshot gate 内，重入 capture/restore 只会得到 `busy` Result。

有限次数的读取无法为任意带写副作用的 getter 证明最终状态，因此 `Model.to_dict()` 与命令历史 `serialize_full_history()` 的契约是：对整个快照域无副作用，并在同一 capture 事务中返回确定性结果。GF 不会为计数器、时间、随机值、惰性写缓存或跨对象改写做猜测式收敛；只要两次观察不同就 fail closed。成功 Result 表示正序冻结与反序复核观察到同一份 JSON 状态，不表示 GF 接受有副作用的 serializer。

`get_all_models_state_async()`、`restore_all_models_state_async()`、`get_global_snapshot_async()` 与 `restore_global_snapshot_async()` 会按 `max_models_per_frame` 分帧物化或应用 Model；传 `0` 可关闭主动让帧。async capture 会在第一次 `await` 前完成全部 Model/命令历史的初始冻结与稳定性复核，分帧阶段不再重新调用业务对象；其 snapshot gate 会一直持有到最终 Result 提交，等待期间的 capture/restore 会 fail closed。等待期间若 Model 注册身份或稳定 key 改变，整个捕获显式失败，不会返回混合时点快照。`Model` 的字段如何序列化、命令字典如何恢复成具体实例、以及最终写入哪个存档文件，仍由项目层决定。

全局快照载荷固定包含精确整数 `format_version: 1` 与 `models: Dictionary`，可选包含 `command_history: Dictionary`。restore 会拒绝缺少版本、bool/float/字符串形式的版本 `1`、旧式命令历史 Array、非字符串 Model key 或其他畸形载荷；本次变更不提供旧格式兼容层。迁移时应重新捕获存档，或由项目层先把旧数据转换成版本 `1` 且 Model key 集合完整的载荷，再调用 GF restore。

快照内容会先转换为 JSON 兼容数据，避免 `NaN`、对象引用、资源或不可表示类型在后续 `JSON.stringify()` 时才暴露问题。GF 只保证成功 Result 中的 `snapshot` 适合交给项目存储层继续处理；压缩、加密、签名和后续格式迁移仍属于项目策略。

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

路径写入与直接属性写入是两个不同协议。`write_property()` 接受 `NodePath`，支持 Object、Dictionary 和 Godot 内置数学类型的公开子属性，并在调用引擎 setter 后读取实际值确认写入成功；无法解析的路径会在写入前失败。`write_direct_property()` 接受精确 `StringName`，不会把属性名里的 `/` 或 `:` 当成路径分隔符。`object_to_dictionary()` / `apply_dictionary()` 使用后者完成对称 round-trip，并过滤 property list 中的 group、subgroup 和 category 描述符。

### `GFTimeProvider`

`GFTimeProvider` 是 `GFArchitecture.tick()` / `physics_tick()` 识别的时间控制协议。标准库的 `GFTimeUtility` 继承该协议来提供全局暂停、时间缩放和物理子步；项目也可以实现自己的时间提供者，只要继承 `GFTimeProvider` 并注册为 Utility。

局部 `GFArchitecture` 未注册自己的 `GFTimeProvider` 时，会在非严格依赖查询模式下动态回退到父级架构的时间提供者。父级后续注册、替换或注销时间提供者时，子架构下一帧会按当前父级状态重新解析，不需要重新初始化局部上下文。
