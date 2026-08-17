"""Resolve GF public API owners without treating AutoLoads as class_name types."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any, Iterable

import build_gf_package
from gdscript_api_parser import ApiClass
from gdscript_api_parser import ApiMember
from gdscript_api_parser import ApiScript
from gdscript_api_parser import PUBLIC_API_VISIBILITIES
from gdscript_api_parser import collect_api_scripts
from gdscript_api_parser import parse_gdscript_file
from gdscript_api_parser import scan_gdscript_structure
from gdscript_api_parser import visibility_of


ROOT = Path(__file__).resolve().parents[1]
OWNER_KIND_CLASS = "class"
OWNER_KIND_AUTOLOAD = "autoload"
OWNER_KINDS = frozenset({OWNER_KIND_CLASS, OWNER_KIND_AUTOLOAD})


@dataclass(frozen=True)
class ApiAutoloadContract:
	name: str
	source_path: str
	resource_path: str
	package_id: str
	registration_script_path: str
	runtime_resolver_script_path: str


@dataclass(frozen=True)
class ApiOwner:
	kind: str
	name: str
	script: ApiScript
	package_id: str = ""

	def to_api_class(self) -> ApiClass | None:
		return self.script.to_api_class() if self.kind == OWNER_KIND_CLASS else None


GF_AUTOLOAD_CONTRACT = ApiAutoloadContract(
	name="Gf",
	source_path="addons/gf/kernel/core/gf.gd",
	resource_path="res://addons/gf/kernel/core/gf.gd",
	package_id="gf.kernel",
	registration_script_path="addons/gf/kernel/editor/gf_plugin_autoload.gd",
	runtime_resolver_script_path="addons/gf/kernel/core/gf_autoload.gd",
)
CONTROLLED_AUTOLOAD_CONTRACTS = (GF_AUTOLOAD_CONTRACT,)


def collect_api_owners(
	source_root: Path,
	root: Path = ROOT,
	package_records: list[dict[str, Any]] | None = None,
) -> list[ApiOwner]:
	scripts = collect_api_scripts(source_root, root)
	owners = select_api_owners(scripts, CONTROLLED_AUTOLOAD_CONTRACTS)
	validate_controlled_autoloads(owners, root, CONTROLLED_AUTOLOAD_CONTRACTS)
	return resolve_api_owner_packages(owners, package_records, root)


def select_api_owners(
	api_scripts: list[ApiScript],
	autoload_contracts: tuple[ApiAutoloadContract, ...] = CONTROLLED_AUTOLOAD_CONTRACTS,
) -> list[ApiOwner]:
	contracts_by_path = {contract.source_path: contract for contract in autoload_contracts}
	if len(contracts_by_path) != len(autoload_contracts):
		raise ValueError("controlled API autoload source paths must be unique")
	result: list[ApiOwner] = []
	observed_autoload_paths: set[str] = set()

	for script in api_scripts:
		if script.class_name:
			if script.api_owner_kind or script.api_owner_name:
				raise ValueError(
					f"class_name API script cannot also declare @api_owner: {script.path}"
				)
			if visibility_of(script.docs) not in PUBLIC_API_VISIBILITIES:
				continue
			filtered = _filter_public_script(script)
			result.append(ApiOwner(OWNER_KIND_CLASS, script.class_name, filtered))
			continue

		public_members = _public_script_members(script)
		contract = contracts_by_path.get(script.path)
		if contract is None:
			if public_members or script.api_owner_kind or script.api_owner_name:
				raise ValueError(
					"classless public API script has no controlled owner contract: "
					f"{script.path}"
				)
			continue

		if script.api_owner_kind != OWNER_KIND_AUTOLOAD or script.api_owner_name != contract.name:
			raise ValueError(
				"controlled API autoload declaration does not match its contract: "
				f"{script.path} expected '@api_owner autoload {contract.name}'"
			)
		if visibility_of(script.docs) not in PUBLIC_API_VISIBILITIES:
			raise ValueError(f"controlled API autoload owner is not public/protected: {script.path}")
		if not public_members:
			raise ValueError(f"controlled API autoload owner has no public surface: {script.path}")
		if script.extends != "Node":
			raise ValueError(
				f"controlled API autoload must extend Node exactly: {script.path}: {script.extends!r}"
			)
		observed_autoload_paths.add(script.path)
		result.append(ApiOwner(OWNER_KIND_AUTOLOAD, contract.name, _filter_public_script(script)))

	stale_paths = set(contracts_by_path) - observed_autoload_paths
	if stale_paths:
		raise ValueError(
			"controlled API autoload contract is stale or its source is missing: "
			+ ", ".join(sorted(stale_paths))
		)
	_validate_owner_identities(result)
	return result


def validate_controlled_autoloads(
	owners: list[ApiOwner],
	root: Path = ROOT,
	autoload_contracts: tuple[ApiAutoloadContract, ...] = CONTROLLED_AUTOLOAD_CONTRACTS,
) -> None:
	owners_by_source = {owner.script.path: owner for owner in owners if owner.kind == OWNER_KIND_AUTOLOAD}
	for contract in autoload_contracts:
		owner = owners_by_source.get(contract.source_path)
		if owner is None:
			raise ValueError(f"controlled API autoload owner is missing: {contract.source_path}")
		if owner.name != contract.name or owner.script.path != contract.source_path:
			raise ValueError(f"controlled API autoload identity drifted: {contract.source_path}")

		registration_path = root / contract.registration_script_path
		runtime_resolver_path = root / contract.runtime_resolver_script_path
		for path in (registration_path, runtime_resolver_path):
			if not path.is_file():
				raise ValueError(f"controlled API autoload support script is missing: {path}")
		registration = parse_gdscript_file(registration_path, root / "addons/gf", root)
		runtime_resolver = parse_gdscript_file(runtime_resolver_path, root / "addons/gf", root)
		registration_name = _string_constant_value(registration, "AUTOLOAD_NAME")
		registration_path_value = _string_constant_value(registration, "AUTOLOAD_PATH")
		runtime_name = _string_constant_value(runtime_resolver, "AUTOLOAD_NAME")
		if registration_name != contract.name:
			raise ValueError("GF plugin autoload name does not match the API owner declaration")
		if registration_path_value != contract.resource_path:
			raise ValueError("GF plugin autoload path does not match the API owner source")
		if runtime_name != contract.name:
			raise ValueError("GF runtime autoload resolver name does not match the API owner declaration")
		registration_source = registration_path.read_text(encoding="utf-8")
		if not _uses_controlled_autoload_registration_call(registration_source):
			raise ValueError("GF plugin autoload registration must use AUTOLOAD_NAME and AUTOLOAD_PATH")


def resolve_api_owner_packages(
	owners: list[ApiOwner],
	package_records: list[dict[str, Any]] | None = None,
	root: Path = ROOT,
) -> list[ApiOwner]:
	if package_records is None:
		manifest_load = build_gf_package.load_package_manifests()
		if manifest_load.get("issues"):
			raise ValueError(
				"Package manifests are invalid: " + "; ".join(manifest_load["issues"][:10])
			)
		package_records = [
			record for record in manifest_load["records"]
			if record.get("kind") != "preset"
		]

	candidates: dict[str, list[str]] = {}
	for record in package_records:
		file_issues: list[str] = []
		files = build_gf_package.collect_package_files(record, file_issues)
		if file_issues:
			raise ValueError(
				f"Package {record.get('id', '')} is invalid: " + "; ".join(file_issues[:10])
			)
		for path in files:
			relative = path.relative_to(root).as_posix()
			candidates.setdefault(relative, []).append(str(record.get("id", "")))

	contracts_by_path = {
		contract.source_path: contract for contract in CONTROLLED_AUTOLOAD_CONTRACTS
	}
	resolved: list[ApiOwner] = []
	for owner in owners:
		package_ids = sorted(set(candidates.get(owner.script.path, [])))
		if len(package_ids) != 1:
			raise ValueError(
				"API owner source must belong to exactly one package: "
				f"{owner.name} ({owner.script.path}) -> {package_ids}"
			)
		package_id = package_ids[0]
		contract = contracts_by_path.get(owner.script.path)
		if contract is not None and package_id != contract.package_id:
			raise ValueError(
				f"controlled API autoload package drifted: {owner.name}: "
				f"{package_id} != {contract.package_id}"
			)
		resolved.append(replace(owner, package_id=package_id))
	return resolved


def class_owners(owners: Iterable[ApiOwner]) -> list[ApiOwner]:
	return [owner for owner in owners if owner.kind == OWNER_KIND_CLASS]


def autoload_owners(owners: Iterable[ApiOwner]) -> list[ApiOwner]:
	return [owner for owner in owners if owner.kind == OWNER_KIND_AUTOLOAD]


def _filter_public_script(script: ApiScript) -> ApiScript:
	return replace(
		script,
		signals=_filter_public_members(script.signals),
		enums=_filter_public_members(script.enums),
		constants=_filter_public_members(script.constants),
		properties=_filter_public_members(script.properties),
		methods=_filter_public_members(script.methods),
		inner_classes=[
			filtered
			for inner_class in script.inner_classes
			if (filtered := _filter_public_inner_class(inner_class)) is not None
		],
	)


def _filter_public_inner_class(api_class: ApiClass) -> ApiClass | None:
	if visibility_of(api_class.docs) not in PUBLIC_API_VISIBILITIES:
		return None
	return replace(
		api_class,
		signals=_filter_public_members(api_class.signals),
		enums=_filter_public_members(api_class.enums),
		constants=_filter_public_members(api_class.constants),
		properties=_filter_public_members(api_class.properties),
		methods=_filter_public_members(api_class.methods),
		inner_classes=[
			filtered
			for inner_class in api_class.inner_classes
			if (filtered := _filter_public_inner_class(inner_class)) is not None
		],
	)


def _filter_public_members(members: list[ApiMember]) -> list[ApiMember]:
	return [member for member in members if visibility_of(member.docs) in PUBLIC_API_VISIBILITIES]


def _public_script_members(script: ApiScript) -> list[ApiMember]:
	return _filter_public_members([
		*script.signals,
		*script.enums,
		*script.constants,
		*script.properties,
		*script.methods,
	])


def _validate_owner_identities(owners: list[ApiOwner]) -> None:
	identities: dict[str, ApiOwner] = {}
	for owner in owners:
		if owner.kind not in OWNER_KINDS:
			raise ValueError(f"unsupported API owner kind: {owner.kind!r}")
		identity = owner.name.casefold()
		previous = identities.get(identity)
		if previous is not None:
			raise ValueError(
				"API owner identity collision across owner kinds: "
				f"{previous.kind}:{previous.name} and {owner.kind}:{owner.name}"
			)
		identities[identity] = owner


def _string_constant_value(script: ApiScript, name: str) -> str:
	matches = [member for member in script.constants if member.name == name]
	if len(matches) != 1:
		raise ValueError(f"controlled API autoload constant is missing or duplicated: {script.path}:{name}")
	signature = matches[0].signature.strip()
	match = re.fullmatch(
		rf"const\s+{re.escape(name)}\s*:\s*(?:String|StringName)\s*=\s*&?(\"(?:[^\"\\]|\\.)*\")",
		signature,
	)
	if match is None:
		raise ValueError(f"controlled API autoload constant must be a string literal: {script.path}:{name}")
	try:
		value = json.loads(match.group(1))
	except json.JSONDecodeError as exc:
		raise ValueError(f"controlled API autoload constant is invalid: {script.path}:{name}") from exc
	if not isinstance(value, str) or not value:
		raise ValueError(f"controlled API autoload constant is empty: {script.path}:{name}")
	return value


def _uses_controlled_autoload_registration_call(source: str) -> bool:
	structural_lines, _starts_in_multiline = scan_gdscript_structure(source.splitlines())
	structural_source = "\n".join(structural_lines)
	return re.search(
		r"(?m)^[ \t]*plugin\s*\.\s*add_autoload_singleton\s*"
		r"\(\s*AUTOLOAD_NAME\s*,\s*AUTOLOAD_PATH\s*\)",
		structural_source,
	) is not None
