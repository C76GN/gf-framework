# 采集、应用与存储闭环

`GFSaveGraphUtility` 用于把场景树上的多个节点状态组合成一个存档图。`GFSaveScope` 定义保存边界，`GFSaveSource` 定义数据入口，`GFNodeSerializerRegistry` 管理可组合节点序列化器；框架只负责遍历、聚合和应用，不规定玩家、关卡、背包或实体字段。

最短闭环是：`GFSaveGraphUtility` 从 `GFSaveScope` 树采集内部 graph payload，再包装成带 schema 身份和版本的 `GFSaveDocument` 写盘；读取时先由 Storage 返回强类型读取结果，再严格解析和校验文档，最后应用其中的 SaveGraph section。裸 graph payload 只用于内存中的组合与诊断，不再作为推荐物理存储格式。

```gdscript
var save_graph := Gf.get_utility(GFSaveGraphUtility) as GFSaveGraphUtility
var storage := Gf.get_utility(GFStorageUtility) as GFStorageUtility
var slot_store := GFSaveSlotStorageAdapter.new().setup(storage)
var active_slot := 0

var report := save_graph.inspect_scope(%SaveScope)
if not bool(report.get("ok", false)):
	push_warning(String(report.get("summary", "")))
	return

var captured_document := save_graph.gather_document(%SaveScope, {
	"slot_kind": "manual",
})
if captured_document == null:
	return

var save_error := slot_store.save_slot(active_slot, captured_document)
if save_error != OK:
	push_warning("Save failed: %s" % error_string(save_error))
	return
```

`gather_scope()` 会在主线程遍历当前场景节点。任一 Pipeline Step、Scope 或 Source 在本轮新增 error 时，整次采集都会失败关闭；`save_scope()` 返回 `ERR_INVALID_DATA`，不会用部分或空 Source 载荷覆盖现有文件。大型项目应把项目级 Model 聚合改用 `GFArchitecture.get_global_snapshot_async()`，检查捕获 Result 后只把其中的 `snapshot` 交给存储；也可以在项目自己的保存 System 中把多个 Scope/区域分帧采集，再交给 `GFStorageUtility.save_data_async()` 由所选 Storage 执行器编码和落盘。异步保存必须等操作的强类型终态成功后才算物理提交完成；Storage 的物理读取终态也不代表主线程 Scene 应用已完成。无论执行器是 threaded 还是 cooperative，移交给 Storage 的载荷都必须是纯 Variant 图；不要把 Node、Resource 或 `GFSaveSource` 实例带入执行边界，也不要依赖 cooperative 当前位于主线程来放宽这一契约。模式选择与无线程 Web 调度见 [本地存档管理器：异步执行模式](../../standard/utilities/io/storage-snapshot/storage-utility.md#async-execution-mode)。

```gdscript
var read_result := slot_store.load_slot(active_slot, save_graph.create_document_schema())
if not read_result.is_successful():
	push_warning(read_result.get_error())
	return

var document := read_result.get_document()
var result := save_graph.apply_document(%SaveScope, document, {}, true)
if not bool(result.get("ok", false)):
	push_warning("Load failed: %s" % str(result.get("errors", [])))
	if not bool(result.get("atomicity_restored", true)):
		push_error("Load rollback was incomplete: %s" % str(result.get("rollback_failures", [])))
```

内部 graph payload 的 `format_version` 必须是精确的当前整数版本；缺失、旧版、字符串或未来版本都不会进入 Source mutation。通过版本化 Save Document 从 JSON Storage 读取时，Document adapter 只把 JSON 对当前整数的无损浮点表示规范化为当前版本；旧版本仍必须走显式迁移。

`load_slot()` 的 Document/Section 副本私有保留同次 JSON 输入来源，供 Graph 的属性派发解释 prepared 类型和引用片段；文档 metadata 与其他 Source 仍使用 Storage 的原生值。`to_dict()` / `from_dict()` 只表达持久化数据，不序列化这项来源。需要从文件恢复 Property 时，使用上述 `load_slot()`→`get_document()`→`apply_document()`（组合文档可取 section 交 `apply_section()`），或下面的 `load_scope()`；普通 Storage JSON payload 经手工 `from_dict()` 后不带原始编码来源。

如果 `GFSaveGraphUtility` 是通过 `Gf.get_utility()` 取得，并且 `GFStorageUtility` 已注册到同一个 `GFArchitecture`，也可以直接使用封装方法：

```gdscript
save_graph.save_scope("hero_save.sav", %SaveScope)
save_graph.load_scope("hero_save.sav", %SaveScope, {}, true)
```

## 复用已有数据对象

如果已经有项目自己的 `SaveGamePayload` / Model 聚合对象，且不想让 SaveGraph 遍历场景节点，应把每个长期维护边界转换成独立 `GFSaveSection`，组合成项目 `GFSaveDocument` 后交给 `GFSaveSlotStorageAdapter.save_slot()`。只有不需要项目 schema、分区版本与槽位迁移的普通缓存或工具数据才直接使用 `GFStorageUtility.save_data()` / `save_data_group()`。

如果希望这份业务数据也进入 SaveGraph 的统一 payload，优先使用 `GFSaveDataSource` 适配已有 `to_dict()` / `from_dict()` 风格对象。它可以直接引用 Resource，也可以指向目标 Node 或目标属性上的数据对象，只要求采集方法返回 Dictionary、应用方法接收 Dictionary。需要复杂迁移、跨对象协调或非 Dictionary 协议时，再继承 `GFSaveSource`，在 `_gather_save_data()` 返回业务 Dictionary，在 `_apply_save_data()` 中恢复业务状态。

```gdscript
var source := GFSaveDataSource.new()
source.source_key = &"profile"
source.data = player_profile_resource
%SaveScope.add_child(source)
```

SaveGraph 自身使用固定 `gf.save_graph` schema 和 `save_graph` section。需要与背包、任务或账号数据共存时，项目可以把 `gather_section()` 的结果作为一个 section 放入自己的文档，而不是嵌套另一套未版本化聚合字典。`GFSaveGraphUtility` 的 pipeline 诊断时间使用 `GFClock` 单调时间；在同一架构注册 `GFTimeProvider` 后会自动共享时钟，测试也可显式注入 `GFManualClock`。
