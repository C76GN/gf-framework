"""Stable constants and install-relative paths for the GF AI Developer Kit."""

from __future__ import annotations

import json
from pathlib import Path


TOOL_VERSION = "2.0.0"
CONTRACT_SCHEMA_VERSION = 1
SNAPSHOT_SCHEMA_VERSION = 2
FEEDBACK_SCHEMA_VERSION = 1
DEFAULT_OFFICIAL_REPOSITORY = "C76GN/gf-framework"
MANAGED_BLOCK_START = "<!-- gf-ai-developer:start schema=1 -->"
MANAGED_BLOCK_END = "<!-- gf-ai-developer:end -->"


def find_kit_root() -> Path:
	"""Return the addon or generated plugin root that owns the data directories."""
	runtime_root = Path(__file__).resolve().parents[1]
	for candidate in (runtime_root, runtime_root.parent):
		if (candidate / "schemas/project_contract.schema.json").is_file():
			return candidate
	raise RuntimeError("GF AI Developer Kit data root is incomplete.")


KIT_ROOT = find_kit_root()
SCHEMA_ROOT = KIT_ROOT / "schemas"
KNOWLEDGE_ROOT = KIT_ROOT / "knowledge"
TEMPLATE_ROOT = KIT_ROOT / "templates"


_ARTIFACT_PATH_KEYS = {
	"generated_root",
	"access_output_path",
	"project_access_output_path",
	"config_access_output_path",
	"network_output_root",
	"project_state_root",
	"project_contract_path",
	"ai_output_root",
	"ai_snapshot_path",
	"ai_feedback_root",
}


def find_artifact_policy_path() -> Path:
	"""Return the canonical policy mirror in an installed plugin or GF addon tree."""
	candidates = (
		KIT_ROOT / "project_artifact_policy.json",
		KIT_ROOT.parents[1] / "kernel/core/project_artifact_policy.json",
	)
	for candidate in candidates:
		if candidate.is_file():
			return candidate
	raise RuntimeError("GF project artifact path policy is missing.")


def load_artifact_paths() -> dict[str, str]:
	"""Load and strictly validate the cross-runtime project artifact path policy."""
	path = find_artifact_policy_path()
	try:
		data = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_strict_json_object)
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		raise RuntimeError(f"GF project artifact path policy is invalid: {path}: {exc}") from exc
	if not isinstance(data, dict) or set(data) != {"schema_version", "paths"}:
		raise RuntimeError("GF project artifact path policy root fields are invalid.")
	if data.get("schema_version") != 1 or isinstance(data.get("schema_version"), bool):
		raise RuntimeError("GF project artifact path policy schema_version must be 1.")
	paths = data.get("paths")
	if not isinstance(paths, dict) or set(paths) != _ARTIFACT_PATH_KEYS:
		raise RuntimeError("GF project artifact path policy path fields are invalid.")
	if any(not isinstance(value, str) or not value for value in paths.values()):
		raise RuntimeError("GF project artifact paths must be non-empty strings.")
	generated_root = paths["generated_root"].rstrip("/")
	for key in ("access_output_path", "project_access_output_path", "config_access_output_path", "network_output_root"):
		if not paths[key].startswith(generated_root + "/"):
			raise RuntimeError(f"GF generated artifact path escapes generated_root: {key}.")
	state_root = paths["project_state_root"].rstrip("/")
	for key in ("project_contract_path", "ai_output_root", "ai_snapshot_path", "ai_feedback_root"):
		if not paths[key].startswith(state_root + "/"):
			raise RuntimeError(f"GF project-state path escapes project_state_root: {key}.")
	for key, value in paths.items():
		normalized = value.replace("\\", "/")
		if normalized != value or any(part in ("", ".", "..") for part in normalized.removeprefix("res://").split("/")):
			raise RuntimeError(f"GF project artifact path is not canonical: {key}.")
	return {str(key): str(value) for key, value in paths.items()}


def _strict_json_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
	result: dict[str, object] = {}
	for key, value in pairs:
		if key in result:
			raise ValueError(f"Duplicate JSON object key is not allowed: {key!r}.")
		result[key] = value
	return result


ARTIFACT_POLICY_PATH = find_artifact_policy_path()
PROJECT_ARTIFACT_PATHS = load_artifact_paths()
DEFAULT_CONTRACT_PATH = PROJECT_ARTIFACT_PATHS["project_contract_path"]
DEFAULT_SNAPSHOT_PATH = PROJECT_ARTIFACT_PATHS["ai_snapshot_path"]
DEFAULT_FEEDBACK_ROOT = PROJECT_ARTIFACT_PATHS["ai_feedback_root"]
