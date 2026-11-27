@tool
extends GFUIMotionEffect


func bind_target(_target: Object, inputs: Dictionary) -> GFUIMotionBinding:
	var player: GFUIMotionPlayer = inputs.player
	var sample: Callable = func(weight: float) -> void:
		if weight > 0.0:
			player.cancel()
	return GFUIMotionBinding.new(sample)
