# 采集、应用与存储闭环

`GFSaveGraphUtility` 用于把场景树上的多个节点状态组合成一个存档图。`GFSaveScope` 定义保存边界，`GFSaveSource` 定义数据入口，`GFNodeSerializerRegistry` 管理可组合节点序列化器；框架只负责遍历、聚合和应用，不规定玩家、关卡、背包或实体字段。

最短闭环是：`GFSaveGraphUtility` 从 `GFSaveScope` 树采集内部 graph payload，再包装成带 schema 身份和版本的 `GFSaveDocument` 写盘；读取时先由 Storage 返回强类型读取结果，再严格解析和校验文档，最后应用其中的 SaveGraph section。裸 graph payload 只用于内存中的组合与诊断，不再作为推荐物理存储格式。

```gdscript
var save_graph := Gf.get_utility(GFSaveGraphUtility) as GFSaveGraphUtility
var storage := Gf.get_utility(GFStorageUtility) as GFStorageUtility

var report := save_graph.inspect_scope(%SaveScope)
if not bool(report.get("ok", false)):
	push_warning(String(report.get("summary", "")))
	return

var document := save_graph.gather_document(%SaveScope, {
	"slot_kind": "manual",
})
if document == null:
	return

storage.save_data_async("hero_save.sav", document.to_dict())
```

`gather_scope()` 会在主线程遍历当前场景节点。大型项目应把项目级 Model 聚合改用 `GFArchitecture.get_global_snapshot_async()`，检查捕获 Result 后只把其中的 `snapshot` 交给存储；也可以在项目自己的保存 System 中把多个 Scope/区域分帧采集，再交给 `GFStorageUtility.save_data_async()` 后台编码和落盘。不要在线程里直接访问 Node、Resource 或 `GFSaveSource` 实例。

```gdscript
var read_result := storage.load_data("hero_save.sav")
if not read_result.ok:
	push_warning(read_result.error)
	return

var inspection := GFSaveDocument.inspect_dict(read_result.payload)
if not bool(inspection.get("ok", false)):
	push_warning(String(inspection.get("summary", "")))
	return

var document := GFSaveDocument.from_dict(read_result.payload)
var schema_report := save_graph.create_document_schema().validate_document(document, true)
if not bool(schema_report.get("ok", false)):
	push_warning(String(schema_report.get("summary", "")))
	return

var result := save_graph.apply_document(%SaveScope, document, {}, true)
if not bool(result.get("ok", false)):
	push_warning("Load failed: %s" % str(result.get("errors", [])))
```

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
