# 通用设置存储

游戏设置页通常会混合窗口模式、分辨率、语言、音量、难度、辅助功能等数据。如果这些逻辑直接写进 UI 节点，后续存档、重置默认值、平台差异和测试都会变得困难。

`GFSettingsUtility` 是设置定义、当前值、暂存值和待保存快照的内存核心，不知道它们会被哪个 UI、引擎 API 或物理存储使用。持久化通过独立的 `GFSettingsStoreUtility` 同步端口接入。

```gdscript
var settings := Gf.get_utility(GFSettingsUtility) as GFSettingsUtility

settings.register_setting(
	&"gameplay/difficulty",
	"normal",
	GFSettingDefinition.ValueType.STRING
)
settings.set_value(&"gameplay/difficulty", "hard")
var save_error: Error = settings.save_settings()
if save_error != OK:
	push_warning("设置保存失败：%s" % error_string(save_error))
```

`GFSettingDefinition` 可以资源化描述稳定键、默认值、值类型、是否持久化和 UI 元数据。`set_value()` 会按定义做类型转换，`to_dict(true)` 只导出持久化设置；未注册定义的临时值也能读写，但不会获得默认值、类型钳制或元数据。

## 持久化端口与运行模式

`GFSettingsStoreUtility` 只定义三个物理同步入口：`is_persistence_enabled()` 查询 capability，`read_settings(file_name)` 返回 `GFStorageReadResult`，`write_settings(file_name, data)` 返回 Godot `Error`。自定义后端必须保留成功空字典与失败终态的区别，不能用 `{}` 同时表达“空设置”和“读取失败”。

| 实现 | 源码位置 | 用途 |
| --- | --- | --- |
| `GFSettingsFileStoreUtility` | `standard/utilities/settings` | 把 JSON 写入 `user://`，保留 standalone 的历史默认行为 |
| `GFSettingsNullStoreUtility` | `standard/utilities/settings` | 显式返回 `UNAVAILABLE` 的 capability 哨兵，适合测试或缺失后端诊断 |
| `GFStorageSettingsStoreUtility` | `standard/utilities/settings_storage` | 声明并缓存 `GFStorageUtility` 依赖，把 Settings 端口同步转发到 Storage |

完整 GF 插件已经包含这些实现。只需要内存核心或 File Store 时直接使用 `GFSettingsUtility`；该端口在本阶段仍复用 `GFStorageReadResult`，所以这里的中立性是后端中立，不表示类型已经与 Storage 完全解耦。Architecture 要复用 `GFStorageUtility` 的 root、完整性与恢复边界时，使用 `GFStorageSettingsStoreUtility` adapter。

### Standalone 兼容路径

脱离 Architecture 直接创建 `GFSettingsUtility` 时，`init()` 仍会在 `persistence_enabled=true` 且没有预置 Store 的情况下自动持有一个 `GFSettingsFileStoreUtility`，并按 `auto_load_on_init` 立即尝试一次加载。后续再调用 `begin_activation()` 不会重复这次 standalone 加载，因此既有 `init()` 调用形状保持兼容。

```gdscript
var settings := GFSettingsUtility.new()
settings.storage_file_name = "settings.sav"
settings.init()
```

需要纯内存设置时，应在生命周期计划冻结前关闭持久化：

```gdscript
var settings := GFSettingsUtility.new()
settings.persistence_enabled = false
settings.init()
```

此模式不要求 Store，不执行 FileAccess，加载和保存入口会明确报告不可用，但设置定义、默认值、暂存与批量应用仍可使用。`GFSettingsNullStoreUtility` 不是纯内存开关；启用持久化却注册 Null Store 会让 Architecture 激活因 capability 不可用而失败。

### Architecture 激活与迁移

Architecture 模式不会隐式回退到 `user://`。启用持久化时，项目必须在初始化前把一个可用实现注册为精确的 `GFSettingsStoreUtility` alias；只按具体实现类型注册不能满足 Settings 的依赖声明。迁移时按原有后端分流：

