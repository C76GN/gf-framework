# GFUIMotionBinding

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/ui_motion/gf_ui_motion_binding.gd`
- 模块：`Action Queue`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

一次目标绑定的采样和回收操作。每个目标及播放会话有独立实例。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`EndReason`](#member-gfuimotionbinding-enums-endreason) | `enum EndReason` |
| 属性 | [`sample`](#member-gfuimotionbinding-properties-sample) | `var sample: Callable` |
| 属性 | [`release`](#member-gfuimotionbinding-properties-release) | `var release: Callable` |
| 属性 | [`action`](#member-gfuimotionbinding-properties-action) | `var action: GFVisualAction` |

## 枚举

<a id="member-gfuimotionbinding-enums-endreason"></a>

### `EndReason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum EndReason {
	## 自然走到最后一条轨道的末端。
	COMPLETED,
	## 调用方直接提交终态。
	FINISHED,
	## 会话中断，或旧页交还路由历史，恢复本绑定的初始姿态。
	CANCELLED,
	## 另一播放器已接管属性。释放临时资源并保留当前姿态。
	REPLACED,
}
```

会话结束原因。

## 属性

<a id="member-gfuimotionbinding-properties-sample"></a>

### `sample`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var sample: Callable
```

接受一个经缓动的局部进度。按相同进度重采样时应得到相同姿态。

<a id="member-gfuimotionbinding-properties-release"></a>

### `release`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var release: Callable
```

可选结束钩子，接受 EndReason，释放本实例占有的资源。

<a id="member-gfuimotionbinding-properties-action"></a>

### `action`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var action: GFVisualAction
```

可选的实播动作。按轨道开始时执行一次，结束时释放；含实播动作的配方不接受拖动定位。
