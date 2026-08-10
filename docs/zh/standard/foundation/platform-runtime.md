# 平台能力与 Adapter 运行时

GF 的平台层只定义稳定、平台无关的契约和运行时编排，不内置 Steam、微信小游戏、Web、主机或自建服务 SDK。具体 SDK 实现属于项目或独立发行的 Adapter；`gf.standard.platform` 负责注册、显式路由、生命周期、请求终态和诊断，不解释供应商规则或项目业务。

## 核心类型

- `GFPlatformCapabilitySet`：声明平台或 adapter 暴露的能力 ID，以及每个能力的限制字段。
- `GFPlatformRuntimeContext`：聚合平台 ID、adapter ID、locale、显示尺寸、像素比、安全区域、存储 root、启动参数和能力集合。
- `GFPlatformLifecycleEvent`：表达前后台、窗口变化、安全区域、网络、键盘和内存压力等生命周期事件。
- `GFPlatformActivationIntent`：表达启动参数、邀请、Join 或外部协议唤醒；稳定 intent ID 允许运行时去重和受限重放。
- `GFPlatformContractDescriptor` / `GFPlatformContractMethodDescriptor`：声明方法、请求/结果 Schema、字节预算、能力前置、并发、取消支持和敏感字段。
- `GFPlatformBridgeRequest` / `GFPlatformBridgeResult`：为 JS bridge、native bridge、进程桥接或 SDK 包装层提供统一请求/结果载体。

## 运行时类型

- `GFPlatformAdapter`：外部 Adapter 协议，拥有不可变的 adapter/platform 身份、支持的 contract 集合、初始化状态和 SDK callback pump。
- `GFPlatformRuntime`：注册 Adapter、维护 contract 候选与显式路由、推进 callback pump、处理超时与取消，并把上下文和生命周期事件转发给项目。
- `GFPlatformRequestHandle`：一次性请求句柄。成功、失败、取消和超时都是唯一终态；路由或输入失败同样返回已完成句柄，不用 `null` 表达失败。
- `GFPlatformAdapterConformance`：不调用 SDK 的静态审查器，检查身份、状态、契约描述符、必需方法、能力和 Bridge 覆盖。

运行时的路由规则是确定的：调用方指定 `adapter_id` 时只使用该 Adapter；否则先读取显式 contract route；没有显式 route 时只允许唯一候选自动解析。零候选和多候选都 fail closed，避免安装第二个 Adapter 后静默改变行为。

请求、契约、方法、Adapter 与 Intent 的稳定 ID 都在进入路由、去重、契约查找和并发账本前移除首尾空白。描述符资源本身则必须已经使用规范 ID；直接创作的首尾空白和负载荷/结果/并发限制会让定义校验失败，负限制不会被降级成代表“无限制”的 `0`。

```gdscript
var runtime := GFPlatformRuntime.new()
var adapter := ProjectPlatformAdapter.new() # 项目或独立插件实现 GFPlatformAdapter。
adapter.configure(
	&"project.platform",
	&"sample_platform",
	PackedStringArray(["platform.auth", "platform.cloud_storage"]),
	platform_contract_descriptors,
	initial_context
)

runtime.register_adapter(adapter)
runtime.set_contract_route(&"platform.auth", adapter.get_adapter_id())

var initialization := runtime.initialize_adapter(adapter.get_adapter_id())
if initialization.is_pending():
	await initialization.completed
if not initialization.is_successful():
	push_error(initialization.get_error())
	return

var handle := runtime.invoke_contract(&"platform.auth", &"login", {}, {
	"timeout_msec": 15_000,
})
if handle.is_pending():
	await handle.completed
var result := handle.get_result()
```

每个 contract 都必须配置描述符。`invoke()` 会在调用 SDK 前拒绝未知方法、缺失能力、Schema 错误、超预算请求和超并发调用；`_succeed_request()` 也会验证 Adapter 返回值，非法结果统一成为 `invalid_adapter_result`：

载荷字节预算度量 `GFVariantJsonCodec` 的 JSON-compatible 投影，编码遍历受 codec 的深度、节点和集合项预算保护，但它不等同于任意原生 Object 图的内存预算。需要 JSON / 进程桥接的 Adapter 应用 Schema 明确拒绝 Object / Resource，或先在项目 Adapter 中转换成稳定 ID、路径或纯数据；不要把该字段当成未声明对象图的通用 admission 上限。