- 原先依赖隐式 `user://` fallback 的项目，注册 `GFSettingsFileStoreUtility` 为精确 base alias，保持文件语义不变。
- 原先已经让 Settings 复用 `GFStorageUtility` 的项目，使用 `GFStorageSettingsStoreUtility`，并把它注册为精确 base alias。
- 不需要持久化的项目，在注册和初始化前设置 `persistence_enabled=false`，不注册 Store。

下面演示第二条 Storage adapter 路径：

```gdscript
var architecture := GFArchitecture.new()
var storage := GFStorageUtility.new()
var settings_store := GFStorageSettingsStoreUtility.new()
var settings := GFSettingsUtility.new()

await architecture.register_utility_instance(storage)
await architecture.register_utility_instance_as(
	settings_store,
	GFSettingsStoreUtility
)
await architecture.register_utility_instance(settings)

if not await architecture.init():
	push_error("Settings Architecture 激活失败。")
```

依赖 DAG 会先让 `GFStorageUtility` ready，再让 adapter 缓存依赖，最后在 Settings activation 中执行 `auto_load_on_init`。File Store 路径同样必须使用 `register_utility_instance_as(file_store, GFSettingsStoreUtility)` 注册精确 alias。所有 Store、文件名和 `persistence_enabled` 配置都应在注册与初始化前完成。原先通过继承 `GFSettingsUtility` 覆写物理读写的项目，应把后端逻辑移到 `GFSettingsStoreUtility` 派生类的三个公开入口，并按上述 base alias 注册。

持久化设置会保留 `Vector2`、`Vector2i`、`Color`、`StringName` 等常见 Godot 值；其他需要 JSON 类型标记的值会复用 `GFVariantJsonCodec`，因此超出 JSON 安全范围的 64 位整数也能精确往返。字典 key 也会使用稳定编码，避免 `1` 与 `"1"` 等跨类型 key 在 JSON 对象中互相覆盖；循环引用会让保存返回 `ERR_INVALID_DATA`，调用方应先清理设置值。

File Store 的文件名必须是简单 basename，不能包含路径分隔符、`..`、盘符、绝对路径或首尾空白。需要把设置写到其他逻辑目录时，应实现明确的 Store，不能把外部路径塞进 File Store 文件名。

File Store 保存的 `OK` 与 `settings_saved` 只在 payload 实际写入且 `FileAccess` 没有报告错误时产生；文件可以打开但写入失败时会返回真实 `Error`，不会发出成功信号。显式 `save_settings()` / `flush_pending_save()` 的调用方应处理该错误，不能仅凭启用 `auto_save_on_change` 假定永久落盘成功。

从合法持久化数据恢复时使用 `replace_from_dict()`：输入中缺失的已定义键恢复默认值，缺失的未定义旧键被移除；`load_settings()` 固定采用这一语义。只有明确把输入当作覆盖层时才使用 `merge_from_dict()`，它会保留输入中未出现的当前值。两种入口分离后，切换 profile 或读取合法空对象不会静默继承上一份 profile 的残留字段。

## 结构化加载与恢复

`load_settings()` 返回 `GFSettingsLoadResult`，调用方应先检查终态，再读取当前设置。合法空对象 `{}` 是一次成功加载；文件缺失、空文件、格式损坏、完整性失败、未来 schema、迁移失败和 IO 失败则保留各自的稳定分类，不再被折叠为空字典。

```gdscript
var result: GFSettingsLoadResult = settings.load_settings()
if result.is_successful():
	print("设置终态：", result.get_status())
else:
	push_warning("设置加载失败：%s" % result.get_error())
```

默认的 null 恢复策略是严格模式：失败不会修改当前有效值或暂存值，也不会创建、修复或覆盖源文件。项目确实接受缺失或损坏数据时，必须显式提供 `GFSettingsRecoveryPolicy`。恢复只支持保留当前内存状态或重置为已注册默认值；未来 schema、迁移失败和存储 IO 失败始终不可恢复。

