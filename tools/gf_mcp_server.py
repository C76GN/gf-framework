#!/usr/bin/env python3
"""Dependency-free MCP stdio server for GF repository maintenance."""

from __future__ import annotations

import json
import math
import sys
import traceback
from typing import Any

import gf_maintenance
from gf_maintenance_rendering import encode_strict_json


PROTOCOL_VERSION = "2025-06-18"
SERVER_NAME = "gf-maintenance"
SERVER_VERSION = "1.0.0"
MAX_MCP_REQUEST_BYTES = 1024 * 1024
MAX_MCP_JSON_DEPTH = 64
MAX_MCP_JSON_NODES = 20_000
MAX_MCP_STRING_BYTES = 256 * 1024
MAX_MCP_METHOD_LENGTH = 128
MAX_MCP_ID_LENGTH = 256
MAX_MCP_URI_LENGTH = 4096


class McpRequestError(ValueError):
	def __init__(self, code: int, message: str, *, fatal: bool = False) -> None:
		super().__init__(message)
		self.code = code
		self.fatal = fatal


def main() -> int:
	gf_maintenance.configure_stdio()
	stream = sys.stdin.buffer
	while True:
		try:
			request_bytes = read_request_bytes(stream)
			if request_bytes == b"":
				return 0
			if not request_bytes.strip():
				continue
			message = decode_request_bytes(request_bytes)
			response = handle_message(message)
			if response is not None:
				send_message(response)
		except McpRequestError as exc:
			send_message(error_response(None, exc.code, str(exc)))
			if exc.fatal:
				return 2
		except Exception as exc:
			print(traceback.format_exc(), file=sys.stderr)
			send_message(error_response(None, -32603, str(exc)))


def read_request_bytes(stream: Any) -> bytes:
	line = stream.readline(MAX_MCP_REQUEST_BYTES + 1)
	if len(line) > MAX_MCP_REQUEST_BYTES:
		raise McpRequestError(
			-32600,
			"MCP request exceeds the configured byte limit.",
			fatal=True,
		)
	return line


def decode_request_bytes(request_bytes: bytes) -> dict[str, Any]:
	try:
		text = request_bytes.decode("utf-8-sig", errors="strict").strip()
	except UnicodeDecodeError as error:
		raise McpRequestError(-32700, "MCP request is not valid UTF-8.") from error
	try:
		message = json.loads(
			text,
			object_pairs_hook=_reject_duplicate_json_object_keys,
			parse_constant=_reject_json_constant,
		)
	except (json.JSONDecodeError, RecursionError, ValueError) as error:
		raise McpRequestError(-32700, f"Invalid MCP JSON: {error}") from error
	_validate_json_domain(message)
	if not isinstance(message, dict):
		raise McpRequestError(-32600, "MCP request must be a JSON object.")
	return message


def handle_message(message: dict[str, Any]) -> dict[str, Any] | None:
	_validate_request_envelope(message)
	gf_maintenance.invalidate_api_cache()
	method = message.get("method", "")
	request_id = message.get("id")
	params = message.get("params", {})

	if method.startswith("notifications/"):
		return None
	if method == "initialize":
		client_version = params.get("protocolVersion", PROTOCOL_VERSION)
		return result_response(request_id, {
			"protocolVersion": client_version,
			"capabilities": {
				"tools": {"listChanged": False},
				"resources": {"subscribe": False, "listChanged": False},
			},
			"serverInfo": {
				"name": SERVER_NAME,
				"version": SERVER_VERSION,
			},
			"instructions": (
				"Use this server only for GF Framework repository maintenance. "
				"It exposes compact project/API context and predefined local checks; "
				"it does not add runtime functionality to addons/gf."
			),
		})
	if method == "ping":
		return result_response(request_id, {})
	if method == "tools/list":
		return result_response(request_id, {"tools": list_tools()})
	if method == "tools/call":
		return call_tool(request_id, params)
	if method == "resources/list":
		return result_response(request_id, {"resources": list_resources()})
	if method == "resources/read":
		return read_resource(request_id, params)
	if method == "resources/templates/list":
		return result_response(request_id, {"resourceTemplates": list_resource_templates()})
	return error_response(request_id, -32601, f"Unknown method: {method}")


