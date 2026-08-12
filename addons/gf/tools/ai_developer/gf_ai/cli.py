"""Command-line interface shared by project-local agent integrations."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from . import adapters, catalog, context_bundle, feedback, migration, snapshot
from .constants import DEFAULT_CONTRACT_PATH, DEFAULT_SNAPSHOT_PATH
from .contract import initialize_contract, load_contract
from .paths import read_json_object, resolve_project_path, resolve_project_root, strict_json_loads


MAX_FEEDBACK_INPUT_CHARS = 1024 * 1024


class CLIArgumentError(ValueError):
	"""Raised when argparse would otherwise emit non-JSON process output."""


class CLIInteractionError(ValueError):
	"""Raised when a destructive command has no interactive human terminal."""


class JSONArgumentParser(argparse.ArgumentParser):
	def error(self, message: str) -> None:
		raise CLIArgumentError(message)


def main(argv: list[str] | None = None) -> int:
	_configure_stdio()
	parser = _make_parser()
	try:
		args = parser.parse_args(argv)
		project_root = resolve_project_root(args.project_root)
		result = _dispatch(args, project_root)
	except CLIArgumentError as exc:
		result = {"ok": False, "issues": [{"code": "invalid_arguments", "message": str(exc)}]}
	except CLIInteractionError as exc:
		result = {"ok": False, "status": "blocked", "issues": [{"code": "interactive_approval_required", "message": str(exc)}]}
	except (OSError, UnicodeDecodeError, ValueError, RuntimeError) as exc:
		result = {"ok": False, "issues": [str(exc)]}
	print(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
	return 0 if result.get("ok", False) else 1


def _make_parser() -> argparse.ArgumentParser:
	parser = JSONArgumentParser(description="GF project-side AI context and feedback CLI.")
	subparsers = parser.add_subparsers(dest="command", required=True)

	def command(name: str, help_text: str) -> argparse.ArgumentParser:
		child = subparsers.add_parser(name, help=help_text)
		child.add_argument("--project-root", default=".", help="Godot project root containing project.godot.")
		child.add_argument("--contract", default=DEFAULT_CONTRACT_PATH, help="Project-relative contract path.")
		return child

	command("init-contract", "Create a strict project intent contract without overwriting an existing one.")
	command("contract-migration-plan", "Plan a supported project contract migration without writing files.")
	contract_migrate = command("contract-migrate", "Atomically apply a reviewed project contract migration.")
	contract_migrate.add_argument(
		"--expected-plan-sha256",
		required=True,
		help="Exact reviewed plan hash returned by contract-migration-plan.",
	)
	command("validate", "Validate the project contract and declared-vs-observed drift.")
	command("context", "Return compact declared intent, observed facts, GF capabilities, and workflow.")
	snapshot_parser = command("snapshot", "Write the generated project snapshot under .gf/ai/.")
	snapshot_parser.add_argument("--output", default=DEFAULT_SNAPSHOT_PATH, help="Controlled project-relative output path.")
	context_plan = command("context-bundle-plan", "Plan an explicit, hash-bound offline context bundle without exporting content.")
	context_plan.add_argument("--file", action="append", default=[], help="Explicit project-relative UTF-8 file; repeat as needed.")
	context_plan.add_argument("--setting", action="append", default=[], help="Explicit project setting as section/key; repeat as needed.")
	context_export = command("context-bundle-export", "Interactively export one unchanged, reviewed context plan.")
	context_export.add_argument("--file", action="append", default=[], help="Exact file selection used by context-bundle-plan.")
	context_export.add_argument("--setting", action="append", default=[], help="Exact setting selection used by context-bundle-plan.")
	context_export.add_argument("--expected-plan-sha256", required=True, help="Exact reviewed plan hash.")

	capability_search = command("capability-search", "Search provider-neutral GF capabilities.")
	capability_search.add_argument("query")
	capability_search.add_argument("--limit", type=int, default=10)
	capability = command("capability", "Read one GF capability by stable id.")
	capability.add_argument("capability_id")
	api_search = command("api-search", "Search exact installed GF classes and members.")
	api_search.add_argument("query")
	api_search.add_argument("--limit", type=int, default=20)
	api_class = command("api-class", "Read one exact GF API class record.")
	api_class.add_argument("class_name")
	api_class.add_argument("--no-members", action="store_true")
	api_module = command("api-module", "Read a bounded summary of one exact GF API module.")
	api_module.add_argument("module_name")
	api_module.add_argument("--limit", type=int, default=100)
	package = command("package", "Read one GF package and its public class ownership.")
	package.add_argument("package_id")
	package.add_argument("--limit", type=int, default=100)
	recipe = command("recipe", "Read one GF project recipe by stable id.")
	recipe.add_argument("recipe_id")

	agent_install = command("agent-install", "Install or update managed project-local agent instructions.")
	agent_install.add_argument("--target", action="append", default=[])
	agent_install.add_argument("--dry-run", action="store_true")
	agent_install.add_argument("--replace-drifted", action="store_true", help="Explicitly replace modified GF-managed content.")
	command("agent-status", "Report installed and drifted project-local agent instructions.")
	agent_uninstall = command("agent-uninstall", "Remove only unchanged GF-managed agent instructions.")
	agent_uninstall.add_argument("--target", action="append", default=[])
	agent_uninstall.add_argument("--dry-run", action="store_true")

	feedback_analyze = command("feedback-analyze", "Classify and redact a structured GF feedback candidate.")
	feedback_analyze.add_argument("--input", required=True, help="Project-relative JSON path or - for stdin.")
	feedback_draft = command("feedback-draft", "Create a controlled, redacted GF issue draft.")
	feedback_draft.add_argument("--input", required=True, help="Project-relative JSON path or - for stdin.")
	feedback_prepare = command("feedback-prepare", "Return the exact payload and approval hash for a draft.")
	feedback_prepare.add_argument("--draft", required=True, help="Draft path under .gf/ai/feedback/.")
	feedback_duplicates = command("feedback-duplicates", "Check GitHub for the draft fingerprint.")
	feedback_duplicates.add_argument("--draft", required=True, help="Draft path under .gf/ai/feedback/.")
	feedback_submit = command("feedback-submit", "Submit an approved, unique draft through GitHub CLI.")
	feedback_submit.add_argument("--draft", required=True, help="Draft path under .gf/ai/feedback/.")
	feedback_submit.add_argument("--confirmation-sha256", required=True, help="Exact hash returned by feedback-prepare.")
	return parser


def _dispatch(args: argparse.Namespace, project_root: Path) -> dict[str, Any]:
	if args.command == "init-contract":
		return initialize_contract(project_root, args.contract)
	if args.command == "contract-migration-plan":
		return migration.plan_contract_migration(project_root, args.contract)
	if args.command == "contract-migrate":
		plan = migration.plan_contract_migration(project_root, args.contract)
		if not plan.get("ok"):
			return plan
		if plan.get("status") != "ready":
			return migration.apply_contract_migration(
				project_root,
				args.expected_plan_sha256,
				args.contract,
			)
		if args.expected_plan_sha256 != plan.get("plan_sha256"):
			return migration.apply_contract_migration(
				project_root,
				args.expected_plan_sha256,
				args.contract,
			)
		if not _confirm_contract_migration(plan, args.expected_plan_sha256):
			return {
				"ok": False,
				"status": "blocked",
				"issues": [{"code": "human_approval_required", "message": "Interactive human approval was not completed."}],
			}
		return migration.apply_contract_migration(
			project_root,
			args.expected_plan_sha256,
			args.contract,
			human_approved=True,
		)
	if args.command == "validate":
		contract_result = load_contract(project_root, args.contract)
		observed = snapshot.build_snapshot(project_root, args.contract)
		return {"ok": bool(contract_result["ok"]) and bool(observed["drift"]["ok"]), "contract": contract_result, "drift": observed["drift"]}
	if args.command == "context":
		return snapshot.project_context(project_root, args.contract)
	if args.command == "snapshot":
		return snapshot.write_snapshot(project_root, args.contract, args.output)
	if args.command == "context-bundle-plan":
		return context_bundle.plan_context_bundle(project_root, args.file, args.setting)
	if args.command == "context-bundle-export":
		plan = context_bundle.plan_context_bundle(project_root, args.file, args.setting)
		if plan["plan_sha256"] != args.expected_plan_sha256:
			return context_bundle.export_context_bundle(
				project_root,
				args.file,
				args.setting,
				args.expected_plan_sha256,
			)
		if not _confirm_context_export(plan, args.expected_plan_sha256):
			return {
				"ok": False,
				"status": "blocked",
				"issues": [{"code": "human_approval_required", "message": "Interactive human approval was not completed."}],
			}
		return context_bundle.export_context_bundle(
			project_root,
			args.file,
			args.setting,
			args.expected_plan_sha256,
			human_approved=True,
		)
	if args.command == "capability-search":
		return catalog.capability_search(args.query, args.limit, project_root)
	if args.command == "capability":
		return catalog.capability_by_id(args.capability_id, project_root)
	if args.command == "api-search":
		return catalog.api_search(args.query, args.limit, project_root)
	if args.command == "api-class":
		return catalog.api_class(args.class_name, not args.no_members, project_root)
	if args.command == "api-module":
		return catalog.api_module(args.module_name, args.limit, project_root)
	if args.command == "package":
		return catalog.package_by_id(args.package_id, args.limit, project_root)
	if args.command == "recipe":
		return catalog.recipe_by_id(args.recipe_id, project_root)
	if args.command == "agent-install":
		return adapters.install_agents(project_root, args.target, args.dry_run, args.replace_drifted)
	if args.command == "agent-status":
		return adapters.agent_status(project_root)
	if args.command == "agent-uninstall":
		return adapters.uninstall_agents(project_root, args.target, args.dry_run)
	if args.command == "feedback-analyze":
		return feedback.analyze_candidate(project_root, _read_input(project_root, args.input), args.contract)
	if args.command == "feedback-draft":
		return feedback.draft_feedback(project_root, _read_input(project_root, args.input), args.contract)
	if args.command == "feedback-prepare":
		draft = feedback.load_draft(project_root, args.draft)
		return feedback.prepare_submission(project_root, draft, args.contract)
	if args.command == "feedback-duplicates":
		draft = feedback.load_draft(project_root, args.draft)
		return feedback.check_duplicates(project_root, draft)
	if args.command == "feedback-submit":
		draft = feedback.load_draft(project_root, args.draft)
		prepared = feedback.prepare_submission(project_root, draft, args.contract)
		if not prepared.get("ready"):
			return prepared
		if not _confirm_submission(prepared, args.confirmation_sha256):
			return {
				"ok": False,
				"url": "",
				"issues": ["Interactive human approval was not completed."],
			}
		return feedback.submit_issue(
			project_root,
			draft,
			args.confirmation_sha256,
			args.contract,
			human_approved=True,
		)
	return {"ok": False, "issues": [f"Unknown command: {args.command}"]}


def _read_input(project_root: Path, raw_path: str) -> dict[str, Any]:
	if raw_path == "-":
		source = sys.stdin.read(MAX_FEEDBACK_INPUT_CHARS + 1)
		if len(source) > MAX_FEEDBACK_INPUT_CHARS:
			raise ValueError("Feedback input exceeds the one-megacharacter budget.")
		value = strict_json_loads(source)
		if not isinstance(value, dict):
			raise ValueError("Feedback input root must be a JSON object.")
		return value
	path = resolve_project_path(project_root, raw_path, must_exist=True)
	return read_json_object(path, max_bytes=1024 * 1024)


def _configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="strict")


def _confirm_submission(prepared: dict[str, Any], confirmation_sha256: str) -> bool:
	if confirmation_sha256 != prepared.get("confirmation_sha256"):
		return False
	if not sys.stdin.isatty() or not sys.stdout.isatty():
		raise CLIInteractionError("feedback-submit must run in an interactive human terminal.")
	expected = f"SUBMIT {confirmation_sha256}"
	print("\nThe following public GitHub issue will be created:", file=sys.stderr)
	print(f"Repository: {prepared.get('repository', '')}", file=sys.stderr)
	print(f"Title: {prepared.get('title', '')}", file=sys.stderr)
	print(str(prepared.get("body", "")), file=sys.stderr)
	print(f"Type exactly '{expected}' to approve: ", end="", file=sys.stderr, flush=True)
	return input().strip() == expected


def _confirm_contract_migration(plan: dict[str, Any], plan_sha256: str) -> bool:
	if plan_sha256 != plan.get("plan_sha256"):
		return False
	if not sys.stdin.isatty() or not sys.stdout.isatty():
		raise CLIInteractionError("contract-migrate must run in an interactive human terminal.")
	expected = f"MIGRATE {plan_sha256}"
	print("\nThe following project contract migration will be applied:", file=sys.stderr)
	print(json.dumps(plan.get("candidate", {}), ensure_ascii=False, indent=2, allow_nan=False), file=sys.stderr)
	print(f"Type exactly '{expected}' to approve: ", end="", file=sys.stderr, flush=True)
	return input().strip() == expected


def _confirm_context_export(plan: dict[str, Any], plan_sha256: str) -> bool:
	if plan_sha256 != plan.get("plan_sha256"):
		return False
	if not sys.stdin.isatty() or not sys.stdout.isatty():
		raise CLIInteractionError("context-bundle-export must run in an interactive human terminal.")
	expected = f"EXPORT {plan_sha256}"
	print("\nThe following untrusted project context will be exported locally:", file=sys.stderr)
	print(json.dumps(plan, ensure_ascii=False, indent=2, allow_nan=False), file=sys.stderr)
	print(f"Type exactly '{expected}' to approve: ", end="", file=sys.stderr, flush=True)
	return input().strip() == expected
