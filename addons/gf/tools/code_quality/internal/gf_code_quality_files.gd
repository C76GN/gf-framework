# 规范检查的只读文件边界；不加载目标脚本或项目资源。
extends RefCounted


# --- 框架内部方法 ---

## 将项目资源路径或绝对路径规范为存在的本地目录，并拒绝链接路径。
## [br]
## @api framework_internal
## [br]
## @param path: 调用方选择的项目根目录。
## [br]
## @return 可扫描绝对目录；不可读取或穿过链接时为空。
static func resolve_root(path: String) -> String:
	var absolute: String = ProjectSettings.globalize_path(path).replace("\\", "/")
	if not absolute.is_absolute_path() or absolute.begins_with("//"):
		return ""
	absolute = absolute.simplify_path()
	if absolute != "/":
		absolute = absolute.trim_suffix("/")
	if absolute.ends_with(":"):
		absolute += "/"
	if not DirAccess.dir_exists_absolute(absolute) or crosses_link(absolute):
		return ""
	return absolute


## 检查现存路径的父链，避免扫描跳出调用方选择的项目目录。
## [br]
## @api framework_internal
## [br]
## @param path: 本地绝对文件或目录路径。
## [br]
## @return 任一父链无法确认或存在链接时为 true。
static func crosses_link(path: String) -> bool:
	var cursor: String = path.replace("\\", "/").trim_suffix("/")
	while not cursor.is_empty() and not cursor.ends_with(":"):
		var parent_path: String = cursor.get_base_dir()
		if parent_path == cursor or parent_path.is_empty():
			break
		var directory: DirAccess = DirAccess.open(parent_path)
		if directory == null or directory.is_link(cursor.get_file()):
			return true
		cursor = parent_path
	return false


## 在字节预算内捕获稳定的 UTF-8 文本；原始文本及换行不做规范化。
## [br]
## @api framework_internal
## [br]
## @param path: 本地绝对输入路径。
## [br]
## @param max_bytes: 本次读取允许的最大字节数。
## [br]
## @return 文本捕获或读取错误。
## [br]
## @schema return: Dictionary，ok: bool、text: String、size_bytes/consumed_bytes: int、error: String；失败 text 为空，size_bytes 保留读取前的文件大小，consumed_bytes 为实际读取字节数；读取前拒绝时为 0。
static func read_text(path: String, max_bytes: int) -> Dictionary:
	if crosses_link(path):
		return _failure("输入路径不可读取或穿过链接。")
	var before_time: int = FileAccess.get_modified_time(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("无法只读打开输入文件。")
	var size_bytes: int = file.get_length()
	if size_bytes > max_bytes:
		file.close()
		return _failure("输入超过字节预算。", size_bytes)
	var bytes: PackedByteArray = file.get_buffer(size_bytes)
	var consumed_bytes: int = bytes.size()
	var stable: bool = file.get_length() == size_bytes and bytes.size() == size_bytes
	file.close()
	if (
		not stable
		or FileAccess.get_modified_time(path) != before_time
		or crosses_link(path)
	):
		return _failure(
			"输入在读取期间发生变化。",
			size_bytes,
			consumed_bytes
		)
	if not _valid_utf8(bytes):
		return _failure(
			"输入不是有效 UTF-8 文本。",
			size_bytes,
			consumed_bytes
		)
	return {
		"ok": true,
		"text": bytes.get_string_from_utf8(),
		"size_bytes": size_bytes,
		"consumed_bytes": consumed_bytes,
		"error": "",
	}


# --- 私有/辅助方法 ---

## 在调用引擎解码前拒绝截断、过长编码、代理字符和超范围码点。
## [br]
## @api private
static func _valid_utf8(bytes: PackedByteArray) -> bool:
	var cursor: int = 0
	while cursor < bytes.size():
		var first: int = bytes[cursor]
		if first < 0x80:
			if first == 0:
				return false
			cursor += 1
			continue
		var length: int = 0
		var scalar: int = 0
		var minimum: int = 0
		if first >= 0xc2 and first <= 0xdf:
			length = 2
			scalar = first & 0x1f
			minimum = 0x80
		elif first >= 0xe0 and first <= 0xef:
			length = 3
			scalar = first & 0x0f
			minimum = 0x800
		elif first >= 0xf0 and first <= 0xf4:
			length = 4
			scalar = first & 0x07
			minimum = 0x10000
		else:
			return false
		if cursor + length > bytes.size():
			return false
		for index: int in range(
			cursor + 1,
			cursor + length
		):
			var continuation: int = bytes[index]
			if continuation < 0x80 or continuation > 0xbf:
				return false
			scalar = (scalar << 6) | (continuation & 0x3f)
		if (
			scalar < minimum
			or scalar > 0x10ffff
			or (
				scalar >= 0xd800
				and scalar <= 0xdfff
			)
		):
			return false
		cursor += length
	return true


## 读取失败不暴露部分解码文本。
## [br]
## @api private
static func _failure(
	message: String,
	size_bytes: int = 0,
	consumed_bytes: int = 0
) -> Dictionary:
	return {
		"ok": false,
		"text": "",
		"size_bytes": size_bytes,
		"consumed_bytes": consumed_bytes,
		"error": message,
	}
