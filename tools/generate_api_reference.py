#!/usr/bin/env python3
"""Generate GF API Catalog XML and MkDocs API Reference pages."""

from __future__ import annotations

import argparse
import hashlib
import json
import posixpath
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any
from urllib.parse import unquote

from generated_output_transaction import compare_generated_tree
from generated_output_transaction import lexical_absolute_path
from generated_output_transaction import replace_generated_trees
from generated_output_transaction import validate_controlled_path
from gdscript_api_parser import ApiClass
from gdscript_api_parser import ApiDocs
from gdscript_api_parser import ApiMember
from gdscript_api_parser import ApiScript
from gdscript_api_parser import PUBLIC_API_VISIBILITIES
from gdscript_api_parser import collect_api_scripts as parse_api_scripts
from gdscript_api_parser import first_tag
from gdscript_api_parser import flatten_api_classes
from gdscript_api_parser import full_api_class_name
from gdscript_api_parser import split_named_value
from gdscript_api_parser import top_level_class_name
from gdscript_api_parser import visibility_of
from gf_api_owners import ApiOwner
from gf_api_owners import OWNER_KIND_AUTOLOAD
from gf_api_owners import autoload_owners
from gf_api_owners import class_owners
from gf_api_owners import collect_api_owners as collect_resolved_api_owners


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG_ROOT = lexical_absolute_path(ROOT / "docs/api_catalog")
DEFAULT_REFERENCE_ROOT = lexical_absolute_path(ROOT / "docs/zh/reference/api")
CATALOG_VERSION = "3"
MODULE_LABELS = {
	"kernel": "Kernel",
	"standard": "Standard",
	"tools": "Tool Packages",
	"extensions/action_queue": "Action Queue",
	"extensions/asset_metadata": "Asset Metadata",
	"extensions/behavior_tree": "Behavior Tree",
	"extensions/camera": "Camera",
	"extensions/capability": "Capability",
	"extensions/combat": "Combat",
	"extensions/decision": "Decision",
	"extensions/dialogue": "Dialogue",
	"extensions/domain": "Domain",
	"extensions/feedback": "Feedback",
	"extensions/flow": "Flow",
	"extensions/interaction": "Interaction",
	"extensions/network": "Network",
	"extensions/physics": "Physics",
	"extensions/save": "Save",
	"extensions/turn_based": "Turn Based",
}
MEMBER_GROUPS = {
	"signals": "信号",
	"enums": "枚举",
	"constants": "常量",
	"properties": "属性",
	"methods": "方法",
}
CATEGORY_LABELS = {
	"domain_model": "领域模型",
	"editor_api": "编辑器 API",
	"event_contract": "事件契约",
	"protocol": "协议与扩展点",
	"resource_definition": "资源定义",
	"runtime_handle": "运行时句柄",
	"runtime_service": "运行时服务",
	"tool_api": "工具 API",
	"value_object": "值对象",
	"uncategorized": "未分类",
}
CATEGORY_ORDER = {
	"runtime_service": 0,
	"protocol": 1,
	"resource_definition": 2,
	"runtime_handle": 3,
	"value_object": 4,
	"domain_model": 5,
	"event_contract": 6,
	"editor_api": 7,
	"tool_api": 8,
	"uncategorized": 9,
}
MARKDOWN_LINK_PATTERN = re.compile(r"!?\[[^\]\n]*\]\(([^)\n]+)\)")
MARKDOWN_FENCE_PATTERN = re.compile(r"^ {0,3}(`{3,}|~{3,})")
EXPLICIT_ANCHOR_PATTERN = re.compile(r'<a\s+id="([^"]+)"\s*></a>')
def main(argv: list[str] | None = None) -> int:
	parser = argparse.ArgumentParser(description="Generate GF API Catalog XML and API Reference pages.")
	parser.add_argument("--source", default="addons/gf", help="GDScript source root.")
	parser.add_argument("--catalog", default="docs/api_catalog", help="Generated XML catalog directory.")
	parser.add_argument("--output", default="docs/zh/reference/api", help="Generated MkDocs Markdown directory.")
	parser.add_argument("--check", action="store_true", help="Fail if catalog or Markdown pages are stale.")
	parser.add_argument(
		"--allow-unsafe-output-root",
		action="store_true",
		help="Allow writing generated files outside the standard generated API roots.",
	)
	args = parser.parse_args(argv)

	source_root = (ROOT / args.source).resolve()
	catalog_root = lexical_absolute_path(ROOT / args.catalog)
	output_root = lexical_absolute_path(ROOT / args.output)
	if not source_root.exists():
		print(f"source root not found: {source_root}")
		return 2
	output_root_errors = validate_generated_output_root(catalog_root, DEFAULT_CATALOG_ROOT, args.allow_unsafe_output_root, "API Catalog")
	output_root_errors.extend(validate_generated_output_root(output_root, DEFAULT_REFERENCE_ROOT, args.allow_unsafe_output_root, "API Reference"))
	if output_root_errors:
		for error in output_root_errors:
			print(error, file=sys.stderr)
		return 2

	try:
		api_owners = collect_api_owner_model(source_root)
		api_classes = api_classes_from_owners(api_owners)
		api_autoloads = autoload_owners(api_owners)
		validate_api_model(api_classes)
		catalog_files = render_catalog_files(api_classes, source_root, api_autoloads)
		reference_files = render_reference_files(
			api_classes,
			catalog_files["index.xml"],
			api_autoloads,
		)
	except ValueError as error:
		print(f"API generation input is invalid: {error}", file=sys.stderr)
		return 2
	coverage_status = check_reference_coverage(
		api_classes,
		reference_files,
		report_success=args.check,
		api_autoloads=api_autoloads,
	)
	if args.check:
		return max(
			check_files(catalog_root, catalog_files, "API Catalog"),
			check_files(output_root, reference_files, "API Reference"),
			coverage_status,
		)
	if coverage_status:
		return coverage_status

	replace_generated_trees([
		(catalog_root, {
			relative: normalize_generated_text(content)
			for relative, content in catalog_files.items()
		}),
		(output_root, {
			relative: normalize_generated_text(content)
			for relative, content in reference_files.items()
		}),
	])
	all_classes = flatten_api_classes(api_classes)
	class_count = len(all_classes)
	method_count = sum(len(api_class.methods) for api_class in all_classes)
	print(
		"generated API Catalog: "
		f"{class_count} classes, {len(api_autoloads)} autoloads, "
		f"{method_count + sum(len(owner.script.methods) for owner in api_autoloads)} methods"
	)
	print(f"catalog: {catalog_root}")
	print(f"reference: {output_root}")
	return 0


def collect_api_classes(source_root: Path) -> list[ApiClass]:
	return api_classes_from_owners(collect_api_owner_model(source_root))


def collect_api_owner_model(source_root: Path) -> list[ApiOwner]:
	return collect_resolved_api_owners(source_root, ROOT)


def api_classes_from_owners(api_owners: list[ApiOwner]) -> list[ApiClass]:
	result: list[ApiClass] = []
	for owner in class_owners(api_owners):
		api_class = owner.to_api_class()
		if api_class is None:
			raise ValueError(f"class API owner has no class_name surface: {owner.name}")
		result.append(api_class)
	return result


