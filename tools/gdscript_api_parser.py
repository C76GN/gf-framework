"""读取 GDScript 声明及其文档，为 API 目录、参考手册和维护查询提供同一份解析结果。"""

from __future__ import annotations

import re
from collections.abc import Iterator
from contextlib import contextmanager
from contextvars import ContextVar
from copy import deepcopy
from dataclasses import dataclass, field
from pathlib import Path

from gf_workspace_snapshot import WorkspaceSnapshot


ROOT = Path(__file__).resolve().parents[1]
PUBLIC_API_VISIBILITIES = frozenset({"public", "protected"})
_ACTIVE_API_PARSE_SNAPSHOT: ContextVar[WorkspaceSnapshot | None] = ContextVar(
	"api_parse_snapshot", default=None,
)


@contextmanager
def api_parse_snapshot(snapshot: WorkspaceSnapshot | None) -> Iterator[None]:
	"""在上下文作用域内复用纯解析结果，只有显式参与的调用方共享缓存。"""
	token = _ACTIVE_API_PARSE_SNAPSHOT.set(snapshot)
	try:
		yield
	finally:
		_ACTIVE_API_PARSE_SNAPSHOT.reset(token)


@dataclass
class ApiDocs:
	"""保存声明的正文行及按出现顺序分组的标签，供各生成器从同一份说明取值。"""
	description: list[str] = field(default_factory=list)
	tags: dict[str, list[str]] = field(default_factory=dict)


@dataclass
class ApiMember:
	"""保留成员的种类、完整签名、文档和从 1 起算的声明行号。"""
	kind: str
	name: str
	signature: str
	line: int
	docs: ApiDocs
	decorators: list[str] = field(default_factory=list)


@dataclass
class ApiClass:
	"""表示一个具名类型及其内部类，owner 用来还原内部类的限定名。"""
	name: str
	path: str
	module: str
	extends: str
	line: int
	docs: ApiDocs
	owner: str = ""
	signals: list[ApiMember] = field(default_factory=list)
	enums: list[ApiMember] = field(default_factory=list)
	constants: list[ApiMember] = field(default_factory=list)
	properties: list[ApiMember] = field(default_factory=list)
	methods: list[ApiMember] = field(default_factory=list)
	inner_classes: list["ApiClass"] = field(default_factory=list)


@dataclass
class ApiScript:
	"""表示一个脚本文件，可承载具名类型或显式声明的 AutoLoad。"""
	path: str
	module: str
	class_name: str = ""
	api_owner_kind: str = ""
	api_owner_name: str = ""
	extends: str = ""
	line: int = 0
	docs: ApiDocs = field(default_factory=ApiDocs)
	signals: list[ApiMember] = field(default_factory=list)
	enums: list[ApiMember] = field(default_factory=list)
	constants: list[ApiMember] = field(default_factory=list)
	properties: list[ApiMember] = field(default_factory=list)
	methods: list[ApiMember] = field(default_factory=list)
	inner_classes: list[ApiClass] = field(default_factory=list)

	def has_public_surface(self) -> bool:
		"""判断脚本是否已收集到成员声明，成员的实际可见性由后续查询判断。"""
		return bool(self.signals or self.enums or self.constants or self.properties or self.methods)

	def to_api_class(self) -> ApiClass | None:
		"""将具名脚本投影为类型，无 class_name 的脚本返回 None。"""
		if not self.class_name:
			return None
		return ApiClass(
			name=self.class_name,
			path=self.path,
			module=self.module,
			extends=self.extends,
			line=self.line,
			docs=self.docs,
			signals=self.signals,
			enums=self.enums,
			constants=self.constants,
			properties=self.properties,
			methods=self.methods,
			inner_classes=self.inner_classes,
		)


@dataclass
class _GdscriptLexState:
	multiline_quote: str = ""


