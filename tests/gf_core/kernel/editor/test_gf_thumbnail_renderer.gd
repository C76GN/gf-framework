## 测试 GFThumbnailRenderer 的输入边界处理。
extends GutTest


# --- 常量 ---

const SCRIPTED_NODE2D_SCRIPT = preload(
	"res://tests/gf_core/kernel/editor/fixtures/gf_thumbnail_scripted_node2d.gd"
)
const SCRIPTED_NODE3D_SCRIPT = preload(
	"res://tests/gf_core/kernel/editor/fixtures/gf_thumbnail_scripted_node3d.gd"
)
const SCRIPTED_MATERIAL_SCRIPT = preload(
	"res://tests/gf_core/kernel/editor/fixtures/gf_thumbnail_scripted_material.gd"
)
const MESH_VISUAL_PROBE_SCRIPT = preload(
	"res://tests/gf_core/kernel/editor/fixtures/gf_thumbnail_mesh_visual_probe.gd"
)
const SURFACE_MATERIAL_PROBE_SCRIPT = preload(
	"res://tests/gf_core/kernel/editor/fixtures/gf_thumbnail_surface_material_probe.gd"
)


# --- 测试方法 ---

func test_static_nine_patch_copy_preserves_all_patch_margins() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: NinePatchRect = NinePatchRect.new()
	var margins: Array[int] = [3, 5, 7, 9]
	var sides: Array[Side] = [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]
	for index: int in sides.size():
		source.set_patch_margin(sides[index], margins[index])
	source.size = Vector2(80.0, 60.0)
	var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)

	assert_true(copy is NinePatchRect, "静态九宫格应保留原生视觉类型。")
	if copy is NinePatchRect:
		var patch_copy: NinePatchRect = copy
		for index: int in sides.size():
			assert_eq(patch_copy.get_patch_margin(sides[index]), margins[index], "副本应保留每一侧九宫格边距。")
		assert_eq(patch_copy.size, source.size, "边距复制后仍应保留解析后的矩形。")
	if copy != null:
		copy.free()
	source.free()
	renderer.free()


func test_static_texture_progress_copy_preserves_all_stretch_margins() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: TextureProgressBar = TextureProgressBar.new()
	source.nine_patch_stretch = true
	var margins: Array[int] = [2, 4, 6, 8]
	var sides: Array[Side] = [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]
	for index: int in sides.size():
		source.set_stretch_margin(sides[index], margins[index])
	source.size = Vector2(80.0, 60.0)
	source.value = 37.0
	var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)

	assert_true(copy is TextureProgressBar, "静态纹理进度条应保留原生视觉类型。")
	if copy is TextureProgressBar:
		var progress_copy: TextureProgressBar = copy
		assert_true(progress_copy.nine_patch_stretch, "副本应保留九宫格拉伸开关。")
		for index: int in sides.size():
			assert_eq(progress_copy.get_stretch_margin(sides[index]), margins[index], "副本应保留每一侧拉伸边距。")
		assert_eq(progress_copy.value, 37.0, "副本应保留当前进度。")
	if copy != null:
		copy.free()
	source.free()
	renderer.free()


func test_static_mesh_copy_preserves_per_surface_materials_without_script_reads() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: MESH_VISUAL_PROBE_SCRIPT = MESH_VISUAL_PROBE_SCRIPT.new()
	var source_mesh: ArrayMesh = _create_surface_mesh(2)
	var first_material: StandardMaterial3D = StandardMaterial3D.new()
	var second_material: StandardMaterial3D = StandardMaterial3D.new()
	first_material.albedo_color = Color.RED
	second_material.albedo_color = Color.BLUE
	source.mesh = source_mesh
	source.set_surface_override_material(0, first_material)
	source.set_surface_override_material(1, second_material)
	MESH_VISUAL_PROBE_SCRIPT.reset_observations()
	var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)

	assert_true(copy is MeshInstance3D, "静态 Mesh 应保留原生视觉类型。")
	if copy is MeshInstance3D:
		var mesh_copy: MeshInstance3D = copy
		assert_same(mesh_copy.mesh, source_mesh, "静态副本应只读共享 Mesh。")
		assert_same(mesh_copy.get_surface_override_material(0), first_material, "第一表面应保留实例材质覆盖。")
		assert_same(mesh_copy.get_surface_override_material(1), second_material, "第二表面应保留独立材质覆盖。")
	assert_eq(MESH_VISUAL_PROBE_SCRIPT.getter_count, 0, "材质复制不得读取源脚本导出 getter。")
	assert_eq(MESH_VISUAL_PROBE_SCRIPT.property_list_count, 0, "材质复制不得枚举源脚本动态属性。")
	assert_eq(MESH_VISUAL_PROBE_SCRIPT.dynamic_get_count, 0, "材质复制不得调用源脚本 _get。")
	assert_eq(MESH_VISUAL_PROBE_SCRIPT.dynamic_get_properties, [], "源脚本读取位置应保持为空。")
	assert_same(source.get_surface_override_material(0), first_material, "来源实例材质应保持。")
	assert_eq(first_material.albedo_color, Color.RED, "共享材质内容应保持。")
	assert_eq(second_material.albedo_color, Color.BLUE, "其他表面的共享材质内容也应保持。")
	if copy != null:
		copy.free()
	source.free()
	renderer.free()


