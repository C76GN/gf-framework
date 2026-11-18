"""GF release and development branches, evaluated against exact Git commits."""

from __future__ import annotations

import configparser
import os
import re
from collections.abc import Callable
from pathlib import Path
from typing import Any

from gf_maintenance_check_graph import run_git_bytes
from gf_process_authority import FrozenProcessEnvironment, freeze_git_process


STABLE_SEMVER_RE = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
COMMIT_SHA_RE = re.compile(r"^[0-9a-f]{40}$")
NEW_BRANCH_BEFORE_SHA = "0" * 40
PLUGIN_CONFIG = "addons/gf/plugin.cfg"


class BranchWorkflowError(ValueError):
	pass


class UnpublishedReleaseError(BranchWorkflowError):
	pass


class BranchHistory:
	def __init__(self, root: Path) -> None:
		self.root = root
		self.git_process = freeze_git_process(FrozenProcessEnvironment.capture(os.environ), cwd=root)

	def git(self, *args: str) -> str:
		return run_git_bytes(self.root, list(args), git_process=self.git_process).decode("utf-8").strip()

	def commit(self, ref: str) -> str:
		return require_commit_sha(self.git("rev-parse", "--verify", f"{ref}^{{commit}}"))

	def branch_commit(self, branch: str) -> str:
		return self.commit(f"refs/remotes/origin/{branch}")

	def find_branch_commit(self, branch: str) -> str | None:
		ref = f"refs/remotes/origin/{branch}"
		for line in self.git("for-each-ref", "--format=%(refname) %(objectname)", ref).splitlines():
			name, _, sha = line.partition(" ")
			if name == ref:
				return require_commit_sha(sha)
		return None

	def version(self, commit_sha: str) -> str:
		return parse_plugin_version(self.git("show", f"{require_commit_sha(commit_sha)}:{PLUGIN_CONFIG}"))

	def contains(self, descendant: str, ancestor: str) -> bool:
		return self.git("merge-base", require_commit_sha(descendant), require_commit_sha(ancestor)) == ancestor

	def merge_bases(self, first: str, second: str) -> list[str]:
		return self.git("merge-base", "--all", require_commit_sha(first), require_commit_sha(second)).splitlines()

	def has_tag(self, version: str) -> bool:
		return self.git("tag", "--list", version) == version

	def require_tag_at(self, version: str, commit_sha: str) -> None:
		if STABLE_SEMVER_RE.fullmatch(version) is None:
			raise BranchWorkflowError(f"Release tag must be a stable SemVer, got {version!r}.")
		ref = f"refs/tags/{version}"
		if self.git("cat-file", "-t", ref) != "tag" or self.commit(ref) != commit_sha:
			raise BranchWorkflowError(f"Annotated tag {version} must point to {commit_sha}.")


def require_commit_sha(value: str) -> str:
	if COMMIT_SHA_RE.fullmatch(value) is None or value == NEW_BRANCH_BEFORE_SHA:
		raise BranchWorkflowError(f"Expected a full Git commit SHA, got {value!r}.")
	return value


def parse_plugin_version(source: str) -> str:
	config = configparser.ConfigParser()
	config.read_string(source)
	return config.get("plugin", "version", fallback="").strip().strip('"')


def development_version_of(version: str, target: str) -> bool:
	return re.fullmatch(re.escape(target) + r"-dev\.(0|[1-9][0-9]*)", version) is not None


def next_release_versions(stable_version: str) -> tuple[str, str]:
	stable = STABLE_SEMVER_RE.fullmatch(stable_version)
	if stable is None:
		raise BranchWorkflowError(f"Expected a stable release version, got {stable_version!r}.")
	major, minor, patch = map(int, stable.groups())
	return f"{major + 1}.0.0", f"{major}.{minor}.{patch + 1}"


def stable_main_version(policy: dict[str, Any], version: str) -> bool:
	stable = STABLE_SEMVER_RE.fullmatch(version)
	if stable is None:
		if development_version_of(version, policy["cutover_release"]):
			return False
		raise BranchWorkflowError(f"Unexpected {policy['default_branch']} version {version!r}.")
	cutover = policy["cutover_release"]
	if int(stable[1]) < int(cutover.split(".")[0]):
		raise BranchWorkflowError(f"Expected {policy['default_branch']} to reach cutover release {cutover}.")
	return True


