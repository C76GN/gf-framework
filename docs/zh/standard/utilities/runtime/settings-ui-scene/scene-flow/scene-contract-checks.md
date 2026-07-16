# 场景根节点契约检查

`GFSceneContractTools` 用于在编辑器工具、导入预检、CI 或测试里检查场景根节点是否满足调用方声明的通用契约。它只处理根节点类型、脚本继承、分组、名称和资源路径，不规定项目的实体/组件目录、玩法字段或初始化方法。

## 核心模型

```gdscript
var report := GFSceneContractTools.check_scene_directory("res://game/scenes", {
	"base_class": "Node2D",
	"base_script": preload("res://game/contracts/base_scene_root.gd"),
	"required_groups": PackedStringArray(["loadable_scene"]),
	"name_suffix": "Root",
}, {
	"recursive": true,
	"include_patterns": PackedStringArray(["**/*.tscn"]),
})

if not report["ok"]:
	push_error(report["summary"])
```

## 校验套件

需要接入 `GFValidationSuite` 时，可用 `make_validation_rule()` 生成普通 `GFValidationRule`。默认规则只作用于 Node，适合配合 `GFValidationRunner` 对 `PackedScene` 自动实例化根节点后再检查。

```gdscript
var suite := GFValidationSuite.new()
suite.include_paths = PackedStringArray(["res://game/scenes"])
suite.add_rule(GFSceneContractTools.make_validation_rule({
	"required_groups": PackedStringArray(["loadable_scene"]),
	"path_suffix": ".tscn",
}))

var validation_report := GFValidationRunner.new().run_suite(suite)
```

## 脚本结构

如果要检查根脚本的公开方法、属性或信号，把 `script_structure` 传给契约即可；该字段复用 `GFScriptStructureTools.check_script_structure()`，因此仍然保持“声明什么才检查什么”的边界。

```gdscript
var scene_report := GFSceneContractTools.check_scene_path("res://game/scenes/menu.tscn", {
	"script_structure": {
		"required_methods": PackedStringArray(["open", "close"]),
		"required_signals": PackedStringArray(["closed"]),
	},
})
```

## 使用边界

这类检查适合发现资源库里“看起来像某类场景但根节点缺少必要形状”的问题。具体哪些分组、脚本基类、命名或路径模式有效，仍由项目层声明；GF 不内置任何业务场景分类。