def api_script_members(api_script: ApiScript) -> list[ApiMember]:
	return [
		*api_script.signals,
		*api_script.enums,
		*api_script.constants,
		*api_script.properties,
		*api_script.methods,
	]


def strip_internal_members(api_class: ApiClass) -> ApiClass:
	api_class.signals = filter_public_members(api_class.signals)
	api_class.enums = filter_public_members(api_class.enums)
	api_class.constants = filter_public_members(api_class.constants)
	api_class.properties = filter_public_members(api_class.properties)
	api_class.methods = filter_public_members(api_class.methods)
	api_class.inner_classes = [
		strip_internal_members(inner_class)
		for inner_class in api_class.inner_classes
		if visibility_of(inner_class.docs) in PUBLIC_API_VISIBILITIES
	]
	return api_class


def filter_public_members(members: list[ApiMember]) -> list[ApiMember]:
	return [
		member
		for member in members
		if visibility_of(member.docs) in PUBLIC_API_VISIBILITIES
	]


def render_catalog_files(
	api_classes: list[ApiClass],
	source_root: Path,
	api_autoloads: list[ApiOwner] | None = None,
) -> dict[str, str]:
	api_autoloads = api_autoloads or []
	validate_api_model(api_classes)
	validate_api_autoloads(api_classes, api_autoloads)
	owners_payload = [
		{"kind": "class", "api": api_class_to_digest_payload(api_class)}
		for api_class in api_classes
	]
	owners_payload.extend(autoload_to_digest_payload(owner) for owner in api_autoloads)
	source_digest = hash_api_payload(owners_payload)
	files: dict[str, str] = {
		"index.xml": render_catalog_index(
			api_classes,
			source_root,
			source_digest,
			api_autoloads,
		),
	}
	for api_class in api_classes:
		files[f"classes/{api_class.name}.xml"] = render_class_xml(api_class)
	for owner in api_autoloads:
		files[f"autoloads/{owner.name}.xml"] = render_autoload_xml(owner)
	return files


def render_catalog_index(
	api_classes: list[ApiClass],
	source_root: Path,
	source_digest: str,
	api_autoloads: list[ApiOwner] | None = None,
) -> str:
	api_autoloads = api_autoloads or []
	all_classes = flatten_api_classes(api_classes)
	root = ET.Element(
		"apiCatalog",
		{
			"schemaVersion": CATALOG_VERSION,
			"name": "GF Framework",
			"sourceRoot": source_root.relative_to(ROOT).as_posix(),
			"sourceDigest": source_digest,
			"classCount": str(len(all_classes)),
			"methodCount": str(sum(len(api_class.methods) for api_class in all_classes)),
			"autoloadCount": str(len(api_autoloads)),
			"autoloadMethodCount": str(sum(len(owner.script.methods) for owner in api_autoloads)),
		},
	)
	modules = {
		api_class.module for api_class in all_classes
	} | {
		owner.script.module for owner in api_autoloads
	}
	for module in sorted(modules, key=module_sort_key):
		module_classes = [api_class for api_class in all_classes if api_class.module == module]
		module_autoloads = [owner for owner in api_autoloads if owner.script.module == module]
		module_element = ET.SubElement(
			root,
			"module",
			{
				"id": module,
				"label": module_label(module),
				"classCount": str(len(module_classes)),
				"methodCount": str(sum(len(api_class.methods) for api_class in module_classes)),
				"autoloadCount": str(len(module_autoloads)),
				"autoloadMethodCount": str(sum(len(owner.script.methods) for owner in module_autoloads)),
			},
		)
		for api_class in sorted(module_classes, key=lambda item: full_api_class_name(item)):
			owner_path = f"classes/{top_level_class_name(api_class)}.xml"
			ET.SubElement(
				module_element,
				"class",
				{
					"name": full_api_class_name(api_class),
					"path": owner_path,
					"sourcePath": api_class.path,
					"extends": api_class.extends or "Object",
				},
			)
		for owner in sorted(module_autoloads, key=lambda item: item.name):
			ET.SubElement(
				module_element,
				"autoload",
				{
					"name": owner.name,
					"path": f"autoloads/{owner.name}.xml",
					"sourcePath": owner.script.path,
					"extends": owner.script.extends or "Node",
					"packageId": owner.package_id,
				},
			)
	return xml_to_text(root)


def render_class_xml(api_class: ApiClass) -> str:
	class_digest = hash_api_payload(api_class_to_digest_payload(api_class))
	root = ET.Element(
		"class",
		{
			"name": api_class.name,
			"path": api_class.path,
			"module": api_class.module,
			"extends": api_class.extends or "Object",
			"classDigest": class_digest,
		},
	)
	append_docs(root, api_class.docs)
	append_members(root, "signals", api_class.signals)
	append_members(root, "enums", api_class.enums)
	append_members(root, "constants", api_class.constants)
	append_members(root, "properties", api_class.properties)
	append_members(root, "methods", api_class.methods)
	append_inner_classes(root, api_class.inner_classes)
	return xml_to_text(root)


def render_autoload_xml(owner: ApiOwner) -> str:
	if owner.kind != OWNER_KIND_AUTOLOAD:
		raise ValueError(f"autoload XML requires an autoload owner: {owner.kind}:{owner.name}")
	digest = hash_api_payload(autoload_to_digest_payload(owner))
	root = ET.Element(
		"autoload",
		{
			"name": owner.name,
			"path": owner.script.path,
			"module": owner.script.module,
			"extends": owner.script.extends or "Node",
			"packageId": owner.package_id,
			"autoloadDigest": digest,
		},
	)
	append_docs(root, owner.script.docs)
	append_members(root, "signals", owner.script.signals)
	append_members(root, "enums", owner.script.enums)
	append_members(root, "constants", owner.script.constants)
	append_members(root, "properties", owner.script.properties)
	append_members(root, "methods", owner.script.methods)
	return xml_to_text(root)


def append_docs(parent: ET.Element, docs: ApiDocs) -> None:
	ET.SubElement(parent, "description").text = "\n".join(docs.description)
	tags_element = ET.SubElement(parent, "tags")
	for name in sorted(docs.tags):
		for value in docs.tags[name]:
			tag_element = ET.SubElement(tags_element, "tag", {"name": name})
			tag_element.text = value


def append_members(parent: ET.Element, group_name: str, members: list[ApiMember]) -> None:
	group = ET.SubElement(parent, group_name)
	for member in members:
		member_element = ET.SubElement(
			group,
			"member",
			{
				"kind": member.kind,
				"name": member.name,
			},
		)
		if member.decorators:
			member_element.set("decorators", " ".join(member.decorators))
		ET.SubElement(member_element, "signature").text = member.signature
		append_docs(member_element, member.docs)


def append_inner_classes(parent: ET.Element, inner_classes: list[ApiClass]) -> None:
	group = ET.SubElement(parent, "innerClasses")
	for inner_class in sorted(inner_classes, key=lambda item: full_api_class_name(item)):
		inner_element = ET.SubElement(
			group,
			"class",
			{
				"name": inner_class.name,
				"fullName": full_api_class_name(inner_class),
				"extends": inner_class.extends or "Object",
			},
		)
		append_docs(inner_element, inner_class.docs)
		append_members(inner_element, "signals", inner_class.signals)
		append_members(inner_element, "enums", inner_class.enums)
		append_members(inner_element, "constants", inner_class.constants)
		append_members(inner_element, "properties", inner_class.properties)
		append_members(inner_element, "methods", inner_class.methods)