func test_static_mesh_copy_rejects_scripted_surface_override_material() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: MeshInstance3D = MeshInstance3D.new()
	source.name = "ScriptedSurfaceMesh"
	source.mesh = BoxMesh.new()
	var material: SURFACE_MATERIAL_PROBE_SCRIPT = SURFACE_MATERIAL_PROBE_SCRIPT.new()
	source.set_surface_override_material(0, material)
	SURFACE_MATERIAL_PROBE_SCRIPT.initialized_count = 0
	var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)

	assert_null(copy, "表面覆盖材质也必须满足直接原生资源边界。")
	assert_true(renderer._render_error.contains("surface_material_override/0"), "失败应定位实例表面材质。")
	assert_eq(SURFACE_MATERIAL_PROBE_SCRIPT.initialized_count, 0, "拒绝脚本材质时不得复制或构造脚本资源。")
	assert_same(source.get_surface_override_material(0), material, "拒绝后来源的表面覆盖应保持。")
	if copy != null:
		copy.free()
	source.free()
	renderer.free()


func test_static_mesh_surface_budget_is_shared_and_resets_after_failure() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: Node3D = Node3D.new()
	var shared_mesh: ArrayMesh = _create_surface_mesh(64)
	var last_instance: MeshInstance3D
	for mesh_index: int in 65:
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.name = "Mesh%d" % mesh_index
		mesh_instance.mesh = shared_mesh
		source.add_child(mesh_instance)
		last_instance = mesh_instance
	var rejected: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)
	assert_null(rejected, "共享 Mesh 的每个实例也应计入整次快照的表面预算。")
	assert_true(renderer._render_error.contains("surface material slot limit"), "失败应解释表面预算。")
	assert_true(renderer._render_error.contains("Mesh64"), "失败应定位首个超预算实例。")
	if rejected != null:
		rejected.free()
	if last_instance != null:
		last_instance.free()
	var accepted: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)
	assert_not_null(accepted, "新的快照应重新计数并接受恰好 4096 个表面。")
	if accepted != null:
		assert_eq(accepted.get_child_count(), 64, "达到预算的快照应完整保留全部实例。")
		accepted.free()
	assert_eq(shared_mesh.get_surface_count(), 64, "预算拒绝和重试不得修改共享 Mesh。")
	source.free()
	renderer.free()


func test_static_sprite3d_copy_preserves_indexed_draw_flags() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var sources: Array[SpriteBase3D] = [Sprite3D.new(), AnimatedSprite3D.new()]
	for source: SpriteBase3D in sources:
		for flag_index: int in SpriteBase3D.FLAG_MAX:
			var flag: SpriteBase3D.DrawFlags = flag_index as SpriteBase3D.DrawFlags
			source.set_draw_flag(flag, not source.get_draw_flag(flag))
		var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)
		assert_true(copy is SpriteBase3D, "静态 3D Sprite 应保留原生类型。")
		if copy is SpriteBase3D:
			var sprite_copy: SpriteBase3D = copy
			for flag_index: int in SpriteBase3D.FLAG_MAX:
				var flag: SpriteBase3D.DrawFlags = flag_index as SpriteBase3D.DrawFlags
				assert_eq(sprite_copy.get_draw_flag(flag), source.get_draw_flag(flag), "副本应保留每个绘制标记。")
		if copy != null:
			copy.free()
		source.free()
	renderer.free()


func test_static_label3d_copy_preserves_indexed_draw_flags() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: Label3D = Label3D.new()
	for flag_index: int in Label3D.FLAG_MAX:
		var flag: Label3D.DrawFlags = flag_index as Label3D.DrawFlags
		source.set_draw_flag(flag, not source.get_draw_flag(flag))
	var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)
	assert_true(copy is Label3D, "静态 3D Label 应保留原生类型。")
	if copy is Label3D:
		var label_copy: Label3D = copy
		for flag_index: int in Label3D.FLAG_MAX:
			var flag: Label3D.DrawFlags = flag_index as Label3D.DrawFlags
			assert_eq(label_copy.get_draw_flag(flag), source.get_draw_flag(flag), "副本应保留每个文字绘制标记。")
	if copy != null:
		copy.free()
	source.free()
	renderer.free()


func test_static_light3d_copy_preserves_indexed_light_and_shadow_parameters() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var sources: Array[Light3D] = [DirectionalLight3D.new(), OmniLight3D.new(), SpotLight3D.new()]
	for source: Light3D in sources:
		source.set_param(Light3D.PARAM_ENERGY, 2.25)
		source.set_param(Light3D.PARAM_SHADOW_BIAS, 0.125)
		if source is DirectionalLight3D:
			source.set_param(Light3D.PARAM_SHADOW_SPLIT_1_OFFSET, 0.25)
		else:
			source.set_param(Light3D.PARAM_RANGE, 9.5)
		var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)
		assert_true(copy is Light3D, "静态灯光应保留原生类型。")
		if copy is Light3D:
			var light_copy: Light3D = copy
			for param_index: int in Light3D.PARAM_MAX:
				var param: Light3D.Param = param_index as Light3D.Param
				assert_eq(light_copy.get_param(param), source.get_param(param), "副本应保留灯光和阴影参数。")
		if copy != null:
			copy.free()
		source.free()
	renderer.free()