Adapter 应通过 `_succeed_request()` / `_fail_request()` 提交终态。Platform 层若直接提交预构造 `GFPlatformBridgeResult`，Handle 仍会验证请求身份、非空状态、成功/错误/载荷组合，以及与本请求同一单调时钟域中的起止时间；拒绝不会消耗 pending 终态，也不会发出 `completed`。

本地取消或超时只提交调用方终态，Provider 租约会保留到 Adapter 确认停止；迟到成功和失败都不能覆盖已有终态，但都会释放仍匹配的 Provider 租约。正 timeout 的绝对 deadline 在 int64 上界饱和，Runtime 直接复用 Handle 的单一计算结果，不会因溢出回绕成永久等待。

```gdscript
var report := GFPlatformAdapterConformance.inspect(adapter, {
	"required_contract_ids": PackedStringArray(["platform.auth"]),
	"required_contract_versions": {"platform.auth": "1.0.0"},
	"required_methods": {"platform.auth": PackedStringArray(["login", "logout"])},
	"required_capability_ids": PackedStringArray(["auth"]),
})
assert(GFVariantData.get_option_bool(report, "ok"))
```

Adapter 的 `_initialize()`、`_dispatch()`、`_poll()`、`_cancel_request()` 和 `_shutdown()` 只翻译 SDK 状态。登录 UI、好友赠送、分享任务、奖励、房间界面和商店政策仍属于项目业务层。

`get_debug_snapshot()` 只公开稳定状态和 allowlist 摘要：不包含请求载荷、成功值、结果 metadata、原始 Provider error、契约自由 metadata、能力 metadata、存储物理路径或启动参数。需要完整故障详情时，应在受信 Adapter 内部使用独立的显式脱敏日志，不要把调试快照当作原始 SDK dump。

## 设计边界

- GF Core 和 Standard 不直接调用平台 SDK。
- contract ID 表达可调用协议，capability ID 表达当前运行环境事实；两者都由 Adapter 或项目按稳定约定提供，GF 不把某个发行平台写成框架事实。
- Adapter 注册不会隐式初始化；失败和关闭是终态，需要重连时创建新实例。
- Runtime 为 Activation Intent 维护有界待消费队列和有界去重历史；去重与消费使用无歧义的 `adapter_id + intent_id` 复合身份。待消费身份独立于近期历史，即使历史窗口淘汰也不能重放同一 pending 意图。项目应消费或确认意图，不能把 Provider callback 直接当场景跳转命令。
- `GFPlatformRuntime` 使用不受暂停、缩放和系统校时影响的 `GFClock` 单调时间处理超时和耗时。架构中存在 `GFTimeProvider` 时会自动采用同一底层时钟；有等待请求时拒绝替换时钟，极端正 deadline 会饱和而不回绕。
- Context、Lifecycle Event 与 Activation Intent 在 Adapter / Runtime 层边界会复制，但 Godot 一次 signal 发射中的多个监听者仍接收同一个已发射 Resource 实例；监听者必须把它视为只读，不能通过同步 mutation 向后续监听者传递隐式状态。
- UI、好友赠送、分享任务、活动奖励、房间列表界面等玩法或产品逻辑不属于平台 adapter。
- `GFPlatformRuntimeContext.make_compatibility_profile()` 可以把平台和能力投影成 `GFCompatibilityProfile`，供 `GFCompatibilityPreflight` 做显式预检。

## 示例

```gdscript
var capabilities := GFPlatformCapabilitySet.new().configure(
	&"sample_platform",
	PackedStringArray(["auth", "cloud_storage", "safe_area"]),
	{},
	&"sample_adapter"
)
capabilities.set_limit(&"cloud_storage", &"quota_bytes", 10485760)

var context := GFPlatformRuntimeContext.new().configure(
	&"sample_platform",
	{
		"adapter_id": &"sample_adapter",
		"locale": "zh_CN",
		"pixel_ratio": 2.0,
		"window_size": Vector2i(360, 640),
		"storage_roots": {"user": "platform://user"},
		"capabilities": capabilities,
	}
)

var profile := context.make_compatibility_profile(&"current_runtime")
```

AI Developer Kit 内置 `templates/adapters/platform/`，包含 Platform Adapter、Lobby Backend、契约测试、兼容性 Profile 和故障矩阵模板。模板应复制到项目 Adapter 根或独立包中，不能在 GF 源码目录内直接填入 Provider SDK。