def render_reference_files(
	api_classes: list[ApiClass],
	catalog_index_xml: str,
	api_autoloads: list[ApiOwner] | None = None,
) -> dict[str, str]:
	api_autoloads = api_autoloads or []
	validate_api_model(api_classes)
	validate_api_autoloads(api_classes, api_autoloads)
	catalog_root = ET.fromstring(catalog_index_xml)
	files: dict[str, str] = {
		"index.md": render_reference_index(api_classes, catalog_root, api_autoloads),
		"classes/index.md": render_reference_class_index(api_classes),
	}
	if api_autoloads:
		files["autoloads/index.md"] = render_reference_autoload_index(api_autoloads)
	modules = {
		api_class.module for api_class in api_classes
	} | {
		owner.script.module for owner in api_autoloads
	}
	for module in sorted(modules, key=module_sort_key):
		module_classes = [api_class for api_class in api_classes if api_class.module == module]
		module_autoloads = [owner for owner in api_autoloads if owner.script.module == module]
		files[f"{module_slug(module)}.md"] = render_reference_module(
			module,
			module_classes,
			module_autoloads,
		)
	for api_class in sorted(api_classes, key=lambda item: item.name):
		files[f"classes/{api_class.name}.md"] = render_reference_class_page(api_class)
	for owner in sorted(api_autoloads, key=lambda item: item.name):
		files[f"autoloads/{owner.name}.md"] = render_reference_autoload_page(owner)
	return files


def render_reference_index(
	api_classes: list[ApiClass],
	catalog_root: ET.Element,
	api_autoloads: list[ApiOwner] | None = None,
) -> str:
	api_autoloads = api_autoloads or []
	all_classes = flatten_api_classes(api_classes)
	lines = [
		"# API Reference",
		"",
		"本区由源码 API 注释生成，覆盖可寻址的 `class_name` 与受控 AutoLoad owner、成员签名和机器标签。正文指南负责解释概念、边界和工作流；这里负责精确检索。",
		"",
		"## 范围",
		"",
		f"- 源码根目录：`{catalog_root.get('sourceRoot', '')}`",
		f"- 公开类：`{catalog_root.get('classCount', '0')}`",
		f"- 公开 AutoLoad：`{catalog_root.get('autoloadCount', '0')}`",
		f"- 公开成员：`{count_public_members(all_classes) + sum(public_autoload_member_count(owner) for owner in api_autoloads)}`",
		f"- 公开方法：`{catalog_root.get('methodCount', '0')}`",
		f"- AutoLoad 公开方法：`{catalog_root.get('autoloadMethodCount', '0')}`",
		"",
		"## 模块",
		"",
		"| 模块 | 类 | AutoLoad | 成员 | 方法 | 页面 |",
		"|---|---:|---:|---:|---:|---|",
	]
	modules = {
		api_class.module for api_class in all_classes
	} | {
		owner.script.module for owner in api_autoloads
	}
	for module in sorted(modules, key=module_sort_key):
		module_classes = [api_class for api_class in all_classes if api_class.module == module]
		module_autoloads = [owner for owner in api_autoloads if owner.script.module == module]
		class_count = len(module_classes)
		member_count = count_public_members(module_classes) + sum(
			public_autoload_member_count(owner) for owner in module_autoloads
		)
		method_count = sum(len(api_class.methods) for api_class in module_classes) + sum(
			len(owner.script.methods) for owner in module_autoloads
		)
		page = f"{module_slug(module)}.md"
		lines.append(
			f"| {module_label(module)} | {class_count} | {len(module_autoloads)} "
			f"| {member_count} | {method_count} | [{page}]({page}) |"
		)
	lines.extend([
		"",
		"## Owner 索引",
		"",
		"完整类索引位于 [classes/index.md](classes/index.md)；受控 AutoLoad 索引位于 [autoloads/index.md](autoloads/index.md)。",
	])
	return "\n".join(lines) + "\n"


def render_reference_module(
	module: str,
	api_classes: list[ApiClass],
	api_autoloads: list[ApiOwner] | None = None,
) -> str:
	api_autoloads = api_autoloads or []
	module_all_classes = flatten_api_classes(api_classes)
	lines = [
		f"# {module_label(module)} API",
		"",
		f"模块：`{module}`",
		"",
	]
	if api_autoloads:
		lines.extend([
			"## AutoLoad",
			"",
			"| AutoLoad | 继承 | 包 | 成员 | 源文件 |",
			"|---|---|---|---:|---|",
		])
		for owner in sorted(api_autoloads, key=lambda item: item.name):
			lines.append(
				f"| [`{owner.name}`](autoloads/{owner.name}.md) "
				f"| `{owner.script.extends or 'Node'}` | `{owner.package_id}` "
				f"| {public_autoload_member_count(owner)} | `{owner.script.path}` |"
			)
		lines.append("")
	lines.extend([
		"## 类别概览",
		"",
		"| 类别 | 类 | 成员 | 方法 |",
		"|---|---:|---:|---:|",
	])
	for category in sorted_categories(module_all_classes):
		category_classes = classes_in_category(module_all_classes, category)
		member_count = count_public_members(category_classes)
		method_count = sum(len(api_class.methods) for api_class in category_classes)
		lines.append(
			f"| [{category_label(category)}](#category-{stable_anchor_part(category)}) "
			f"| {len(category_classes)} | {member_count} | {method_count} |"
		)

	lines.extend(["", "## 类", ""])
	for category in sorted_categories(module_all_classes):
		category_classes = classes_in_category(module_all_classes, category)
		lines.extend([
			f'<a id="category-{stable_anchor_part(category)}"></a>',
			"",
			f"### {category_label(category)}",
			"",
			"| 类 | 继承 | 源文件 |",
			"|---|---|---|",
		])
		for api_class in sorted(category_classes, key=lambda item: full_api_class_name(item)):
			lines.append(
				f"| [`{full_api_class_name(api_class)}`]({class_reference_link(api_class)}) "
				f"| `{api_class.extends or 'Object'}` | `{api_class.path}` |"
			)
		lines.append("")
	return "\n".join(lines).rstrip() + "\n"


def render_reference_autoload_index(api_autoloads: list[ApiOwner]) -> str:
	lines = [
		"# API AutoLoad 索引",
		"",
		"由 GF 注册并具有显式生成身份的公开 AutoLoad owner。项目自定义 AutoLoad 不属于本索引。",
		"",
		"| AutoLoad | 模块 | 包 | 继承 | 成员 | 源文件 |",
		"|---|---|---|---|---:|---|",
	]
	for owner in sorted(api_autoloads, key=lambda item: (item.script.module, item.name)):
		lines.append(
			f"| [`{owner.name}`]({owner.name}.md) | {module_label(owner.script.module)} "
			f"| `{owner.package_id}` | `{owner.script.extends or 'Node'}` "
			f"| {public_autoload_member_count(owner)} | `{owner.script.path}` |"
		)
	return "\n".join(lines) + "\n"