func test_default_canvas_thumbnail_does_not_construct_or_run_root_and_nested_scripts() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var source: SCRIPTED_NODE2D_SCRIPT = SCRIPTED_NODE2D_SCRIPT.new()
	var nested: SCRIPTED_NODE2D_SCRIPT = SCRIPTED_NODE2D_SCRIPT.new()
	var shared_material: StandardMaterial3D = StandardMaterial3D.new()
	shared_material.albedo_color = Color.BLUE
	source.shared_material = shared_material
	nested.shared_material = shared_material
	source.add_child(nested)
	SCRIPTED_NODE2D_SCRIPT.reset_observations()

	var _image: Image = await renderer.render_canvas_item(
		source, Vector2i(16, 16), true, Rect2(0.0, 0.0, 8.0, 8.0)
	)

	assert_eq(SCRIPTED_NODE2D_SCRIPT.initialized_count, 0, "静态副本不得构造根或嵌套节点脚本。")
	assert_eq(SCRIPTED_NODE2D_SCRIPT.entered_count, 0, "静态副本不得执行脚本 _enter_tree。")
	assert_eq(SCRIPTED_NODE2D_SCRIPT.ready_count, 0, "静态副本不得执行脚本 _ready。")
	assert_eq(SCRIPTED_NODE2D_SCRIPT.getter_count, 0, "静态读取不得触发源脚本的导出 getter。")
	assert_eq(SCRIPTED_NODE2D_SCRIPT.property_list_count, 0, "静态读取不得枚举源脚本动态属性。")
	assert_eq(shared_material.albedo_color, Color.BLUE, "预览不得通过脚本写回共享资源。")
	assert_eq(renderer._canvas_root.get_child_count(), 1, "完成后应释放临时静态副本。")
	source.free()
	renderer.queue_free()
	await get_tree().process_frame


func test_default_node3d_thumbnail_does_not_construct_or_run_root_and_nested_scripts() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var source: SCRIPTED_NODE3D_SCRIPT = SCRIPTED_NODE3D_SCRIPT.new()
	var nested: SCRIPTED_NODE3D_SCRIPT = SCRIPTED_NODE3D_SCRIPT.new()
	var shared_material: StandardMaterial3D = StandardMaterial3D.new()
	shared_material.albedo_color = Color.BLUE
	source.shared_material = shared_material
	nested.shared_material = shared_material
	source.add_child(nested)
	SCRIPTED_NODE3D_SCRIPT.reset_observations()

	var _image: Image = await renderer.render_node3d(source, Vector2i(16, 16))

	assert_eq(SCRIPTED_NODE3D_SCRIPT.initialized_count, 0, "静态副本不得构造根或嵌套节点脚本。")
	assert_eq(SCRIPTED_NODE3D_SCRIPT.entered_count, 0, "静态副本不得执行脚本 _enter_tree。")
	assert_eq(SCRIPTED_NODE3D_SCRIPT.ready_count, 0, "静态副本不得执行脚本 _ready。")
	assert_eq(shared_material.albedo_color, Color.BLUE, "预览不得通过脚本写回共享资源。")
	assert_eq(renderer._world_root.get_child_count(), 3, "完成后应只保留相机和灯光。")
	source.free()
	renderer.queue_free()
	await get_tree().process_frame


func test_static_copy_does_not_inherit_persistent_connections_or_groups() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var source: Node2D = Node2D.new()
	var entered_count: Array[int] = [0]
	var entered_callback: Callable = func() -> void:
		entered_count[0] += 1
	var _connected: Error = source.tree_entered.connect(entered_callback, CONNECT_PERSIST) as Error
	source.add_to_group(&"gf_thumbnail_source_group", true)
	var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)

	assert_not_null(copy, "普通 Node2D 应支持静态副本。")
	if copy != null:
		assert_false(copy.is_in_group(&"gf_thumbnail_source_group"), "副本不得参与来源的业务分组。")
		renderer._canvas_root.add_child(copy)
		assert_eq(entered_count[0], 0, "副本入树不得调用来源的外部持久信号连接。")
		renderer._free_render_instance(copy)
	assert_true(source.is_in_group(&"gf_thumbnail_source_group"), "来源分组应保持。")
	assert_true(source.tree_entered.is_connected(entered_callback), "来源信号连接应保持。")
	source.free()
	renderer.queue_free()
	await get_tree().process_frame


func test_static_button_copy_preserves_pressed_visual_without_joining_source_group() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: Button = Button.new()
	var group: ButtonGroup = ButtonGroup.new()
	source.toggle_mode = true
	source.button_group = group
	source.button_pressed = true
	var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)

	assert_true(copy is Button, "静态按钮应保留原生视觉类型。")
	assert_eq(group.get_buttons(), [source], "副本不能注册到来源 ButtonGroup。")
	assert_true(source.button_pressed, "副本不能改变来源的选中状态。")
	if copy is Button:
		var button_copy: Button = copy
		assert_null(button_copy.button_group, "副本不得保留外部行为关联。")
		assert_true(button_copy.toggle_mode, "副本应保留切换按钮外观。")
		assert_true(button_copy.button_pressed, "副本应保留当前按下外观。")
	if copy != null:
		copy.free()
	assert_eq(group.get_buttons(), [source], "释放副本后来源分组也应保持。")
	source.free()
	renderer.free()


