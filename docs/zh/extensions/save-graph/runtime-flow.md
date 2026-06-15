# 采集、应用与存储闭环

`GFSaveGraphUtility` 用于把场景树上的多个节点状态组合成一个存档图。`GFSaveScope` 定义保存边界，`GFSaveSource` 定义数据入口，`GFNodeSerializerRegistry` 管理可组合节点序列化器；框架只负责遍历、聚合和应用，不规定玩家、关卡、背包或实体字段。

最短闭环是：`GFSaveGraphUtility` 从 `GFSaveScope` 树采集 Dictionary payload，`GFStorageUtility` 把这个 Dictionary 写盘；读取时由 Storage 读出 Dictionary，再交给 SaveGraph 校验并应用回当前场景。

```gdscript
var save_graph := Gf.get_utility(GFSaveGraphUtility) as GFSaveGraphUtility
var storage := Gf.get_utility(GFStorageUtility) as GFStorageUtility

var report := save_graph.inspect_scope(%SaveScope)
if not bool(report.get("ok", false)):
	push_warning(String(report.get("summary", "")))
	return

var payload := save_graph.gather_scope(%SaveScope)
if payload.is_empty():
	return

storage.save_data_async("hero_save.sav", payload)
```

`gather_scope()` 会在主线程遍历当前场景节点。大型项目应把项目级 Model 聚合改用 `GFArchitecture.get_global_snapshot_async()`，或在项目自己的保存 System 中把多个 Scope/区域分帧采集，再交给 `GFStorageUtility.save_data_async()` 后台编码和落盘。不要在线程里直接访问 Node、Resource 或 `GFSaveSource` 实例。

```gdscript
var payload := storage.load_data("hero_save.sav")
var payload_report := save_graph.validate_payload_for_scope(%SaveScope, payload, true)
if not bool(payload_report.get("ok", false)):
	push_warning(String(payload_report.get("summary", "")))
	return

var result := save_graph.apply_scope(%SaveScope, payload, {}, true)
if not bool(result.get("ok", false)):
	push_warning("Load failed: %s" % str(result.get("errors", [])))
```

如果 `GFSaveGraphUtility` 是通过 `Gf.get_utility()` 取得，并且 `GFStorageUtility` 已注册到同一个 `GFArchitecture`，也可以直接使用封装方法：

```gdscript
save_graph.save_scope("hero_save.sav", %SaveScope)
save_graph.load_scope("hero_save.sav", %SaveScope, {}, true)
```

## 复用已有数据对象

如果已经有项目自己的 `SaveGamePayload` / Model 聚合对象，且不想让 SaveGraph 遍历场景节点，可以直接把它转成 Dictionary 后交给 `GFStorageUtility.save_data()` 或 `save_slot()`。

如果希望这份业务数据也进入 SaveGraph 的统一 payload，优先使用 `GFSaveDataSource` 适配已有 `to_dict()` / `from_dict()` 风格对象。它可以直接引用 Resource，也可以指向目标 Node 或目标属性上的数据对象，只要求采集方法返回 Dictionary、应用方法接收 Dictionary。需要复杂迁移、跨对象协调或非 Dictionary 协议时，再继承 `GFSaveSource`，在 `_gather_save_data()` 返回业务 Dictionary，在 `_apply_save_data()` 中恢复业务状态。

```gdscript
var source := GFSaveDataSource.new()
source.source_key = &"profile"
source.data = player_profile_resource
%SaveScope.add_child(source)
```