```gdscript
var policy := GFSettingsRecoveryPolicy.new()
policy.missing_file_action = GFSettingsRecoveryPolicy.ACTION_USE_CURRENT_STATE
policy.corrupt_file_action = GFSettingsRecoveryPolicy.ACTION_RESET_TO_DEFAULTS

var result: GFSettingsLoadResult = settings.load_settings("", policy)
if result.was_recovered():
	print("恢复动作：", result.get_recovery_action())
```

加载与恢复本身都不会保存。确认恢复结果符合项目决策后，如需持久化默认值，调用方应在独立步骤中显式调用 `save_settings()`。这样损坏证据不会在读取阶段被静默覆盖。

使用 `GFStorageSettingsStoreUtility` 时，`ACTION_RESET_TO_DEFAULTS` 只恢复内存；若底层 Storage family 的 catalog、owner 或事务 identity 已损坏，直接保存仍会失败。调用方必须从本次 `GFSettingsLoadResult` 取回来源绑定的原始 Storage 证据，显式 reset 同一 logical family，并且只在 reset 完整成功后保存默认值：

```gdscript
var target_file_name: String = settings.storage_file_name
var result: GFSettingsLoadResult = settings.load_settings("", policy)
if result.was_recovered():
	var observed: GFStorageReadResult = result.get_storage_result()
	if observed != null and \
		observed.failure_kind == GFStorageReadResult.FailureKind.CORRUPT:
		# 复用前文注册到同一 architecture、并产生 observed 的 storage 实例。
		var authorization: GFStorageFamilyResetAuthorization = \
			storage.create_family_reset_authorization(target_file_name, observed)
		var reset_result: GFStorageFamilyResetResult = \
			storage.reset_file_family(target_file_name, authorization)
		if reset_result.is_successful():
			var save_error: Error = settings.save_settings(target_file_name)
			if save_error != OK:
				push_error("无法持久化恢复后的默认设置：%s" % error_string(save_error))
```

授权按 attempt 一次性消费并绑定同一 Utility、root 与 canonical logical identity。reset 物理失败后，只有来源绑定结果的授权资格字段 `ok`、`error_code` 与 `failure_kind` 仍匹配签发快照，才能重新签发新授权；不能序列化、合成或跨文件复用证据。`MISSING` 可按项目政策直接创建新设置，未来 schema、迁移失败和普通 IO 失败不能走 reset。File Store 或其他自定义 Store 继续由各自适配器定义破坏性恢复，Settings 核心不会解析 `.gf-storage` 私有布局。

非空策略会在存储读取前完整校验；未知动作返回 `STATUS_INVALID_REQUEST`，不会访问存储或取消既有保存队列。合法加载请求一旦开始，则会作为全局顺序屏障取消此前尚未执行的延迟保存和批处理保存请求，而不只取消同名文件，避免加载 B 后把新内存状态写回旧来源 A。

`auto_load_on_init` 使用严格 null 策略。启动阶段需要自定义恢复时，应把它设为 `false`，先完成设置定义注册，再显式调用带策略的 `load_settings()`；不要依赖初始化时自动猜测恢复动作。每次终态都会通过 `settings_load_completed` 发出隔离结果，也可用 `get_last_load_result()` 获取最近结果的副本。

自动保存默认会按 `save_debounce_seconds` 做防抖，避免设置页拖动滑块时每次变化都落盘。需要一次性应用多个字段时，可用 `begin_batch()` / `end_batch()` 包裹，或手动 `queue_save()` 后在合适时机 `flush_pending_save()`。

## 静默、排空与重试

每次保存请求获准时，Settings 会冻结目标文件名和持久化 payload 快照；同一目标后续获准的新快照替代旧快照，不同目标则分别保留。未在 flush 开始前取消的 `begin_quiesce()` 会先关闭设置变化与新保存请求的准入，再把尚未结束的 batch 提升为待保存记录，并按准入顺序 flush 全部目标，而不是只处理调用时的 `storage_file_name`。Store 写入期间的同步重入也无法越过已经关闭的 mutation gate。

