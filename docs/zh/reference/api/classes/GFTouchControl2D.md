# GFTouchControl2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/touch/gf_touch_control_2d.gd`
- 模块：`Standard`
- 继承：`Node2D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

触屏 Node2D 控件共享底座。 提供触点捕获、隐藏/离树/process mode 禁用释放、屏幕坐标到画布坐标转换和输入 handled 标记。 具体按钮、摇杆、滑条或项目自定义触屏控件仍负责自己的形状、输出和业务无关配置。 直接调用 set_process_input(false) 不会产生可拦截的 Node 禁用通知；调用方必须先 release()。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`release`](#member-gftouchcontrol2d-methods-release) | `func release() -> void:` |
| 方法 | [`is_touch_active`](#member-gftouchcontrol2d-methods-is_touch_active) | `func is_touch_active() -> bool:` |
| 方法 | [`get_active_touch_index`](#member-gftouchcontrol2d-methods-get_active_touch_index) | `func get_active_touch_index() -> int:` |
| 方法 | [`_try_capture_touch_index`](#member-gftouchcontrol2d-methods-_try_capture_touch_index) | `func _try_capture_touch_index(touch_index: int) -> bool:` |
| 方法 | [`_release_touch_capture`](#member-gftouchcontrol2d-methods-_release_touch_capture) | `func _release_touch_capture(touch_index: int = _NO_POINTER_ID) -> bool:` |
| 方法 | [`_touch_matches`](#member-gftouchcontrol2d-methods-_touch_matches) | `func _touch_matches(touch_index: int) -> bool:` |
| 方法 | [`_screen_to_global_position`](#member-gftouchcontrol2d-methods-_screen_to_global_position) | `func _screen_to_global_position(screen_position: Vector2) -> Vector2:` |
| 方法 | [`_mark_input_as_handled`](#member-gftouchcontrol2d-methods-_mark_input_as_handled) | `func _mark_input_as_handled() -> void:` |

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

<a id="member-gftouchcontrol2d-methods-_try_capture_touch_index"></a>

### `_try_capture_touch_index`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _try_capture_touch_index(touch_index: int) -> bool:
```

捕获指定触点；拒绝哨兵索引，已有捕获时仅允许同一触点继续匹配。

参数：

| 名称 | 说明 |
|---|---|
| `touch_index` | 输入事件的触点索引；-1 为未捕获哨兵，不可接纳。 |

返回：成功捕获或已由同一触点持有时返回 true。

<a id="member-gftouchcontrol2d-methods-_release_touch_capture"></a>

### `_release_touch_capture`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _release_touch_capture(touch_index: int = _NO_POINTER_ID) -> bool:
```

释放触点捕获；可选索引必须匹配当前捕获，省略或传哨兵值时释放任意当前捕获。

参数：

| 名称 | 说明 |
|---|---|
| `touch_index` | 要释放的触点索引；-1 表示释放当前任意触点。 |

返回：实际解除捕获时返回 true；未捕获或索引不匹配返回 false。

<a id="member-gftouchcontrol2d-methods-_touch_matches"></a>

### `_touch_matches`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _touch_matches(touch_index: int) -> bool:
```

检查给定触点索引是否等于当前捕获索引。

参数：

| 名称 | 说明 |
|---|---|
| `touch_index` | 要与当前捕获状态比较的索引。 |

返回：索引与当前保存值相同时返回 true，包含未捕获时的 -1。

<a id="member-gftouchcontrol2d-methods-_screen_to_global_position"></a>

### `_screen_to_global_position`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _screen_to_global_position(screen_position: Vector2) -> Vector2:
```

将屏幕位置经当前 Viewport 的 canvas 逆变换换算到画布坐标；无 Viewport 时原样返回。

参数：

| 名称 | 说明 |
|---|---|
| `screen_position` | 输入事件在 Viewport 中的屏幕坐标。 |

返回：当前画布坐标；尚未取得 Viewport 时返回原坐标。

<a id="member-gftouchcontrol2d-methods-_mark_input_as_handled"></a>

### `_mark_input_as_handled`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _mark_input_as_handled() -> void:
```

若存在当前 Viewport，将本次输入标记为已处理。
