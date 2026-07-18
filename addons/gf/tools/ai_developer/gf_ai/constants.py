"""Stable constants and install-relative paths for the GF AI Developer Kit."""

from __future__ import annotations

from pathlib import Path


TOOL_VERSION = "1.0.0"
CONTRACT_SCHEMA_VERSION = 1
SNAPSHOT_SCHEMA_VERSION = 1
FEEDBACK_SCHEMA_VERSION = 1
DEFAULT_CONTRACT_NAME = "gf_project_contract.json"
DEFAULT_SNAPSHOT_PATH = ".gf/ai/project_snapshot.json"
DEFAULT_FEEDBACK_ROOT = ".gf/ai/feedback"
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
