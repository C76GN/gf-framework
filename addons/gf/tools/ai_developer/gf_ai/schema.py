"""Dependency-free validator for the strict JSON Schema subset used by the kit."""

from __future__ import annotations

import math
import re
from pathlib import Path
from typing import Any

from .paths import read_json_object


_ALLOWED_SCHEMA_KEYS = {
	"$id",
	"$schema",
	"additionalProperties",
	"const",
	"default",
	"description",
	"enum",
	"items",
	"maxItems",
	"maxLength",
	"maximum",
	"minItems",
	"minLength",
	"minProperties",
	"minimum",
	"pattern",
	"properties",
	"required",
	"title",
	"type",
	"uniqueItems",
}
_ALLOWED_TYPES = {"array", "boolean", "integer", "null", "number", "object", "string"}
_NON_NEGATIVE_INTEGER_KEYS = {"maxItems", "maxLength", "minItems", "minLength", "minProperties"}
_STRING_METADATA_KEYS = {"$id", "$schema", "description", "title"}


def validate_schema_file(value: Any, schema_path: Path) -> list[dict[str, Any]]:
	schema = read_json_object(schema_path)
	definition_issues = validate_schema_definition(schema)
	return definition_issues if definition_issues else validate_schema(value, schema)


def validate_schema_definition(schema: dict[str, Any]) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	_validate_schema_definition_node(schema, "$schema", issues)
	return issues


def validate_schema(value: Any, schema: dict[str, Any]) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	_validate_node(value, schema, "$", issues)
	return issues


def _validate_node(
	value: Any,
	schema: dict[str, Any],
	path: str,
	issues: list[dict[str, Any]],
) -> None:
	if "const" in schema and value != schema["const"]:
		_add_issue(issues, path, "const_mismatch", f"Value must equal {schema['const']!r}.")
	if "enum" in schema and value not in schema["enum"]:
		_add_issue(issues, path, "enum_mismatch", "Value is not one of the allowed values.")

	expected_type = schema.get("type")
	if expected_type is not None and not _matches_type(value, expected_type):
		_add_issue(
			issues,
			path,
			"type_mismatch",
			f"Expected {_type_description(expected_type)}, got {_value_type(value)}.",
		)
		return

	if isinstance(value, dict):
		_validate_object(value, schema, path, issues)
	elif isinstance(value, list):
		_validate_array(value, schema, path, issues)
	elif isinstance(value, str):
		_validate_string(value, schema, path, issues)
	elif _is_number(value):
		_validate_number(value, schema, path, issues)