func test_static_foldable_copy_preserves_expanded_visual_without_joining_source_group() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: FoldableContainer = FoldableContainer.new()
	var group: FoldableGroup = FoldableGroup.new()
	source.folded = false
	source.foldable_group = group
	var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)

	assert_true(copy is FoldableContainer, "静态折叠容器应保留原生视觉类型。")
	assert_eq(group.get_containers(), [source], "副本不能注册到来源 FoldableGroup。")
	assert_same(group.get_expanded_container(), source, "副本不能替换来源组的展开容器。")
	assert_false(source.folded, "副本不能改变来源的展开状态。")
	if copy is FoldableContainer:
		var container_copy: FoldableContainer = copy
		assert_null(container_copy.foldable_group, "副本不得保留外部折叠分组。")
		assert_false(container_copy.folded, "副本应保留当前展开外观。")
	if copy != null:
		copy.free()
	assert_eq(group.get_containers(), [source], "释放副本后来源折叠分组也应保持。")
	source.free()
	renderer.free()


func test_static_copy_neutralizes_native_autoplay_and_external_transform_writes() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var external_target: Node3D = Node3D.new()
	add_child(external_target)
	external_target.position = Vector3(7.0, 8.0, 9.0)
	var source: Node3D = Node3D.new()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = BoxMesh.new()
	var shared_material: StandardMaterial3D = StandardMaterial3D.new()
	shared_material.albedo_color = Color.BLUE
	mesh_instance.material_override = shared_material
	source.add_child(mesh_instance)
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "Animation"
	var animation: Animation = Animation.new()
	var track: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("Mesh:material_override:albedo_color"))
	var _inserted: int = animation.track_insert_key(track, 0.0, Color.RED)
	var library: AnimationLibrary = AnimationLibrary.new()
	var _added_animation: Error = library.add_animation(&"mutate", animation)
	var _added_library: Error = player.add_animation_library(&"", library)
	player.autoplay = "mutate"
	source.add_child(player)
	var timer: Timer = Timer.new()
	timer.name = "Timer"
	timer.autostart = true
	source.add_child(timer)
	var remote: RemoteTransform3D = RemoteTransform3D.new()
	remote.name = "Remote"
	remote.position = Vector3(90.0, 80.0, 70.0)
	remote.remote_path = external_target.get_path()
	source.add_child(remote)
	var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)

	assert_not_null(copy, "行为节点应转为静态层级载体并保留可见子节点。")
	if copy != null:
		renderer._world_root.add_child(copy)
		await get_tree().process_frame
		assert_eq(shared_material.albedo_color, Color.BLUE, "自动播放不得写回共享材质。")
		assert_eq(external_target.position, Vector3(7.0, 8.0, 9.0), "远程变换不得写入预览树外的节点。")
		var copied_timer: Node = copy.get_node_or_null("Timer")
		assert_not_null(copied_timer, "静态载体应保留层级名称。")
		assert_false(copied_timer is Timer, "静态层级中不应保留可自动启动的 Timer。")
		var copied_mesh: Node = copy.get_node_or_null("Mesh")
		assert_true(copied_mesh is MeshInstance3D, "静态副本应保留命名的 Mesh 节点。")
		if copied_mesh is MeshInstance3D:
			var mesh_copy: MeshInstance3D = copied_mesh
			assert_same(mesh_copy.material_override, shared_material, "静态资源应只读共享，避免任意深复制。")
		renderer._free_render_instance(copy)
	assert_eq(player.autoplay, "mutate", "来源的动画配置应保持。")
	assert_true(timer.autostart, "来源的自动启动配置应保持。")
	assert_eq(remote.remote_path, external_target.get_path(), "来源的外部关联应保持。")
	source.free()
	external_target.queue_free()
	renderer.queue_free()
	await get_tree().process_frame


func test_static_copy_keeps_animated_sprite_current_frame_without_autoplay() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: AnimatedSprite2D = AnimatedSprite2D.new()
	var frames: SpriteFrames = SpriteFrames.new()
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	frames.add_frame(&"default", ImageTexture.create_from_image(image))
	frames.add_frame(&"default", ImageTexture.create_from_image(image))
	source.sprite_frames = frames
	source.autoplay = "default"
	source.frame = 1
	var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)

	assert_true(copy is AnimatedSprite2D, "静态帧应保留原生 Sprite 绘制能力。")
	if copy is AnimatedSprite2D:
		var sprite_copy: AnimatedSprite2D = copy
		assert_eq(sprite_copy.frame, 1, "副本应保持当前帧。")
		assert_eq(sprite_copy.autoplay, "", "副本入树前必须去除自动播放。")
		assert_false(sprite_copy.is_playing(), "副本不应启动播放。")
	if copy != null:
		copy.free()
	source.free()
	renderer.free()