def collect_api_scripts(source_root: Path, root: Path = ROOT) -> list[ApiScript]:
	"""按路径顺序解析源码树中可作为查询对象的 GDScript 文件。"""
	result: list[ApiScript] = []
	for path in sorted(source_root.rglob("*.gd")):
		api_script = parse_gdscript_file(path, source_root, root)
		if api_script.class_name or api_script.api_owner_kind or api_script.has_public_surface():
			result.append(api_script)
	return result


def collect_api_classes(source_root: Path, root: Path = ROOT) -> list[ApiClass]:
	"""收集具备 class_name 的脚本，保持源码路径的遍历顺序。"""
	result: list[ApiClass] = []
	for script in collect_api_scripts(source_root, root):
		api_class = script.to_api_class()
		if api_class != None:
			result.append(api_class)
	return result


def parse_gdscript_file(path: Path, source_root: Path, root: Path = ROOT) -> ApiScript:
	"""读取当前 UTF-8 源码并解析声明。启用调用级缓存时，向每个调用方交付独立副本。"""
	relative_path = path.relative_to(root).as_posix()
	source_relative = path.relative_to(source_root)
	module = module_from_path(source_relative)
	# 每次都读取源码，文件大小和修改时间不足以判定解析输入是否相同。
	source = path.read_text(encoding="utf-8")
	snapshot = _ACTIVE_API_PARSE_SNAPSHOT.get()
	if snapshot is None:
		return parse_gdscript_source(source, relative_path, module)
	identity = (str(root.absolute()), str(source_root.absolute()), relative_path, module, source)
	parsed = snapshot.memoize(
		"api_script_parse",
		identity,
		lambda: parse_gdscript_source(source, relative_path, module),
	)
	# 调用者可能修改嵌套文档、成员或内部类，首次命中也应交付独立副本。
	return deepcopy(parsed)


