# Godot GDScript 编码风格指南

本指南旨在为项目提供一套统一、清晰的GDScript编码规范。遵循这些规范有助于提升代码的可读性、可维护性，并促进团队成员间的协作效率。

本文档中的规则主要基于项目现有代码的优秀实践和Godot官方文档的通用约定。

## 目录
1.  [命名规范](#1-命名规范)
2.  [代码布局与顺序](#2-代码布局与顺序)
3.  [注释风格](#3-注释风格)
4.  [类型提示](#4-类型提示)
5.  [格式与最佳实践](#5-格式与最佳实践)
6.  [文件格式与编码](#6-文件格式与编码)

---

## 1. 命名规范

清晰的命名是代码自解释能力的基础。

### 1.1 文件命名
*   **GDScript脚本**: 使用蛇形命名法 (`snake_case`)。这与Godot引擎源码风格一致，并能避免在跨平台（特别是大小写敏感的系统）时出现问题。
	*   示例: `game_board.gd`, `main_menu.gd`, `classic_interaction_rule.gd`
*   **场景文件**: 使用蛇形命名法 (`snake_case`)。
	*   示例: `game_play.tscn`, `mode_selection.tscn`

### 1.2 类与节点命名
*   **`class_name`**: 使用大驼峰命名法 (`PascalCase`)。
	*   示例: `class_name GameBoard`, `class_name StateMachine`
*   **场景树中的节点**: 使用大驼峰命名法 (`PascalCase`)。如果一个节点在脚本中会被频繁引用（通过 `%` 唯一名称获取），其名称应清晰表达其用途。
	*   示例: `GameBoard`, `ModeListContainer`, `StartGameButton`

### 1.3 函数与方法命名
*   **公共方法**: 使用蛇形命名法 (`snake_case`)。名称应为动词或动宾短语，清晰描述其功能。
	*   示例: `initialize_board()`, `get_state_snapshot()`, `update_display()`
*   **私有/内部方法**: 遵循蛇形命名法，并以一个下划线 `_` 开头。
	*   示例: `_update_board_layout()`, `_process_line()`
*   **Godot内置虚方法**: 遵循Godot的命名，例如 `_ready()`, `_process()`。
*   **信号回调函数**: 推荐使用 `_on_NodeName_signal_name` 的格式，这是Godot编辑器自动连接信号时生成的默认格式，非常直观。
	*   示例: `_on_start_game_button_pressed()`, `_on_hud_message_timer_timeout()`

### 1.4 变量与属性命名
*   **公共变量/属性**: 使用蛇形命名法 (`snake_case`)。
	*   示例: `var grid_size: int = 4`, `var move_count: int = 0`
*   **私有/内部变量**: 遵循蛇形命名法，并以一个下划线 `_` 开头。
	*   示例: `var _current_replay_data`, `var _game_state_history`
*   **常量 (`const`)**: 使用全大写蛇形命名法 (`CONSTANT_CASE`)。
	*   示例: `const CELL_SIZE: int = 100`, `const MAIN_MENU_SCENE_PATH = "..."`
*   **枚举 (`enum`)**: 枚举名使用大驼峰 (`PascalCase`)，其成员使用全大写 (`CONSTANT_CASE`)，每个成员占一行。
	*   示例:
		```gdscript
		enum State {
			READY,
			PLAYING,
			GAME_OVER,
		}
		```

### 1.5 信号命名
*   信号名称使用过去时态，描述已经发生的事件。
	*   示例: `signal score_changed`, `signal door_opened`

---

## 2. 代码布局与顺序

一个结构清晰的脚本文件能让人快速定位信息。脚本内的内容应遵循以下顺序组织：

1.  **脚本元注解**: `@tool`, `@icon` 等。
2.  **文件级文档注释**: 带 `class_name` 的 API 脚本使用 `##` 说明该类的核心职责；classless helper、插件入口或 Autoload 单例脚本使用普通 `#` 说明维护语义，除非下一行就是可绑定的声明。
3.  **`class_name`**
4.  **`extends`**
5.  **`signal` 声明**
6.  **`enum` 定义**
7.  **`const` 定义**
8.  **`@export` 变量** (按 `@export_group` 分组)
9.  **公共变量**
10.  **私有变量** (以下划线 `_` 开头)
11.  **`@onready var` 变量** (节点引用，仅限 Node 兼容脚本)
12.  **Godot 生命周期 / 回调方法 (Lifecycle & Callbacks)**: 按逻辑执行顺序排列。包括 `_ready()`、`_process()` 等节点生命周期方法，以及 Editor 插件、Inspector 插件等 Godot 类型约定的 `_can_handle()`、`_parse_begin()` 等回调。
	 *   `_init()`
	 *   `_enter_tree()`
	 *   `_ready()`
	 *   `_unhandled_input()` / `_input()`
	 *   `_process()`
	 *   `_physics_process()`
	 *   `_exit_tree()`
	 *   ...等等
13.  **GF 生命周期方法**: `init()`、`async_init()`、`ready()`、`dispose()` 等 GF 约定入口。
14.  **公共方法**
15.  **可重写钩子 / 虚方法**：供子类重写、但不作为普通调用入口的方法。若这类方法使用 `_` 前缀，必须集中放在明确的钩子区，而不要混在公共方法区。
16.  **框架内部方法**
17.  **层内方法**
18.  **私有/辅助方法** (以下划线 `_` 开头)
19.  **信号回调函数** (例如 `_on_*`)
20.  **内部类 (Subclasses)**

下划线前缀代表非普通公共 API。即使某个 `_` 方法会被框架通过反射、`has_method()`、`call()` 或约定名称调用，它仍应按其语义放入“私有/辅助方法”“可重写钩子/虚方法”“Godot 生命周期方法”“Godot 回调方法”或“信号回调函数”区，不能仅因为调用点相邻就放在公共方法区。

`@onready` 是 Node 生命周期语义，只能用于继承 `Node` 或已知 Node 派生类型的脚本。`RefCounted`、`Resource`、`Object` 等数据型脚本不允许使用 `@onready` section 或变量。

允许按模块职责细化 section 名称，但必须保留 canonical section 基名。例如 `# --- 公共方法（注册） ---`、`# --- 公共方法 (简单事件) ---`、`# --- @onready 变量（节点引用） ---` 可以被测试稳定归类；`# --- 获取方法 ---`、`# --- 事件系统 ---`、`# --- 私有方法 ---` 不允许。完整 section 列表以根目录 `API_SURFACE.md` 为准。

文件路径信息应以编辑器标签、仓库目录结构和 `res://` 资源路径为准，不再额外要求 `# path/to/file.gd` 形式的文件路径注释。

**空行使用规则**:

*   **节与节之间**: 在不同的代码节（例如 `signal` 节和 `enum` 节，或变量区和函数区）之间，使用**一个**空行。推荐使用[节注释](#35-节注释-section-comments)来标记节的开始。
*   **节内部成员的空行**:
	*   任何带有文档注释 (`##`) 的成员（信号、变量、常量等），其完整的声明块（注释 + 声明）之后**必须**跟一个空行。这确保了每个有文档的成员都是一个清晰的视觉单元。
	*   连续的、**没有**文档注释的单行成员之间**不应**有空行，以保持内部或简单变量的紧凑性。
*   **函数之间**: 在函数、枚举、内部类定义之间使用**两个**空行，以提供清晰的视觉分隔。
*   **函数内部**: 在函数内部，使用**一个**空行来分隔不同的逻辑块。

---

## 3. 注释风格

注释的目的是解释**“为什么”**，而不是“是什么”。代码本身应该清晰地说明它在“做什么”。`##` 文档注释同时也是 GF API Surface Contract 的入口：公开、可重写和内部协作 API 必须用 `##` 明确标注；私有实现细节不使用 `##`，避免被半自动 API 文档生成误收录。完整可见性、类型分类和迁移标记规则见仓库根目录的 `API_SURFACE.md`。

### 3.1 文件级注释
*   带 `class_name` 的脚本顶部应使用文档注释 (`##`) 绑定到该类型，并说明类的用途和核心职责。
*   没有 `class_name` 的 helper、插件入口、Autoload 单例或模板脚本不应使用悬空顶部 `##`。这类说明使用普通 `#`，避免被 API 文档生成器误收录。
*   classless 顶层 `public` / `protected` API 只允许出现在继承 `Node` 或已知 Node 派生类型的 Autoload / 插件单例脚本中；普通 helper 和数据脚本只能声明内部协作 API。
*   人读说明和 `@api`、`@param`、`@return`、`@schema` 等机器标签之间，以及连续机器标签之间，都应使用 `## [br]` 分隔。Godot 悬停文档支持 BBCode；显式 `[br]` 可以避免说明文字和标签在提示框中粘连。
*   不再要求使用单独的文件路径注释；脚本头部说明统一由类型文档或普通维护注释承担。

	```gdscript
	## StateMachine: 一个通用的有限状态机 (FSM) 节点。
	##
	## 该节点被设计为任何需要状态管理逻辑的父节点的子节点...
	## [br]
	## @api public
	## [br]
	## @category protocol
	## [br]
	## @since 3.17.0
	```

### 3.2 成员文档注释
*   所有公共的类成员（信号、枚举、常量、变量、函数等）都必须使用文档注释 (`##`) 来说明其用途，并通过 `@api public` 或其他明确可见性标签声明 API 边界。这有助于在Godot编辑器中获得悬停提示，并能自动生成文档。

*   **信号 (Signal)**
	```gdscript
	## 当状态成功切换后发出。
	## [br]
	## @api public
	## [br]
	## @param new_state_name: 进入的新状态的名称。
	signal state_changed(new_state_name)
	```

*   **枚举 (Enum) 与其成员**
	```gdscript
	## 定义了 GamePlay 的核心状态。
	enum State {
		## 游戏已初始化，等待开始
		READY,
		## 游戏正在进行中
		PLAYING,
		## 游戏已结束
		GAME_OVER,
	}
	```

*   **常量 (Constant)**
	```gdscript
	## 每个单元格的像素尺寸。
	const CELL_SIZE: int = 100
	```

*   **变量 (Variable)**
	```gdscript
	## 棋盘的尺寸（例如 4x4 中的 4）。
	@export var grid_size: int = 4

	## 存储棋盘上所有方块节点的二维数组引用。'null'代表空格。
	var grid: Array[Array] = []
	```

*   **函数 (Function)**
	对于复杂的公共函数，可以使用文档注释来说明其功能、参数 (`@param`) 和返回值 (`@return`)。
	```gdscript
	## 切换到新状态。这是控制状态机的核心函数。
	## [br]
	## @api public
	## [br]
	## @param new_state_name: 要切换到的新状态的名称。
	## [br]
	## @param message: 一个可选的字典，用于在状态间传递数据。
	func set_state(new_state_name, message: Dictionary = {}) -> void:
		# ...
	```

### 3.3 行内注释 (函数内部)
*   **非必要不添加**: 函数内部应追求**代码即文档**。如果一段代码的逻辑可以通过良好的变量命名和结构清晰表达，则严禁添加注释。
*   **简洁至上**: 如果必须添加注释，注释内容越简洁越好，直击要害。
*   **仅解释“为什么”**: 注释应仅用于解释复杂的算法、反直觉的业务逻辑判断、魔法数字的来源或由于外部限制而采取的变通方案。
*   **禁止翻译代码**: 严禁出现“这行代码是用来赋值的”、“这里开始循环”等解释代码本身行为的废话注释。

### 3.4 注释间距
*   **说明性注释**: 井号 `#` 或 `##` 后应跟一个空格，以区分代码。
	*   `# 这是一个说明。`
	*   `## 这是一个文档注释。`
*   **被注释掉的代码**: 井号 `#` 与代码之间不留空格。这可以快速识别出哪些是临时禁用的代码。
	*   `#print("debug message")`

### 3.5 节注释 (Section Comments)

* **用途**: 为了严格遵循[代码布局与顺序](#2-代码布局与顺序)中定义的结构，我们使用节注释来创建视觉分隔，这极大地提高了代码的可扫描性和导航速度。

*   **规范**:
	*   节注释是**强制性**的，用于分隔代码布局顺序中的不同部分。
	*   统一使用格式：`# --- Section Name ---`
	*   `Section Name` 必须能映射到 `API_SURFACE.md` 中的 canonical section；可追加括号说明，但不能替换 canonical 基名。
	*   每个节注释之后，必须紧跟一个空行，然后再开始该节的代码。
	*   即使某个节为空，也建议保留其注释（或省略），以维持结构的统一性。
	*   遇到新的语言结构、声明形态或框架约定时，不允许临时塞进相近 section。必须先更新 `API_SURFACE.md`、正例夹具和维护测试，再在源码中使用它作为 API。

*   **示例 (标准模板)**:

	```gdscript
	@tool

	## 简要说明该类的作用及其核心职责。
	##
	## 如果需要，可以有更详细的说明。
	class_name GamePlay
	extends Control

	# --- 信号 ---
	signal game_started
	signal score_updated(new_score)

	# --- 枚举 ---
	enum State {
		## 准备阶段
		READY,
		## 游戏进行中
		PLAYING,
		## 游戏结束
		GAME_OVER,
	}

	# --- 常量 ---
	const MAX_PLAYERS: int = 4

	# --- 导出变量 ---
	@export_group("游戏设置")
	@export var speed: float = 100.0
	@export var gravity: float = 9.8

	# --- 公共变量 ---
	var current_level: int = 1

	# --- 私有变量 ---
	var _score: int = 0
	var _time_elapsed: float = 0.0

	# --- @onready 变量 (节点引用) ---
	@onready var _game_board: Control = %GameBoard
	@onready var _hud: VBoxContainer = %HUD


	# --- Godot 生命周期方法 ---

	func _ready() -> void:
		# ...


	func _process(delta: float) -> void:
		# ...


	# --- 公共方法 ---

	func start_game() -> void:
		# ...


	# --- 可重写钩子 ---

	func _on_started() -> void:
		# ...


	# --- 私有/辅助方法 ---

	func _update_score(amount: int) -> void:
		# ...


	# --- 信号处理函数 ---

	func _on_player_died() -> void:
		# ...

	```

### 3.6 严禁修改记录 (No Changelogs)
*   **相信版本控制**: 代码文件中**严禁**出现任何形式的手动修改记录、变更日志或作者署名。
*   **禁止项示例**:
	*   `# [核心修复] `
	*   `# Modified: Fixed the crash bug`
	*   `# EDIT: Changed logic below`
*   **正确做法**: 文件的变更历史、具体修改内容和责任人应完全依赖版本控制系统（Git）的 `Commit Message` 和 `Blame` 功能进行追溯。代码库应只反映当前的最新状态。

---

## 4. 类型提示

本项目强制要求使用静态类型提示，以提高代码的健壮性和可读性，并利用Godot 4的类型检查功能。

### 4.1 基本用法
*   **变量**: `var my_variable: Type = value`
*   **函数参数**: `func my_function(param: Type):`
*   **函数返回值**: `func my_function() -> ReturnType:` (无返回值时用 `-> void:`)

### 4.2 类型推断 (`:=`)
GF 框架源码以长期维护和 Godot strict warning clean 为优先级。`addons/gf/**` 中的局部变量、成员变量和 `@onready` 变量默认使用显式类型声明，不依赖 `:=` 承担 API 边界或框架语义。

*   **推荐做法**: 直接写出维护者期望的类型，让读者和编译器看到同一份契约。
	```gdscript
	var direction: Vector3 = Vector3.UP
	var state_machine: GFStateMachine = GFStateMachine.new()
	@onready var health_bar: ProgressBar = %HealthBar
	```
*   **受限例外**: 仅在非常局部、不会跨 API 边界、不会接触 `Variant` 的算法临时量中，才可以使用 `:=`。这类右值必须是编译器稳定知道类型的字面量、构造函数或强类型函数返回值。
	```gdscript
	var next_index := index + 1
	var bounds := Rect2(Vector2.ZERO, size)
	```
*   **禁止场景**: 只要右值来自动态边界，就必须显式声明类型并做必要的类型检查。动态边界包括但不限于 `Dictionary.get()`、`Array`/`Dictionary` 下标、`Object.get()`、`call()`、`load()`、`get_script()`、`WeakRef.get_ref()`、`JSON.parse_string()`、`FileAccess.get_var()`、`ResourceLoader.load()`、信号参数、反射调用和 `await` 结果。
	```gdscript
	var value: Variant = payload.get("enabled", false)
	var enabled: bool = bool(value) if value is bool else false
	```

### 4.3 Variant 边界与类型收窄
从 `Variant` 边界进入框架强类型代码时，应把类型收窄集中、显式、可复用地表达出来，避免让不安全 cast 分散在业务逻辑中。

*   **对象类型**: 先用 `is` 判断，再赋给显式类型变量。不要把 `Variant as Object`、`Variant as Script`、`Variant as Dictionary`、`Variant as Array` 直接和 `:=` 组合。
	```gdscript
	var raw_script: Variant = instance.get_script()
	if raw_script is Script:
		var script: Script = raw_script
	```
*   **字典与数组**: 读取 `Dictionary` / `Array` 时先接收为 `Variant`，再按目标类型校验或通过私有 helper 收口。通用 helper 应返回强类型结果，例如 `Dictionary`、`Array`、`Script` 或 `Object`，调用方不要重复写裸 cast。
	```gdscript
	var raw_entry: Variant = entries.get(id)
	if raw_entry is Dictionary:
		var entry: Dictionary = raw_entry
	```
*   **布尔、数字和字符串**: 对来自 `Variant` 的标量值先确认可转换类型，再调用 `bool()`、`int()`、`float()`、`String()` 或 `StringName()`，避免 Godot 的 unsafe call argument 警告。
*   **命名防御**: 局部变量和参数不得使用容易遮蔽基类 API 或 Godot 属性的名字，例如 `name`、`reference`。使用语义名，如 `property_name`、`object_ref`、`weak_ref`。

### 4.4 GDScript warning-clean 规则
GF 源码和测试必须保持 Godot reload warning clean。新增或修改 GDScript 时，不允许用 `@warning_ignore` 掩盖本可修复的问题，优先改成静态类型明确的写法。

*   **禁止遮蔽**: 局部变量、参数和测试常量不得与当前类成员或全局 `class_name` 同名。测试需要 preload 脚本时使用 `_SCRIPT` 后缀；如果已有全局类名，优先直接使用全局类。
	```gdscript
	const GF_CONFIG_PIPELINE_SCRIPT = preload("res://addons/gf/tools/config_pipeline/gf_config_pipeline.gd")
	```
*   **禁止裸动态 cast**: 不要从 `Variant` 直接写 `value as GFType`。先用 `is` 判断，再赋给显式类型变量；重复逻辑收进私有 helper。
	```gdscript
	func _variant_to_database(value: Variant) -> GFConfigDatabaseResource:
		if value is GFConfigDatabaseResource:
			var database: GFConfigDatabaseResource = value
			return database
		return null
	```
*   **构造函数参数先收窄**: `String()`、`StringName()`、`NodePath()` 等构造函数只接收已收窄的 `String`、`StringName` 或 `NodePath`，不要直接传 `Variant`。
*   **动态脚本实例化先收窄**: `get_script()` 返回值先接收为 `Variant`，确认 `is GDScript` 后再调用 `new()`；不要把它声明成 `Script` 后直接 `.new()`。
*   **返回值必须处理**: Godot API 或 GF API 有返回值时必须接收、检查或明确命名为 `_xxx_result`。例如 `store_string()`、`merge_dictionary()`、`connect()`、`append()` 等不要直接丢弃返回值。
*   **改完必须验证**: 涉及 `.gd` 的修改至少运行相关 focused GUT；提交前或收敛前运行 `python tools\gf_maintenance.py check --check gdscript_warnings --json`，截图中出现的 `UNSAFE_*`、`SHADOWED_*`、`RETURN_VALUE_DISCARDED` 等 warning 必须清零。维护测试 `test_gdscript_parse_validation.gd` 会静态拦截遮蔽全局 `class_name` 的脚本常量、未收窄的 GF 类强转，以及对 `Script` 类型变量直接 `.new()` 的写法。

---

## 5. 格式与最佳实践

保持一致的格式可以减少阅读时的认知负荷。

### 5.1 空格
*   在二元操作符 (`=`, `+`, `==`, `>`) 两侧加空格。
*   在逗号 `,` 后面加空格。
*   在类型提示的冒号 `:` 后面加空格。
*   不要在函数名和左括号 `(` 之间加空格。
*   在单行字典的 `{}` 内部两侧添加空格，以和数组的 `[]` 区分。
	*   `var dict = { "key": "value" }`
	*   `var array = [1, 2, 3]`

### 5.2 行尾逗号
*   在多行书写的数组、字典和枚举的最后一个元素后面，总是加上一个逗号。这会让版本控制的差异对比（diff）更清晰，且添加新元素更方便。
	```gdscript
	var my_array = [
		"one",
		"two",
		"three", # <-- 这个逗号很重要
	]
	```

### 5.3 多行语句
*   对于过长的表达式（如复杂的`if`条件），推荐使用圆括号 `()` 将其括起来换行，而不是使用反斜杠 `\`。
*   换行时，逻辑运算符 `and` 或 `or` 应放在下一行的开头，并增加一级缩进。
	```gdscript
	if (long_variable_name_a > 10
		and long_variable_name_b < 20
	):
		print("Condition met")
	```

### 5.4 布尔运算符
*   优先使用单词形式的运算符，它们更易读：`and`, `or`, `not`，而不是 `&&`, `||`, `!`。

### 5.5 数字格式
*   **浮点数**: 不要省略前导或后缀的零。使用 `1.0` 和 `0.5`，而不是 `1.` 或 `.5`。
*   **十六进制**: 使用小写字母，例如 `#ffffff`。
*   **大数字**: 使用下划线 `_` 作为千位分隔符来提高可读性。
	*   示例: `var large_number = 1_000_000`

### 5.6 代码简洁性
*   **一条语句一行**: 避免使用分号 `;` 在一行内写多条语句。
*   **避免冗余括号**: 除非为了改变运算优先级或多行书写，否则不要在 `if` 语句或表达式中滥用括号。

### 5.7 字符串
*   优先使用双引号 `"` 来定义字符串，保持一致性。

---

## 6. 文件格式与编码

*   **编码**: 所有 `.gd` 文件必须使用 **UTF-8** 编码（不带BOM）。
*   **换行符**: 使用 **Unix-style** 换行符 (**LF**)，而不是Windows-style (CRLF)。
*   **文件末尾**: 所有文件应以一个空行结束。
*   **缩进**: 使用制表符 (`Tab`) 进行缩进，而不是空格。

> 注意: 以上四条均为Godot编辑器的默认行为，保持默认设置即可。