func test_static_request_rejects_complex_visuals_and_continues_queue() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var unsupported: Node3D = Node3D.new()
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "UnsupportedParticles"
	unsupported.add_child(particles)
	var supported: MeshInstance3D = MeshInstance3D.new()
	supported.mesh = BoxMesh.new()
	var rejected: GFThumbnailRenderTask = renderer.submit_render_request(
		GFThumbnailRenderRequest.for_node3d_image(unsupported, Vector2i(16, 16))
	)
	var following: GFThumbnailRenderTask = renderer.submit_render_request(
		GFThumbnailRenderRequest.for_node3d_image(supported, Vector2i(16, 16))
	)
	var _rejected_result: Variant = await rejected.wait_completed()
	var _following_result: Variant = await following.wait_completed()

	assert_true(rejected.is_failed(), "不支持的运行时视觉应失败，不能悄悄执行。")
	assert_true(rejected.get_error().contains("UnsupportedParticles"), "失败应定位不支持的节点。")
	assert_true(rejected.get_error().contains("GPUParticles3D"), "失败应解释原生类型边界。")
	assert_true(following.is_finished(), "前一请求失败不应阻塞后续队列。")
	assert_false(following.get_error().contains("Static thumbnail"), "静态构建错误不能泄漏到下一请求。")
	assert_eq(renderer._world_root.get_child_count(), 3, "失败和完成路径都不应遗留副本。")
	unsupported.free()
	supported.free()
	renderer.queue_free()
	await get_tree().process_frame


func test_static_copy_rejects_multimesh_nodes_that_write_shared_interpolation_state() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var sources: Array[Node] = [MultiMeshInstance2D.new(), MultiMeshInstance3D.new()]
	for source: Node in sources:
		var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)
		assert_null(copy, "MultiMesh 节点入树会更新共享资源状态，静态模式应明确拒绝。")
		assert_true(renderer._render_error.contains(source.get_class()), "失败应解释不支持的原生类型。")
		if copy != null:
			copy.free()
		source.free()
	renderer.free()


func test_static_request_rejects_scripted_resource_without_constructing_another_instance() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var source: MeshInstance3D = MeshInstance3D.new()
	source.mesh = BoxMesh.new()
	var material: SCRIPTED_MATERIAL_SCRIPT = SCRIPTED_MATERIAL_SCRIPT.new()
	source.material_override = material
	SCRIPTED_MATERIAL_SCRIPT.initialized_count = 0
	var task: GFThumbnailRenderTask = renderer.submit_render_request(
		GFThumbnailRenderRequest.for_node3d_image(source, Vector2i(16, 16))
	)
	var _result: Variant = await task.wait_completed()

	assert_true(task.is_failed(), "静态模式应拒绝直接绑定的脚本资源。")
	assert_true(task.get_error().contains("material_override"), "资源失败应定位原生视觉属性。")
	assert_eq(SCRIPTED_MATERIAL_SCRIPT.initialized_count, 0, "检查资源不能通过 duplicate 再构造脚本。")
	assert_same(source.material_override, material, "来源资源绑定应保持。")
	source.free()
	renderer.queue_free()
	await get_tree().process_frame


func test_trusted_dynamic_mode_preserves_preview_scripts_and_custom_draw() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var source: SCRIPTED_NODE2D_SCRIPT = SCRIPTED_NODE2D_SCRIPT.new()
	SCRIPTED_NODE2D_SCRIPT.reset_observations()
	var request: GFThumbnailRenderRequest = GFThumbnailRenderRequest.for_canvas_item_image(
		source, Vector2i(24, 24), true, Rect2(0.0, 0.0, 8.0, 8.0), 0.0,
		GFThumbnailRenderRequest.PreviewMode.TRUSTED_DYNAMIC
	)
	var task: GFThumbnailRenderTask = renderer.submit_render_request(request)
	var result: Variant = await task.wait_completed()

	assert_eq(request.get_preview_mode(), GFThumbnailRenderRequest.PreviewMode.TRUSTED_DYNAMIC)
	assert_gt(SCRIPTED_NODE2D_SCRIPT.initialized_count, 0, "显式可信动态模式应保留脚本构造。")
	assert_eq(SCRIPTED_NODE2D_SCRIPT.ready_count, 1, "显式可信动态模式应允许预览节点 ready。")
	if result is Image:
		var image: Image = result
		_assert_visible_pixels(image, "可信动态预览应保留自定义 _draw。")
	else:
		assert_eq(DisplayServer.get_name(), "headless", "真实渲染后端应生成动态预览。")
	assert_eq(renderer._canvas_root.get_child_count(), 1, "动态副本也必须释放。")
	source.free()
	renderer.queue_free()
	await get_tree().process_frame


func test_static_render_preserves_basic_control_and_mesh_visuals() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var control: ColorRect = ColorRect.new()
	control.size = Vector2(8.0, 8.0)
	control.color = Color.GREEN
	var control_image: Image = await renderer.render_canvas_item(
		control, Vector2i(24, 24), true, Rect2(0.0, 0.0, 8.0, 8.0), 0.0
	)
	_assert_visible_pixels(control_image, "静态 Control 快照应保留矩形和颜色。")
	var mesh: BoxMesh = BoxMesh.new()
	var mesh_image: Image = await renderer.render_mesh(mesh, Vector2i(24, 24))
	_assert_visible_pixels(mesh_image, "静态 Mesh 快照应保留可见几何。")
	assert_true(renderer._viewport.world_2d != get_viewport().world_2d, "2D 预览应使用独立 World2D。")
	assert_true(renderer._viewport.gui_disable_input, "预览 Viewport 不应接收 GUI 输入。")
	control.free()
	renderer.queue_free()
	await get_tree().process_frame