def parse_gdscript_source(source: str, relative_path: str, module: str = "root") -> ApiScript:
	"""将源码解析为一个脚本及其声明，保留成员行号和文档标签。

	Args:
	    source: 待解析的完整 GDScript 文本。
	    relative_path: 记录在结果和诊断中的脚本路径。
	    module: 归入索引时使用的模块名。

	Returns:
	    含顶层声明和内部类的脚本记录。

	Raises:
	    ValueError: 声明了冲突的脚本所有者，或受校验的文档标签格式无效。
	"""
	api_script = ApiScript(
		path=relative_path,
		module=module,
	)
	lines = source.splitlines()
	structural_lines, starts_in_multiline = scan_gdscript_structure(lines)
	docs_buffer: list[str] = []
	decorators: list[str] = []
	i = 0
	while i < len(lines):
		raw_line = lines[i]
		stripped = raw_line.strip()
		structural = structural_lines[i].strip()
		if starts_in_multiline[i] or not is_top_level(raw_line):
			i += 1
			continue
		if stripped.startswith("##"):
			docs_buffer.append(stripped[2:].strip())
			i += 1
			continue
		decorated_var = parse_decorated_var_line(structural)
		if structural.startswith("@") and decorated_var == None:
			decorators.append(stripped)
			i += 1
			continue
		if not stripped:
			i += 1
			continue

		if match := re.match(r"extends\b", structural):
			api_script.extends = strip_gdscript_comment(raw_line)[match.end():].strip()
			owner_kind, owner_name = parse_api_owner_declaration(docs_buffer)
			if owner_kind:
				api_script.api_owner_kind = owner_kind
				api_script.api_owner_name = owner_name
				api_script.line = i + 1
				api_script.docs = parse_docs(docs_buffer)
			clear_buffers(docs_buffer, decorators)
			i += 1
			continue
		if match := re.match(r"class_name\s+([A-Za-z_]\w*)", structural):
			owner_kind, _owner_name = parse_api_owner_declaration(docs_buffer)
			if api_script.api_owner_kind or owner_kind:
				raise ValueError(
					"GDScript API script cannot declare both class_name and @api_owner: "
					f"{relative_path}"
				)
			api_script.class_name = match.group(1)
			api_script.line = i + 1
			api_script.docs = parse_docs(docs_buffer)
			clear_buffers(docs_buffer, decorators)
			i += 1
			continue
		if match := re.match(r"signal\s+([A-Za-z_]\w*)", structural):
			signature, next_index = collect_callable_signature(lines, i, "signal")
			api_script.signals.append(make_member("signal", match.group(1), signature, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i = next_index
			continue
		if match := re.match(r"enum\s+([A-Za-z_]\w*)", structural):
			signature, next_index = collect_block_signature(lines, i)
			api_script.enums.append(make_member("enum", match.group(1), signature, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i = next_index
			continue
		if match := re.match(r"const\s+([A-Za-z_]\w*)", structural):
			name = match.group(1)
			signature, next_index = collect_data_signature(lines, i, "const")
			if should_collect_member(name, docs_buffer):
				api_script.constants.append(make_member("const", name, signature, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i = next_index
			continue
		var_line = strip_gdscript_comment(raw_line).strip()
		if decorated_var != None:
			original_decorated_var = parse_decorated_var_line(strip_gdscript_comment(raw_line).strip())
			decorators.append(original_decorated_var[0] if original_decorated_var != None else decorated_var[0])
			var_line = original_decorated_var[1] if original_decorated_var != None else decorated_var[1]
		if match := re.match(r"var\s+([A-Za-z_]\w*)", var_line):
			name = match.group(1)
			signature, next_index = collect_data_signature(lines, i, "var", var_line)
			if should_collect_member(name, docs_buffer):
				api_script.properties.append(make_member("property", name, signature, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i = next_index
			continue
		if structural.startswith("func ") or structural.startswith("static func "):
			signature, next_index = collect_function_signature(lines, i)
			name = parse_function_name(signature)
			if name and should_collect_member(name, docs_buffer):
				api_script.methods.append(make_member("method", name, signature, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i = next_index
			continue
		clear_buffers(docs_buffer, decorators)
		i += 1

	if api_script.class_name:
		owner = api_script.to_api_class()
		if owner != None:
			api_script.inner_classes = parse_inner_classes(lines, owner)
	return api_script


def parse_inner_classes(lines: list[str], owner: ApiClass) -> list[ApiClass]:
	result: list[ApiClass] = []
	docs_buffer: list[str] = []
	structural_lines, starts_in_multiline = scan_gdscript_structure(lines)
	for i, raw_line in enumerate(lines):
		if not is_top_level(raw_line):
			continue

		stripped = raw_line.strip()
		structural = structural_lines[i].strip()
		if starts_in_multiline[i]:
			continue
		if stripped.startswith("##"):
			docs_buffer.append(stripped[2:].strip())
			continue
		if not stripped:
			continue

		if declaration := parse_inner_class_declaration(raw_line, structural):
			name, extends = declaration
			inner_class = ApiClass(
				name=name,
				path=owner.path,
				module=owner.module,
				extends=extends,
				line=i + 1,
				docs=parse_docs(docs_buffer),
				owner=full_api_class_name(owner),
			)
			block_end = find_class_block_end(lines, i, get_indent_level(raw_line))
			parse_inner_class_members(lines, i + 1, block_end, inner_class, get_indent_level(raw_line))
			result.append(inner_class)
			docs_buffer = []
			continue

		docs_buffer = []
	return result


def parse_inner_class_declaration(raw_line: str, structural: str) -> tuple[str, str] | None:
	"""在屏蔽字面量的源码中定位内部类声明，从原文保留其基类写法。"""
	match = re.match(r"class\s+([A-Za-z_]\w*)(?:\s+(extends)\s+[^:]+)?:", structural)
	if match is None:
		return None
	# 屏蔽引号后值的开头变成空白，应从关键字一直截取到结构冒号，才能保留原值。
	declaration = strip_gdscript_comment(raw_line)
	extends = declaration[match.end(2):match.end() - 1].strip() if match.group(2) else ""
	return match.group(1), extends


def find_class_block_end(lines: list[str], start: int, class_indent: int) -> int:
	for i in range(start + 1, len(lines)):
		raw_line = lines[i]
		if not raw_line.strip():
			continue
		if get_indent_level(raw_line) <= class_indent:
			return i
	return len(lines)


def parse_inner_class_members(
	lines: list[str],
	start: int,
	end: int,
	inner_class: ApiClass,
	class_indent: int,
) -> None:
	member_indent = find_direct_child_indent(lines, start, end, class_indent)
	if member_indent == None:
		return

	docs_buffer: list[str] = []
	decorators: list[str] = []
	structural_lines, starts_in_multiline = scan_gdscript_structure(lines)
	i = start
	while i < end:
		raw_line = lines[i]
		stripped = raw_line.strip()
		structural = structural_lines[i].strip()
		if starts_in_multiline[i]:
			i += 1
			continue
		if not stripped:
			i += 1
			continue
		if get_indent_level(raw_line) != member_indent:
			i += 1
			continue

		if stripped.startswith("##"):
			docs_buffer.append(stripped[2:].strip())
			i += 1
			continue
		decorated_var = parse_decorated_var_line(structural)
		if structural.startswith("@") and decorated_var == None:
			decorators.append(stripped)
			i += 1
			continue

		if declaration := parse_inner_class_declaration(raw_line, structural):
			name, extends = declaration
			nested_class = ApiClass(
				name=name,
				path=inner_class.path,
				module=inner_class.module,
				extends=extends,
				line=i + 1,
				docs=parse_docs(docs_buffer),
				owner=full_api_class_name(inner_class),
			)
			block_end = min(find_class_block_end(lines, i, member_indent), end)
			parse_inner_class_members(lines, i + 1, block_end, nested_class, member_indent)
			inner_class.inner_classes.append(nested_class)
			clear_buffers(docs_buffer, decorators)
			i = block_end
			continue

		if match := re.match(r"signal\s+([A-Za-z_]\w*)", structural):
			signature, next_index = collect_callable_signature(lines, i, "signal")
			inner_class.signals.append(make_member("signal", match.group(1), signature, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i = min(next_index, end)
			continue
		if match := re.match(r"enum\s+([A-Za-z_]\w*)", structural):
			signature, next_index = collect_block_signature(lines, i, end)
			inner_class.enums.append(make_member("enum", match.group(1), signature, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i = min(next_index, end)
			continue
		if match := re.match(r"const\s+([A-Za-z_]\w*)", structural):
			name = match.group(1)
			signature, next_index = collect_data_signature(lines, i, "const", limit=end)
			if should_collect_member(name, docs_buffer):
				inner_class.constants.append(make_member("const", name, signature, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i = next_index
			continue
		var_line = strip_gdscript_comment(raw_line).strip()
		if decorated_var != None:
			original_decorated_var = parse_decorated_var_line(strip_gdscript_comment(raw_line).strip())
			decorators.append(original_decorated_var[0] if original_decorated_var != None else decorated_var[0])
			var_line = original_decorated_var[1] if original_decorated_var != None else decorated_var[1]
		if match := re.match(r"var\s+([A-Za-z_]\w*)", var_line):
			name = match.group(1)
			signature, next_index = collect_data_signature(
				lines,
				i,
				"var",
				var_line,
				end,
			)
			if should_collect_member(name, docs_buffer):
				inner_class.properties.append(make_member("property", name, signature, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i = next_index
			continue
		if structural.startswith("func ") or structural.startswith("static func "):
			signature, next_index = collect_function_signature(lines, i)
			name = parse_function_name(signature)
			if name and should_collect_member(name, docs_buffer):
				inner_class.methods.append(make_member("method", name, signature, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i = min(next_index, end)
			continue

		clear_buffers(docs_buffer, decorators)
		i += 1


def find_direct_child_indent(lines: list[str], start: int, end: int, class_indent: int) -> int | None:
	for i in range(start, end):
		raw_line = lines[i]
		if not raw_line.strip():
			continue
		indent = get_indent_level(raw_line)
		if indent > class_indent:
			return indent
	return None


def parse_docs(lines: list[str]) -> ApiDocs:
	"""提取正文与可重复标签，跳过仅供 Godot 渲染换行的 [br]。"""
	docs = ApiDocs()
	for raw_line in lines:
		line = raw_line.strip()
		if not line or line == "[br]":
			continue
		if line.startswith("@"):
			name, value = split_tag(line)
			if name == "schema" and re.fullmatch(r"[A-Za-z_]\w*\s*:\s*\S.*", value) is None:
				raise ValueError("GDScript @schema must use '<name>: <nonempty description>' syntax.")
			docs.tags.setdefault(name, []).append(value)
		else:
			docs.description.append(line)
	return docs


def parse_api_owner_declaration(lines: list[str]) -> tuple[str, str]:
	"""从待绑定的文档中解析显式的顶层 API 所有者声明。"""
	docs = parse_docs(lines)
	values = docs.tags.get("api_owner", [])
	if not values:
		return "", ""
	if len(values) != 1:
		raise ValueError("GDScript @api_owner must be declared exactly once per script.")
	parts = values[0].split()
	if len(parts) != 2:
		raise ValueError("GDScript @api_owner must use '<kind> <name>' syntax.")
	kind, name = parts
	if not re.fullmatch(r"[a-z][a-z0-9_]*", kind):
		raise ValueError(f"GDScript @api_owner kind is invalid: {kind!r}")
	if not re.fullmatch(r"[A-Za-z_]\w*", name):
		raise ValueError(f"GDScript @api_owner name is invalid: {name!r}")
	return kind, name


def make_member(
	kind: str,
	name: str,
	signature: str,
	line_index: int,
	docs_buffer: list[str],
	decorators: list[str],
) -> ApiMember:
	return ApiMember(
		kind=kind,
		name=name,
		signature=signature,
		line=line_index + 1,
		docs=parse_docs(docs_buffer),
		decorators=decorators[:],
	)


def collect_function_signature(lines: list[str], start: int) -> tuple[str, int]:
	return collect_callable_signature(lines, start, "function")


def collect_callable_signature(
	lines: list[str],
	start: int,
	declaration_kind: str,
) -> tuple[str, int]:
	"""按词法意义上的括号收集完整可调用声明，忽略字面量中的括号。"""
	parts: list[str] = []
	state = _GdscriptLexState()
	depth = 0
	saw_opening_parenthesis = False
	i = start
	while i < len(lines):
		structural, comment_index, _started_in_multiline = scan_gdscript_line(lines[i], state)
		part = lines[i] if comment_index is None else lines[i][:comment_index]
		part = part.strip()
		if part:
			parts.append(part)
		opening_count = structural.count("(")
		closing_count = structural.count(")")
		if opening_count:
			saw_opening_parenthesis = True
		depth += opening_count - closing_count
		if depth < 0:
			raise ValueError(
				f"Malformed {declaration_kind} declaration at line {start + 1}: unexpected ')'"
			)
		if not state.multiline_quote and (not saw_opening_parenthesis or depth == 0):
			return " ".join(parts), i + 1
		i += 1
	raise ValueError(f"Unclosed {declaration_kind} declaration at line {start + 1}")


def collect_block_signature(
	lines: list[str],
	start: int,
	limit: int | None = None,
) -> tuple[str, int]:
	return collect_balanced_declaration(
		lines,
		start,
		"enum",
		required_opening="{",
		preserve_comments=True,
		limit=limit,
	)


def collect_data_signature(
	lines: list[str],
	start: int,
	declaration_kind: str,
	first_line: str | None = None,
	limit: int | None = None,
) -> tuple[str, int]:
	return collect_balanced_declaration(
		lines,
		start,
		declaration_kind,
		first_line=first_line,
		limit=limit,
	)


def collect_balanced_declaration(
	lines: list[str],
	start: int,
	declaration_kind: str,
	first_line: str | None = None,
	required_opening: str = "",
	preserve_comments: bool = False,
	limit: int | None = None,
) -> tuple[str, int]:
	"""收集一条已闭合的声明，跳过字符串和注释中的定界符。"""
	state = _GdscriptLexState()
	depths = {"(": 0, "[": 0, "{": 0}
	closing_to_opening = {")": "(", "]": "[", "}": "{"}
	saw_required_opening = required_opening == ""
	parts: list[str] = []
	end = len(lines) if limit is None else min(limit, len(lines))
	i = start
	while i < end:
		structural, comment_index, _started_in_multiline = scan_gdscript_line(lines[i], state)
		raw_part = (
			lines[i]
			if preserve_comments or comment_index is None
			else lines[i][:comment_index]
		)
		part = first_line.rstrip() if i == start and first_line is not None else raw_part.rstrip()
		if i == start:
			part = part.strip()
		if part.strip():
			parts.append(part)

		for character in structural:
			if character in depths:
				depths[character] += 1
				if character == required_opening:
					saw_required_opening = True
			elif character in closing_to_opening:
				opener = closing_to_opening[character]
				depths[opener] -= 1
				if depths[opener] < 0:
					raise ValueError(
						f"Malformed {declaration_kind} declaration at line {start + 1}: "
						f"unexpected {character!r}"
					)

		continues_explicitly = structural.rstrip().endswith("\\")
		if (
			not state.multiline_quote
			and saw_required_opening
			and all(depth == 0 for depth in depths.values())
			and not continues_explicitly
		):
			return "\n".join(parts), i + 1
		i += 1

	raise ValueError(f"Unclosed {declaration_kind} declaration at line {start + 1}")


def parse_function_name(signature: str) -> str:
	"""返回签名中的函数名，无法识别时返回空串。"""
	match = re.search(r"(?:static\s+)?func\s+([A-Za-z_]\w*)", signature)
	return match.group(1) if match else ""


def parse_decorated_var_line(line: str) -> tuple[str, str] | None:
	if not line.startswith("@"):
		return None
	# 先屏蔽注解中的字符串再定位声明，以相同字符偏移截取原行，保留注解的原始拼写。
	structural_lines, _starts_in_multiline = scan_gdscript_structure([line])
	var_index = structural_lines[0].find(" var ")
	if var_index == -1:
		return None
	decorator = line[:var_index].strip()
	var_line = line[var_index + 1:].strip()
	if not decorator or not var_line.startswith("var "):
		return None
	return decorator, var_line


def visibility_of(docs: ApiDocs) -> str:
	"""取第一个 @api 标签中的可见性，缺失时返回空串。"""
	value = first_tag(docs, "api")
	return value.split()[0] if value else ""


def should_collect_member(name: str, docs_buffer: list[str]) -> bool:
	if not name.startswith("_"):
		return True
	return visibility_of(parse_docs(docs_buffer)) != ""


def first_tag(docs: ApiDocs, name: str) -> str:
	"""取指定标签的第一个值，缺失时返回空串。"""
	values = docs.tags.get(name, [])
	return values[0] if values else ""


def split_tag(line: str) -> tuple[str, str]:
	without_prefix = line[1:]
	if " " not in without_prefix:
		if ":" in without_prefix:
			name, value = without_prefix.split(":", 1)
			return name.strip(), value.strip()
		return without_prefix.strip().rstrip(":"), ""
	name, value = without_prefix.split(" ", 1)
	return name.strip().rstrip(":"), value.strip()


def split_named_value(value: str) -> tuple[str, str]:
	"""在首个冒号处分开名称和说明，缺少冒号时说明为空。"""
	if ":" not in value:
		return value.strip(), ""
	name, description = value.split(":", 1)
	return name.strip(), description.strip()


def has_triple_quote(text: str) -> bool:
	state = _GdscriptLexState()
	scan_gdscript_line(text, state)
	return bool(state.multiline_quote)


def is_top_level(raw_line: str) -> bool:
	return raw_line == raw_line.lstrip(" \t")


def get_indent_level(raw_line: str) -> int:
	level = 0
	for character in raw_line:
		if character == "\t":
			level += 1
		elif character == " ":
			level += 1
		else:
			break
	return level


def parenthesis_delta(text: str) -> int:
	state = _GdscriptLexState()
	structural, _comment_index, _started_in_multiline = scan_gdscript_line(text, state)
	return structural.count("(") - structural.count(")")


def scan_gdscript_structure(lines: list[str]) -> tuple[list[str], list[bool]]:
	"""按行返回结构文本，并标识行首是否处于三引号字符串中。"""
	state = _GdscriptLexState()
	structural_lines: list[str] = []
	starts_in_multiline: list[bool] = []
	for line in lines:
		structural, _comment_index, started_in_multiline = scan_gdscript_line(line, state)
		structural_lines.append(structural)
		starts_in_multiline.append(started_in_multiline)
	return structural_lines, starts_in_multiline


def strip_gdscript_comment(text: str) -> str:
	state = _GdscriptLexState()
	_structural, comment_index, _started_in_multiline = scan_gdscript_line(text, state)
	return (text if comment_index is None else text[:comment_index]).strip()


def scan_gdscript_line(
	text: str,
	state: _GdscriptLexState,
) -> tuple[str, int | None, bool]:
	"""屏蔽字面量和注释，同时保留各结构字符在原文中的位置。"""
	structural = [" "] * len(text)
	started_in_multiline = bool(state.multiline_quote)
	comment_index: int | None = None
	i = 0
	while i < len(text):
		if state.multiline_quote:
			if text.startswith(state.multiline_quote, i) and not _is_escaped(text, i):
				i += len(state.multiline_quote)
				state.multiline_quote = ""
				continue
			i += 1
			continue

		if text[i] == "#":
			comment_index = i
			break
		if text.startswith('"""', i) or text.startswith("'''", i):
			state.multiline_quote = text[i:i + 3]
			i += 3
			continue
		if text[i] in {'"', "'"}:
			quote = text[i]
			i += 1
			while i < len(text):
				if text[i] == quote and not _is_escaped(text, i):
					i += 1
					break
				i += 1
			continue
		structural[i] = text[i]
		i += 1
	return "".join(structural), comment_index, started_in_multiline


def _is_escaped(text: str, index: int) -> bool:
	backslash_count = 0
	i = index - 1
	while i >= 0 and text[i] == "\\":
		backslash_count += 1
		i -= 1
	return backslash_count % 2 == 1


def brace_delta(text: str) -> int:
	state = _GdscriptLexState()
	structural, _comment_index, _started_in_multiline = scan_gdscript_line(text, state)
	return structural.count("{") - structural.count("}")


def clear_buffers(docs_buffer: list[str], decorators: list[str]) -> None:
	docs_buffer.clear()
	decorators.clear()


def module_from_path(relative_path: Path) -> str:
	parts = relative_path.parts
	if not parts:
		return "root"
	if parts[0] == "extensions" and len(parts) > 1:
		return f"{parts[0]}/{parts[1]}"
	return parts[0]


def full_api_class_name(api_class: ApiClass) -> str:
	"""生成包含内部类所有者的完整限定名。"""
	return f"{api_class.owner}.{api_class.name}" if api_class.owner else api_class.name


def top_level_class_name(api_class: ApiClass) -> str:
	"""返回最外层的类型名称，便于把内部类映射回脚本文件。"""
	return api_class.owner.split(".", 1)[0] if api_class.owner else api_class.name


def flatten_api_classes(api_classes: list[ApiClass]) -> list[ApiClass]:
	"""将顶层类与其嵌套类型展开，供需要逐类型处理的索引使用。"""
	result: list[ApiClass] = []
	for api_class in api_classes:
		result.append(api_class)
		result.extend(flatten_api_classes(api_class.inner_classes))
	return result