def _validate_schema_definition_node(
	schema: dict[str, Any],
	path: str,
	issues: list[dict[str, Any]],
) -> None:
	for key in schema:
		if key not in _ALLOWED_SCHEMA_KEYS:
			_add_issue(issues, f"{path}.{key}", "unsupported_schema_keyword", "Schema keyword is not implemented by the kit validator.")
	for key in _STRING_METADATA_KEYS:
		if key in schema and not isinstance(schema[key], str):
			_add_issue(issues, f"{path}.{key}", "invalid_schema", f"Schema {key} must be a string.")
	_validate_type_definition(schema.get("type"), path, issues)
	_validate_enum_definition(schema.get("enum"), path, issues)
	for key in _NON_NEGATIVE_INTEGER_KEYS:
		if key in schema and (not _is_integer(schema[key]) or schema[key] < 0):
			_add_issue(issues, f"{path}.{key}", "invalid_schema", f"Schema {key} must be a non-negative integer.")
	for minimum_key, maximum_key in (("minItems", "maxItems"), ("minLength", "maxLength")):
		minimum_value = schema.get(minimum_key)
		maximum_value = schema.get(maximum_key)
		if _is_integer(minimum_value) and _is_integer(maximum_value) and minimum_value > maximum_value:
			_add_issue(issues, path, "invalid_schema", f"Schema {minimum_key} must not exceed {maximum_key}.")
	for key in ("minimum", "maximum"):
		if key in schema and not _is_number(schema[key]):
			_add_issue(issues, f"{path}.{key}", "invalid_schema", f"Schema {key} must be a finite number.")
	minimum = schema.get("minimum")
	maximum = schema.get("maximum")
	if _is_number(minimum) and _is_number(maximum) and minimum > maximum:
		_add_issue(issues, path, "invalid_schema", "Schema minimum must not exceed maximum.")
	if "uniqueItems" in schema and not isinstance(schema["uniqueItems"], bool):
		_add_issue(issues, f"{path}.uniqueItems", "invalid_schema", "Schema uniqueItems must be a boolean.")
	pattern = schema.get("pattern")
	if pattern is not None:
		if not isinstance(pattern, str):
			_add_issue(issues, f"{path}.pattern", "invalid_schema", "Schema pattern must be a string.")
		else:
			try:
				re.compile(pattern)
			except re.error as exc:
				_add_issue(issues, f"{path}.pattern", "invalid_schema_pattern", str(exc))
	properties = schema.get("properties")
	if properties is not None and not isinstance(properties, dict):
		_add_issue(issues, f"{path}.properties", "invalid_schema", "Schema properties must be an object.")
	elif isinstance(properties, dict):
		for field, child in properties.items():
			if not isinstance(child, dict):
				_add_issue(issues, f"{path}.properties.{field}", "invalid_schema", "Property schema must be an object.")
				continue
			_validate_schema_definition_node(child, f"{path}.properties.{field}", issues)
	items = schema.get("items")
	if items is not None:
		if isinstance(items, dict):
			_validate_schema_definition_node(items, f"{path}.items", issues)
		else:
			_add_issue(issues, f"{path}.items", "invalid_schema", "Array item schema must be an object.")
	required = schema.get("required")
	if required is not None and (
		not isinstance(required, list)
		or any(not isinstance(item, str) for item in required)
	):
		_add_issue(issues, f"{path}.required", "invalid_schema", "Schema required must be an array of strings.")
	elif isinstance(required, list):
		if len(required) != len(set(required)):
			_add_issue(issues, f"{path}.required", "invalid_schema", "Schema required fields must be unique.")
		if isinstance(properties, dict):
			for field in required:
				if field not in properties:
					_add_issue(issues, f"{path}.required", "invalid_schema", f"Required field is not declared in properties: {field}.")
	additional = schema.get("additionalProperties")
	if additional is not None and not isinstance(additional, bool):
		_add_issue(issues, f"{path}.additionalProperties", "unsupported_schema_value", "Only boolean additionalProperties is supported.")


def _validate_type_definition(
	expected: Any,
	path: str,
	issues: list[dict[str, Any]],
) -> None:
	if expected is None:
		return
	values = expected if isinstance(expected, list) else [expected]
	if not values or any(not isinstance(item, str) or item not in _ALLOWED_TYPES for item in values):
		_add_issue(issues, f"{path}.type", "invalid_schema", "Schema type must contain only supported JSON types.")
		return
	if len(values) != len(set(values)):
		_add_issue(issues, f"{path}.type", "invalid_schema", "Schema type alternatives must be unique.")


def _validate_enum_definition(
	values: Any,
	path: str,
	issues: list[dict[str, Any]],
) -> None:
	if values is None:
		return
	if not isinstance(values, list) or not values:
		_add_issue(issues, f"{path}.enum", "invalid_schema", "Schema enum must be a non-empty array.")
		return
	seen: list[Any] = []
	for value in values:
		if value in seen:
			_add_issue(issues, f"{path}.enum", "invalid_schema", "Schema enum values must be unique.")
			return
		seen.append(value)


def _validate_object(
	value: dict[str, Any],
	schema: dict[str, Any],
	path: str,
	issues: list[dict[str, Any]],
) -> None:
	properties = schema.get("properties", {})
	if not isinstance(properties, dict):
		_add_issue(issues, path, "invalid_schema", "Schema properties must be an object.")
		return
	required = schema.get("required", [])
	if isinstance(required, list):
		for field in required:
			if isinstance(field, str) and field not in value:
				_add_issue(issues, f"{path}.{field}", "missing_required", "Required field is missing.")
	for field, child in value.items():
		child_path = f"{path}.{field}"
		child_schema = properties.get(field)
		if isinstance(child_schema, dict):
			_validate_node(child, child_schema, child_path, issues)
		elif schema.get("additionalProperties", True) is False:
			_add_issue(issues, child_path, "unknown_field", "Field is not part of the schema.")
	min_properties = schema.get("minProperties")
	if _is_integer(min_properties) and len(value) < min_properties:
		_add_issue(issues, path, "min_properties", f"Object requires at least {min_properties} fields.")


