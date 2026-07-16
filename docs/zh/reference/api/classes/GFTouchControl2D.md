# GFTouchControl2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/touch/gf_touch_control_2d.gd`
- 模块：`Standard`
- 继承：`Node2D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

触屏 Node2D 控件共享底座。 提供触点捕获、隐藏/离树释放、屏幕坐标到画布坐标转换和输入 handled 标记。 具体按钮、摇杆、滑条或项目自定义触屏控件仍负责自己的形状、输出和业务无关配置。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`release`](#member-gftouchcontrol2d-methods-release) | `func release() -> void:` |
| 方法 | [`is_touch_active`](#member-gftouchcontrol2d-methods-is_touch_active) | `func is_touch_active() -> bool:` |
| 方法 | [`get_active_touch_index`](#member-gftouchcontrol2d-methods-get_active_touch_index) | `func get_active_touch_index() -> int:` |

## 方法

<a id="member-gftouchcontrol2d-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func release() -> void:
```

手动释放触屏控件。 子类应重写该方法并清理自己的输出状态；底座默认只释放触点捕获。

<a id="member-gftouchcontrol2d-methods-is_touch_active"></a>

### `is_touch_active`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_touch_active() -> bool:
```

检查当前是否捕获了触点。

返回：有活动触点捕获时返回 true。

<a id="member-gftouchcontrol2d-methods-get_active_touch_index"></a>

### `get_active_touch_index`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_active_touch_index() -> int:
```

获取当前活动触点 index。

返回：当前活动触点 index；没有捕获时返回 -1。
