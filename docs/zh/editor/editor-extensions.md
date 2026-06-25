# Inspector、工作区页面与导出插件

标准库自带编辑器增强集中声明在 `addons/gf/standard/editor/gf_standard_editor_extensions.gd`，再由根插件 `addons/gf/plugin.gd` 作为组合入口传给 `kernel/editor` 辅助脚本。

## 标准库页面

这些通用页面会进入 `GF Workspace`：

- State Tools 页面，用于扫描当前场景中的节点状态机并展示结构校验报告。
- Input Mapping 页面，用于读取 `GFInputContext` 资源，查看动作、绑定与重绑定冲突诊断。
- Storage Viewer 页面，用于按 `GFStorageCodec` 选项查看本地存档文件内容。
- Signal Diagnostics 页面，用于查看当前编辑场景的信号连接、未连接信号和显式开启后的发射记录。
- Diagnostics 页面，用于采集通用性能、架构、工具监控与可选场景树快照。

Inspector 与导出插件仍按对应类型装载，例如 Node State Machine Inspector、Pattern2D Inspector、AudioBank Inspector 和 BuildInfo 导出插件。

## 资源预览与路径字段

GF 会注册一个通用 Resource 预览生成器。资源可以通过 `get_gf_preview_texture()` 或 `get_gf_icon_texture()` 返回 `Texture2D`；没有显式方法时，生成器会尝试读取 `preview_texture` 或 `icon` 字段。预览生成器只把已有纹理等比适配到编辑器请求尺寸，不解释资源业务含义，也不要求项目资源继承某个 GF 基类。

GF 也会为 `String` 类型且带有可识别 `@export_file()` 资源 hint 的字段提供 ResourcePicker。例如 `@export_file("*.tscn") var scene_path: String` 会显示场景资源选择器，保存时优先写入 `uid://`，资源没有 UID 时回退到 `res://`。当字段当前值是 `uid://` 时，Inspector 会显示解析后的 `res://` 路径；路径缺失、UID 无效或类型不匹配时会在字段下方显示状态提示。普通文本文件路径、未识别扩展名和非 String 字段不会被接管。

需要用资源类型而不是扩展名声明单个路径时，可以使用 `GFResourcePathHint.RESOURCE_PATH`：

```gdscript
@export_custom(GFResourcePathHint.RESOURCE_PATH, "Texture2D")
var icon_path: String = ""
```

资源路径列表可以显式使用 `GFResourcePathHint.RESOURCE_PATH_ARRAY`。编辑器会为 `Array[String]` 和 `PackedStringArray` 提供按行选择、排序、移除和状态提示，并沿用单值路径字段的 `uid://` 写入策略：

```gdscript
@export_custom(GFResourcePathHint.RESOURCE_PATH_ARRAY, "PackedScene")
var preload_scene_paths: PackedStringArray = []
```

数组字段必须显式使用 GF hint，避免普通字符串数组被 Inspector 误判为资源路径列表。`hint_string` 可以写 Godot 资源类名，例如 `PackedScene`、`Texture2D`、`AudioStream`，为空时按通用 `Resource` 处理。

## 扩展贡献

GF 内置扩展或外部扩展的编辑器增强由各自 manifest 声明：

- `editor_action_paths`：GF 菜单动作，也可贡献脚本模板记录。
- `editor_dock_paths`：GF 工作区页面。
- `editor_inspector_paths`：`EditorInspectorPlugin`。
- `export_plugin_paths`：扩展自己的导出插件。
- `access_generator_extension_paths`：访问器生成扩展。

核心插件只按启用状态装载这些入口，不在 `kernel` 中硬编码标准库或可选扩展脚本。这样可选扩展被禁用或删除时，核心和标准库仍应可加载；标准库增强存在与否也不会改变 `kernel` 的源码依赖边界。
