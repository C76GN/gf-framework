#!/usr/bin/env python3
"""Generate GF API Catalog XML and MkDocs API Reference pages."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

from gdscript_api_parser import ApiClass
from gdscript_api_parser import ApiDocs
from gdscript_api_parser import ApiMember
from gdscript_api_parser import collect_api_classes as parse_api_classes
from gdscript_api_parser import first_tag
from gdscript_api_parser import flatten_api_classes
from gdscript_api_parser import full_api_class_name
from gdscript_api_parser import split_named_value
from gdscript_api_parser import top_level_class_name
from gdscript_api_parser import visibility_of


ROOT = Path(__file__).resolve().parents[1]
PUBLIC_VISIBILITIES = {"public", "protected"}
CATALOG_VERSION = "2"
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


def main() -> int:
	parser = argparse.ArgumentParser(description="Generate GF API Catalog XML and API Reference pages.")
	parser.add_argument("--source", default="addons/gf", help="GDScript source root.")
	parser.add_argument("--catalog", default="docs/api_catalog", help="Generated XML catalog directory.")
	parser.add_argument("--output", default="docs/zh/reference/api", help="Generated MkDocs Markdown directory.")
	parser.add_argument("--check", action="store_true", help="Fail if catalog or Markdown pages are stale.")
	args = parser.parse_args()

	source_root = (ROOT / args.source).resolve()
	catalog_root = (ROOT / args.catalog).resolve()
	output_root = (ROOT / args.output).resolve()
	if not source_root.exists():
		print(f"source root not found: {source_root}")
		return 2

	api_classes = collect_api_classes(source_root)
	catalog_files = render_catalog_files(api_classes, source_root)
	reference_files = render_reference_files(api_classes, catalog_files["index.xml"])
	coverage_status = check_reference_coverage(api_classes, reference_files, report_success=args.check)
	if args.check:
		return max(
			check_files(catalog_root, catalog_files, "API Catalog"),
			check_files(output_root, reference_files, "API Reference"),
			coverage_status,
		)
	if coverage_status:
		return coverage_status

	write_generated_files(catalog_root, catalog_files)
	write_generated_files(output_root, reference_files)
	all_classes = flatten_api_classes(api_classes)
	class_count = len(all_classes)
	method_count = sum(len(api_class.methods) for api_class in all_classes)
	print(f"generated API Catalog: {class_count} classes in {len(api_classes)} files, {method_count} methods")
	print(f"catalog: {catalog_root}")
	print(f"reference: {output_root}")
	return 0


def collect_api_classes(source_root: Path) -> list[ApiClass]:
	result: list[ApiClass] = []
	for api_class in parse_api_classes(source_root, ROOT):
		if visibility_of(api_class.docs) not in PUBLIC_VISIBILITIES:
			continue
		result.append(strip_internal_members(api_class))
	return result


def strip_internal_members(api_class: ApiClass) -> ApiClass:
	api_class.signals = filter_public_members(api_class.signals)
	api_class.enums = filter_public_members(api_class.enums)
	api_class.constants = filter_public_members(api_class.constants)
	api_class.properties = filter_public_members(api_class.properties)
	api_class.methods = filter_public_members(api_class.methods)
	api_class.inner_classes = [
		strip_internal_members(inner_class)
		for inner_class in api_class.inner_classes
		if visibility_of(inner_class.docs) in PUBLIC_VISIBILITIES
	]
	return api_class


def filter_public_members(members: list[ApiMember]) -> list[ApiMember]:
	return [
		member
		for member in members
		if visibility_of(member.docs) in PUBLIC_VISIBILITIES
	]


def render_catalog_files(api_classes: list[ApiClass], source_root: Path) -> dict[str, str]:
	classes_payload = [api_class_to_digest_payload(api_class) for api_class in api_classes]
	source_digest = hash_api_payload(classes_payload)
	files: dict[str, str] = {
		"index.xml": render_catalog_index(api_classes, source_root, source_digest),
	}
	for api_class in api_classes:
		files[f"classes/{api_class.name}.xml"] = render_class_xml(api_class)
	return files


def render_catalog_index(api_classes: list[ApiClass], source_root: Path, source_digest: str) -> str:
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
		},
	)
	for module in sorted({api_class.module for api_class in all_classes}, key=module_sort_key):
		module_classes = [api_class for api_class in all_classes if api_class.module == module]
		module_element = ET.SubElement(
			root,
			"module",
			{
				"id": module,
				"label": module_label(module),
				"classCount": str(len(module_classes)),
				"methodCount": str(sum(len(api_class.methods) for api_class in module_classes)),
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


def render_reference_files(api_classes: list[ApiClass], catalog_index_xml: str) -> dict[str, str]:
	catalog_root = ET.fromstring(catalog_index_xml)
	files: dict[str, str] = {
		"index.md": render_reference_index(api_classes, catalog_root),
		"classes/index.md": render_reference_class_index(api_classes),
	}
	for module in sorted({api_class.module for api_class in api_classes}, key=module_sort_key):
		module_classes = [api_class for api_class in api_classes if api_class.module == module]
		files[f"{module_slug(module)}.md"] = render_reference_module(module, module_classes)
	for api_class in sorted(api_classes, key=lambda item: item.name):
		files[f"classes/{api_class.name}.md"] = render_reference_class_page(api_class)
	return files


def render_reference_index(api_classes: list[ApiClass], catalog_root: ET.Element) -> str:
	all_classes = flatten_api_classes(api_classes)
	lines = [
		"# API Reference",
		"",
		"本区由源码 API 注释生成，作为公开类、成员签名和机器标签的完整参考。正文指南负责解释概念、边界和工作流；这里负责精确检索。",
		"",
		"## 范围",
		"",
		f"- 源码根目录：`{catalog_root.get('sourceRoot', '')}`",
		f"- 公开类：`{catalog_root.get('classCount', '0')}`",
		f"- 公开成员：`{count_public_members(all_classes)}`",
		f"- 公开方法：`{catalog_root.get('methodCount', '0')}`",
		"",
		"## 模块",
		"",
		"| 模块 | 类 | 成员 | 方法 | 页面 |",
		"|---|---:|---:|---:|---|",
	]
	for module in sorted({api_class.module for api_class in all_classes}, key=module_sort_key):
		module_classes = [api_class for api_class in all_classes if api_class.module == module]
		class_count = len(module_classes)
		member_count = count_public_members(module_classes)
		method_count = sum(len(api_class.methods) for api_class in module_classes)
		page = f"{module_slug(module)}.md"
		lines.append(f"| {module_label(module)} | {class_count} | {member_count} | {method_count} | [{page}]({page}) |")
	lines.extend([
		"",
		"## 类索引",
		"",
		"完整类索引独立生成在 [classes/index.md](classes/index.md)，单类页面可从模块索引或类索引进入。",
	])
	return "\n".join(lines) + "\n"


def render_reference_module(module: str, api_classes: list[ApiClass]) -> str:
	module_all_classes = flatten_api_classes(api_classes)
	lines = [
		f"# {module_label(module)} API",
		"",
		f"模块：`{module}`",
		"",
		"## 类别概览",
		"",
		"| 类别 | 类 | 成员 | 方法 |",
		"|---|---:|---:|---:|",
	]
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
				f"| [`{markdown_table_cell(member.name)}`](#{member_anchor_id(api_class, group_name, member)}) "
				f"| `{markdown_table_cell(member_summary_signature(member))}` |"
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
) -> None:
	if not members:
		return
	lines.extend([f"{'#' * group_level} {MEMBER_GROUPS[group_name]}", ""])
	for member in members:
		if anchor_owner != None:
			lines.extend([f'<a id="{member_anchor_id(anchor_owner, group_name, member)}"></a>', ""])
		lines.extend([f"{'#' * member_level} `{member.name}`", ""])
		append_tag_line(lines, "API", visibility_of(member.docs))
		append_tag_line(lines, "首次版本", first_tag(member.docs, "since"))
		append_tag_line(lines, "弃用", "; ".join(member.docs.tags.get("deprecated", [])))
		lines.append("")
		lines.extend(["```gdscript", member.signature, "```", ""])
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


def append_params(lines: list[str], docs: ApiDocs) -> None:
	params = docs.tags.get("param", [])
	if not params:
		return
	lines.extend(["参数：", "", "| 名称 | 说明 |", "|---|---|"])
	for param in params:
		name, description = split_named_value(param)
		lines.append(f"| `{name}` | {description} |")
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
		lines.append(f"- `{name}`: {description}")
	lines.append("")


def append_tag_line(lines: list[str], label: str, value: str, code: bool = True) -> None:
	if value:
		formatted_value = f"`{value}`" if code else value
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


def member_summary_signature(member: ApiMember) -> str:
	if member.kind == "enum":
		return f"enum {member.name}"
	return member.signature


def member_anchor_id(api_class: ApiClass, group_name: str, member: ApiMember) -> str:
	return (
		"member-"
		+ stable_anchor_part(full_api_class_name(api_class))
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


def module_sort_key(module: str) -> tuple[int, str]:
	if module == "kernel":
		return (0, module)
	if module == "standard":
		return (1, module)
	return (2, module)


def anchor_for(title: str) -> str:
	return title.lower().replace("_", "-").replace(".", "")


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


def write_generated_files(root: Path, files: dict[str, str]) -> None:
	if root.exists():
		for path in root.rglob("*"):
			if path.is_file():
				path.unlink()
		for path in sorted(root.rglob("*"), reverse=True):
			if path.is_dir():
				path.rmdir()
	root.mkdir(parents=True, exist_ok=True)
	for relative, content in files.items():
		path = root / relative
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(normalize_generated_text(content), encoding="utf-8", newline="\n")


def check_files(root: Path, desired: dict[str, str], label: str) -> int:
	mismatches: list[str] = []
	for relative, content in desired.items():
		path = root / relative
		if not path.exists():
			mismatches.append(f"missing: {relative}")
			continue
		if path.read_text(encoding="utf-8") != normalize_generated_text(content):
			mismatches.append(f"stale: {relative}")
	existing = {
		path.relative_to(root).as_posix()
		for path in root.rglob("*")
		if path.is_file()
	} if root.exists() else set()
	for extra in sorted(existing - set(desired.keys())):
		mismatches.append(f"extra: {extra}")
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
) -> int:
	errors: list[str] = []
	class_count = 0
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

	if errors:
		print("API Reference coverage is incomplete:")
		for error in errors:
			print(f"- {error}")
		return 1

	if report_success:
		print(f"API Reference coverage is complete: {class_count} classes, {member_count} members.")
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

	if class_heading_level == 1:
		section = section.split("\n## Inner Classes\n", 1)[0]

	members = api_class_members(api_class)
	for member in members:
		member_heading = f"{'#' * (class_heading_level + 2)} `{member.name}`"
		if not has_markdown_line(section, member_heading):
			errors.append(f"{full_name}.{member.name}: missing member heading in {file_name}")
			continue
		if member.signature not in section:
			errors.append(f"{full_name}.{member.name}: missing signature in {file_name}")

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


def api_class_members(api_class: ApiClass) -> list[ApiMember]:
	members: list[ApiMember] = []
	members.extend(api_class.signals)
	members.extend(api_class.enums)
	members.extend(api_class.constants)
	members.extend(api_class.properties)
	members.extend(api_class.methods)
	return members


if __name__ == "__main__":
	raise SystemExit(main())
