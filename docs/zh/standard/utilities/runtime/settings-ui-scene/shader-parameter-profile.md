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

`apply_profile()` / `apply_parameters()` 还会默认拒绝与 uniform 声明类型不一致的值。GF 不做 int 到 float 等隐式数值兼容；需要在工具、CI 或资源导入阶段获得完整问题列表时，应先使用下节的显式契约校验，而不是只依赖应用数量和 warning。

## 接口快照与参数契约

`GFShaderInterfaceSnapshot` 把 `Shader.get_shader_uniform_list(false)` 公开的 uniform 接口规范化为稳定数据。快照记录 `schema_version`、`shader_mode`，以及按名称排序的 `name`、`type`、`class_name`、`hint`、`hint_string`、`usage`；它不会保存 shader 源码、默认值、材质当前值或渲染后端生成代码。

从外部字典恢复时，`from_dict()` 只接受显式 schema 字段类型，不会把字符串数字或缺失的 `uniforms` 静默强转为合法契约；调用方应先检查 `validate_definition()`，再把快照作为基线使用。

```gdscript
var snapshot := GFShaderInterfaceSnapshot.capture(weather_material.shader)
var report := runtime_profile.validate_against(snapshot)
if not report.is_ok():
	push_error(report.make_summary())
	return

shader_params.apply_profile(weather_material, runtime_profile)
```

Profile 被视为“部分覆盖”：默认不要求它提供 shader 的全部 uniform，但 Profile 中不存在于接口的参数、值类型错误和资源类错误会进入 `GFValidationReport`。需要校验一份完整参数集时，显式启用缺失错误：

```gdscript
var complete_report := snapshot.validate_parameters(parameters, {
	"missing_severity": "error",
})
```

数值类型使用严格 Variant 类型匹配，因此 `float` uniform 应提供 `float`，不能依赖 Godot 对错误类型写入的静默行为。纹理等 Object uniform 允许用 `null` 清除；非空对象还会根据反射得到的资源类进行校验。

### 持久化基线与接口漂移

快照是使用私有 storage 字段封存的 Resource。公开 getter 返回深拷贝，调用方不能通过正常 API 原地修改已捕获接口；制作工具可以用 `ResourceSaver` 保存基线，再用当前 Shader 重新捕获和比较：

```gdscript
var loaded_value: Variant = load(
	"res://contracts/weather_shader_interface.tres"
)
if not loaded_value is GFShaderInterfaceSnapshot:
	return
var expected: GFShaderInterfaceSnapshot = loaded_value
var drift_report := expected.validate_shader(weather_material.shader)
if not drift_report.is_healthy():
	push_warning(drift_report.make_summary())
```

直接 `GFShaderInterfaceSnapshot.new()` 得到的是未配置 Resource，不代表合法的空 spatial 接口；必须通过 `capture()` 或严格 `from_dict()` 建立快照，并在保存或作为门禁前检查 `validate_definition()`。Storage 在加载时会重新规范化 uniform 顺序，缺少配置标记、未来 schema、畸形字段或非规范字段类型仍会失败关闭。

比较默认把 shader mode、缺失 uniform 和类型/提示签名变化作为 error，把新增 uniform 与 `usage` 变化作为 warning。调用方可以通过 `mode_mismatch_severity`、`missing_severity`、`extra_severity`、`signature_severity` 和 `usage_severity` 显式调整门禁，但 GF 不做隐式 schema 降级。

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
- 接口快照只约束可反射的 uniform 形状，不解析 shader 源码，也不承诺 GPU 后端二进制兼容。
- 不要把某个游戏的海面、天气、选中态或后处理规则写进 GF。
- Binder 只绑定 profile 到目标材质，不负责读取风、时间、角色状态或其他业务状态。
- 对复杂 GPU compute、CompositorEffect 或 shader 变体编译缓存，应在出现明确重复需求后再做独立工具，不要塞进参数 profile。