func test_static_copy_rejects_deep_hierarchy_before_exhausting_the_script_stack() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: Node2D = Node2D.new()
	var parent: Node = source
	for _index: int in 140:
		var child: Node2D = Node2D.new()
		parent.add_child(child)
		parent = child
	var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)

	assert_null(copy, "超深输入应拒绝，不能耗尽脚本递归栈。")
	assert_true(renderer._render_error.contains("hierarchy depth"), "深度拒绝应解释边界。")
	if copy != null:
		copy.free()
	source.free()
	renderer.free()


func test_static_copy_rejects_wide_hierarchy_and_releases_partial_snapshot() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: Node2D = Node2D.new()
	for _index: int in 4096:
		source.add_child(Node.new())
	var copy: Node = renderer._create_render_instance(source, GFThumbnailRenderRequest.PreviewMode.STATIC)

	assert_null(copy, "包含根节点的总数超过 4096 时应拒绝浅层宽树。")
	assert_true(renderer._render_error.contains("node count"), "节点总数拒绝应解释预算。")
	assert_eq(source.get_child_count(), 4096, "部分构建失败不能修改来源层级。")
	if copy != null:
		copy.free()
	source.free()
	renderer.free()


func test_queued_static_request_fails_when_source_is_freed_before_execution() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var source: Node2D = Node2D.new()
	var task: GFThumbnailRenderTask = renderer.submit_render_request(
		GFThumbnailRenderRequest.for_canvas_item_image(source, Vector2i(16, 16))
	)
	source.free()
	var _result: Variant = await task.wait_completed()

	assert_true(task.is_failed(), "排队期间释放来源应使请求失败。")
	assert_eq(renderer._canvas_root.get_child_count(), 1, "失效来源不得创建副本。")
	renderer.queue_free()
	await get_tree().process_frame


func test_node_request_factories_default_to_static_and_preserve_explicit_dynamic_mode() -> void:
	var canvas: Node2D = Node2D.new()
	var spatial: Node3D = Node3D.new()
	var defaults: Array[GFThumbnailRenderRequest] = [
		GFThumbnailRenderRequest.for_canvas_item_image(canvas),
		GFThumbnailRenderRequest.for_canvas_item_texture(canvas),
		GFThumbnailRenderRequest.for_node3d_image(spatial),
		GFThumbnailRenderRequest.for_node3d_texture(spatial),
	]
	for request: GFThumbnailRenderRequest in defaults:
		assert_eq(request.get_preview_mode(), GFThumbnailRenderRequest.PreviewMode.STATIC)
	var mode: GFThumbnailRenderRequest.PreviewMode = GFThumbnailRenderRequest.PreviewMode.TRUSTED_DYNAMIC
	var explicit: Array[GFThumbnailRenderRequest] = [
		GFThumbnailRenderRequest.for_canvas_item_image(canvas, Vector2i.ONE, true, Rect2(), 0.0, mode),
		GFThumbnailRenderRequest.for_canvas_item_texture(canvas, Vector2i.ONE, true, Rect2(), 0.0, mode),
		GFThumbnailRenderRequest.for_node3d_image(spatial, Vector2i.ONE, true, mode),
		GFThumbnailRenderRequest.for_node3d_texture(spatial, Vector2i.ONE, true, mode),
	]
	for request: GFThumbnailRenderRequest in explicit:
		assert_eq(request.get_preview_mode(), mode)
	canvas.free()
	spatial.free()


func test_trusted_dynamic_texture_convenience_methods_forward_preview_mode() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var canvas: SCRIPTED_NODE2D_SCRIPT = SCRIPTED_NODE2D_SCRIPT.new()
	var spatial: SCRIPTED_NODE3D_SCRIPT = SCRIPTED_NODE3D_SCRIPT.new()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	spatial.add_child(mesh_instance)
	SCRIPTED_NODE2D_SCRIPT.reset_observations()
	SCRIPTED_NODE3D_SCRIPT.reset_observations()
	var canvas_texture: ImageTexture = await renderer.render_canvas_item_texture(
		canvas, Vector2i(24, 24), true, Rect2(0.0, 0.0, 8.0, 8.0), 0.0,
		GFThumbnailRenderRequest.PreviewMode.TRUSTED_DYNAMIC
	)
	var spatial_texture: ImageTexture = await renderer.render_node3d_texture(
		spatial, Vector2i(24, 24), true, GFThumbnailRenderRequest.PreviewMode.TRUSTED_DYNAMIC
	)

	assert_eq(SCRIPTED_NODE2D_SCRIPT.ready_count, 1, "2D Texture 便捷入口应传递可信动态模式。")
	assert_eq(SCRIPTED_NODE3D_SCRIPT.ready_count, 1, "3D Texture 便捷入口应传递可信动态模式。")
	if DisplayServer.get_name() != "headless":
		assert_not_null(canvas_texture, "真实后端应产生 2D 纹理。")
		assert_not_null(spatial_texture, "真实后端应产生 3D 纹理。")
		if canvas_texture != null:
			_assert_visible_pixels(canvas_texture.get_image(), "2D Texture 应包含自绘内容。")
		if spatial_texture != null:
			_assert_visible_pixels(spatial_texture.get_image(), "3D Texture 应包含几何内容。")
	canvas.free()
	spatial.free()
	renderer.queue_free()
	await get_tree().process_frame


func test_normalize_render_size_clamps_to_positive_pixels() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()

	assert_eq(renderer._normalize_render_size(Vector2i(0, -4)), Vector2i(1, 1), "渲染尺寸应钳制到至少 1 像素。")
	renderer.free()


