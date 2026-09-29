# 最小 kernel 示例的固定模板；只生成项目源码，不加载生成的脚本。
extends RefCounted


# --- 框架内部方法 ---

## 创建带明确输出路径的模板内容。
## [br]
## @api framework_internal
## [br]
## @param directory: 已验证的项目资源目录。
## [br]
## @param class_prefix: 已验证且无冲突的类型前缀。
## [br]
## @return 相对文件名到 UTF-8 文本内容的映射。
## [br]
## @schema return: Dictionary[String, String]，包含 counter_model.gd、counter_system.gd、game_installer.gd、bootstrap.gd、bootstrap.tscn 和 README.md。
static func render(directory: String, class_prefix: String) -> Dictionary:
	var result: Dictionary = {}
	var templates: Dictionary = {
		"counter_model.gd": _model(),
		"counter_system.gd": _system(),
		"game_installer.gd": _installer(),
		"bootstrap.gd": _bootstrap(),
		"bootstrap.tscn": _scene(),
		"README.md": _readme(),
	}
	for file_name: String in templates:
		var content: String = templates[file_name]
		# 只替换模板原文中的 token，不二次解释用户目录或前缀内的相同字符。
		var parts: PackedStringArray = content.split("__ROOT__")
		for index: int in range(parts.size()):
			parts[index] = parts[index].replace("__PREFIX__", class_prefix)
		result[file_name] = directory.join(parts)
	return result


# --- 私有/辅助方法 ---

static func _model() -> String:
	return """# 示例状态：由 System 修改，场景订阅更新。
class_name __PREFIX__CounterModel
extends GFModel


signal count_changed(value: int)


var count: int = 0


func increment() -> void:
	count += 1
	count_changed.emit(count)
"""


static func _system() -> String:
	return """# 示例逻辑：声明依赖后，只在运行期访问 Model。
class_name __PREFIX__CounterSystem
extends GFSystem


const _MODEL_SCRIPT = preload("__ROOT__/counter_model.gd")


func get_required_models() -> Array[Script]:
	return [_MODEL_SCRIPT]


func increment() -> void:
	var model: Object = get_model(_MODEL_SCRIPT)
	if model is _MODEL_SCRIPT:
		var counter: _MODEL_SCRIPT = model
		counter.increment()
"""


static func _installer() -> String:
	return """# 项目装配入口；已追加至 gf/project/installers。
class_name __PREFIX__Installer
extends GFInstaller


const _MODEL_SCRIPT = preload("__ROOT__/counter_model.gd")
const _SYSTEM_SCRIPT = preload("__ROOT__/counter_system.gd")


## 装配示例模块；每次异步注册后都检查启动作用域是否取消。
## [br]
## @param architecture: 接收示例模块的架构。
## [br]
## @param scope: 当前启动步骤的取消作用域。
func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:
	var model_registered: bool = await architecture.register_model_instance(_MODEL_SCRIPT.new())
	if scope.is_cancel_requested():
		return
	if not model_registered:
		architecture.fail_initialization("__PREFIX__CounterModel registration failed.")
		return
	var system_registered: bool = await architecture.register_system_instance(_SYSTEM_SCRIPT.new())
	if scope.is_cancel_requested():
		return
	if not system_registered:
		architecture.fail_initialization("__PREFIX__CounterSystem registration failed.")
"""


static func _bootstrap() -> String:
	return """# 在编辑器中打开 bootstrap.tscn，按 F6 运行当前场景。
extends Control


const _MODEL_SCRIPT = preload("__ROOT__/counter_model.gd")
const _SYSTEM_SCRIPT = preload("__ROOT__/counter_system.gd")


var _model: _MODEL_SCRIPT = null
var _system: _SYSTEM_SCRIPT = null


@onready var _status: Label = %Status
@onready var _increment: Button = %Increment


func _ready() -> void:
	_increment.disabled = true
	var initialized: bool = await Gf.init()
	if not is_inside_tree():
		return
	if not initialized:
		_status.text = "GF 初始化失败：" + Gf.get_architecture().last_initialization_error
		return
	var model: Object = Gf.get_model(_MODEL_SCRIPT)
	var system: Object = Gf.get_system(_SYSTEM_SCRIPT)
	if not model is _MODEL_SCRIPT or not system is _SYSTEM_SCRIPT:
		_status.text = "未找到示例模块；请检查 gf/project/installers。"
		return
	_model = model
	_system = system
	var _model_connected: int = _model.count_changed.connect(_on_count_changed)
	var _button_connected: int = _increment.pressed.connect(_on_increment_pressed)
	_on_count_changed(_model.count)
	_increment.disabled = false


func _exit_tree() -> void:
	if _model != null and _model.count_changed.is_connected(_on_count_changed):
		_model.count_changed.disconnect(_on_count_changed)
	_model = null
	_system = null


func _on_increment_pressed() -> void:
	if _system != null:
		_system.increment()


func _on_count_changed(value: int) -> void:
	if is_inside_tree():
		_status.text = "GF 已就绪 · 计数：%d" % value
"""


static func _scene() -> String:
	return """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="__ROOT__/bootstrap.gd" id="1"]

[node name="Bootstrap" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")

[node name="Center" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Content" type="VBoxContainer" parent="Center"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="Title" type="Label" parent="Center/Content"]
layout_mode = 2
text = "GF 最小项目"
horizontal_alignment = 1

[node name="Status" type="Label" parent="Center/Content"]
unique_name_in_owner = true
layout_mode = 2
text = "正在初始化 GF…"
horizontal_alignment = 1

[node name="Increment" type="Button" parent="Center/Content"]
unique_name_in_owner = true
layout_mode = 2
disabled = true
text = "计数 +1"
"""


static func _readme() -> String:
	return """# GF 最小项目

打开 `__ROOT__/bootstrap.tscn`，按 F6 运行当前场景，再点击“计数 +1”。

- `counter_model.gd` 保存计数并发送变化信号。
- `counter_system.gd` 声明 Model 依赖并处理递增请求。
- `game_installer.gd` 装配这两个模块，已追加至 `gf/project/installers`。
- `bootstrap.gd` 等待 `Gf.init()` 成功后连接场景 UI，退出场景时解除 Model 订阅。

这些文件现在属于项目，可以自由编辑。生成器不会覆盖它们。
默认保留原有 Installer 和主场景；只有创建时显式勾选才设置主场景。
请保持 GF 插件启用及 `Gf` AutoLoad 存在。示例只依赖 GF kernel。
"""