def _validate_request_envelope(message: dict[str, Any]) -> None:
	if not isinstance(message, dict):
		raise McpRequestError(-32600, "MCP request must be an object.")
	if message.get("jsonrpc") != "2.0":
		raise McpRequestError(-32600, "MCP request jsonrpc must equal '2.0'.")
	method = message.get("method")
	if not isinstance(method, str) or not method or len(method) > MAX_MCP_METHOD_LENGTH:
		raise McpRequestError(-32600, "MCP request method must be a bounded non-empty string.")
	if "params" in message and not isinstance(message["params"], dict):
		raise McpRequestError(-32602, "MCP request params must be an object.")
	if "id" not in message:
		return
	request_id = message["id"]
	if request_id is None:
		return
	if isinstance(request_id, bool) or not isinstance(request_id, (int, str)):
		raise McpRequestError(-32600, "MCP request id must be a string, integer, or null.")
	if isinstance(request_id, int) and abs(request_id) > 2**63 - 1:
		raise McpRequestError(-32600, "MCP integer request id is outside the supported range.")
	if isinstance(request_id, str) and len(request_id) > MAX_MCP_ID_LENGTH:
		raise McpRequestError(-32600, "MCP string request id exceeds the configured length limit.")


def _validate_json_domain(value: Any) -> None:
	node_count = 0
	stack: list[tuple[Any, int]] = [(value, 0)]
	while stack:
		current, depth = stack.pop()
		node_count += 1
		if node_count > MAX_MCP_JSON_NODES:
			raise McpRequestError(-32600, "MCP JSON exceeds the configured node limit.")
		if depth > MAX_MCP_JSON_DEPTH:
			raise McpRequestError(-32600, "MCP JSON exceeds the configured nesting limit.")
		if isinstance(current, dict):
			for key, child in current.items():
				if len(key.encode("utf-8")) > MAX_MCP_STRING_BYTES:
					raise McpRequestError(-32600, "MCP JSON object key exceeds the string byte limit.")
				stack.append((child, depth + 1))
		elif isinstance(current, list):
			stack.extend((child, depth + 1) for child in current)
		elif isinstance(current, str):
			if len(current.encode("utf-8")) > MAX_MCP_STRING_BYTES:
				raise McpRequestError(-32600, "MCP JSON string exceeds the configured byte limit.")
		elif isinstance(current, float) and not math.isfinite(current):
			raise McpRequestError(-32600, "MCP JSON contains a non-finite number.")


def _reject_duplicate_json_object_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
	result: dict[str, Any] = {}
	for key, value in pairs:
		if key in result:
			raise ValueError(f"duplicate JSON object key: {key}")
		result[key] = value
	return result


def _reject_json_constant(value: str) -> Any:
	raise ValueError(f"non-finite JSON number: {value}")


def _validate_object_fields(
	value: dict[str, Any],
	*,
	required: set[str],
	allowed: set[str],
	path: str,
) -> None:
	missing = sorted(required.difference(value))
	if missing:
		raise McpRequestError(-32602, f"{path} is missing required field(s): {', '.join(missing)}")
	unexpected = sorted(set(value).difference(allowed))
	if unexpected:
		raise McpRequestError(-32602, f"{path} contains unexpected field(s): {', '.join(unexpected)}")