def validate_pull_route(
	policy: dict[str, Any],
	history: BranchHistory,
	*,
	base_ref: str,
	head_ref: str,
	base_sha: str,
	head_sha: str,
	internal: bool,
	merged_version: str,
	require_published: Callable[[str], None],
) -> str | None:
	"""Return the stable release candidate version, if this PR prepares one."""
	require_commit_sha(base_sha)
	require_commit_sha(head_sha)
	main_branch = policy["default_branch"]
	development_branch = policy["development_branch"]
	cutover = policy["cutover_release"]
	main_sha = base_sha if base_ref == main_branch else history.branch_commit(main_branch)
	main_version = history.version(main_sha)
	if not stable_main_version(policy, main_version):
		if base_ref != main_branch:
			raise BranchWorkflowError(f"Publish {cutover} before opening {development_branch} to pull requests.")
		if development_version_of(merged_version, cutover):
			if internal and head_ref.startswith(("release/", "hotfix/", "sync/")):
				raise BranchWorkflowError(f"Use a development topic branch or prepare release/{cutover}.")
			return None
		if merged_version != cutover or not internal or head_ref != f"release/{cutover}":
			raise BranchWorkflowError(f"Publish {cutover} from the internal release/{cutover} branch.")
		require_stable_ancestry(history, development_branch, head_sha, main_sha)
		return require_release_candidate(history, head_sha, main_sha, cutover, require_published)

	next_major, next_patch = next_release_versions(main_version)
	if base_ref == main_branch and policy["abandoned_release_tags"].get(main_version) == main_sha:
		if not internal or head_ref != f"release/{next_patch}" or merged_version != next_patch:
			raise BranchWorkflowError(f"Recover the abandoned {main_version} through release/{next_patch}.")
		require_abandoned_candidate(history, main_version, main_sha, require_published)
		require_stable_ancestry(history, development_branch, head_sha, main_sha)
		return require_release_candidate(history, head_sha, main_sha, next_patch, require_published)

	if (
		base_ref == main_branch
		and internal
		and head_ref == f"release/{main_version}"
		and merged_version == main_version
	):
		require_stable_ancestry(history, development_branch, head_sha, main_sha)
		return require_release_candidate(history, head_sha, main_sha, main_version, require_published)

	require_published(main_version)
	history.require_tag_at(main_version, main_sha)
	if base_ref == main_branch:
		if not internal:
			raise BranchWorkflowError(f"Release and hotfix PRs to {main_branch} must come from this repository.")
		if head_ref == f"hotfix/{next_patch}" and merged_version == next_patch:
			require_stable_ancestry(history, development_branch, head_sha, main_sha)
			return require_release_candidate(history, head_sha, main_sha, next_patch, require_published)
		if head_ref != f"release/{next_major}" or merged_version != next_major:
			raise BranchWorkflowError(
				f"{main_branch} accepts release/{next_major} or hotfix/{next_patch} with matching stable metadata."
			)
		development_sha = history.branch_commit(development_branch)
		if not development_version_of(history.version(development_sha), next_major):
			raise BranchWorkflowError(f"{development_branch} must target {next_major} before promotion.")
		if not history.contains(development_sha, main_sha) or not history.contains(head_sha, development_sha):
			raise BranchWorkflowError(f"Prepare release/{next_major} from current, synchronized {development_branch}.")
		return require_release_candidate(history, head_sha, main_sha, next_major, require_published)

	if not development_version_of(merged_version, next_major):
		raise BranchWorkflowError(f"{development_branch} must target {next_major}-dev.N.")
	if history.contains(base_sha, main_sha):
		if internal and head_ref.startswith(("release/", "hotfix/", "sync/")):
			raise BranchWorkflowError(f"Use a development topic branch for work targeting {development_branch}.")
		return None
	if not internal or head_ref != f"sync/{main_version}":
		raise BranchWorkflowError(f"Merge {main_branch} into {development_branch} via sync/{main_version} first.")
	if (
		not history.contains(head_sha, main_sha)
		or not history.contains(head_sha, base_sha)
		or history.version(head_sha) != merged_version
	):
		raise BranchWorkflowError(
			f"sync/{main_version} must contain both branch tips and carry {next_major}-dev.N on its own head."
		)
	return None