def _validate_array(
	value: list[Any],
	schema: dict[str, Any],
	path: str,
	issues: list[dict[str, Any]],
) -> None:
	min_items = schema.get("minItems")
	max_items = schema.get("maxItems")
	if _is_integer(min_items) and len(value) < min_items:
		_add_issue(issues, path, "min_items", f"Array requires at least {min_items} items.")
	if _is_integer(max_items) and len(value) > max_items:
		_add_issue(issues, path, "max_items", f"Array allows at most {max_items} items.")
	if schema.get("uniqueItems") is True:
		seen: list[Any] = []
		for item in value:
			if item in seen:
				_add_issue(issues, path, "duplicate_item", "Array items must be unique.")
				break
			seen.append(item)
	item_schema = schema.get("items")
	if isinstance(item_schema, dict):
		for index, item in enumerate(value):
			_validate_node(item, item_schema, f"{path}[{index}]", issues)


def _validate_string(
	value: str,
	schema: dict[str, Any],
	path: str,
	issues: list[dict[str, Any]],
) -> None:
	min_length = schema.get("minLength")
	max_length = schema.get("maxLength")
	if _is_integer(min_length) and len(value) < min_length:
		_add_issue(issues, path, "min_length", f"String requires at least {min_length} characters.")
	if _is_integer(max_length) and len(value) > max_length:
		_add_issue(issues, path, "max_length", f"String allows at most {max_length} characters.")
	pattern = schema.get("pattern")
	if isinstance(pattern, str):
		try:
			matched = re.fullmatch(pattern, value) is not None
		except re.error as exc:
			_add_issue(issues, path, "invalid_schema_pattern", str(exc))
			return
		if not matched:
			_add_issue(issues, path, "pattern_mismatch", "String does not match the required pattern.")


def _validate_number(
	value: int | float,
	schema: dict[str, Any],
	path: str,
	issues: list[dict[str, Any]],
) -> None:
	minimum = schema.get("minimum")
	maximum = schema.get("maximum")
	if _is_number(minimum) and value < minimum:
		_add_issue(issues, path, "minimum", f"Number must be at least {minimum}.")
	if _is_number(maximum) and value > maximum:
		_add_issue(issues, path, "maximum", f"Number must be at most {maximum}.")


def _matches_type(value: Any, expected: Any) -> bool:
	if isinstance(expected, list):
		return any(_matches_type(value, item) for item in expected)
	if expected == "object":
		return isinstance(value, dict)
	if expected == "array":
		return isinstance(value, list)
	if expected == "string":
		return isinstance(value, str)
	if expected == "integer":
		return _is_integer(value)
	if expected == "number":
		return _is_number(value)
	if expected == "boolean":
		return isinstance(value, bool)
	if expected == "null":
		return value is None
	return False


def _is_integer(value: Any) -> bool:
	return isinstance(value, int) and not isinstance(value, bool)


def _is_number(value: Any) -> bool:
	if _is_integer(value):
		return True
	return isinstance(value, float) and math.isfinite(value)


def _type_description(expected: Any) -> str:
	if isinstance(expected, list):
		return " or ".join(str(item) for item in expected)
	return str(expected)


def _value_type(value: Any) -> str:
	if value is None:
		return "null"
	if isinstance(value, bool):
		return "boolean"
	if isinstance(value, dict):
		return "object"
	if isinstance(value, list):
		return "array"
	if isinstance(value, str):
		return "string"
	if _is_integer(value):
		return "integer"
	if isinstance(value, float):
		return "number"
	return type(value).__name__


def _add_issue(
	issues: list[dict[str, Any]],
	path: str,
	code: str,
	message: str,
) -> None:
	issues.append({"severity": "error", "path": path, "code": code, "message": message})