def render_reference_autoload_page(owner: ApiOwner) -> str:
	lines = [
		f"# {owner.name}",
		"",
		f"[API Reference](../index.md) / [{module_label(owner.script.module)}](../{module_slug(owner.script.module)}.md) / [AutoLoad 索引](index.md)",
		"",
		"- Owner 类型：`autoload`",
		f"- 路径：`{owner.script.path}`",
		f"- 模块：`{module_label(owner.script.module)}`",
		f"- 包：`{owner.package_id}`",
		f"- 继承：`{owner.script.extends or 'Node'}`",
	]
	append_tag_line(lines, "API", visibility_of(owner.script.docs))
	append_tag_line(lines, "类别", category_display(first_tag(owner.script.docs, "category")), code=False)
	append_tag_line(lines, "首次版本", first_tag(owner.script.docs, "since"))
	append_tag_line(lines, "弃用", "; ".join(owner.script.docs.tags.get("deprecated", [])))
	lines.append("")
	append_description(lines, autoload_description(owner))
	append_autoload_member_summary_markdown(lines, owner, 2)
	for group_name, members in autoload_member_groups(owner):
		append_member_group_markdown(
			lines,
			group_name,
			members,
			group_level=2,
			member_level=3,
			anchor_owner_name=owner.name,
		)
	return "\n".join(lines).rstrip() + "\n"


def sorted_categories(api_classes: list[ApiClass]) -> list[str]:
	categories = {category_of(api_class) for api_class in api_classes}
	return sorted(categories, key=category_sort_key)


def classes_in_category(api_classes: list[ApiClass], category: str) -> list[ApiClass]:
	return [
		api_class
		for api_class in api_classes
		if category_of(api_class) == category
	]


def count_public_members(api_classes: list[ApiClass]) -> int:
	return sum(public_member_count(api_class) for api_class in api_classes)


def public_member_count(api_class: ApiClass) -> int:
	return sum(len(members) for _, members in api_class_member_groups(api_class))


def public_autoload_member_count(owner: ApiOwner) -> int:
	return sum(len(members) for _, members in autoload_member_groups(owner))


def category_of(api_class: ApiClass) -> str:
	return first_tag(api_class.docs, "category") or "uncategorized"


def category_label(category: str) -> str:
	return CATEGORY_LABELS.get(category, category.replace("_", " ").title())


def category_display(category: str | None) -> str:
	if not category:
		return "-"
	return f"{category_label(category)} (`{category}`)"


def category_sort_key(category: str) -> tuple[int, str]:
	return (CATEGORY_ORDER.get(category, 99), category)


def render_reference_class_index(api_classes: list[ApiClass]) -> str:
	all_classes = flatten_api_classes(api_classes)
	lines = [
		"# API 类索引",
		"",
		"公开 API 的单类页面索引。顶层类拥有独立页面；内部类归入所属顶层类页面。",
		"",
		"## 模块概览",
		"",
		"| 模块 | 类 | 成员 | 页面内索引 |",
		"|---|---:|---:|---|",
	]
	for module in sorted({api_class.module for api_class in all_classes}, key=module_sort_key):
		module_classes = [api_class for api_class in all_classes if api_class.module == module]
		lines.append(
			f"| {module_label(module)} | {len(module_classes)} | {count_public_members(module_classes)} "
			f"| [{module_label(module)}](#module-{stable_anchor_part(module)}) |"
		)

	lines.extend(["", "## 模块索引", ""])
	for module in sorted({api_class.module for api_class in all_classes}, key=module_sort_key):
		module_classes = [api_class for api_class in all_classes if api_class.module == module]
		lines.extend([
			f'<a id="module-{stable_anchor_part(module)}"></a>',
			"",
			f"### {module_label(module)}",
			"",
			"| 类 | 类别 | 继承 | 成员 | 源文件 |",
			"|---|---|---|---:|---|",
		])
		for api_class in sorted(module_classes, key=class_index_sort_key):
			lines.append(
				f"| [`{full_api_class_name(api_class)}`]({class_reference_link(api_class, from_classes_dir=True)}) "
				f"| {category_display(first_tag(api_class.docs, 'category'))} "
				f"| `{api_class.extends or 'Object'}` | {public_member_count(api_class)} | `{api_class.path}` |"
			)
		lines.append("")
	return "\n".join(lines).rstrip() + "\n"


def class_index_sort_key(api_class: ApiClass) -> tuple[tuple[int, str], str]:
	return (category_sort_key(category_of(api_class)), full_api_class_name(api_class))


def render_reference_class_page(api_class: ApiClass) -> str:
	lines: list[str] = []
	append_api_class_markdown(lines, api_class, heading_level=1, include_inner_classes=True)
	lines.append("")
	return "\n".join(lines) + "\n"


def append_api_class_markdown(
	lines: list[str],
	api_class: ApiClass,
	heading_level: int = 2,
	include_inner_classes: bool = True,
) -> None:
	lines.extend([
		f"{'#' * heading_level} {full_api_class_name(api_class)}",
		"",
	])
	if heading_level == 1:
		append_class_navigation(lines, api_class)
	lines.extend([
		f"- 路径：`{api_class.path}`",
		f"- 模块：`{module_label(api_class.module)}`",
		f"- 继承：`{api_class.extends or 'Object'}`",
	])
	append_tag_line(lines, "API", visibility_of(api_class.docs))
	append_tag_line(lines, "类别", category_display(first_tag(api_class.docs, "category")), code=False)
	append_tag_line(lines, "首次版本", first_tag(api_class.docs, "since"))
	append_tag_line(lines, "弃用", "; ".join(api_class.docs.tags.get("deprecated", [])))
	lines.append("")
	append_description(lines, class_description(api_class))
	append_member_summary_markdown(lines, api_class, summary_level=heading_level + 1)
	append_member_group_markdown(
		lines,
		"signals",
		api_class.signals,
		group_level=heading_level + 1,
		member_level=heading_level + 2,
		anchor_owner=api_class,
	)
	append_member_group_markdown(
		lines,
		"enums",
		api_class.enums,
		group_level=heading_level + 1,
		member_level=heading_level + 2,
		anchor_owner=api_class,
	)
	append_member_group_markdown(
		lines,
		"constants",
		api_class.constants,
		group_level=heading_level + 1,
		member_level=heading_level + 2,
		anchor_owner=api_class,
	)
	append_member_group_markdown(
		lines,
		"properties",
		api_class.properties,
		group_level=heading_level + 1,
		member_level=heading_level + 2,
		anchor_owner=api_class,
	)
	append_member_group_markdown(
		lines,
		"methods",
		api_class.methods,
		group_level=heading_level + 1,
		member_level=heading_level + 2,
		anchor_owner=api_class,
	)
	if include_inner_classes:
		append_inner_classes_markdown(lines, api_class, heading_level=heading_level + 1)


def append_class_navigation(lines: list[str], api_class: ApiClass) -> None:
	module_page = f"../{module_slug(api_class.module)}.md"
	lines.extend([
		f"[API Reference](../index.md) / [{module_label(api_class.module)}]({module_page}) / [类索引](index.md)",
		"",
	])


