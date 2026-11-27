@tool

## GFUIMaterialMotion: 将独立材质装到表现节点，显式绑定纹理输入并随轨道驱动一个 uniform。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFUIMaterialMotion
extends GFUIMotionEffect


# --- 导出变量 ---

## 各运行会话复制的材质模板。可使用项目自己的 canvas_item shader。
## [br]
## @api public
## [br]
## @since unreleased
@export var material: ShaderMaterial

## 接受局部进度的浮点 uniform。
## [br]
## @api public
## [br]
## @since unreleased
@export var progress_parameter: StringName = &"progress"

## 把项目提供的具名纹理绑定到独立的 sampler2D。
## [br]
## @api public
## [br]
## @schema textures: Dictionary[StringName, StringName]，键是 shader uniform，值是输入槽。
## [br]
## @since unreleased
@export var textures: Dictionary[StringName, StringName] = {}

## 在自然或立即完成后隐藏临时合成面，暴露宿主提供的目标页面。
## [br]
## @api public
## [br]
## @since unreleased
@export var hide_on_end: bool = true


# --- 公共方法 ---

## 声明材质要用到的独立二维纹理。
## [br]
## @api public
## [br]
## @return: 需要绑定的纹理类型。
## [br]
## @schema return: Dictionary，输入名映射到 Texture2D。
## [br]
## @since unreleased
func input_types() -> Dictionary:
	var types: Dictionary = {}
	for slot: StringName in textures.values():
		types[slot] = Texture2D
	return types


## 一个表现节点在会话内只装配一套合成材质。
## [br]
## @api public
## [br]
## @return: 独占的材质和局部可见性属性。
## [br]
## @since unreleased
func written_properties() -> Array[NodePath]:
	return [^"material", ^"visible"]


## 验证材质进度及纹理 uniform 的实际类型。
## [br]
## @api public
## [br]
## @param target: 材质的宿主。
## [br]
## @param _inputs: 项目纹理。
## [br]
## @schema _inputs: Dictionary，名称对应已验证的 Texture2D。
## [br]
## @return: 失败原因或空串。
## [br]
## @since unreleased
func binding_error(target: Object, _inputs: Dictionary) -> String:
	if (
		not target is CanvasItem
		or material == null
		or material.shader == null
	):
		return "合成需要 CanvasItem 和有效 ShaderMaterial"
	var uniforms: Dictionary = {}
	for item: Dictionary in material.shader.get_shader_uniform_list():
		var uniform_name: StringName = item.name
		uniforms[uniform_name] = item
	var progress_info: Dictionary = uniforms.get(progress_parameter, {})
	if progress_info.get("type") != TYPE_FLOAT:
		return "缺少 float uniform %s" % progress_parameter
	for uniform: StringName in textures:
		var texture_info: Dictionary = uniforms.get(uniform, {})
		if texture_info.get("hint_string") != "Texture2D":
			return "缺少 sampler2D uniform %s" % uniform
	return ""


## 绑定纹理并持有本实例的材质，结束时恢复先前材质。
## [br]
## @api public
## [br]
## @param target: 画面宿主。
## [br]
## @param inputs: 项目纹理输入。
## [br]
## @schema inputs: Dictionary，具名 Texture2D，可包含实时 ViewportTexture。
## [br]
## @return: 可定位的进度采样操作。
## [br]
## @since unreleased
func bind_target(target: Object, inputs: Dictionary) -> GFUIMotionBinding:
	var canvas: CanvasItem = target as CanvasItem
	var previous: Material = canvas.material
	var was_visible: bool = canvas.visible
	var instance: ShaderMaterial = material.duplicate() as ShaderMaterial
	var parameter: StringName = progress_parameter
	var should_hide: bool = hide_on_end
	for uniform: StringName in textures:
		instance.set_shader_parameter(
			uniform,
			inputs[textures[uniform]]
		)
	var sample: Callable = func(weight: float) -> void:
		if canvas.material != instance:
			canvas.material = instance
			canvas.show()
		instance.set_shader_parameter(parameter, weight)
	var release: Callable = func(reason: int) -> void:
		if not is_instance_valid(canvas) or canvas.material != instance:
			return
		if reason == GFUIMotionBinding.EndReason.REPLACED:
			return
		if reason == GFUIMotionBinding.EndReason.CANCELLED or should_hide:
			canvas.material = previous
			canvas.visible = was_visible if reason == GFUIMotionBinding.EndReason.CANCELLED else false
	return GFUIMotionBinding.new(sample, release)