如果绑定的 scope 在同步 flush 启动前已取消，quiesce completion 以 `CANCELLED` 终结：这条路径仍关闭准入并提升开放 batch，但不会启动 Store I/O，pending 记录继续保留。若 scope 在某个同步 Store write 内被取消，已经启动的当前 write 仍按真实结果结算；循环会在启动下一个 target 前停止，未尝试记录继续保留。实例仍存活时可显式调用 `flush_pending_save()` 处理这些记录；重复调用 `begin_quiesce()` 只返回同一个已提交的取消终态，不会隐式 flush 或改写证据。

成功写入的记录会被移除并发出 `settings_saved`。已经成功捕获 payload、但物理写入失败的记录会连同冻结 payload 保留在 pending 集合中；quiesce completion 以失败终结，并在 metadata 中报告失败文件名、错误码和仍待处理目标。后续 `tick()` 不会热重试这类失败，实例仍存活时必须显式调用 `flush_pending_save()` 才会复用同一冻结快照；重试成功也不会把既有 quiesce 失败终态改写为成功。

循环引用等捕获失败不会保留可写 payload，只保留 target 与 `ERR_INVALID_DATA` 证据。单独调用 `flush_pending_save()` 只会重复同一捕获错误；调用方必须先修正内存值，再让同一 target 接纳一份新快照以覆盖失败记录。重复调用失败的 `begin_quiesce()` 同样只返回原终态，不会自动重试。项目必须自行决定修正、显式重试与最终失败处理时机。

`dispose()` 不再承担权威持久化排空：它只关闭准入、清理内存记录并释放 Settings 自己拥有的 Store。正常的 Architecture 关闭应等待 `shutdown_async()`，直接管理 Utility 生命周期时则先调用并检查 `begin_quiesce()`；只有无法等待的强制清理路径才直接 `dispose()`。一旦 dispose，仍 pending 的失败记录也会被清除，不能再重试。

## 暂存设置

设置页如果需要“应用 / 取消”按钮，不应让滑块、选项框直接写入真实设置。可以先把用户选择写入暂存层，用 `get_staged_or_value()` 渲染预览值，确认后再提交。

```gdscript
settings.stage_value(&"audio/master", 0.6)

var preview_value: Variant = settings.get_staged_or_value(&"audio/master")

if settings.has_staged_values():
	var report: Dictionary = settings.apply_staged_values()
	if not report["ok"]:
		print(report["issues"])
```

暂存值会沿用 `GFSettingDefinition` 做类型转换，但不会触发 `setting_changed`、不会保存，也不会出现在 `to_dict()` 中。`apply_staged_values()` 会复用 `apply_values()` 的真实设置应用流程，因此会按现有批处理和自动保存规则合并落盘。需要放弃用户未确认的选择时，调用 `discard_staged_value(key)` 或 `discard_staged_values()`。

如果一个设置页只想提交当前页负责的键，可以通过 `scope` 限制提交范围；未在 scope 中的暂存值会继续保留，供其他页面或后续流程处理。

```gdscript
var report: Dictionary = settings.apply_staged_values({
	"scope": PackedStringArray([
		"video/window_mode",
		"video/window_size",
	]),
})
```

## 预设应用

需要把“低画质”“无障碍”“手柄方案”这类项目预设一次性应用到设置中时，可以使用 `apply_values()`。它会沿用已注册定义做类型转换，并把自动保存合并成一次。

如果预设希望把缺失的键重置为默认值，必须显式传入 `scope`，避免误重置不属于该预设的其他设置。

```gdscript
var report := settings.apply_values({
	"audio/master": 0.75,
	"video/fullscreen": true,
}, {
	"reset_missing": true,
	"scope": PackedStringArray([
		"audio/master",
		"video/fullscreen",
		"video/vsync",
	]),
})

if not report["ok"]:
	print(report["issues"])
```
