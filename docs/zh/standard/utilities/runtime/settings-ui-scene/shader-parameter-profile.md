# Shader 参数 Profile

`GFShaderParameterProfile`、`GFShaderParameterUtility` 与 `GFShaderParameterBinder` 用来把一组 `ShaderMaterial` uniform 参数声明为可复制、可合并、可插值的数据，再批量写入材质或绑定到场景节点。它们只处理参数集合、目标材质解析、写入校验和 profile 变化响应，不提供具体 shader、后处理算法、天气规则或项目视觉风格。

## 典型流程

```gdscript
var profile := GFShaderParameterProfile.new()
profile.set_parameter(&"storm_pressure", 0.7)
profile.set_parameter(&"atmosphere_tint", Color(0.12, 0.18, 0.22, 0.4))

var shader_params := GFShaderParameterUtility.new()
shader_params.apply_profile($WeatherOverlay, profile, {
	"duplicate_material": true,
})
```

目标可以直接是 `ShaderMaterial`，也可以是带 `material` 属性的节点。默认会检查 shader 是否声明了对应 uniform，避免 profile 中的拼写错误被静默吞掉。多个节点共享同一个材质资源时，传入 `"duplicate_material": true` 会先复制材质并写回目标属性，再应用参数。

## 合并与过渡

`merge_from()` 可把默认 profile、场景 profile 和运行时覆盖值合并成一个最终 profile。`blend_with()` 会对 float、int、`Color`、`Vector2`、`Vector3`、`Vector4` 和 `Quaternion` 做插值；纹理、bool、字符串等不可插值值会保持源值，权重到 1 时切换到目标值。需要平滑过渡的参数应在两端 profile 中都提供默认值。

```gdscript
var blended := calm_profile.blend_with(storm_profile, transition_weight)
shader_params.apply_profile(weather_material, blended)
```

## 场景绑定

`GFShaderParameterBinder` 是一个轻量节点组件。把它作为材质节点的子节点时，默认 `target_path` 指向父节点；也可以显式指定其他目标路径。Binder 会在 ready 阶段应用 profile，并可在 profile 通过公开方法发出 `changed` 信号时自动重应用。

```gdscript
var binder := GFShaderParameterBinder.new()
binder.profile = runtime_profile
binder.duplicate_material_on_apply = true
$TargetNode.add_child(binder)
```

如果需要每帧把外部系统计算出的参数写入 shader，可以启用 `apply_each_process`，但高频变化更适合项目层先合并成最终 profile，再由 Binder 或 Utility 批量写入。GF 不读取游戏状态，也不定义参数含义。

## 全局 Shader 参数

Godot 的 `global uniform` 需要先注册到 RenderingServer，全局参数还可以通过 `ProjectSettings` 的 `shader_globals/<name>` 持久声明，避免编辑器或导出包启动时出现 shader 编译顺序问题。`GFShaderParameterUtility` 提供这两层的通用入口，但默认只修改当前会话，不会保存 `project.godot`。

```gdscript
var globals := GFShaderParameterUtility.new()
globals.ensure_global_parameter(
	&"weather_fog_amount",
	RenderingServer.GLOBAL_VAR_TYPE_FLOAT,
	0.0,
	{
		"persist_project_setting": true,
	}
)

globals.apply_global_parameters({
	&"weather_fog_amount": runtime_fog_amount,
})
```

`apply_global_parameters()` 会在当前会话中补齐缺失的全局参数并写入值。无法从值安全推断类型时，通过 `"parameter_types"` 显式传入 `RenderingServer.GLOBAL_VAR_TYPE_*`；需要写入完整 `shader_globals` 定义时，通过 `"project_setting_definitions"` 传入项目自己的 type、value、filter、repeat 等字段。持久化路径严格锁定在 `shader_globals/<name>` 命名空间，调用方不能传入任意 ProjectSettings path 覆盖其他项目配置。只有明确设置 `"save_project_settings": true` 时，GF 才会调用 `ProjectSettings.save()`。

当前会话 live 参数和 `ProjectSettings` declaration 是两层不同状态。`has_global_parameter()` / `has_global_parameter_live()` 只检查本工具在当前会话注册过的 live 参数；`has_global_parameter_declaration()` 只检查 `shader_globals/<name>` 声明。需要列出两者时分别使用 `get_global_parameter_live_names()` 和 `get_global_parameter_declaration_names()`，避免把“项目文件里有声明”误当作“当前 RenderingServer 已可写”。

Godot 的部分 `RenderingServer` 全局参数枚举和读回接口在不同渲染后端、编辑器测试和 headless 环境中并不稳定。需要验证 GF 是否声明和应用了全局参数时，优先检查 `apply_global_parameters()` / `ensure_global_parameter()` 的报告，以及 live/declaration 分层查询；真实渲染项目中仍由 RenderingServer 接收注册和写入。

## 使用边界

- GF 只负责参数 profile 和写入流程；shader 代码、uniform 命名和视觉含义由项目维护。
- 不要把某个游戏的海面、天气、选中态或后处理规则写进 GF。
- Binder 只绑定 profile 到目标材质，不负责读取风、时间、角色状态或其他业务状态。
- 对复杂 GPU compute、CompositorEffect 或 shader 变体编译缓存，应在出现明确重复需求后再做独立工具，不要塞进参数 profile。