def require_stable_ancestry(
	history: BranchHistory, development_branch: str, head_sha: str, main_sha: str,
) -> None:
	development_sha = history.find_branch_commit(development_branch)
	if development_sha is not None and any(
		not history.contains(main_sha, shared) for shared in history.merge_bases(head_sha, development_sha)
	):
		raise BranchWorkflowError("A stable-line candidate must start from main without development ancestry.")


def require_release_candidate(
	history: BranchHistory,
	head_sha: str,
	main_sha: str,
	version: str,
	require_published: Callable[[str], None],
) -> str:
	if history.version(head_sha) != version or not history.contains(head_sha, main_sha):
		raise BranchWorkflowError(f"Release candidate must carry {version} and include the current main commit.")
	if history.has_tag(version):
		raise BranchWorkflowError(f"The {version} tag already exists. Keep release tags immutable.")
	require_unpublished(version, require_published)
	return version


def require_unpublished(version: str, require_published: Callable[[str], None]) -> None:
	try:
		require_published(version)
	except UnpublishedReleaseError:
		return
	raise BranchWorkflowError(f"The official release {version} already exists.")


def require_abandoned_candidate(
	history: BranchHistory, version: str, commit: str, require_published: Callable[[str], None],
) -> None:
	history.require_tag_at(version, commit)
	require_unpublished(version, require_published)


def validate_branch_push(
	policy: dict[str, Any],
	history: BranchHistory,
	branch: str,
	before_sha: str,
	head_sha: str,
	require_published: Callable[[str], None],
) -> None:
	main_branch = policy["default_branch"]
	version = history.version(head_sha)
	if branch == main_branch:
		before_version = history.version(before_sha)
		if not history.contains(head_sha, before_sha):
			raise BranchWorkflowError(f"{main_branch} push must preserve prior history.")
		if not stable_main_version(policy, before_version):
			cutover = policy["cutover_release"]
			if development_version_of(version, cutover):
				return
			allowed = version == cutover
		elif policy["abandoned_release_tags"].get(before_version) == before_sha:
			require_abandoned_candidate(history, before_version, before_sha, require_published)
			allowed = version == next_release_versions(before_version)[1]
		elif version == before_version:
			if not history.has_tag(version):
				require_unpublished(version, require_published)
			allowed = True
		else:
			require_published(before_version)
			history.require_tag_at(before_version, before_sha)
			allowed = version in next_release_versions(before_version)
		if not allowed:
			raise BranchWorkflowError(f"Invalid {main_branch} version transition {before_version} -> {version}.")
		if history.has_tag(version):
			history.require_tag_at(version, head_sha)
		return

	if branch != policy["development_branch"]:
		raise BranchWorkflowError(f"Branch {branch!r} is outside this workflow.")
	main_sha = history.branch_commit(main_branch)
	main_version = history.version(main_sha)
	if not stable_main_version(policy, main_version):
		raise BranchWorkflowError(f"Publish {policy['cutover_release']} before creating {branch}.")
	require_published(main_version)
	history.require_tag_at(main_version, main_sha)
	if before_sha == NEW_BRANCH_BEFORE_SHA:
		if head_sha != main_sha:
			raise BranchWorkflowError(f"Create {branch} at the published {main_version} commit.")
		return
	next_major, _ = next_release_versions(main_version)
	if not history.contains(head_sha, before_sha) or not history.contains(head_sha, main_sha):
		raise BranchWorkflowError(f"{branch} must preserve prior history and the published {main_version} commit.")
	if not development_version_of(version, next_major):
		raise BranchWorkflowError(f"{branch} must carry {next_major}-dev.N, got {version!r}.")


def validate_release_tag(policy: dict[str, Any], history: BranchHistory, version: str) -> None:
	main_branch = policy["default_branch"]
	main_sha = history.branch_commit(main_branch)
	if (
		version in policy["abandoned_release_tags"]
		or history.commit("HEAD") != main_sha
		or history.version(main_sha) != version
	):
		raise BranchWorkflowError(f"Release tag {version!r} must identify the current {main_branch} release commit.")
	history.require_tag_at(version, main_sha)
