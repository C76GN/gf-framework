# 纯数值时间轴与自定义预览样机

`GFTweenNumericTimeline` 编译冻结的直接数值属性时间轴。运行时受控 Tween、原生 Inspector 的受控预览与这个入口共用编译/采样核心。输入不接收 Object、Resource、Callable 或业务上下文；调用方负责时钟和提交。

```gdscript
var properties: Array[Dictionary] = [{
	"name": "progress", "type": TYPE_FLOAT, "initial": 0.0,
	"minimum": 0.0, "maximum": 1.0,
}]
var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture({
	"steps": [{"property_name": ^"progress", "target_value": 1.0,
		"duration": 0.8, "transition_type": Tween.TRANS_LINEAR}],
}, properties)
if timeline.get_error().is_empty():
	print(timeline.sample(0.4)) # { "progress": 0.5 }
```

捕获后修改输入或返回字典不改变时间轴。有限越界采样时间收窄到端点，非有限时间、拒绝计划或越界输出返回空字典，没有部分结果。采样不发出 marker 或业务完成通知。

受控核心在每个串行组开始时冻结 `from`，`delay` 不重新读取值，相对循环按上个冻结终点累计。这沿用 GF 受控播放合同；Godot 原生 `PropertyTweener` 在含延迟时会延后读取初值，`relative + delay + loops` 的组合输出可能不同，不能以这个原生组合代替受控时间轴的预期值。[Godot 4.7.2 原生实现](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/animation/tween.cpp#L576-L616)

## 有限合同与硬包络

| 项目 | 要求 |
| --- | --- |
| 属性 | 1–32 个唯一直接标识符，名称 1–64 字符；`TYPE_INT` / `TYPE_FLOAT`，初值同型 |
| 数据 | 使用 API 注释中的闭合 schema，未知字段与对象/资源/回调拒绝 |
| 时间 | 1–128 步、1–32 次循环、最多 4,096 个展开步骤；全部时长和延迟的保守总和乘循环/往返次数不超过 120 秒 |
| 组合 | 延迟、串行、不同根并行、相对值、缩放、有限循环与往返；并行同根或已知属性别名冲突整组拒绝 |
| 零时间 | 单步可为零，总时长为零拒绝；原生非受控预览保留瞬时一轮语义 |
| 曲线 | 原生 Curve 的纯字段快照，沿用受控曲线预算，不接收 Curve 本身 |
| 包络 | 有限 `minimum < maximum`，绝对值最多 1,000,000，包含初值、相对终点与中间插值 |

边界是允许提交的硬包络，不能仅当作 UI 滑块范围。捕获检查保守包络，采样再次检查，不默默钳制。相对循环须包含累计终点。BACK、ELASTIC、SPRING 使用较宽的保守进度包络，可能拒绝窄边界内实际可显示的动画；可选不超调缓动或明确放宽描述。曲线按实际消费的烘焙格点包络检查。整数转换与运行时受控计划相同。

## 显式注册隔离样机

项目 EditorPlugin 实现 `GFTweenPreviewAdapter`，通过 `GFTweenPreviewRegistry` 向共享目录注册 ID、revision、label 和数值属性，并持有 `GFTweenPreviewRegistration` 管理注册生命周期。登记本身不执行钩子。打开资源后按已声明用途解析；未声明时只自动选择唯一兼容候选，歧义需要明确选择。首次接纳后，本次编辑保留该用途，源编辑只重新检查新配置的准备条件。Inspector 与 Steps 共用同一个目标及初值目录。

```gdscript
@tool
extends EditorPlugin

var _registration: GFTweenPreviewRegistration = null

func _enter_tree() -> void:
	_registration = GFTweenPreviewRegistry.get_shared().register_adapter(self, {
		"id": "progress_sample", "revision": 1, "label": "Progress 色块",
		"properties": [{"name": "progress", "type": TYPE_FLOAT,
			"initial": 0.0, "minimum": 0.0, "maximum": 1.0}],
	}, ProgressSample.new())

func _exit_tree() -> void:
	if _registration != null:
		_registration.release()
		_registration = null

class ProgressSample extends GFTweenPreviewAdapter:
	func _create_sample() -> Control:
		var color: ColorRect = ColorRect.new()
		color.size = Vector2(48, 48)
		return color

	func _apply_sample(sample: Control, values: Dictionary) -> void:
		var progress: float = GFVariantData.get_option_float(values, "progress")
		sample.position = Vector2(48 + progress * 280, 120)
		sample.modulate.a = 0.3 + progress * 0.7
```

来源须是精确原生 `GFTweenActionConfig` / `GFTweenActionStep`；使用 `progress` 路径及匹配数值终点。不接纳项目配置子类，不调用来源方法或自定义 getter，不提供真实目标。

样机须是全新、未入树、无父节点的 Control，最多 128 节点/8 层。GF 接纳后负责挂载与释放。钩子只获得工具样机和独立数值副本，播放、暂停、定位、复位和正反向使用冻结时间轴。

目录最多 32 项，ID 不覆盖。owner 弱持有；插件退出须显式 release，最后一个句柄释放也撤销注册。release 幂等，旧句柄不能撤销后续同 ID 租约。修改 schema/revision 时先释放再注册，旧会话失效，恢复的目标须重新准备。换源或释放也终止旧资格；创建、入树和提交后检查代次、租约和样机身份。

这些 GDScript 钩子是受信任扩展，不能提供沙箱。实现者须避免全局业务、来源方法、marker、导航、文件保存和持久化，不应强持 owner 或来源配置；框架不宣称能阻止任意脚本访问全局状态。

## 关联资源与预览用途

普通配置仍是精确原生资源，不需要增加项目子类。插件可用 `register_binding` 把已保存的资源路径关联到项目适配器或内置 ID `gf.preview.2d`、`gf.preview.ui`、`gf.preview.3d`，并持有返回的同类租约：

```gdscript
var binding: GFTweenPreviewRegistration = GFTweenPreviewRegistry.get_shared().register_binding(
	self, "res://motions/open_panel.tres", &"gf.preview.ui",
	{"size": Vector2(64, 64)}, "面板展开"
)
# 插件退出时与适配器租约一起显式 binding.release()。
```

路径须为规范 `res://` 身份，每个路径只能有一个有效声明，最多 256 条。目标允许晚注册；在它可用前显示缺失原因，不回退其他样机。`initial_values` 最多覆盖 32 个样机初值表中的规范根属性，不接受分量路径。内置样机旋转用 `rotation` 弧度值，3D 用弧度 `Vector3`，不接受 `rotation_degrees` 别名作为初值键；属性浏览与动画步骤仍可使用这个别名。项目数值样机使用其描述中声明的直接属性。按实际目录复核类型、有限范围和整组计划。关联不加载或改写配置，也不影响运行时绑定；运行时仍由项目向真实目标创建动作。

作者在 Inspector 明确切换用途或编辑初值，覆盖本次编辑器会话选择；不会写入资源或生成关联。选择绑定用途时沿用其声明初值，再应用作者覆盖。切换用途、换源或租约失效都会撤销旧样机资格，标签和无关目录变化不重启既有冻结计划。

合法初值调整可以修复相对步骤的越界包络，仍须完整校验；若关联声明包含未知根属性，作者覆盖不能把它丢弃后当作有效声明。新配置无效时禁止新捕获或启动尚未播放的准备态；已经播放或定位且租约仍有效的旧快照可继续、定位或切换方向，直到显式重新准备或释放。

## 有限属性选择器

Steps 保留手动 property_name 输入，属性搜索直接使用上方预览所选的 2D/UI/3D 白名单或适配器目录，不再维护第二个用途选择。搜索仅匹配有限记录的名称，大小写无关、最多 128 字符，不扫描场景/资源，不调用任意 getter。

名称、类型、初值、硬边界和来源由准入、初值表单与选择器共用。选择沿用独立步骤复制及 Inspector Undo / Redo。换源、换目录或注册失效后，旧控件无提交资格。目录不支持的合法运行时路径保留原文，可继续手动编辑。

原生预览、运行时标记、完成与恢复行为见[配置化 Tween 动作](tween-config.md)。