func test_free_render_instance_removes_temporary_child() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	renderer._ensure_viewport()
	var instance: Node3D = Node3D.new()
	renderer._world_root.add_child(instance)

	renderer._free_render_instance(instance)

	assert_eq(renderer._world_root.get_child_count(), 3, "清理临时渲染节点后应只保留 camera 与两盏灯。")
	renderer.queue_free()


func test_thumbnail_render_task_cancels_pending_task_through_kernel_token() -> void:
	var task: GFThumbnailRenderTask = GFThumbnailRenderTask.new(GFThumbnailRenderRequest.new(), 7)
	var completed_tasks: Array[GFThumbnailRenderTask] = []
	var completed_callback: Callable = func(completed_task: GFThumbnailRenderTask) -> void:
		completed_tasks.append(completed_task)
	var _connected_completed: Error = task.completed.connect(completed_callback) as Error

	assert_true(task.cancel(&"test_cancel"), "pending 任务应能立即取消。")
	task.completed.disconnect(completed_callback)

	var completion: GFAsyncCompletion = task.get_completion()
	assert_true(task.is_cancelled(), "任务应进入取消终态。")
	assert_true(task.get_cancel_token().is_cancel_requested(), "任务 token 应记录取消请求。")
	assert_true(completion.is_cancelled(), "任务完成源应进入取消终态。")
	assert_eq(task.get_cancel_reason(), &"test_cancel", "任务应保留取消原因。")
	assert_eq(completed_tasks, [task], "任务取消应发出 completed 信号。")


func test_thumbnail_renderer_submit_request_fails_invalid_request_via_task_queue() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)

	var task: GFThumbnailRenderTask = renderer.submit_render_request(GFThumbnailRenderRequest.new())
	var result: Variant = await task.wait_completed()

	assert_eq(task.get_task_id(), 1, "renderer 应分配稳定递增任务 ID。")
	assert_true(task.is_failed(), "无效 request 应失败完成。")
	assert_true(result == null, "失败任务不应返回结果。")
	assert_false(task.get_error().is_empty(), "失败任务应保留错误说明。")
	renderer.queue_free()


func test_thumbnail_renderer_exit_completes_active_task_immediately() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var task: GFThumbnailRenderTask = GFThumbnailRenderTask.new(
		GFThumbnailRenderRequest.new(),
		1
	)
	var completed_count: Array[int] = [0]
	var completed_callback: Callable = func(_completed_task: GFThumbnailRenderTask) -> void:
		completed_count[0] += 1
	var _connected: Error = task.completed.connect(completed_callback) as Error
	assert_true(task.mark_running(), "测试任务应进入 RUNNING。")
	renderer._active_task = task

	renderer._cancel_all_tasks(&"renderer_exited")

	assert_true(task.is_cancelled(), "renderer 退出时 active task 必须立即进入终态。")
	assert_eq(task.get_cancel_reason(), &"renderer_exited", "取消原因应保留 renderer 生命周期来源。")
	assert_eq(completed_count[0], 1, "active task 应只发出一次 completed。")
	assert_null(renderer._active_task, "取消后不应保留 active task 指针。")
	task.completed.disconnect(completed_callback)
	renderer.free()


func test_thumbnail_renderer_rejects_oversized_target_before_queueing() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: Node3D = Node3D.new()
	var request: GFThumbnailRenderRequest = GFThumbnailRenderRequest.for_node3d_image(
		source,
		Vector2i(GFThumbnailRenderer.MAX_TARGET_DIMENSION + 1, 1)
	)

	var task: GFThumbnailRenderTask = renderer.submit_render_request(request)

	assert_true(task.is_failed(), "超大目标应在进入队列前失败。")
	assert_true(task.get_error().contains("dimension limit"), "失败应指出尺寸预算。")
	assert_true(renderer._pending_tasks.is_empty(), "被拒请求不得占用队列。")
	source.free()
	renderer.free()


func test_thumbnail_renderer_bounds_pending_queue() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: Node3D = Node3D.new()
	var request: GFThumbnailRenderRequest = GFThumbnailRenderRequest.for_node3d_image(
		source,
		Vector2i.ONE
	)
	for _index: int in GFThumbnailRenderer.MAX_PENDING_TASKS:
		var accepted_task: GFThumbnailRenderTask = renderer.submit_render_request(
			request
		)
		assert_true(accepted_task.is_pending(), "预算内任务应进入等待队列。")

	var overflow_task: GFThumbnailRenderTask = renderer.submit_render_request(request)

	assert_true(overflow_task.is_failed(), "队列满后新任务应立即失败。")
	assert_true(overflow_task.get_error().contains("task limit"), "失败应指出队列预算。")
	assert_eq(
		renderer._pending_tasks.size(),
		GFThumbnailRenderer.MAX_PENDING_TASKS,
		"拒绝请求不能扩大队列。"
	)
	renderer._cancel_all_tasks(&"test_cleanup")
	source.free()
	renderer.free()


