"""One source-bound layout plan shared by diagnostics and formatting previews.

The planners propose canonical layout. Only the horizontal token-gap subset has
an automatic-write proof; changes to suites, physical lines, or syntax remain
reviewable suggestions. Capturing a plan never changes source or relaxes checks.
"""

from __future__ import annotations

from bisect import bisect_right
from dataclasses import dataclass
import difflib
import hashlib
import json

import gf_gdscript_readability as readability


MAX_FORMAT_BYTES = 512 * 1024
MAX_FORMAT_LINES = 10_000
MAX_PREVIEW_PASSES = 8


@dataclass(frozen=True)
class FormatEdit:
	start: int
	end: int
	replacement: str
	rule: str
	phase: str
	line: int
	column: int
	message: str


@dataclass(frozen=True)
class FormatPlan:
	path: str
	source: str
	edits: tuple[FormatEdit, ...]
	_lexical_issues: str = "[]"

	@classmethod
	def capture(cls, path: str, source: str) -> FormatPlan:
		return cls.from_view(path, readability.lex_source(path, source))

	@classmethod
	def from_view(cls, path: str, view: readability.LexedSource) -> FormatPlan:
		from gf_gdscript_list_layout import layout_edits as list_edits
		from gf_gdscript_expression_layout import layout_edits as expression_edits
		from gf_gdscript_layout_integrity import layout_edits as integrity_edits

		if view.issues:
			return cls(path, view.source, (), json.dumps(view.issues, ensure_ascii=False))
		starts = [0, *(index + 1 for index, value in enumerate(view.source) if value == "\n")]
		edits = []
		for phase, decisions in (
			("list", list_edits(view, max_inline_items=readability.MAX_INLINE_LIST_ITEMS)),
			("expression", expression_edits(view, max_inline_items=readability.MAX_INLINE_LIST_ITEMS)),
			("integrity", integrity_edits(view)),
		):
			for edit in decisions:
				if not 0 <= edit.start <= edit.end <= len(view.source) or edit.rule not in readability.RULES:
					raise ValueError("Invalid canonical layout decision.")
				line = bisect_right(starts, edit.start)
				edits.append(FormatEdit(
					edit.start, edit.end, edit.replacement, edit.rule, phase,
					getattr(edit, "line", line), 1 if phase == "integrity" else edit.start - starts[line - 1] + 1,
					getattr(edit, "message", "This syntax structure does not use its canonical layout."),
				))
		return cls(path, view.source, tuple(edits))

	@property
	def source_sha256(self) -> str:
		return hashlib.sha256(self.source.encode("utf-8")).hexdigest()

	def diagnostics(self) -> list[dict]:
		issues = json.loads(self._lexical_issues)
		observed = set()
		for edit in self.edits:
			key = (edit.rule, edit.line)
			if edit.phase != "integrity" and key in observed:
				continue
			observed.add(key)
			issues.append(readability._issue(
				self.path, edit.rule, edit.line, edit.column, edit.message,
				"Preview the concrete diff with tools/gf_gdscript_format.py --path <file>; only proven horizontal token spacing supports --write.",
			))
		return issues

	def _bounded_preview(self) -> None:
		if len(self.source.encode("utf-8")) > MAX_FORMAT_BYTES or self.source.count("\n") > MAX_FORMAT_LINES:
			raise ValueError("Formatting preview exceeds its source budget; repository checks remain available.")
		if self._lexical_issues != "[]":
			raise ValueError("Formatting requires a complete lexical view.")

	def suggested_source(self) -> str:
		"""Resolve overlapping planner phases sequentially, with bounded convergence."""
		self._bounded_preview()
		source = self.source
		seen = set()
		for _ in range(MAX_PREVIEW_PASSES):
			if source in seen:
				raise ValueError("Layout preview did not converge; no source was written.")
			seen.add(source)
			previous = source
			for phase in ("list", "expression", "integrity"):
				plan = self if source == self.source else self.capture(self.path, source)
				plan._bounded_preview()
				source = _replace(source, tuple(edit for edit in plan.edits if edit.phase == phase))
			if source == previous:
				return source
		raise ValueError("Layout preview pass budget exhausted; no source was written.")

	def safe_source(self) -> str:
		"""Prove token/comment payloads, physical lines and all indentation unchanged.

		Node shorthand has whitespace-sensitive path syntax, so its whole physical
		line is excluded. No syntax carrier, newline, indentation, literal, or
		comment edit is ever admitted by this proof.
		"""
		self._bounded_preview()
		if not self.path.endswith(".gd"):
			raise ValueError("Automatic writes support .gd sources only; templates are preview-only.")
		before = readability.lex_source(self.path, self.source)
		candidate = _replace(self.source, self._safe_edits(before))
		after = readability.lex_source(self.path, candidate)
		if after.issues or _semantic_layout_signature(before) != _semantic_layout_signature(after):
			raise ValueError("Horizontal spacing proof failed; no source was written.")
		if candidate != self.source and self.capture(self.path, candidate)._safe_edits(after):
			raise ValueError("Horizontal spacing is not idempotent; no source was written.")
		return candidate

	def _safe_edits(self, view: readability.LexedSource) -> tuple[FormatEdit, ...]:
		gaps = {(left.end, right.start) for left, right in zip(view.tokens, view.tokens[1:]) if left.end_line == right.line}
		path_lines = {token.line for token in view.tokens if token.value in {"$", "%"}}
		return tuple(edit for edit in self.edits if (
			edit.phase == "integrity" and edit.rule == "token_spacing"
			and edit.line not in path_lines
			and (edit.start, edit.end) in gaps
			and set(self.source[edit.start:edit.end] + edit.replacement) <= {" ", "\t"}
		))

	def diff(self, candidate: str) -> str:
		return "".join(difflib.unified_diff(
			self.source.splitlines(keepends=True), candidate.splitlines(keepends=True),
			fromfile=self.path, tofile=self.path + " (suggested)",
		))


def _replace(source: str, edits: tuple[FormatEdit, ...]) -> str:
	ordered = sorted(edits, key=lambda edit: (edit.start, edit.end))
	for left, right in zip(ordered, ordered[1:]):
		if left.end > right.start or left.start == right.start:
			raise ValueError("Layout decisions overlap within a planner phase.")
	for edit in reversed(ordered):
		source = source[:edit.start] + edit.replacement + source[edit.end:]
	return source


def _semantic_layout_signature(view: readability.LexedSource) -> tuple:
	return (
		tuple((token.kind, token.value, token.line, token.end_line) for token in view.tokens),
		tuple((token.kind, token.value, token.line, token.end_line) for token in view.comments),
		tuple(line[:len(line) - len(line.lstrip(" \t"))] for line in view.source.split("\n")),
	)
