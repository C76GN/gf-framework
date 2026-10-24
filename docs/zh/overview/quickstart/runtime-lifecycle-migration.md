# 资源与上下文 API 迁移

本页说明下一主版本的资源请求、上下文关闭、UI 归属与 Save 请求变更。旧 API 直接移除，
按下面的步骤修改项目代码；不提供通用转换器。本组变更不修改存档、项目配置或 Flow 资源
的序列化格式，项目已有的 Save schema 迁移链仍然有效。其他主版本变更见[更新日志](../../changelog.md)。

## 资源请求改用作用域与独立操作

先为页面、场景或其他业务生命周期创建 `GFAssetScope`，再发出请求。作用域同时持有等待中
的操作和成功句柄；关闭后取消尚未完成的请求并释放句柄。底层已经开始的共享加载由框架排空。

```gdscript
var assets: GFAssetUtility = get_assets_for_this_context()
var scope: GFAssetScope = assets.create_scope(self)
var operation: GFAssetLoadOperation = assets.load_async(
	"res://ui/inventory.tscn",
	scope,
	"PackedScene"
)
var result: GFAssetLoadResult = await operation.wait_result_async()
if not result.is_successful():
	return
var handle: GFAssetHandle = result.get_handle()
if not handle.is_valid():
	return
var resource: Resource = handle.get_resource()
```

`get_assets_for_this_context()` 表示项目现有的类型化依赖获取入口。保存 scope 到对应业务对象
的字段中，或在整个使用期间保持引用。Node owner 退出树会自动关闭 scope；提前离开业务流程
时也可显式调用 `scope.close()`。成功终态描述历史事实，不能保证 scope 关闭后句柄仍有效。

| 原调用习惯 | 新调用方式 |
| --- | --- |
| `load_async(path, callback, type_hint, options)` | `load_async(path, scope, type_hint, options)`，返回 `GFAssetLoadOperation` |
| `load_handle_async(...)` | 使用同一 `load_async(...)`，从成功结果取得 `get_handle()` |
| 按路径取消加载 | 保存并取消当前调用的 `operation.cancel()` |
| `acquire_handle` 分散传 owner/group | `acquire_handle(path, scope, type_hint, resource_override)` |
| 用 group 表示对象所有权 | 用 scope 管生命周期；group 只用于既有分组操作 |

同路径的多个请求可以共享物理加载，但取消一个操作不会取消其他调用者。重复等待和重复读取
结果会取得同一个句柄，不增加租约。成功后 `cancel()` 不再回收资源，应关闭 scope 或释放句柄。
Registry 与 Resolver 的异步资源入口也改为显式 scope 和类型化 Operation，详见
[资源注册](../../standard/utilities/io/assets-jobs-warmup/asset-utility/resource-registry.md)与
[资源解析](../../standard/utilities/io/assets-jobs-warmup/asset-utility/resource-resolver.md)。

## 操作统一使用类型化等待

Save、Save 事务、Scene、BGM、UI Route 和异步面板操作提供 `wait_result_async()`。
用它替代每处重复的“先判断完成，再 await 信号”代码；立即拒绝、缓存命中与异步完成都走同一入口。
面板操作等待后返回自身，面板仍由 UIUtility 管理，不因等待而延长节点生命周期。

Storage 保留两个事实边界：

- `wait_caller_result_async()`：调用者已经得到确定结果或结束观察；写入可能返回 `OUTCOME_UNKNOWN`。
- `wait_physical_result_async()`：物理请求已经结算。
- `GFStorageOwnedRead.wait_result_async()`：返回不含 payload 的 caller 回执，仍须显式 `take()` 领取一次。

owner 失效也会通知终态并唤醒等待者。等待后先核对目标存活、作用域与请求身份，再更新 UI。
不能再依赖“owner 释放后没有信号”阻止业务回调；取消观察也不表示磁盘写入没有发生。

## UI 在装配时绑定业务 Context

局部 Architecture 中的 `GFUIUtility` 必须在初始化前调用 `configure_host(source_context)`。
默认显示 host 在该 Context 下。需挂到其他 Canvas 或 Viewport 时，使用
`configure_host(source_context, mount_parent)`；框架会在显示树中创建借用源 Context 的
INHERITED 上下文，Controller 无需各自手工绑定。

未绑定来源的局部 UI 初始化会明确失败。来源关闭、离树或重建后，旧绑定失效，不会退回全局
Architecture。真正的全局 UI 可以沿用全局显示默认。销毁 UIUtility 会销毁其自有 host，
业务传入的 mount_parent 仍由业务管理。Router 的运行时历史与请求应随对应 UI 实例持有，
显式目标失效时不会换用其他 UI 实例。详见[面板栈](../../standard/utilities/runtime/settings-ui-scene/ui-stack-routing/ui-stack-modal/panel-stack.md)。

## 在移除节点前等待 Context 关闭

需要平滑关闭时，先调用 `await context.close_async()`，检查 `GFContextCloseResult`，再由业务
移除或释放节点。`is_closed()` 表示绑定与自有架构已经关闭；`is_drained()` 表示全部子上下文
和自有架构正常完成了协作关闭，两者不能互相替代。

SCOPED Context 关闭自有 Architecture；INHERITED Context 仅撤销自己的借用与绑定，不关闭
共享 Architecture。逻辑子 Context 先于父 Context 关闭，包括跨显示树显式绑定的子 Context。
直接离树仍有同步兜底，但无法承诺等待全部异步工作。框架不替业务决定是否保存、离开关卡或
`queue_free()`。详见[节点上下文](../../kernel/lifecycle/node-contexts.md)。

## Save 普通元数据改为隔离快照

把 `GFSaveProfileRequest.take_ownership()`、`GFSaveProfileMutationRequest.take_ownership()`
与 `GFSaveProfileReconcileRequest.take_ownership()` 改为对应的 `create()`。
新入口复制普通 document metadata、Provider context 和 result metadata；创建后可以继续
使用和修改源字典。仍需保存请求对象以便一次性提交，不能重复 claim。

```gdscript
var request: GFSaveProfileRequest = GFSaveProfileRequest.create(
	{"slot_kind": "auto"},
	{"reason": "checkpoint"},
	{"request_tag": "autosave"}
)
if request == null:
	push_error("Save metadata is invalid or exceeds the budget.")
	return
var operation: GFSaveProfileOperation = save_profiles.save_profile(&"project.player", request)
var result: GFSaveProfileResult = await operation.wait_result_async()
```

输入必须是有界纯数据，不接受对象、可执行值、循环或非有限数。三个字典合计使用 64 层、
100000 节点和 1 MiB 保守复制计量预算；失败返回 `null`。必须检查创建结果，不能把失败的
`null` 传回保存入口，因为保存入口的 `null` 明确表示“使用空元数据”。load、flush、activate
与 switch 的普通元数据也遵循同一边界。

类型化容器的声明也必须是纯数据类型；例如空的 `Array[Resource]` 仍会被拒绝。
`Array[int]`、`Dictionary[String, int]` 等合法容器会保留类型信息并隔离源数据。

大型 section 继续使用 `GFSaveSectionSnapshot`、`GFSaveSectionMutation` 的明确所有权转移
与协作式准备，不能把大 payload 放进 context 绕过预算。现有未知写入对账、回滚与磁盘迁移
机制保持其职责，详见[Save Profile 运行时](../../extensions/save-graph/save-profile-runtime.md)。
