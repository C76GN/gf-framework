# 空项目固定文本模板。只读取并展开文本，不加载或实例化生成的项目脚本。
extends RefCounted


# --- 常量 ---

## 空项目模板族的稳定身份，随 manifest 纳入预览签名以绑定用户确认的产物来源。
## [br]
## @api private
const _TEMPLATE_ID: String = "gf.empty_project"

## 当前固定模板版本；与实际文本一同进入计划签名，不只依赖版本号判断内容是否变化。
## [br]
## @api private
const _TEMPLATE_VERSION: int = 1

## 随工具分发的文本模板目录；生成器不从用户输出目录加载可执行模板。
## [br]
## @api private
const _TEMPLATE_ROOT: String = "res://addons/gf/tools/project_bootstrap/templates/empty_project/"

## 相对产物名到固定文本模板的有序映射；选项只筛选该清单，不接收任意文件名。
## [br]
## @api private
const _FILE_TEMPLATES: Dictionary = {
	"boot.gd": "boot.gd.txt",
	"boot.tscn": "boot.tscn.txt",
	"main.tscn": "main.tscn.txt",
	"project_installer.gd": "project_installer.gd.txt",
	"README.md": "README.md.txt",
}


# --- 框架内部方法 ---

## 声明本版本固定支持的文件，并按显式选项选择本次产物。
## [br]
## @api framework_internal
## [br]
## @param options: 已由生成器校验的选项；省略时使用新项目默认值。
## [br]
## @schema options: Dictionary，mode:String 默认 new_project，create_installer:bool 默认 true，include_readme:bool 默认 false。
## [br]
## @return 固定模板身份及本次有序文件清单。
## [br]
## @schema return: Dictionary，包含 id:String、version:int 和 file_names:PackedStringArray。
static func get_manifest(options: Dictionary = {}) -> Dictionary:
	var mode: String = options.get("mode", "new_project")
	var create_installer: bool = options.get("create_installer", true)
	var include_readme: bool = options.get("include_readme", false)
	var names: PackedStringArray = PackedStringArray()
	for file_name: String in _FILE_TEMPLATES:
		if file_name == "project_installer.gd":
			if not create_installer:
				continue
		elif file_name == "README.md":
			if not include_readme:
				continue
		elif mode != "new_project":
			continue
		var _appended: bool = names.append(file_name)
	return {"id": _TEMPLATE_ID, "version": _TEMPLATE_VERSION, "file_names": names}


## 读取固定文件并替换原文占位符；不会递归解释用户目录里的占位符文字。
## [br]
## @api framework_internal
## [br]
## @param directory: 已验证的项目资源目录。
## [br]
## @param options: 已由生成器校验的选项；省略时使用新项目默认值。
## [br]
## @schema options: Dictionary，mode:String 默认 new_project，create_installer:bool 默认 true，include_readme:bool 默认 false。
## [br]
## @return 相对文件名到 UTF-8 文本的映射；任何模板缺失或不可读时返回空字典。
## [br]
## @schema return: Dictionary[String, String]，键来自 get_manifest() 的 file_names，值为实际生成内容。
static func render(directory: String, options: Dictionary = {}) -> Dictionary:
	var manifest: Dictionary = get_manifest(options)
	var names: PackedStringArray = manifest["file_names"]
	var mode: String = options.get("mode", "new_project")
	var create_installer: bool = options.get("create_installer", true)
	var mode_guidance: String = "运行项目时先进入 boot.tscn；GF 初始化成功后才打开空 main.tscn。按 F5 运行项目，或打开 boot.tscn 后按 F6；直接按 F6 运行 main.tscn 会绕过启动页。"
	if mode == "existing_project":
		mode_guidance = "既有主场景与用户脚本保持不变。请把工作区提供的初始化片段合并到项目自己的启动入口，并在初始化成功后继续业务流程。"
	var installer_guidance: String = "未创建 Installer。需要装配项目模块时，可显式新建并登记项目 Installer。"
	if create_installer:
		installer_guidance = "project_installer.gd 是已登记的空装配入口。仅在项目需要时添加自己的模块，不包含预设业务逻辑。"
	var result: Dictionary = {}
	for file_name: String in names:
		var template_name: String = _FILE_TEMPLATES[file_name]
		var content: String = _read_template(template_name)
		if content.is_empty():
			return {}
		var parts: PackedStringArray = content.split("__ROOT__")
		for index: int in range(parts.size()):
			parts[index] = parts[index].replace("__MODE_GUIDANCE__", mode_guidance).replace("__INSTALLER_GUIDANCE__", installer_guidance)
		result[file_name] = directory.join(parts)
	return result


## 提供已有项目手工合并的初始化片段；不扫描或改写用户脚本。
## [br]
## @api framework_internal
## [br]
## @return 接入片段；模板缺失或不可读时为空。
static func get_integration_snippet() -> String:
	return _read_template("integration_snippet.gd.txt")


# --- 私有/辅助方法 ---

## 从固定模板根读取文本；缺失或读取为空时让上层拒绝不完整产物，不加载脚本资源。
## [br]
## @api private
static func _read_template(file_name: String) -> String:
	var path: String = _TEMPLATE_ROOT.path_join(file_name)
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)
