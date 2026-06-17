"""Shared GDScript API parser used by GF documentation generators."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


@dataclass
class ApiDocs:
	description: list[str] = field(default_factory=list)
	tags: dict[str, list[str]] = field(default_factory=dict)


@dataclass
class ApiMember:
	kind: str
	name: str
	signature: str
	line: int
	docs: ApiDocs
	decorators: list[str] = field(default_factory=list)


@dataclass
class ApiClass:
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
	path: str
	module: str
	class_name: str = ""
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
		return bool(self.signals or self.enums or self.constants or self.properties or self.methods)

	def to_api_class(self) -> ApiClass | None:
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


def collect_api_scripts(source_root: Path, root: Path = ROOT) -> list[ApiScript]:
	result: list[ApiScript] = []
	for path in sorted(source_root.rglob("*.gd")):
		api_script = parse_gdscript_file(path, source_root, root)
		if api_script.class_name or api_script.has_public_surface():
			result.append(api_script)
	return result


def collect_api_classes(source_root: Path, root: Path = ROOT) -> list[ApiClass]:
	result: list[ApiClass] = []
	for script in collect_api_scripts(source_root, root):
		api_class = script.to_api_class()
		if api_class != None:
			result.append(api_class)
	return result


def parse_gdscript_file(path: Path, source_root: Path, root: Path = ROOT) -> ApiScript:
	relative_path = path.relative_to(root).as_posix()
	source_relative = path.relative_to(source_root)
	api_script = ApiScript(
		path=relative_path,
		module=module_from_path(source_relative),
	)
	lines = path.read_text(encoding="utf-8").splitlines()
	docs_buffer: list[str] = []
	decorators: list[str] = []
	in_multiline_string = False
	i = 0
	while i < len(lines):
		raw_line = lines[i]
		stripped = raw_line.strip()
		if has_triple_quote(stripped):
			in_multiline_string = not in_multiline_string
			i += 1
			continue
		if in_multiline_string or not is_top_level(raw_line):
			i += 1
			continue
		if stripped.startswith("##"):
			docs_buffer.append(stripped[2:].strip())
			i += 1
			continue
		decorated_var = parse_decorated_var_line(stripped)
		if stripped.startswith("@") and decorated_var == None:
			decorators.append(stripped)
			i += 1
			continue
		if not stripped:
			i += 1
			continue

		if match := re.match(r"extends\s+(.+)", stripped):
			api_script.extends = match.group(1).strip()
			clear_buffers(docs_buffer, decorators)
			i += 1
			continue
		if match := re.match(r"class_name\s+([A-Za-z_]\w*)", stripped):
			api_script.class_name = match.group(1)
			api_script.line = i + 1
			api_script.docs = parse_docs(docs_buffer)
			clear_buffers(docs_buffer, decorators)
			i += 1
			continue
		if match := re.match(r"signal\s+([A-Za-z_]\w*)", stripped):
			api_script.signals.append(make_member("signal", match.group(1), stripped, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i += 1
			continue
		if match := re.match(r"enum\s+([A-Za-z_]\w*)", stripped):
			signature, next_index = collect_block_signature(lines, i)
			api_script.enums.append(make_member("enum", match.group(1), signature, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i = next_index
			continue
		if match := re.match(r"const\s+([A-Za-z_]\w*)", stripped):
			name = match.group(1)
			if should_collect_member(name, docs_buffer):
				api_script.constants.append(make_member("const", name, stripped, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i += 1
			continue
		var_line = stripped
		if decorated_var != None:
			decorators.append(decorated_var[0])
			var_line = decorated_var[1]
		if match := re.match(r"var\s+([A-Za-z_]\w*)", var_line):
			name = match.group(1)
			if should_collect_member(name, docs_buffer):
				api_script.properties.append(make_member("property", name, var_line, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i += 1
			continue
		if stripped.startswith("func ") or stripped.startswith("static func "):
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
	for i, raw_line in enumerate(lines):
		if not is_top_level(raw_line):
			continue

		stripped = raw_line.strip()
		if stripped.startswith("##"):
			docs_buffer.append(stripped[2:].strip())
			continue
		if not stripped:
			continue

		if match := re.match(r"class\s+([A-Za-z_]\w*)(?:\s+extends\s+([^:]+))?:", stripped):
			inner_class = ApiClass(
				name=match.group(1),
				path=owner.path,
				module=owner.module,
				extends=(match.group(2) or "").strip(),
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
	i = start
	while i < end:
		raw_line = lines[i]
		stripped = raw_line.strip()
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
		decorated_var = parse_decorated_var_line(stripped)
		if stripped.startswith("@") and decorated_var == None:
			decorators.append(stripped)
			i += 1
			continue

		if match := re.match(r"signal\s+([A-Za-z_]\w*)", stripped):
			inner_class.signals.append(make_member("signal", match.group(1), stripped, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i += 1
			continue
		if match := re.match(r"enum\s+([A-Za-z_]\w*)", stripped):
			signature, next_index = collect_block_signature(lines, i)
			inner_class.enums.append(make_member("enum", match.group(1), signature, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i = min(next_index, end)
			continue
		if match := re.match(r"const\s+([A-Za-z_]\w*)", stripped):
			name = match.group(1)
			if should_collect_member(name, docs_buffer):
				inner_class.constants.append(make_member("const", name, stripped, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i += 1
			continue
		var_line = stripped
		if decorated_var != None:
			decorators.append(decorated_var[0])
			var_line = decorated_var[1]
		if match := re.match(r"var\s+([A-Za-z_]\w*)", var_line):
			name = match.group(1)
			if should_collect_member(name, docs_buffer):
				inner_class.properties.append(make_member("property", name, var_line, i, docs_buffer, decorators))
			clear_buffers(docs_buffer, decorators)
			i += 1
			continue
		if stripped.startswith("func ") or stripped.startswith("static func "):
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
	docs = ApiDocs()
	for raw_line in lines:
		line = raw_line.strip()
		if not line or line == "[br]":
			continue
		if line.startswith("@"):
			name, value = split_tag(line)
			docs.tags.setdefault(name, []).append(value)
		else:
			docs.description.append(line)
	return docs


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
	parts = [lines[start].strip()]
	depth = parenthesis_delta(parts[0])
	i = start
	while depth > 0 and i + 1 < len(lines):
		i += 1
		part = lines[i].strip()
		parts.append(part)
		depth += parenthesis_delta(part)
	return " ".join(parts), i + 1


def collect_block_signature(lines: list[str], start: int) -> tuple[str, int]:
	parts = [lines[start].strip()]
	depth = brace_delta(parts[0])
	i = start
	while depth > 0 and i + 1 < len(lines):
		i += 1
		part = lines[i].rstrip()
		parts.append(part)
		depth += brace_delta(part)
	return "\n".join(parts), i + 1


def parse_function_name(signature: str) -> str:
	match = re.search(r"(?:static\s+)?func\s+([A-Za-z_]\w*)", signature)
	return match.group(1) if match else ""


def parse_decorated_var_line(line: str) -> tuple[str, str] | None:
	if not line.startswith("@"):
		return None
	var_index = line.find(" var ")
	if var_index == -1:
		return None
	decorator = line[:var_index].strip()
	var_line = line[var_index + 1:].strip()
	if not decorator or not var_line.startswith("var "):
		return None
	return decorator, var_line


def visibility_of(docs: ApiDocs) -> str:
	value = first_tag(docs, "api")
	return value.split()[0] if value else ""


def should_collect_member(name: str, docs_buffer: list[str]) -> bool:
	if not name.startswith("_"):
		return True
	return visibility_of(parse_docs(docs_buffer)) != ""


def first_tag(docs: ApiDocs, name: str) -> str:
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
	if ":" not in value:
		return value.strip(), ""
	name, description = value.split(":", 1)
	return name.strip(), description.strip()


def has_triple_quote(text: str) -> bool:
	return (text.count('"""') + text.count("'''")) % 2 == 1


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
	return text.count("(") - text.count(")")


def brace_delta(text: str) -> int:
	return text.count("{") - text.count("}")


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
	return f"{api_class.owner}.{api_class.name}" if api_class.owner else api_class.name


def top_level_class_name(api_class: ApiClass) -> str:
	return api_class.owner.split(".", 1)[0] if api_class.owner else api_class.name


def flatten_api_classes(api_classes: list[ApiClass]) -> list[ApiClass]:
	result: list[ApiClass] = []
	for api_class in api_classes:
		result.append(api_class)
		result.extend(flatten_api_classes(api_class.inner_classes))
	return result