def append_member_summary_markdown(lines: list[str], api_class: ApiClass, summary_level: int) -> None:
	members_by_group = api_class_member_groups(api_class)
	if not any(members for _, members in members_by_group):
		lines.extend([
			f"{'#' * summary_level} 成员概览",
			"",
			"此类不声明额外公开成员。",
			"",
		])
		return

	lines.extend([
		f"{'#' * summary_level} 成员概览",
		"",
		"| 类型 | 名称 | 签名 |",
		"|---|---|---|",
	])
	for group_name, members in members_by_group:
		for member in members:
			lines.append(
				f"| {MEMBER_GROUPS[group_name]} "
				f"| [{markdown_inline_code(member.name)}](#{member_anchor_id(api_class, group_name, member)}) "
				f"| {markdown_inline_code(member_summary_signature(member))} |"
			)
	lines.append("")


def append_autoload_member_summary_markdown(
	lines: list[str],
	owner: ApiOwner,
	summary_level: int,
) -> None:
	members_by_group = autoload_member_groups(owner)
	if not any(members for _, members in members_by_group):
		lines.extend([
			f"{'#' * summary_level} 成员概览",
			"",
			"此 AutoLoad 不声明额外公开成员。",
			"",
		])
		return

	lines.extend([
		f"{'#' * summary_level} 成员概览",
		"",
		"| 类型 | 名称 | 签名 |",
		"|---|---|---|",
	])
	for group_name, members in members_by_group:
		for member in members:
			lines.append(
				f"| {MEMBER_GROUPS[group_name]} "
				f"| [{markdown_inline_code(member.name)}]"
				f"(#{member_anchor_id_from_name(owner.name, group_name, member)}) "
				f"| {markdown_inline_code(member_summary_signature(member))} |"
			)
	lines.append("")


def append_inner_classes_markdown(lines: list[str], api_class: ApiClass, heading_level: int = 3) -> None:
	if not api_class.inner_classes:
		return
	class_heading_level = heading_level + 1
	member_group_level = class_heading_level + 1
	member_level = class_heading_level + 2
	sorted_inner_classes = sorted(api_class.inner_classes, key=lambda item: full_api_class_name(item))
	lines.extend([
		f"{'#' * heading_level} 内部类概览",
		"",
		"| 内部类 | 类别 | 继承 | 成员 |",
		"|---|---|---|---:|",
	])
	for inner_class in sorted_inner_classes:
		lines.append(
			f"| [`{full_api_class_name(inner_class)}`](#{anchor_for(full_api_class_name(inner_class))}) "
			f"| {category_display(first_tag(inner_class.docs, 'category'))} "
			f"| `{inner_class.extends or 'Object'}` | {public_member_count(inner_class)} |"
		)
	lines.extend(["", f"{'#' * heading_level} 内部类详情", ""])
	for inner_class in sorted_inner_classes:
		lines.extend([
			f"{'#' * class_heading_level} {full_api_class_name(inner_class)}",
			"",
			f"- 路径：`{inner_class.path}`",
			f"- 模块：`{module_label(inner_class.module)}`",
			f"- 继承：`{inner_class.extends or 'Object'}`",
		])
		append_tag_line(lines, "API", visibility_of(inner_class.docs))
		append_tag_line(lines, "类别", category_display(first_tag(inner_class.docs, "category")), code=False)
		append_tag_line(lines, "首次版本", first_tag(inner_class.docs, "since"))
		append_tag_line(lines, "弃用", "; ".join(inner_class.docs.tags.get("deprecated", [])))
		lines.append("")
		append_description(lines, class_description(inner_class))
		append_member_summary_markdown(lines, inner_class, summary_level=member_group_level)
		append_member_group_markdown(
			lines,
			"signals",
			inner_class.signals,
			group_level=member_group_level,
			member_level=member_level,
			anchor_owner=inner_class,
		)
		append_member_group_markdown(
			lines,
			"enums",
			inner_class.enums,
			group_level=member_group_level,
			member_level=member_level,
			anchor_owner=inner_class,
		)
		append_member_group_markdown(
			lines,
			"constants",
			inner_class.constants,
			group_level=member_group_level,
			member_level=member_level,
			anchor_owner=inner_class,
		)
		append_member_group_markdown(
			lines,
			"properties",
			inner_class.properties,
			group_level=member_group_level,
			member_level=member_level,
			anchor_owner=inner_class,
		)
		append_member_group_markdown(
			lines,
			"methods",
			inner_class.methods,
			group_level=member_group_level,
			member_level=member_level,
			anchor_owner=inner_class,
		)


def append_member_group_markdown(
	lines: list[str],
	group_name: str,
	members: list[ApiMember],
	group_level: int = 3,
	member_level: int = 4,
	anchor_owner: ApiClass | None = None,
	anchor_owner_name: str = "",
) -> None:
	if not members:
		return
	lines.extend([f"{'#' * group_level} {MEMBER_GROUPS[group_name]}", ""])
	for member in members:
		if anchor_owner != None:
			lines.extend([f'<a id="{member_anchor_id(anchor_owner, group_name, member)}"></a>', ""])
		elif anchor_owner_name:
			lines.extend([
				f'<a id="{member_anchor_id_from_name(anchor_owner_name, group_name, member)}"></a>',
				"",
			])
		lines.extend([f"{'#' * member_level} `{member.name}`", ""])
		append_tag_line(lines, "API", visibility_of(member.docs))
		append_tag_line(lines, "首次版本", first_tag(member.docs, "since"))
		append_tag_line(lines, "弃用", "; ".join(member.docs.tags.get("deprecated", [])))
		lines.append("")
		fence = markdown_code_fence(member.signature)
		lines.extend([f"{fence}gdscript", member.signature, fence, ""])
		append_description(lines, member.docs.description)
		append_params(lines, member.docs)
		append_return(lines, member.docs)
		append_schemas(lines, member.docs)


def append_description(lines: list[str], description: list[str]) -> None:
	if description:
		lines.append(" ".join(description))
		lines.append("")


def class_description(api_class: ApiClass) -> list[str]:
	description = api_class.docs.description[:]
	if not description:
		return description

	for name in [full_api_class_name(api_class), api_class.name]:
		prefix = f"{name}:"
		if description[0].startswith(prefix):
			description[0] = description[0][len(prefix):].strip()
			if description[0] == "":
				description = description[1:]
			break
	return description


def autoload_description(owner: ApiOwner) -> list[str]:
	description = owner.script.docs.description[:]
	if description:
		prefix = f"{owner.name}:"
		if description[0].startswith(prefix):
			description[0] = description[0][len(prefix):].strip()
			if not description[0]:
				description = description[1:]
	return description


def append_params(lines: list[str], docs: ApiDocs) -> None:
	params = docs.tags.get("param", [])
	if not params:
		return
	lines.extend(["参数：", "", "| 名称 | 说明 |", "|---|---|"])
	for param in params:
		name, description = split_named_value(param)
		lines.append(
			f"| {markdown_inline_code(name)} | {markdown_table_cell(description)} |"
		)
	lines.append("")


def append_return(lines: list[str], docs: ApiDocs) -> None:
	returns = docs.tags.get("return", [])
	if returns:
		lines.append(f"返回：{' '.join(returns)}")
		lines.append("")


def append_schemas(lines: list[str], docs: ApiDocs) -> None:
	schemas = docs.tags.get("schema", [])
	if not schemas:
		return
	lines.extend(["结构：", ""])
	for schema in schemas:
		name, description = split_named_value(schema)
		lines.append(f"- {markdown_inline_code(name)}: {description}")
	lines.append("")


