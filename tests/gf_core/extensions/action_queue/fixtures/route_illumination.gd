@tool

# 消费方自定义效果。距离来自项目输入，每次绑定计算一次，不修改共享资源。
extends GFUIMotionEffect

@export var wave_width: float = 0.28
@export var color: Color = Color("#81dfcb")


func input_types() -> Dictionary:
	return { &"routes": TYPE_PACKED_FLOAT32_ARRAY, &"source": TYPE_INT }


func binding_error(target: Object, inputs: Dictionary) -> String:
	var graph: PackedFloat32Array = inputs[&"routes"]
	var count: int = roundi(sqrt(graph.size()))
	var origin: int = inputs[&"source"]
	if (
		not target is Node2D
		or count * count != graph.size()
		or origin < 0
		or origin >= count
	):
		return "需要方形航线耗时矩阵、起始星球和 Node2D"
	return ""


func bind_target(target: Object, inputs: Dictionary) -> GFUIMotionBinding:
	var graph: PackedFloat32Array = inputs[&"routes"]
	var count: int = roundi(sqrt(graph.size()))
	var distance: PackedFloat32Array = PackedFloat32Array()
	var _resized: int = distance.resize(count)
	distance.fill(INF)
	var origin: int = inputs[&"source"]
	distance[origin] = 0
	for pass_index: int in range(count - 1):
		for i: int in count:
			for j: int in count:
				var cost: float = graph[i * count + j]
				if cost >= 0.0:
					distance[j] = minf(
						distance[j],
						distance[i] + cost
					)
	var longest: float = 0.001
	for arrival: float in distance:
		if is_finite(arrival):
			longest = maxf(longest, arrival)
	var width: float = maxf(wave_width, 0.001)
	var node: Node2D = target as Node2D
	var ink: Color = color
	var sample: Callable = func(p: float) -> void:
		var glow: PackedColorArray = PackedColorArray()
		for arrival: float in distance:
			var weight: float = clampf(
				(p * (longest + width) - arrival) / width,
				0.0,
				1.0
			)
			var _added: bool = glow.append(Color(ink, weight))
		node.set_meta(&"route_glow", glow)
		node.queue_redraw()
	var release: Callable = func(reason: int) -> void:
		if reason == GFUIMotionBinding.EndReason.CANCELLED and is_instance_valid(node):
			node.remove_meta(&"route_glow")
			node.queue_redraw()
	return GFUIMotionBinding.new(sample, release)
