# 显式 Live Asset Slot

`GFAssetSlot` 为一个稳定资源身份提供显式、可替换的当前 `Resource` 引用。它适合主题、配置、规则资源或其他需要由项目在受控提交点切换实例的场景；普通一次性加载、缓存 pin 或分组预热继续使用 `GFAssetUtility` 与 `GFAssetHandle`。

## 配置与替换

槽位必须由调用方在主线程创建并且只允许成功配置一次。`GFResourceIdentity` 会在配置时复制并固定，后续修改原身份对象不会改变槽位；可选 `type_hint_override` 会覆盖身份自带的类型提示。`is_configured()` 区分尚未配置与已经进入释放终态的槽位。

```gdscript
# 这些输入由项目的 resolver / asset handle 流程取得并完成候选校验。
var identity: GFResourceIdentity = resolved_identity
var initial_resource: Resource = resolved_initial_resource
var validated_candidate: Resource = resolved_candidate_resource
var slot := GFAssetSlot.new()

if not slot.configure(identity, initial_resource, self):
	push_error("无法配置资源槽位。")
	return

slot.resource_replaced.connect(
	func(_previous: Resource, current: Resource, generation: int) -> void:
		print("资源已切换：", current, " generation=", generation)
)

if slot.accepts_resource(validated_candidate):
	var _replaced: bool = slot.replace(validated_candidate)
```

空类型提示接受任意 `Resource`；非空提示支持 Godot 原生类名、脚本 `class_name` 和脚本资源路径。空资源、同一实例或类型不兼容的替换会失败并保持原状态。需要先检查候选时，可以调用 `accepts_resource()`。

## Generation 与通知

新建但未配置的槽位 generation 为 0。成功配置、每次成功替换和首次成功释放各推进一次 generation；失败操作和重复释放不会推进。`resource_replaced` 与 `released` 都在新状态提交后同步发出，因此回调读取到的是已提交资源、generation 和释放状态。

通知期间对同一槽位再次替换或释放会失败关闭，避免不同监听器观察到不同中间状态。需要串联下一次切换时，应由项目队列或延迟边界在当前通知返回后执行。

槽位的配置、查询、替换、释放和 owner 生命周期处理全部限定在主线程。worker 上的调用只返回各入口记录的失败关闭值，不读取或改变槽位状态；后台加载应先完成自己的工作，再由项目的主线程提交候选资源。

## 所有权与释放

槽位直接强持有当前 `Resource`，调用 `release()` 会清空引用并进入不可逆终态。若配置时传入 owner，槽位只保存弱引用：

- owner 是 `Node` 时，配置时必须已经位于活动场景树中；随后退出场景树会自动释放槽位。树外 Node 会让配置原子失败，进入树后可以重试。
- owner 是其他 `Object` 时，槽位在后续资源或状态操作中发现对象已经释放后提交释放。
- owner 为空时，由调用方显式调用 `release()`，或释放槽位自身。

`released` 在资源清空、generation 推进和 owner 监听解除后发出。释放后的槽位不能重新配置或替换；需要新的生命周期时创建新 `GFAssetSlot`。

## 使用边界

Live slot 是显式 opt-in 的运行时间接层，不监听文件变化、不自动重载资源，也不接管 `GFAssetUtility` 缓存。它持有的是当前资源实例，不会 pin 缓存，不拥有或释放 `GFAssetHandle`，也不改变句柄已经取得的资源快照。

项目仍负责决定何时加载候选资源、如何验证业务一致性、何时提交替换，以及是否把切换动作纳入存档、网络同步或命令历史。只有多个消费者确实需要共享“同一稳定身份当前指向哪个资源”时才应引入槽位。
