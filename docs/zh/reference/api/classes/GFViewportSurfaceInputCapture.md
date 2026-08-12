# GFViewportSurfaceInputCapture

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/runtime/gf_viewport_surface_input_capture.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

表面指针按下代际的不可变回执。 调用方必须保留该回执并在 move、release 或 cancel 时原样交回创建它的 [code]GFViewportSurfaceInputBridge[/code]。同一 source/device/pointer key 重用后，旧回执不能操作新代际。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`is_valid`](#member-gfviewportsurfaceinputcapture-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`get_source_id`](#member-gfviewportsurfaceinputcapture-methods-get_source_id) | `func get_source_id() -> StringName:` |
| 方法 | [`get_device_id`](#member-gfviewportsurfaceinputcapture-methods-get_device_id) | `func get_device_id() -> int:` |
| 方法 | [`get_pointer_id`](#member-gfviewportsurfaceinputcapture-methods-get_pointer_id) | `func get_pointer_id() -> int:` |
| 方法 | [`get_pointer_type`](#member-gfviewportsurfaceinputcapture-methods-get_pointer_type) | `func get_pointer_type() -> int:` |
| 方法 | [`get_capture_generation`](#member-gfviewportsurfaceinputcapture-methods-get_capture_generation) | `func get_capture_generation() -> int:` |
| 方法 | [`get_target_generation`](#member-gfviewportsurfaceinputcapture-methods-get_target_generation) | `func get_target_generation() -> int:` |

## 方法

<a id="member-gfviewportsurfaceinputcapture-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_valid() -> bool:
```

检查回执是否已由桥成功配置。

返回：包含完整指针与代际身份时返回 true。

<a id="member-gfviewportsurfaceinputcapture-methods-get_source_id"></a>

### `get_source_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_source_id() -> StringName:
```

获取输入源标识。

返回：Resolver 提供的稳定输入源标识。

<a id="member-gfviewportsurfaceinputcapture-methods-get_device_id"></a>

### `get_device_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_device_id() -> int:
```

获取设备标识。

返回：按下时的非负设备标识。

<a id="member-gfviewportsurfaceinputcapture-methods-get_pointer_id"></a>

### `get_pointer_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_pointer_id() -> int:
```

获取输入源内的指针标识。

返回：按下时的非负指针标识。

<a id="member-gfviewportsurfaceinputcapture-methods-get_pointer_type"></a>

### `get_pointer_type`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_pointer_type() -> int:
```

获取指针类型。

返回：`GFViewportSurfaceInputBridge.PointerType` 值。

<a id="member-gfviewportsurfaceinputcapture-methods-get_capture_generation"></a>

### `get_capture_generation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_capture_generation() -> int:
```

获取桥分配的单调捕获代际。

返回：大于 0 的捕获代际。

<a id="member-gfviewportsurfaceinputcapture-methods-get_target_generation"></a>

### `get_target_generation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_target_generation() -> int:
```

获取 Resolver 在按下时提供的目标代际。

返回：大于 0 的外部目标代际。