def _validate_schema(value: Any, schema: dict[str, Any], *, path: str) -> None:
	expected_type = schema.get("type")
	if expected_type == "object":
		if not isinstance(value, dict):
			raise McpRequestError(-32602, f"{path} must be an object.")
		properties = schema.get("properties", {})
		required = set(schema.get("required", []))
		missing = sorted(required.difference(value))
		if missing:
			raise McpRequestError(-32602, f"{path} is missing required field(s): {', '.join(missing)}")
		if schema.get("additionalProperties") is False:
			unexpected = sorted(set(value).difference(properties))
			if unexpected:
				raise McpRequestError(-32602, f"{path} contains unexpected field(s): {', '.join(unexpected)}")
		for key, child in value.items():
			child_schema = properties.get(key)
			if child_schema is not None:
				_validate_schema(child, child_schema, path=f"{path}.{key}")
		return
	if expected_type == "array":
		if not isinstance(value, list):
			raise McpRequestError(-32602, f"{path} must be an array.")
		if len(value) < int(schema.get("minItems", 0)):
			raise McpRequestError(-32602, f"{path} contains too few items.")
		if "maxItems" in schema and len(value) > int(schema["maxItems"]):
			raise McpRequestError(-32602, f"{path} contains too many items.")
		if schema.get("uniqueItems") and any(
			item == previous
			for index, item in enumerate(value)
			for previous in value[:index]
		):
			raise McpRequestError(-32602, f"{path} must contain unique items.")
		item_schema = schema.get("items")
		if item_schema is not None:
			for index, child in enumerate(value):
				_validate_schema(child, item_schema, path=f"{path}[{index}]")
		return
	if expected_type == "string":
		if not isinstance(value, str):
			raise McpRequestError(-32602, f"{path} must be a string.")
		if len(value) < int(schema.get("minLength", 0)):
			raise McpRequestError(-32602, f"{path} is shorter than allowed.")
		if "maxLength" in schema and len(value) > int(schema["maxLength"]):
			raise McpRequestError(-32602, f"{path} is longer than allowed.")
	elif expected_type == "integer":
		if isinstance(value, bool) or not isinstance(value, int):
			raise McpRequestError(-32602, f"{path} must be an integer.")
	elif expected_type == "boolean":
		if not isinstance(value, bool):
			raise McpRequestError(-32602, f"{path} must be a boolean.")
	elif expected_type is not None:
		raise RuntimeError(f"Unsupported MCP schema type: {expected_type}")
	if "enum" in schema and value not in schema["enum"]:
		raise McpRequestError(-32602, f"{path} is not one of the allowed values.")
	if "minimum" in schema and value < schema["minimum"]:
		raise McpRequestError(-32602, f"{path} is below the allowed minimum.")
	if "maximum" in schema and value > schema["maximum"]:
		raise McpRequestError(-32602, f"{path} is above the allowed maximum.")


def list_tools() -> list[dict[str, Any]]:
	return [
		{
			"name": "gf_project_summary",
			"description": "Return compact GF repository status, release metadata, API catalog stats, and maintenance entry points.",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"additionalProperties": False,
			},
			"annotations": {"readOnlyHint": True},
		},
		{
			"name": "gf_api_search",
			"description": "Search GF API classes and members without reading the whole repository.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"query": {"type": "string", "minLength": 1, "maxLength": 256},
					"kind": {"type": "string", "enum": ["all", "class", "member"], "default": "all"},
					"limit": {"type": "integer", "minimum": 1, "maximum": 80, "default": 20},
				},
				"required": ["query"],
				"additionalProperties": False,
			},
			"annotations": {"readOnlyHint": True},
		},
		{
			"name": "gf_api_class",
			"description": "Return source path, docs, reference page, and public members for one GF class.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"class_name": {"type": "string", "minLength": 1, "maxLength": 256},
					"include_members": {"type": "boolean", "default": True},
				},
				"required": ["class_name"],
				"additionalProperties": False,
			},
			"annotations": {"readOnlyHint": True},
		},
		{
			"name": "gf_api_module",
			"description": "Return compact class and member-count context for a GF API module without dumping the full API index.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"module": {"type": "string", "minLength": 1, "maxLength": 512, "description": "Module id such as kernel, standard, extensions/domain, or domain."},
					"include_members": {"type": "boolean", "default": False},
					"limit": {"type": "integer", "minimum": 1, "maximum": 160, "default": 80},
				},
				"required": ["module"],
				"additionalProperties": False,
			},
			"annotations": {"readOnlyHint": True},
		},
		{
			"name": "gf_workspace_status",
			"description": "Return categorized git status, ignored AI workspace state, and suggested maintenance checks.",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"additionalProperties": False,
			},
			"annotations": {"readOnlyHint": True},
		},
		{
			"name": "gf_run_checks",
			"description": "Run predefined GF maintenance checks such as API, docs, full, or release suites.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"suite": {"type": "string", "enum": sorted(gf_maintenance.CHECK_SUITES), "default": "quick"},
					"checks": {
						"type": "array",
						"minItems": 1,
						"maxItems": 128,
						"uniqueItems": True,
						"items": {
							"type": "string",
							"enum": sorted(gf_maintenance.VALIDATION_ACTION_NAMES),
						},
					},
					"jobs": {
						"type": "integer",
						"minimum": 0,
						"maximum": gf_maintenance.MAX_PARALLEL_FULL_JOBS,
						"default": 0,
						"description": (
							"Full-suite shard workers: 0 selects the bounded default, "
							"1 uses the serial diagnostic path."
						),
					},
					"timeout_seconds": {
						"type": "integer",
						"minimum": 30,
						"maximum": 7200,
						"description": "Optional minimum per-check budget; dedicated longer check policies still win.",
					},
					"suite_timeout_seconds": {
						"type": "integer",
						"minimum": 30,
						"maximum": 14400,
						"description": (
							"Optional overall suite budget; remaining time constrains external checks, "
							"and in-process overruns are reported when they return."
						),
					},
					"fail_fast": {"type": "boolean", "default": False},
					"allow_breaking_api": {
						"type": "boolean",
						"default": False,
						"description": (
							"Allow explicitly approved breaking API baseline changes in "
							"changelog_policy and release_metadata; migration notes remain mandatory."
						),
					},
					"artifact_manifest": {
						"type": "string",
						"maxLength": 4096,
						"description": "Prebuilt release artifact manifest required when release_metadata is selected.",
					},
				},
				"additionalProperties": False,
			},
			"annotations": {"readOnlyHint": False},
		},
		{
			"name": "gf_release_status",
			"description": "Validate release metadata, one prebuilt immutable artifact set, and local tag state for a GF version without rebuilding assets.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"version": {"type": "string", "maxLength": 64, "description": "Expected SemVer. Defaults to addons/gf/plugin.cfg version."},
					"allow_dirty": {"type": "boolean", "default": False, "description": "Allow dirty-worktree diagnostics. Do not use for release packaging."},
					"allow_breaking_api": {
						"type": "boolean",
						"default": False,
						"description": "Allow explicitly approved breaking API baseline changes without requiring a major version bump.",
					},
					"artifact_manifest": {
						"type": "string",
						"minLength": 1,
						"maxLength": 4096,
						"description": "Manifest created by tools/build_gf_release_artifacts.py.",
					},
				},
				"required": ["artifact_manifest"],
				"additionalProperties": False,
			},
			"annotations": {"readOnlyHint": True},
		},
	]


