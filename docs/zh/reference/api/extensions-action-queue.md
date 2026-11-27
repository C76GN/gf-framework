# Action Queue API

模块：`extensions/action_queue`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 3 | 76 | 68 |
| [协议与扩展点](#category-protocol) | 4 | 27 | 21 |
| [资源定义](#category-resource_definition) | 8 | 80 | 30 |
| [运行时句柄](#category-runtime_handle) | 12 | 106 | 54 |
| [值对象](#category-value_object) | 2 | 17 | 13 |
| [编辑器 API](#category-editor_api) | 1 | 7 | 6 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAction`](classes/GFAction.md#gfaction) | `RefCounted` | `addons/gf/extensions/action_queue/core/gf_action.gd` |
| [`GFActionQueueSystem`](classes/GFActionQueueSystem.md#gfactionqueuesystem) | `GFSystem` | `addons/gf/extensions/action_queue/core/gf_action_queue_system.gd` |
| [`GFUIMotionPlayer`](classes/GFUIMotionPlayer.md#gfuimotionplayer) | `Node` | `addons/gf/extensions/action_queue/ui_motion/gf_ui_motion_player.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFActionInterceptor`](classes/GFActionInterceptor.md#gfactioninterceptor) | `RefCounted` | `addons/gf/extensions/action_queue/core/gf_action_interceptor.gd` |
| [`GFTweenPreviewAdapter`](classes/GFTweenPreviewAdapter.md#gftweenpreviewadapter) | `RefCounted` | `addons/gf/extensions/action_queue/editor/gf_tween_preview_adapter.gd` |
| [`GFUIMotionEffect`](classes/GFUIMotionEffect.md#gfuimotioneffect) | `Resource` | `addons/gf/extensions/action_queue/ui_motion/gf_ui_motion_effect.gd` |
| [`GFVisualAction`](classes/GFVisualAction.md#gfvisualaction) | `RefCounted` | `addons/gf/extensions/action_queue/actions/gf_visual_action.gd` |

<a id="category-resource_definition"></a>

### 资源定义

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFTweenActionConfig`](classes/GFTweenActionConfig.md#gftweenactionconfig) | `Resource` | `addons/gf/extensions/action_queue/tween/gf_tween_action_config.gd` |
| [`GFTweenActionStep`](classes/GFTweenActionStep.md#gftweenactionstep) | `Resource` | `addons/gf/extensions/action_queue/tween/gf_tween_action_step.gd` |
| [`GFUILayoutMotion`](classes/GFUILayoutMotion.md#gfuilayoutmotion) | `GFUIMotionEffect` | `addons/gf/extensions/action_queue/ui_motion/gf_ui_layout_motion.gd` |
| [`GFUIMaterialMotion`](classes/GFUIMaterialMotion.md#gfuimaterialmotion) | `GFUIMotionEffect` | `addons/gf/extensions/action_queue/ui_motion/gf_ui_material_motion.gd` |
| [`GFUIMotionRecipe`](classes/GFUIMotionRecipe.md#gfuimotionrecipe) | `Resource` | `addons/gf/extensions/action_queue/ui_motion/gf_ui_motion_recipe.gd` |
| [`GFUIMotionTrack`](classes/GFUIMotionTrack.md#gfuimotiontrack) | `Resource` | `addons/gf/extensions/action_queue/ui_motion/gf_ui_motion_track.gd` |
| [`GFUIPropertyMotion`](classes/GFUIPropertyMotion.md#gfuipropertymotion) | `GFUIMotionEffect` | `addons/gf/extensions/action_queue/ui_motion/gf_ui_property_motion.gd` |
| [`GFUITweenMotion`](classes/GFUITweenMotion.md#gfuitweenmotion) | `GFUIMotionEffect` | `addons/gf/extensions/action_queue/ui_motion/gf_ui_tween_motion.gd` |

<a id="category-runtime_handle"></a>

### 运行时句柄

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAudioAction`](classes/GFAudioAction.md#gfaudioaction) | `GFVisualAction` | `addons/gf/extensions/action_queue/actions/gf_audio_action.gd` |
| [`GFCallableAction`](classes/GFCallableAction.md#gfcallableaction) | `GFVisualAction` | `addons/gf/extensions/action_queue/actions/gf_callable_action.gd` |
| [`GFConfiguredTweenAction`](classes/GFConfiguredTweenAction.md#gfconfiguredtweenaction) | `GFVisualAction` | `addons/gf/extensions/action_queue/actions/gf_configured_tween_action.gd` |
| [`GFFlashAction`](classes/GFFlashAction.md#gfflashaction) | `GFVisualAction` | `addons/gf/extensions/action_queue/actions/gf_flash_action.gd` |
| [`GFMoveTweenAction`](classes/GFMoveTweenAction.md#gfmovetweenaction) | `GFVisualAction` | `addons/gf/extensions/action_queue/actions/gf_move_tween_action.gd` |
| [`GFRepeatAction`](classes/GFRepeatAction.md#gfrepeataction) | `GFVisualAction` | `addons/gf/extensions/action_queue/actions/gf_repeat_action.gd` |
| [`GFShaderParameterAction`](classes/GFShaderParameterAction.md#gfshaderparameteraction) | `GFVisualAction` | `addons/gf/extensions/action_queue/actions/gf_shader_parameter_action.gd` |
| [`GFTweenPreviewRegistration`](classes/GFTweenPreviewRegistration.md#gftweenpreviewregistration) | `RefCounted` | `addons/gf/extensions/action_queue/editor/gf_tween_preview_registration.gd` |
| [`GFTweenReplacementScope`](classes/GFTweenReplacementScope.md#gftweenreplacementscope) | `RefCounted` | `addons/gf/extensions/action_queue/tween/gf_tween_replacement_scope.gd` |
| [`GFUIMotionBinding`](classes/GFUIMotionBinding.md#gfuimotionbinding) | `RefCounted` | `addons/gf/extensions/action_queue/ui_motion/gf_ui_motion_binding.gd` |
| [`GFVisualActionGroup`](classes/GFVisualActionGroup.md#gfvisualactiongroup) | `GFVisualAction` | `addons/gf/extensions/action_queue/actions/gf_visual_action_group.gd` |
| [`GFWaitAction`](classes/GFWaitAction.md#gfwaitaction) | `GFVisualAction` | `addons/gf/extensions/action_queue/actions/gf_wait_action.gd` |

<a id="category-value_object"></a>

### 值对象

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFActionInterceptionResult`](classes/GFActionInterceptionResult.md#gfactioninterceptionresult) | `RefCounted` | `addons/gf/extensions/action_queue/core/gf_action_interception_result.gd` |
| [`GFTweenNumericTimeline`](classes/GFTweenNumericTimeline.md#gftweennumerictimeline) | `RefCounted` | `addons/gf/extensions/action_queue/tween/gf_tween_numeric_timeline.gd` |

<a id="category-editor_api"></a>

### 编辑器 API

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFTweenPreviewRegistry`](classes/GFTweenPreviewRegistry.md#gftweenpreviewregistry) | `RefCounted` | `addons/gf/extensions/action_queue/editor/gf_tween_preview_registry.gd` |
