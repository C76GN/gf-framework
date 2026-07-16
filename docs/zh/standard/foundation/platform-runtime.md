# 平台运行时上下文

GF 的平台层只定义稳定、平台无关的事实载体，不内置 Steam、微信小游戏、Web、主机或自建服务 SDK。具体平台能力应由外部 adapter 读取 SDK 后写入这些资源，再交给项目、扩展预检或诊断工具使用。

## 核心类型

- `GFPlatformCapabilitySet`：声明平台或 adapter 暴露的能力 ID，以及每个能力的限制字段。
- `GFPlatformRuntimeContext`：聚合平台 ID、adapter ID、locale、显示尺寸、像素比、安全区域、存储 root、启动参数和能力集合。
- `GFPlatformLifecycleEvent`：表达前后台、窗口变化、安全区域、网络、键盘和内存压力等生命周期事件。
- `GFPlatformBridgeRequest` / `GFPlatformBridgeResult`：为 JS bridge、native bridge、进程桥接或 SDK 包装层提供统一请求/结果载体。

## 设计边界

- GF Core 和 Standard 不直接调用平台 SDK。
- 能力 ID 由 adapter 或项目按稳定约定提供，GF 不把某个发行平台写成框架事实。
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
