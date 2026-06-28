# GFSurfaceUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/display/gf_surface_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

3D 表面材质查询工具。 根据碰撞命中的 face index 推导 MeshInstance3D surface，并返回基础材质、 覆盖材质或最终 active material。框架只负责几何到材质的映射，不解释材质语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`CacheMode`](#member-gfsurfaceutility-enums-cachemode) | `enum CacheMode` |
| 常量 | [`DEFAULT_AUTO_CACHE_SIZE`](#member-gfsurfaceutility-constants-default_auto_cache_size) | `const DEFAULT_AUTO_CACHE_SIZE: int = 8` |
| 属性 | [`cache_mode`](#member-gfsurfaceutility-properties-cache_mode) | `var cache_mode: CacheMode = CacheMode.AUTOMATIC` |
| 属性 | [`auto_cache_size`](#member-gfsurfaceutility-properties-auto_cache_size) | `var auto_cache_size: int = DEFAULT_AUTO_CACHE_SIZE` |
| 方法 | [`dispose`](#member-gfsurfaceutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`get_active_material`](#member-gfsurfaceutility-methods-get_active_material) | `func get_active_material(source: Object, face_index: int) -> Material:` |
| 方法 | [`describe_surface_hit`](#member-gfsurfaceutility-methods-describe_surface_hit) | `func describe_surface_hit(source: Object, face_index: int) -> Dictionary:` |
| 方法 | [`get_surface_override_material`](#member-gfsurfaceutility-methods-get_surface_override_material) | `func get_surface_override_material(source: Object, face_index: int) -> Material:` |
| 方法 | [`get_base_material`](#member-gfsurfaceutility-methods-get_base_material) | `func get_base_material(source: Object, face_index: int) -> Material:` |
| 方法 | [`get_surface_index`](#member-gfsurfaceutility-methods-get_surface_index) | `func get_surface_index(source: Object, face_index: int) -> int:` |
| 方法 | [`clear_cache`](#member-gfsurfaceutility-methods-clear_cache) | `func clear_cache() -> void:` |
| 方法 | [`cache_mesh_surface`](#member-gfsurfaceutility-methods-cache_mesh_surface) | `func cache_mesh_surface(source: Object) -> bool:` |
| 方法 | [`erase_cached_mesh`](#member-gfsurfaceutility-methods-erase_cached_mesh) | `func erase_cached_mesh(source: Object) -> bool:` |
| 方法 | [`set_auto_cache_size`](#member-gfsurfaceutility-methods-set_auto_cache_size) | `func set_auto_cache_size(size: int) -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfsurfaceutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 枚举

<a id="member-gfsurfaceutility-enums-cachemode"></a>

### `CacheMode`

- API：`public`

```gdscript
enum CacheMode {
	## 不读写缓存，每次查询都重新计算。
	DISABLED,
	## 只使用显式预热写入的缓存。
	MANUAL,
	## 查询时自动缓存，并按 auto_cache_size 控制容量。
	AUTOMATIC,
}
```

Mesh surface face count 缓存策略。

## 常量

<a id="member-gfsurfaceutility-constants-default_auto_cache_size"></a>

### `DEFAULT_AUTO_CACHE_SIZE`

- API：`public`

```gdscript
const DEFAULT_AUTO_CACHE_SIZE: int = 8
```

自动缓存默认容量。

## 属性

<a id="member-gfsurfaceutility-properties-cache_mode"></a>

### `cache_mode`

- API：`public`

```gdscript
var cache_mode: CacheMode = CacheMode.AUTOMATIC
```

当前缓存策略。

<a id="member-gfsurfaceutility-properties-auto_cache_size"></a>

### `auto_cache_size`

- API：`public`

```gdscript
var auto_cache_size: int = DEFAULT_AUTO_CACHE_SIZE
```

自动缓存容量。小于 1 时会被归一化为 1。

## 方法

<a id="member-gfsurfaceutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放工具时清空 Mesh surface face count 缓存。

<a id="member-gfsurfaceutility-methods-get_active_material"></a>

### `get_active_material`

- API：`public`

```gdscript
func get_active_material(source: Object, face_index: int) -> Material:
```

获取命中表面最终渲染使用的材质。

参数：

| 名称 | 说明 |
|---|---|
| `source` | MeshInstance3D、CollisionObject3D 或其相邻节点。 |
| `face_index` | RayCast3D.get_collision_face_index() 返回的面索引。 |

返回：命中材质；无法解析时返回 null。

<a id="member-gfsurfaceutility-methods-describe_surface_hit"></a>

### `describe_surface_hit`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func describe_surface_hit(source: Object, face_index: int) -> Dictionary:
```

描述命中表面的结构化报告。 返回值面向运行时分发、调试面板和日志摘要；GF 只暴露 surface/material 数据， 不解释脚步声、弹孔、地形标签或其它业务语义。

参数：

| 名称 | 说明 |
|---|---|
| `source` | MeshInstance3D、CollisionObject3D 或其相邻节点。 |
| `face_index` | RayCast3D.get_collision_face_index() 返回的面索引。 |

返回：表面命中报告；无法解析时 ok 为 false，并保留 reason。

结构：

- `return`: Dictionary，包含 ok、reason、face_index、surface_index、base_material、override_material、active_material、has_*_material 以及对应 *_material_name、*_material_path、*_material_type 字段。

<a id="member-gfsurfaceutility-methods-get_surface_override_material"></a>

### `get_surface_override_material`

- API：`public`

```gdscript
func get_surface_override_material(source: Object, face_index: int) -> Material:
```

获取 MeshInstance3D surface override 材质。

参数：

| 名称 | 说明 |
|---|---|
| `source` | MeshInstance3D、CollisionObject3D 或其相邻节点。 |
| `face_index` | RayCast3D.get_collision_face_index() 返回的面索引。 |

返回：覆盖材质；未设置或无法解析时返回 null。

<a id="member-gfsurfaceutility-methods-get_base_material"></a>

### `get_base_material`

- API：`public`

```gdscript
func get_base_material(source: Object, face_index: int) -> Material:
```

获取 Mesh 资源自身的 surface 材质。

参数：

| 名称 | 说明 |
|---|---|
| `source` | MeshInstance3D、CollisionObject3D 或其相邻节点。 |
| `face_index` | RayCast3D.get_collision_face_index() 返回的面索引。 |

返回：基础材质；无法解析时返回 null。

<a id="member-gfsurfaceutility-methods-get_surface_index"></a>

### `get_surface_index`

- API：`public`

```gdscript
func get_surface_index(source: Object, face_index: int) -> int:
```

获取 face index 所属的 Mesh surface 索引。

参数：

| 名称 | 说明 |
|---|---|
| `source` | MeshInstance3D、CollisionObject3D 或其相邻节点。 |
| `face_index` | RayCast3D.get_collision_face_index() 返回的面索引。 |

返回：surface 索引；无法解析时返回 -1。

<a id="member-gfsurfaceutility-methods-clear_cache"></a>

### `clear_cache`

- API：`public`

```gdscript
func clear_cache() -> void:
```

清空 Mesh surface face count 缓存。

<a id="member-gfsurfaceutility-methods-cache_mesh_surface"></a>

### `cache_mesh_surface`

- API：`public`

```gdscript
func cache_mesh_surface(source: Object) -> bool:
```

预热指定 Mesh 或 MeshInstance3D 的 surface face count 缓存。

参数：

| 名称 | 说明 |
|---|---|
| `source` | Mesh、MeshInstance3D、CollisionObject3D 或其相邻节点。 |

返回：缓存成功返回 true。

<a id="member-gfsurfaceutility-methods-erase_cached_mesh"></a>

### `erase_cached_mesh`

- API：`public`

```gdscript
func erase_cached_mesh(source: Object) -> bool:
```

移除指定 Mesh 或 MeshInstance3D 的 surface face count 缓存。

参数：

| 名称 | 说明 |
|---|---|
| `source` | Mesh、MeshInstance3D、CollisionObject3D 或其相邻节点。 |

返回：移除成功返回 true。

<a id="member-gfsurfaceutility-methods-set_auto_cache_size"></a>

### `set_auto_cache_size`

- API：`public`

```gdscript
func set_auto_cache_size(size: int) -> void:
```

设置自动缓存容量。

参数：

| 名称 | 说明 |
|---|---|
| `size` | 自动缓存容量；小于 1 时按 1 处理。 |

<a id="member-gfsurfaceutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：缓存状态。

结构：

- `return`: Dictionary，包含 cached_meshes、cache_mode 和 auto_cache_size。