def call_tool(request_id: Any, params: dict[str, Any]) -> dict[str, Any]:
	try:
		_validate_object_fields(
			params,
			required={"name"},
			allowed={"name", "arguments"},
			path="params",
		)
		name = params.get("name")
		if not isinstance(name, str) or not name or len(name) > MAX_MCP_METHOD_LENGTH:
			raise McpRequestError(-32602, "params.name must be a bounded non-empty string.")
		arguments = params.get("arguments", {})
		if not isinstance(arguments, dict):
			raise McpRequestError(-32602, "params.arguments must be an object.")
		tool = next((item for item in list_tools() if item["name"] == name), None)
		if tool is None:
			raise McpRequestError(-32602, f"Unknown tool: {name}")
		_validate_schema(arguments, tool["inputSchema"], path="arguments")
	except McpRequestError as error:
		return error_response(request_id, error.code, str(error))
	try:
		if name == "gf_project_summary":
			data = gf_maintenance.project_summary()
		elif name == "gf_api_search":
			data = gf_maintenance.api_search(
				str(arguments.get("query", "")),
				kind=str(arguments.get("kind", "all")),
				limit=int(arguments.get("limit", 20)),
			)
		elif name == "gf_api_class":
			data = gf_maintenance.api_class(
				str(arguments.get("class_name", "")),
				include_members=bool(arguments.get("include_members", True)),
			)
		elif name == "gf_api_module":
			data = gf_maintenance.api_module(
				str(arguments.get("module", "")),
				include_members=bool(arguments.get("include_members", False)),
				limit=int(arguments.get("limit", 80)),
			)
		elif name == "gf_workspace_status":
			data = gf_maintenance.workspace_status()
		elif name == "gf_run_checks":
			checks = arguments.get("checks")
			timeout_seconds = arguments.get("timeout_seconds")
			suite_timeout_seconds = arguments.get("suite_timeout_seconds")
			data = gf_maintenance.run_checks_with_log_hygiene(
				suite=str(arguments.get("suite", "quick")),
				checks=checks if isinstance(checks, list) else None,
				jobs=int(arguments.get("jobs", 0)),
				timeout_seconds=int(timeout_seconds) if timeout_seconds != None else None,
				suite_timeout_seconds=(
					int(suite_timeout_seconds)
					if suite_timeout_seconds != None
					else None
				),
				fail_fast=bool(arguments.get("fail_fast", False)),
				allow_breaking_api=bool(arguments.get("allow_breaking_api", False)),
				artifact_manifest=str(arguments.get("artifact_manifest", "")),
			)
		elif name == "gf_release_status":
			data = gf_maintenance.release_status(
				str(arguments.get("version", "")),
				allow_dirty=bool(arguments.get("allow_dirty", False)),
				allow_breaking_api=bool(arguments.get("allow_breaking_api", False)),
				artifact_manifest=str(arguments.get("artifact_manifest", "")),
			)
		return result_response(request_id, tool_result(data, is_error=not data.get("ok", True) if isinstance(data, dict) else False))
	except Exception as exc:
		return result_response(request_id, tool_result({"error": str(exc)}, is_error=True))


