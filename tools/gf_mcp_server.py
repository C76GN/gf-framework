#!/usr/bin/env python3
"""Dependency-free MCP stdio server for GF repository maintenance."""

from __future__ import annotations

import json
import sys
import traceback
from typing import Any

import gf_maintenance


PROTOCOL_VERSION = "2025-06-18"
SERVER_NAME = "gf-maintenance"
SERVER_VERSION = "1.0.0"


def main() -> int:
	gf_maintenance.configure_stdio()
	for line in sys.stdin:
		line = line.strip().removeprefix("\ufeff")
		if not line:
			continue
		try:
			message = json.loads(line)
			response = handle_message(message)
			if response is not None:
				send_message(response)
		except Exception as exc:
			print(traceback.format_exc(), file=sys.stderr)
			send_message(error_response(None, -32603, str(exc)))
	return 0


def handle_message(message: dict[str, Any]) -> dict[str, Any] | None:
	method = message.get("method", "")
	request_id = message.get("id")
	params = message.get("params") or {}

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
					"query": {"type": "string"},
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
					"class_name": {"type": "string"},
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
					"module": {"type": "string", "description": "Module id such as kernel, standard, extensions/domain, or domain."},
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
						"items": {
							"type": "string",
							"enum": sorted([*gf_maintenance.CHECK_DEFINITIONS.keys(), "release_metadata"]),
						},
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
						"description": "Allow explicitly approved breaking API baseline changes in release_metadata.",
					},
					"artifact_manifest": {
						"type": "string",
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
					"version": {"type": "string", "description": "Expected SemVer. Defaults to addons/gf/plugin.cfg version."},
					"allow_dirty": {"type": "boolean", "default": False, "description": "Allow dirty-worktree diagnostics. Do not use for release packaging."},
					"allow_breaking_api": {
						"type": "boolean",
						"default": False,
						"description": "Allow explicitly approved breaking API baseline changes without requiring a major version bump.",
					},
					"artifact_manifest": {
						"type": "string",
						"minLength": 1,
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
	name = params.get("name", "")
	arguments = params.get("arguments") or {}
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
		else:
			return error_response(request_id, -32602, f"Unknown tool: {name}")
		return result_response(request_id, tool_result(data, is_error=not data.get("ok", True) if isinstance(data, dict) else False))
	except Exception as exc:
		return result_response(request_id, tool_result({"error": str(exc)}, is_error=True))


def tool_result(data: dict[str, Any], is_error: bool = False) -> dict[str, Any]:
	text = json.dumps(data, ensure_ascii=False, indent=2)
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
	uri = str(params.get("uri", ""))
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
			"text": json.dumps(data, ensure_ascii=False, indent=2),
		}]
	})


def result_response(request_id: Any, result: Any) -> dict[str, Any]:
	return {"jsonrpc": "2.0", "id": request_id, "result": result}


def error_response(request_id: Any, code: int, message: str) -> dict[str, Any]:
	return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}


def send_message(message: dict[str, Any]) -> None:
	print(json.dumps(message, ensure_ascii=False), flush=True)


if __name__ == "__main__":
	raise SystemExit(main())