def append_tag_line(lines: list[str], label: str, value: str, code: bool = True) -> None:
	if value:
		formatted_value = markdown_inline_code(value) if code else value
		lines.append(f"- {label}：{formatted_value}")


def module_label(module: str) -> str:
	return MODULE_LABELS.get(module, module.replace("/", " / ").replace("_", " ").title())


def module_slug(module: str) -> str:
	return module.replace("/", "-").replace("_", "-")


def class_reference_link(api_class: ApiClass, from_classes_dir: bool = False) -> str:
	page = f"{top_level_class_name(api_class)}.md" if from_classes_dir else class_page_path(api_class)
	return f"{page}#{anchor_for(full_api_class_name(api_class))}"


def class_page_path(api_class: ApiClass) -> str:
	return f"classes/{top_level_class_name(api_class)}.md"


def api_class_member_groups(api_class: ApiClass) -> list[tuple[str, list[ApiMember]]]:
	return [
		("signals", api_class.signals),
		("enums", api_class.enums),
		("constants", api_class.constants),
		("properties", api_class.properties),
		("methods", api_class.methods),
	]


def autoload_member_groups(owner: ApiOwner) -> list[tuple[str, list[ApiMember]]]:
	return [
		("signals", owner.script.signals),
		("enums", owner.script.enums),
		("constants", owner.script.constants),
		("properties", owner.script.properties),
		("methods", owner.script.methods),
	]


def member_summary_signature(member: ApiMember) -> str:
	if member.kind == "enum":
		return f"enum {member.name}"
	return member.signature


def member_anchor_id(api_class: ApiClass, group_name: str, member: ApiMember) -> str:
	return member_anchor_id_from_name(full_api_class_name(api_class), group_name, member)


def member_anchor_id_from_name(owner_name: str, group_name: str, member: ApiMember) -> str:
	return (
		"member-"
		+ stable_anchor_part(owner_name)
		+ "-"
		+ stable_anchor_part(group_name)
		+ "-"
		+ stable_anchor_part(member.name)
	)


def stable_anchor_part(value: str) -> str:
	normalized = re.sub(r"[^a-z0-9_-]+", "-", value.lower())
	normalized = re.sub(r"-+", "-", normalized).strip("-")
	return normalized or "item"


def markdown_table_cell(value: str) -> str:
	return value.replace("\n", " ").replace("|", "\\|").replace("`", "\\`")


def markdown_inline_code(value: str) -> str:
	table_safe_value = value.replace("\n", " ").replace("|", "\\|")
	longest_run = max(
		(len(match.group(0)) for match in re.finditer(r"`+", table_safe_value)),
		default=0,
	)
	delimiter = "`" * max(1, longest_run + 1)
	if longest_run:
		return f"{delimiter} {table_safe_value} {delimiter}"
	return f"{delimiter}{table_safe_value}{delimiter}"


def markdown_code_fence(value: str) -> str:
	longest_run = max((len(match.group(0)) for match in re.finditer(r"`+", value)), default=0)
	return "`" * max(3, longest_run + 1)


def module_sort_key(module: str) -> tuple[int, str]:
	if module == "kernel":
		return (0, module)
	if module == "standard":
		return (1, module)
	return (2, module)


def anchor_for(title: str) -> str:
	return title.lower().replace("_", "-").replace(".", "")


def validate_api_model(api_classes: list[ApiClass]) -> None:
	"""Reject owner/path/anchor identities that cannot be rendered uniquely."""
	top_level_pages: dict[str, str] = {}
	for api_class in api_classes:
		page = f"classes/{api_class.name}.md"
		identity = portable_identity(page)
		previous = top_level_pages.get(identity)
		if previous is not None:
			if previous == page:
				raise ValueError(f"duplicate API owner output page: {page}")
			raise ValueError(
				"API owner output page portable identity collision: "
				f"{previous} and {page}"
			)
		top_level_pages[identity] = page

	owner_identities: dict[str, str] = {}
	anchors_by_page: dict[tuple[str, str], str] = {}
	for api_class in flatten_api_classes(api_classes):
		full_name = full_api_class_name(api_class)
		identity = portable_identity(full_name)
		previous_owner = owner_identities.get(identity)
		if previous_owner is not None:
			if previous_owner == full_name:
				raise ValueError(f"duplicate API owner: {full_name}")
			raise ValueError(
				"API owner portable identity collision: "
				f"{previous_owner} and {full_name}"
			)
		owner_identities[identity] = full_name

		page = class_page_path(api_class)
		owner_anchor = anchor_for(full_name)
		_register_render_anchor(anchors_by_page, page, owner_anchor, f"owner {full_name}")
		for group_name, members in api_class_member_groups(api_class):
			for member in members:
				_register_render_anchor(
					anchors_by_page,
					page,
					member_anchor_id(api_class, group_name, member),
					f"member {full_name}.{member.name}",
				)


def validate_api_autoloads(
	api_classes: list[ApiClass],
	api_autoloads: list[ApiOwner],
) -> None:
	"""Reject AutoLoad identities that cannot coexist with class API owners."""
	owner_identities = {
		portable_identity(full_api_class_name(api_class)): f"class:{full_api_class_name(api_class)}"
		for api_class in flatten_api_classes(api_classes)
	}
	page_identities: dict[str, str] = {}
	anchors_by_page: dict[tuple[str, str], str] = {}
	for owner in api_autoloads:
		if owner.kind != OWNER_KIND_AUTOLOAD:
			raise ValueError(
				f"autoload collection contains a non-autoload owner: {owner.kind}:{owner.name}"
			)
		if not owner.name or not re.fullmatch(r"[A-Za-z_]\w*", owner.name):
			raise ValueError(f"autoload API owner name is invalid: {owner.name!r}")
		if owner.script.class_name:
			raise ValueError(f"autoload API owner cannot declare class_name: {owner.name}")
		if owner.script.api_owner_kind != OWNER_KIND_AUTOLOAD or owner.script.api_owner_name != owner.name:
			raise ValueError(f"autoload API owner declaration drifted: {owner.name}")
		if not owner.package_id:
			raise ValueError(f"autoload API owner has no package identity: {owner.name}")
		identity = portable_identity(owner.name)
		previous = owner_identities.get(identity)
		if previous is not None:
			raise ValueError(
				"API owner portable identity collision across owner kinds: "
				f"{previous} and autoload:{owner.name}"
			)
		owner_identities[identity] = f"autoload:{owner.name}"

		page = f"autoloads/{owner.name}.md"
		page_identity = portable_identity(page)
		previous_page = page_identities.get(page_identity)
		if previous_page is not None:
			raise ValueError(
				"autoload API owner output page portable identity collision: "
				f"{previous_page} and {page}"
			)
		page_identities[page_identity] = page
		_register_render_anchor(anchors_by_page, page, anchor_for(owner.name), f"autoload {owner.name}")
		for group_name, members in autoload_member_groups(owner):
			for member in members:
				_register_render_anchor(
					anchors_by_page,
					page,
					member_anchor_id_from_name(owner.name, group_name, member),
					f"member {owner.name}.{member.name}",
				)