def tool_result(data: dict[str, Any], is_error: bool = False) -> dict[str, Any]:
	text = encode_strict_json(data, indent=2)
	return {
		"content": [{"type": "text", "text": text}],
		"structuredContent": data,
		"isError": is_error,
	}


def list_resources() -> list[dict[str, str]]:
	return [
		{
			"uri": "gf://maintenance/project-summary",
			"name": "GF Project Summary",
			"description": "Compact dynamic repository, release, and API catalog summary.",
			"mimeType": "application/json",
		},
		{
			"uri": "gf://maintenance/rules",
			"name": "GF AI Maintenance Rules",
			"description": "Repository maintenance rules from AI_MAINTENANCE.md.",
			"mimeType": "text/markdown",
		},
		{
			"uri": "gf://maintenance/workspace-status",
			"name": "GF Workspace Status",
			"description": "Categorized dirty files and recommended checks for current repository state.",
			"mimeType": "application/json",
		},
		{
			"uri": "gf://api/index",
			"name": "GF API Index",
			"description": "Compact API class and module index generated from current addons/gf sources.",
			"mimeType": "application/json",
		},
	]


def list_resource_templates() -> list[dict[str, str]]:
	return [
		{
			"uriTemplate": "gf://api/classes/{class_name}",
			"name": "GF API Class",
			"description": "Dynamic API details for one class_name.",
			"mimeType": "application/json",
		},
		{
			"uriTemplate": "gf://api/modules/{module}",
			"name": "GF API Module",
			"description": "Dynamic compact API module summary.",
			"mimeType": "application/json",
		}
	]


def read_resource(request_id: Any, params: dict[str, Any]) -> dict[str, Any]:
	try:
		_validate_object_fields(
			params,
			required={"uri"},
			allowed={"uri"},
			path="params",
		)
		uri_value = params.get("uri")
		if not isinstance(uri_value, str) or not uri_value or len(uri_value) > MAX_MCP_URI_LENGTH:
			raise McpRequestError(-32602, "params.uri must be a bounded non-empty string.")
		uri = uri_value
	except McpRequestError as error:
		return error_response(request_id, error.code, str(error))
	if uri == "gf://maintenance/project-summary":
		return resource_response(request_id, uri, "application/json", gf_maintenance.project_summary())
	if uri == "gf://maintenance/rules":
		text = (gf_maintenance.ROOT / "AI_MAINTENANCE.md").read_text(encoding="utf-8")
		return result_response(request_id, {"contents": [{"uri": uri, "mimeType": "text/markdown", "text": text}]})
	if uri == "gf://maintenance/workspace-status":
		return resource_response(request_id, uri, "application/json", gf_maintenance.workspace_status())
	if uri == "gf://api/index":
		return resource_response(request_id, uri, "application/json", gf_maintenance.api_index())
	if uri.startswith("gf://api/classes/"):
		class_name = uri.removeprefix("gf://api/classes/")
		return resource_response(request_id, uri, "application/json", gf_maintenance.api_class(class_name))
	if uri.startswith("gf://api/modules/"):
		module = uri.removeprefix("gf://api/modules/")
		return resource_response(request_id, uri, "application/json", gf_maintenance.api_module(module))
	return error_response(request_id, -32602, f"Unknown resource: {uri}")


def resource_response(request_id: Any, uri: str, mime_type: str, data: dict[str, Any]) -> dict[str, Any]:
	return result_response(request_id, {
		"contents": [{
			"uri": uri,
			"mimeType": mime_type,
			"text": encode_strict_json(data, indent=2),
		}]
	})


def result_response(request_id: Any, result: Any) -> dict[str, Any]:
	return {"jsonrpc": "2.0", "id": request_id, "result": result}


def error_response(request_id: Any, code: int, message: str) -> dict[str, Any]:
	return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}


def send_message(message: dict[str, Any]) -> None:
	print(encode_strict_json(message), flush=True)


if __name__ == "__main__":
	raise SystemExit(main())
