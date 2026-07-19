# 平台能力与 Adapter 运行时

GF 的平台层只定义稳定、平台无关的契约和运行时编排，不内置 Steam、微信小游戏、Web、主机或自建服务 SDK。具体 SDK 实现属于项目或独立发行的 Adapter；`gf.standard.platform` 负责注册、显式路由、生命周期、请求终态和诊断，不解释供应商规则或项目业务。

## 核心类型

- `GFPlatformCapabilitySet`：声明平台或 adapter 暴露的能力 ID，以及每个能力的限制字段。
- `GFPlatformRuntimeContext`：聚合平台 ID、adapter ID、locale、显示尺寸、像素比、安全区域、存储 root、启动参数和能力集合。
- `GFPlatformLifecycleEvent`：表达前后台、窗口变化、安全区域、网络、键盘和内存压力等生命周期事件。
- `GFPlatformBridgeRequest` / `GFPlatformBridgeResult`：为 JS bridge、native bridge、进程桥接或 SDK 包装层提供统一请求/结果载体。

## 运行时类型

- `GFPlatformAdapter`：外部 Adapter 协议，拥有不可变的 adapter/platform 身份、支持的 contract 集合、初始化状态和 SDK callback pump。
- `GFPlatformRuntime`：注册 Adapter、维护 contract 候选与显式路由、推进 callback pump、处理超时与取消，并把上下文和生命周期事件转发给项目。
- `GFPlatformRequestHandle`：一次性请求句柄。成功、失败、取消和超时都是唯一终态；路由或输入失败同样返回已完成句柄，不用 `null` 表达失败。

运行时的路由规则是确定的：调用方指定 `adapter_id` 时只使用该 Adapter；否则先读取显式 contract route；没有显式 route 时只允许唯一候选自动解析。零候选和多候选都 fail closed，避免安装第二个 Adapter 后静默改变行为。

```gdscript
var runtime := GFPlatformRuntime.new()
var adapter := ProjectPlatformAdapter.new() # 项目或独立插件实现 GFPlatformAdapter。
adapter.configure(
	&"project.platform",
	&"sample_platform",
	PackedStringArray(["platform.auth", "platform.cloud_storage"])
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

Adapter 的 `_initialize()`、`_dispatch()`、`_poll()`、`_cancel_request()` 和 `_shutdown()` 只翻译 SDK 状态。登录 UI、好友赠送、分享任务、奖励、房间界面和商店政策仍属于项目业务层。

## 设计边界

- GF Core 和 Standard 不直接调用平台 SDK。
- contract ID 表达可调用协议，capability ID 表达当前运行环境事实；两者都由 Adapter 或项目按稳定约定提供，GF 不把某个发行平台写成框架事实。
- Adapter 注册不会隐式初始化；失败和关闭是终态，需要重连时创建新实例。
- `GFPlatformRuntime` 使用不受暂停、缩放和系统校时影响的 `GFClock` 单调时间处理超时和耗时。架构中存在 `GFTimeProvider` 时会自动采用同一底层时钟；有等待请求时拒绝替换时钟。
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