func test_canvas_item_request_rejects_non_finite_margin() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var source: Node2D = Node2D.new()
	var request: GFThumbnailRenderRequest = GFThumbnailRenderRequest.for_canvas_item_image(
		source,
		Vector2i(64, 64),
		true,
		Rect2(),
		NAN
	)

	var task: GFThumbnailRenderTask = renderer.submit_render_request(request)

	assert_false(request.is_valid(), "非有限 margin 不应形成合法请求。")
	assert_true(task.is_failed(), "非有限参数必须在进入渲染路径前失败。")
	assert_true(renderer._pending_tasks.is_empty(), "非法参数不得占用队列。")
	source.free()
	renderer.free()


func test_canvas_item_request_preserves_explicit_bounds_and_margin() -> void:
	var source: Node2D = Node2D.new()
	var content_bounds: Rect2 = Rect2(Vector2(-12.0, -8.0), Vector2(24.0, 16.0))
	var request: GFThumbnailRenderRequest = GFThumbnailRenderRequest.for_canvas_item_image(
		source,
		Vector2i(96, 64),
		true,
		content_bounds,
		0.2
	)

	assert_true(request.is_valid(), "有效 CanvasItem 应形成可执行请求。")
	assert_eq(request.get_kind(), GFThumbnailRenderRequest.Kind.CANVAS_ITEM_IMAGE)
	assert_eq(request.get_source_canvas_item(), source)
	assert_true(request.has_content_bounds(), "正尺寸边界应被识别为显式边界。")
	assert_eq(request.get_content_bounds(), content_bounds)
	assert_eq(request.get_margin_ratio(), 0.2)
	source.free()
	assert_false(request.is_valid(), "来源释放后请求应失效。")


func test_canvas_item_bounds_include_transformed_sprite_geometry() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	renderer._ensure_viewport()
	var root: Node2D = Node2D.new()
	var sprite: Sprite2D = Sprite2D.new()
	var image: Image = Image.create(20, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.position = Vector2(5.0, 7.0)
	root.add_child(sprite)
	renderer._canvas_root.add_child(root)

	var bounds: Rect2 = renderer._get_combined_canvas_rect(root)

	assert_eq(bounds, Rect2(Vector2(-5.0, 2.0), Vector2(20.0, 10.0)))
	renderer._free_render_instance(root)
	assert_eq(renderer._canvas_root.get_child_count(), 1, "清理 2D 实例后应只保留 Camera2D。")
	renderer.queue_free()


func test_canvas_item_bounds_include_control_geometry() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	renderer._ensure_viewport()
	var root: Node2D = Node2D.new()
	var control: ColorRect = ColorRect.new()
	control.position = Vector2(4.0, 6.0)
	control.size = Vector2(30.0, 12.0)
	root.add_child(control)
	renderer._canvas_root.add_child(root)

	var bounds: Rect2 = renderer._get_combined_canvas_rect(root)

	assert_eq(bounds, Rect2(Vector2(4.0, 6.0), Vector2(30.0, 12.0)))
	renderer._free_render_instance(root)
	renderer.queue_free()


func test_canvas_item_bounds_include_polygon_offset() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	renderer._ensure_viewport()
	var root: Node2D = Node2D.new()
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(-2.0, -1.0),
		Vector2(6.0, -1.0),
		Vector2(6.0, 3.0),
	])
	polygon.offset = Vector2(10.0, 20.0)
	root.add_child(polygon)
	renderer._canvas_root.add_child(root)

	var bounds: Rect2 = renderer._get_combined_canvas_rect(root)

	assert_eq(bounds, Rect2(Vector2(8.0, 19.0), Vector2(8.0, 4.0)))
	renderer._free_render_instance(root)
	renderer.queue_free()


func test_render_canvas_item_returns_requested_image_size() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var source: Node2D = Node2D.new()
	var sprite: Sprite2D = Sprite2D.new()
	var source_image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	source_image.fill(Color(0.2, 0.7, 1.0, 1.0))
	sprite.texture = ImageTexture.create_from_image(source_image)
	source.add_child(sprite)

	var rendered: Image = await renderer.render_canvas_item(
		source,
		Vector2i(40, 24),
		true,
		Rect2(Vector2(-4.0, -4.0), Vector2(8.0, 8.0)),
		0.0
	)

	if rendered != null:
		assert_eq(rendered.get_size(), Vector2i(40, 24), "输出应遵循请求尺寸。")
		_assert_visible_pixels(rendered, "静态 Sprite 快照应保留纹理内容。")
	else:
		assert_true(
			RenderingServer.get_video_adapter_name().strip_edges().is_empty(),
			"只有不提供纹理存储的 dummy 渲染后端可以安全返回 null。"
		)
	assert_eq(renderer._canvas_root.get_child_count(), 1, "任务完成后不应遗留临时 CanvasItem。")
	source.free()
	renderer.queue_free()
	await get_tree().process_frame


# --- 私有/辅助方法 ---

func _create_surface_mesh(surface_count: int) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for surface_index: int in surface_count:
		var arrays: Array = []
		var _resized: int = arrays.resize(Mesh.ARRAY_MAX)
		var offset: float = float(surface_index) * 2.0
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
			Vector3(offset, 0.0, 0.0),
			Vector3(offset + 1.0, 0.0, 0.0),
			Vector3(offset, 1.0, 0.0),
		])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _assert_visible_pixels(image: Image, message: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	assert_not_null(image, message)
	if image == null:
		return
	var visible: bool = false
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.1:
				visible = true
				break
		if visible:
			break
	assert_true(visible, message)