def _register_render_anchor(
	anchors_by_page: dict[tuple[str, str], str],
	page: str,
	anchor: str,
	label: str,
) -> None:
	key = (portable_identity(page), portable_identity(anchor))
	previous = anchors_by_page.get(key)
	if previous is not None:
		raise ValueError(
			f"API anchor portable identity collision in {page}: {previous} and {label}"
		)
	anchors_by_page[key] = label


def portable_identity(value: str) -> str:
	return unicodedata.normalize("NFC", value).casefold()


def api_class_to_digest_payload(api_class: ApiClass) -> dict[str, Any]:
	return {
		"name": api_class.name,
		"path": api_class.path,
		"module": api_class.module,
		"extends": api_class.extends,
		"owner": api_class.owner,
		"docs": docs_to_payload(api_class.docs),
		"signals": [member_to_payload(member) for member in api_class.signals],
		"enums": [member_to_payload(member) for member in api_class.enums],
		"constants": [member_to_payload(member) for member in api_class.constants],
		"properties": [member_to_payload(member) for member in api_class.properties],
		"methods": [member_to_payload(member) for member in api_class.methods],
		"inner_classes": [api_class_to_digest_payload(inner_class) for inner_class in api_class.inner_classes],
	}


def autoload_to_digest_payload(owner: ApiOwner) -> dict[str, Any]:
	return {
		"kind": OWNER_KIND_AUTOLOAD,
		"name": owner.name,
		"path": owner.script.path,
		"module": owner.script.module,
		"extends": owner.script.extends,
		"package_id": owner.package_id,
		"docs": docs_to_payload(owner.script.docs),
		"signals": [member_to_payload(member) for member in owner.script.signals],
		"enums": [member_to_payload(member) for member in owner.script.enums],
		"constants": [member_to_payload(member) for member in owner.script.constants],
		"properties": [member_to_payload(member) for member in owner.script.properties],
		"methods": [member_to_payload(member) for member in owner.script.methods],
	}


def hash_api_payload(payload: Any) -> str:
	return hashlib.sha256(
		json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
	).hexdigest()


def member_to_payload(member: ApiMember) -> dict[str, Any]:
	return {
		"kind": member.kind,
		"name": member.name,
		"signature": member.signature,
		"docs": docs_to_payload(member.docs),
		"decorators": member.decorators,
	}


def docs_to_payload(docs: ApiDocs) -> dict[str, Any]:
	return {
		"description": docs.description,
		"tags": docs.tags,
	}


def xml_to_text(element: ET.Element) -> str:
	ET.indent(element, space="\t")
	return '<?xml version="1.0" encoding="utf-8"?>\n' + ET.tostring(element, encoding="unicode") + "\n"


def normalize_generated_text(content: str) -> str:
	normalized = content.replace("\r\n", "\n").replace("\r", "\n")
	lines = [line.rstrip() for line in normalized.split("\n")]
	while lines and lines[-1] == "":
		lines.pop()
	return "\n".join(lines) + "\n"


def validate_generated_output_root(root: Path, expected_root: Path, allow_unsafe: bool, label: str) -> list[str]:
	if not allow_unsafe and root != expected_root:
		return [
			f"{label} output root is not a standard generated directory: {root}. "
			f"Expected {expected_root}; pass --allow-unsafe-output-root only for an intentional temporary output root."
		]
	containment_root = root.parent if allow_unsafe else ROOT
	try:
		validate_controlled_path(root, containment_root)
	except ValueError as error:
		return [f"{label} output root is unsafe: {error}"]
	return []


def check_files(root: Path, desired: dict[str, str], label: str) -> int:
	mismatches = compare_generated_tree(root, desired, normalize_generated_text)
	if not mismatches:
		print(f"{label} is current.")
		return 0
	print(f"{label} is stale:")
	for mismatch in mismatches:
		print(f"- {mismatch}")
	return 1


def check_reference_coverage(
	api_classes: list[ApiClass],
	reference_files: dict[str, str],
	report_success: bool = True,
	api_autoloads: list[ApiOwner] | None = None,
) -> int:
	api_autoloads = api_autoloads or []
	errors = validate_generated_reference_links(reference_files)
	class_count = 0
	autoload_count = 0
	member_count = 0
	for api_class in sorted(api_classes, key=lambda item: full_api_class_name(item)):
		class_errors, class_members = check_class_reference_coverage(api_class, reference_files, 1)
		errors.extend(class_errors)
		class_count += 1
		member_count += class_members
		for inner_class in sorted(api_class.inner_classes, key=lambda item: full_api_class_name(item)):
			inner_errors, inner_members = check_class_reference_coverage(inner_class, reference_files, 3)
			errors.extend(inner_errors)
			class_count += 1
			member_count += inner_members
	for owner in sorted(api_autoloads, key=lambda item: item.name):
		autoload_errors, autoload_members = check_autoload_reference_coverage(
			owner,
			reference_files,
		)
		errors.extend(autoload_errors)
		autoload_count += 1
		member_count += autoload_members

	if errors:
		print("API Reference coverage is incomplete:")
		for error in errors:
			print(f"- {error}")
		return 1

	if report_success:
		print(
			"API Reference coverage is complete: "
			f"{class_count} classes, {autoload_count} autoloads, {member_count} members."
		)
	return 0


def check_class_reference_coverage(
	api_class: ApiClass,
	reference_files: dict[str, str],
	class_heading_level: int,
) -> tuple[list[str], int]:
	errors: list[str] = []
	file_name = class_page_path(api_class)
	text = reference_files.get(file_name)
	full_name = full_api_class_name(api_class)
	if text == None:
		return [f"{full_name}: missing class reference page {file_name}"], 0

	section = find_heading_section(text, class_heading_level, full_name)
	if section == None:
		return [f"{full_name}: missing class heading in {file_name}"], 0

	members = api_class_members(api_class)
	for member in members:
		anchor_line = f'<a id="{member_anchor_id(api_class, member_group_name(member), member)}"></a>'
		anchor_count = sum(line == anchor_line for line in section.splitlines())
		if anchor_count == 0:
			errors.append(f"{full_name}.{member.name}: missing owner-qualified member anchor in {file_name}")
			continue
		if anchor_count > 1:
			errors.append(f"{full_name}.{member.name}: duplicate owner-qualified member anchor in {file_name}")
			continue
		member_section = find_explicit_anchor_section(section, anchor_line)
		member_heading = f"{'#' * (class_heading_level + 2)} `{member.name}`"
		if not has_markdown_line(member_section, member_heading):
			errors.append(f"{full_name}.{member.name}: missing member heading in {file_name}")
			continue
		if member.signature not in member_section:
			errors.append(f"{full_name}.{member.name}: missing signature in {file_name}")

	return errors, len(members)


