# GFAction 工厂

框架内置了几个常用动作，避免每个项目重复写样板类。

## 常用动作

`GFMoveTweenAction` 负责位置 Tween，`GFFlashAction` 负责短时颜色闪烁，`GFAudioAction` 负责一次音频播放；三者都遵循 ActionQueue 的统一取消和完成生命周期。

```gdscript
q_sys.enqueue(GFMoveTweenAction.new(card_node, Vector2(400, 300), 0.25))
q_sys.enqueue(GFFlashAction.new(card_node, Color.WHITE, 0.12))
q_sys.enqueue(GFShaderParameterAction.new(card_node, &"hit_strength", 1.0, 0.08))
q_sys.enqueue(GFAudioAction.new("res://audio/sfx/hit.wav"))
```

这些动作只封装通用表现操作，不解释项目对象含义。

需要更短的组合写法时，可以使用 `GFAction` 静态工厂创建常见动作。

它只负责生成 `GFVisualAction`，不隐含任何业务流程。

## 组合工厂

```gdscript
q_sys.enqueue(GFAction.sequence([
	GFAction.move_to(card_node, Vector2(400, 300), 0.2),
	GFAction.parallel([
		GFAction.fade_to(card_node, 0.4, 0.12),
		GFAction.wait(0.12, card_node),
	]),
	GFAction.callback(func() -> void:
		print("visual done")
	),
]))
```

`GFAction.parallel()` 会等待所有需要等待的子动作。只需要等待最先完成分支时，可以使用 `GFAction.race(actions, cancel_remaining)`；`cancel_remaining` 默认为 `true`，用于在动作组完成后取消仍在等待的子动作。

`GFAction` 也提供 `tween_by()`、`move_by()`、`scale_to()`、`scale_by()`、`rotate_to()`、`rotate_by()`、`fade_by()`、`colorize()`、`shader_parameter()`、`set_property()`、`show()`、`hide()` 和 `remove_node()` 等便捷工厂。

## Shader 参数

`GFShaderParameterAction` 只负责驱动 `ShaderMaterial` 的 uniform 参数，不提供任何具体 shader 或特效语义。目标可以直接是 `ShaderMaterial`，也可以是带 `material` 属性的节点；直接操作资源且需要 Tween 时，应通过 `host_node` 提供宿主节点。

```gdscript
q_sys.enqueue(GFAction.shader_parameter(sprite, &"dissolve_progress", 1.0, 0.25, {
	"duplicate_material_on_execute": true,
	"restore_initial_value_on_cancel": true,
}))
```

如果多个节点共享同一个材质资源，启用 `duplicate_material_on_execute` 可以在执行前复制材质并写回目标，避免把参数变化扩散到其他节点。

## 使用边界

这些工厂仅将常见属性写入、Tween、Shader 参数写入或节点释放转换为 `GFVisualAction`；调度方式、业务对象含义和流程语义仍由调用方决定。