def check_autoload_reference_coverage(
	owner: ApiOwner,
	reference_files: dict[str, str],
) -> tuple[list[str], int]:
	errors: list[str] = []
	file_name = f"autoloads/{owner.name}.md"
	text = reference_files.get(file_name)
	if text is None:
		return [f"{owner.name}: missing autoload reference page {file_name}"], 0

	section = find_heading_section(text, 1, owner.name)
	if section is None:
		return [f"{owner.name}: missing autoload heading in {file_name}"], 0

	members = api_script_members(owner.script)
	for member in members:
		anchor_line = (
			f'<a id="{member_anchor_id_from_name(owner.name, member_group_name(member), member)}"></a>'
		)
		anchor_count = sum(line == anchor_line for line in section.splitlines())
		if anchor_count == 0:
			errors.append(
				f"{owner.name}.{member.name}: missing owner-qualified member anchor in {file_name}"
			)
			continue
		if anchor_count > 1:
			errors.append(
				f"{owner.name}.{member.name}: duplicate owner-qualified member anchor in {file_name}"
			)
			continue
		member_section = find_explicit_anchor_section(section, anchor_line)
		member_heading = f"### `{member.name}`"
		if not has_markdown_line(member_section, member_heading):
			errors.append(f"{owner.name}.{member.name}: missing member heading in {file_name}")
			continue
		if member.signature not in member_section:
			errors.append(f"{owner.name}.{member.name}: missing signature in {file_name}")
	return errors, len(members)


def find_heading_section(text: str, level: int, title: str) -> str | None:
	lines = text.splitlines()
	start_index = -1
	target = f"{'#' * level} {title}"
	for index, line in enumerate(lines):
		if line == target:
			start_index = index
			break
	if start_index == -1:
		return None

	heading_pattern = re.compile(r"^(#{1,%d})\s+" % level)
	end_index = len(lines)
	for index in range(start_index + 1, len(lines)):
		if heading_pattern.match(lines[index]):
			end_index = index
			break
	return "\n".join(lines[start_index:end_index]) + "\n"


def has_markdown_line(text: str, expected_line: str) -> bool:
	return any(line == expected_line for line in text.splitlines())


def find_explicit_anchor_section(text: str, anchor_line: str) -> str:
	lines = text.splitlines()
	start_index = lines.index(anchor_line)
	end_index = len(lines)
	for index in range(start_index + 1, len(lines)):
		if lines[index].startswith('<a id="member-'):
			end_index = index
			break
	return "\n".join(lines[start_index:end_index]) + "\n"


def member_group_name(member: ApiMember) -> str:
	return {
		"signal": "signals",
		"enum": "enums",
		"const": "constants",
		"property": "properties",
		"method": "methods",
	}[member.kind]


def api_class_members(api_class: ApiClass) -> list[ApiMember]:
	members: list[ApiMember] = []
	members.extend(api_class.signals)
	members.extend(api_class.enums)
	members.extend(api_class.constants)
	members.extend(api_class.properties)
	members.extend(api_class.methods)
	return members


def validate_generated_reference_links(reference_files: dict[str, str]) -> list[str]:
	"""Validate every local link and fragment in the in-memory generated tree."""
	errors: list[str] = []
	anchors_by_file: dict[str, set[str]] = {}
	for relative_path, text in sorted(reference_files.items()):
		anchors, anchor_errors = collect_generated_reference_anchors(relative_path, text)
		anchors_by_file[relative_path] = anchors
		errors.extend(anchor_errors)

	for relative_path, text in sorted(reference_files.items()):
		for line_number, line in visible_generated_markdown_lines(text):
			for match in MARKDOWN_LINK_PATTERN.finditer(line):
				target = normalize_markdown_link_target(match.group(1))
				if not target or is_external_markdown_target(target):
					continue
				path_part, separator, fragment = target.partition("#")
				path_part = unquote(path_part.split("?", 1)[0])
				fragment = unquote(fragment.split("?", 1)[0]).strip() if separator else ""
				target_path = resolve_generated_reference_target(relative_path, path_part)
				if target_path is None:
					errors.append(
						f"{relative_path}:{line_number}: generated reference link escapes its root: {target}"
					)
					continue
				if target_path not in reference_files:
					errors.append(
						f"{relative_path}:{line_number}: generated reference link target is missing: {target}"
					)
					continue
				if fragment and fragment not in anchors_by_file[target_path]:
					errors.append(
						f"{relative_path}:{line_number}: generated reference anchor is missing: {target}"
					)
	return errors


def collect_generated_reference_anchors(
	relative_path: str,
	text: str,
) -> tuple[set[str], list[str]]:
	anchors: set[str] = set()
	errors: list[str] = []
	heading_counts: dict[str, int] = {}
	for line_number, line in visible_generated_markdown_lines(text):
		for match in EXPLICIT_ANCHOR_PATTERN.finditer(line):
			anchor = match.group(1)
			if anchor in anchors:
				errors.append(
					f"{relative_path}:{line_number}: duplicate generated reference anchor: {anchor}"
				)
			anchors.add(anchor)
		heading_match = re.match(r"^#{1,6}\s+(.+?)\s*$", line)
		if heading_match is None:
			continue
		heading_title = heading_match.group(1)
		base_anchor = generated_heading_anchor(heading_title)
		if not base_anchor:
			continue
		count = heading_counts.get(base_anchor, 0)
		heading_counts[base_anchor] = count + 1
		anchor = base_anchor if count == 0 else f"{base_anchor}_{count}"
		if anchor in anchors:
			errors.append(
				f"{relative_path}:{line_number}: duplicate generated reference anchor: {anchor}"
			)
		anchors.add(anchor)
		plain_title = re.sub(r"`([^`]+)`", r"\1", heading_title).strip()
		if re.fullmatch(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*", plain_title):
			anchors.add(anchor_for(plain_title))
	return anchors, errors


def visible_generated_markdown_lines(text: str) -> list[tuple[int, str]]:
	visible: list[tuple[int, str]] = []
	fence_character = ""
	fence_length = 0
	for line_number, line in enumerate(text.splitlines(), start=1):
		stripped = line.lstrip()
		if fence_character:
			if (
				stripped.startswith(fence_character * fence_length)
				and stripped.strip(fence_character).strip() == ""
			):
				fence_character = ""
				fence_length = 0
			continue
		fence_match = MARKDOWN_FENCE_PATTERN.match(line)
		if fence_match is not None:
			marker = fence_match.group(1)
			fence_character = marker[0]
			fence_length = len(marker)
			continue
		visible.append((line_number, line))
	return visible


def normalize_markdown_link_target(raw_target: str) -> str:
	target = raw_target.strip()
	if target.startswith("<"):
		end = target.find(">")
		return target[1:end].strip() if end != -1 else target[1:].strip()
	return target.split()[0] if target else ""


def is_external_markdown_target(target: str) -> bool:
	return re.match(r"^(?:https?://|mailto:)", target, re.IGNORECASE) is not None


def resolve_generated_reference_target(source_path: str, path_part: str) -> str | None:
	if "\\" in path_part or re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", path_part):
		return None
	if path_part.startswith("/"):
		return None
	candidate = source_path if not path_part else posixpath.join(posixpath.dirname(source_path), path_part)
	normalized = posixpath.normpath(candidate)
	if normalized == ".." or normalized.startswith("../"):
		return None
	return normalized


def generated_heading_anchor(title: str) -> str:
	plain = re.sub(r"<[^>]+>", "", title)
	plain = re.sub(r"`([^`]+)`", r"\1", plain)
	plain = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", plain)
	plain = plain.replace("*", "").replace("_", "").strip().lower()
	characters: list[str] = []
	previous_dash = False
	for character in plain:
		if character.isalnum():
			characters.append(character)
			previous_dash = False
		elif not previous_dash:
			characters.append("-")
			previous_dash = True
	return "".join(characters).strip("-")


if __name__ == "__main__":
	raise SystemExit(main())
