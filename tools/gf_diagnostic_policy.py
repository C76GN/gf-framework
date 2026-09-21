"""Check framework-owned native diagnostic templates without executing GDScript.

This bounded lexer recognizes output calls and literal/constant templates. It is
not a GDScript compiler or a data-flow proof. Reviewed forwarding boundaries are
explicit, expression-bound records; arbitrary new dynamic output fails closed.
Runtime arguments (including translated project text and Unicode paths) are not
subject to the English template rule. Human review still owns wording and
severity semantics, while GUT owns observable emission and failure behavior.
"""

from __future__ import annotations

import json
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


SCHEMA_VERSION = 1
POLICY_PATH = "tools/gf_diagnostic_forwarders.json"
MAX_SOURCE_BYTES = 2 * 1024 * 1024
MAX_TOKENS = 300_000
MAX_DEPTH = 128
MAX_TEMPLATE_BYTES = 64 * 1024
MAX_ISSUES = 200
OUTPUTS = frozenset({"push_error", "push_warning"})
PREFIX = re.compile(r"^\[(GF[A-Za-z0-9]*)\]\[([a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+)\] (.+)$", re.DOTALL)
CODED_LITERAL = re.compile(r"^(?:\[GF[A-Za-z0-9]*\])?\[[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\] ")
OPEN = {"(": ")", "[": "]", "{": "}"}
CLOSE = frozenset(OPEN.values())


@dataclass(frozen=True)
class Token:

	kind: str
	value: str
	line: int
	start: int
	end: int


class SourceError(ValueError):
	pass


def tokenize(source: str) -> list[Token]:
	"""Keep decoded strings and offsets; comments never become call sites."""
	if len(source.encode("utf-8")) > MAX_SOURCE_BYTES:
		raise SourceError("Source exceeds the diagnostic scan budget.")
	tokens: list[Token] = []
	i, line = 0, 1
	while i < len(source):
		character = source[i]
		if character.isspace():
			line += character == "\n"
			i += 1
			continue
		if character == "#":
			end = source.find("\n", i)
			i = len(source) if end < 0 else end
			continue
		start, start_line = i, line
		raw = character == "r" and i + 1 < len(source) and source[i + 1] in "\"'"
		if character in "\"'" or raw:
			if raw:
				i += 1
			quote = source[i]
			triple = source.startswith(quote * 3, i)
			delimiter = quote * (3 if triple else 1)
			i += len(delimiter)
			parts: list[str] = []
			while i < len(source) and not source.startswith(delimiter, i):
				character = source[i]
				if character == "\n":
					if not triple:
						raise SourceError("Unterminated single-line string.")
					line += 1
				if character != "\\":
					parts.append(character)
					i += 1
					continue
				if i + 1 >= len(source):
					raise SourceError("Unterminated string escape.")
				escaped = source[i + 1]
				if raw:
					parts.append(source[i:i + 2])
					line += escaped == "\n"
					i += 2
					continue
				if escaped in "uU":
					width = 4 if escaped == "u" else 6
					digits = source[i + 2:i + 2 + width]
					if len(digits) != width or re.fullmatch(r"[0-9a-fA-F]+", digits) is None:
						raise SourceError("Invalid Unicode escape.")
					try:
						parts.append(chr(int(digits, 16)))
					except ValueError as error:
						raise SourceError("Invalid Unicode code point.") from error
					i += 2 + width
					continue
				escapes = {"n": "\n", "r": "\r", "t": "\t", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "\\": "\\", "\"": "\"", "'": "'", "\n": ""}
				if escaped not in escapes:
					raise SourceError("Unsupported string escape.")
				parts.append(escapes[escaped])
				line += escaped == "\n"
				i += 2
			if i >= len(source):
				raise SourceError("Unterminated string.")
			i += len(delimiter)
			tokens.append(Token("string", "".join(parts), start_line, start, i))
		elif character == "_" or character.isalpha():
			i += 1
			while i < len(source) and (source[i] == "_" or source[i].isalnum()):
				i += 1
			tokens.append(Token("identifier", source[start:i], line, start, i))
		else:
			i += 1
			tokens.append(Token("symbol", character, line, start, i))
		if len(tokens) > MAX_TOKENS:
			raise SourceError("Token budget exceeded.")
	return tokens


def _groups(tokens: list[Token], separator: str) -> list[list[Token]]:
	groups: list[list[Token]] = [[]]
	stack: list[str] = []
	for token in tokens:
		value = token.value if token.kind == "symbol" else ""
		if value in OPEN:
			stack.append(OPEN[value])
			if len(stack) > MAX_DEPTH:
				raise SourceError("Delimiter budget exceeded.")
		elif value in CLOSE:
			if not stack or stack.pop() != value:
				raise SourceError("Unbalanced delimiters.")
		if value == separator and not stack:
			groups.append([])
		else:
			groups[-1].append(token)
	if stack:
		raise SourceError("Unclosed delimiters.")
	return groups


def _closing(tokens: list[Token], index: int) -> int:
	stack: list[str] = []
	for cursor in range(index, len(tokens)):
		token = tokens[cursor]
		if token.kind != "symbol":
			continue
		if token.value in OPEN:
			stack.append(OPEN[token.value])
			if len(stack) > MAX_DEPTH:
				raise SourceError("Delimiter budget exceeded.")
		elif token.value in CLOSE:
			if not stack or stack.pop() != token.value:
				raise SourceError("Unbalanced delimiters.")
			if not stack:
				return cursor
	raise SourceError("Unclosed call.")


def _unparen(tokens: list[Token]) -> list[Token]:
	while tokens and tokens[0].value == "(" and tokens[0].kind == "symbol":
		if _closing(tokens, 0) != len(tokens) - 1:
			break
		tokens = tokens[1:-1]
	return tokens


def _constant_values(tokens: list[Token]) -> dict[str, list[Token]]:
	values: dict[str, list[Token]] = {}
	ambiguous: set[str] = set()
	for index, token in enumerate(tokens):
		if token.kind != "identifier" or token.value != "const" or index + 2 >= len(tokens):
			continue
		name = tokens[index + 1].value
		cursor = index + 2
		while cursor < len(tokens) and tokens[cursor].line == token.line and tokens[cursor].value != "=":
			cursor += 1
		if cursor == len(tokens) or tokens[cursor].value != "=":
			continue
		start = cursor + 1
		cursor = start
		while cursor < len(tokens):
			current = tokens[cursor]
			if cursor > start and current.line > tokens[cursor - 1].line:
				break
			if current.kind == "symbol" and current.value in OPEN:
				cursor = _closing(tokens, cursor) + 1
			else:
				cursor += 1
		if name in values:
			ambiguous.add(name)
		values[name] = tokens[start:cursor]
	for name in ambiguous:
		values.pop(name, None)
	return values


def _literal(tokens: list[Token], constants: dict[str, list[Token]], seen: frozenset[str] = frozenset(), cache: dict[str, str | None] | None = None) -> str | None:
	tokens = _unparen(tokens)
	if cache is None:
		cache = {}
	if len(seen) > 16:
		raise SourceError("Constant resolution budget exceeded.")
	parts = _groups(tokens, "+")
	if len(parts) > 1:
		values: list[str] = []
		size = 0
		for part in parts:
			value = _literal(part, constants, seen, cache)
			if value is None:
				return None
			size += len(value.encode("utf-8"))
			if size > MAX_TEMPLATE_BYTES:
				raise SourceError("Expanded diagnostic template exceeds its byte budget.")
			values.append(value)
		return "".join(values)
	if len(tokens) == 1:
		token = tokens[0]
		if token.kind == "string":
			if len(token.value.encode("utf-8")) > MAX_TEMPLATE_BYTES:
				raise SourceError("Diagnostic template exceeds its byte budget.")
			return token.value
		if token.kind == "identifier" and token.value in constants:
			if token.value in seen:
				raise SourceError("Cyclic diagnostic constant.")
			if token.value not in cache:
				cache[token.value] = _literal(constants[token.value], constants, seen | {token.value}, cache)
			return cache[token.value]
	return None


def _operand_end(tokens: list[Token], start: int = 0) -> int:
	"""Accept one primary expression; require brackets around operator expressions."""
	if start >= len(tokens):
		return start
	token = tokens[start]
	if token.kind == "symbol" and token.value in OPEN:
		cursor = _closing(tokens, start) + 1
	elif token.kind in {"string", "identifier"}:
		cursor = start + 1
	else:
		return start
	while cursor < len(tokens):
		if tokens[cursor].kind != "symbol":
			break
		if tokens[cursor].value in {"(", "["}:
			cursor = _closing(tokens, cursor) + 1
		elif tokens[cursor].value == "." and cursor + 1 < len(tokens) and tokens[cursor + 1].kind == "identifier":
			cursor += 2
		else:
			break
	return cursor


def _numeric_literal(tokens: list[Token]) -> bool:
	return re.fullmatch(r"[-+]?(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|[0-9][0-9_]*(?:\.[0-9_]*)?(?:[eE][-+]?[0-9_]+)?)", "".join(token.value for token in tokens)) is not None


def _template(tokens: list[Token], constants: dict[str, list[Token]]) -> str | None:
	tokens = _unparen(tokens)
	parts = _groups(tokens, "%")
	if len(parts) == 2:
		return _literal(parts[0], constants) if _operand_end(parts[1]) == len(parts[1]) or _numeric_literal(parts[1]) else None
	# String.format parameters are runtime context, not template language.
	for index in range(len(tokens) - 2):
		if tokens[index].kind == "symbol" and tokens[index].value == "." and tokens[index + 1].kind == "identifier" and tokens[index + 1].value == "format" and tokens[index + 2].kind == "symbol" and tokens[index + 2].value == "(" and _closing(tokens, index + 2) == len(tokens) - 1:
			return _literal(tokens[:index], constants)
	return _literal(tokens, constants)


def _expression(tokens: list[Token]) -> str:
	return " ".join(json.dumps(token.value, ensure_ascii=False) if token.kind == "string" else token.value for token in tokens)


def _format_issues(path: str, line: int, tokens: list[Token], constants: dict[str, list[Token]]) -> list[dict[str, object]]:
	parts = _groups(_unparen(tokens), "%")
	if len(parts) != 2:
		return []
	template = _literal(parts[0], constants)
	arguments = _unparen(parts[1])
	if template is None:
		return []
	slots = 0
	cursor = 0
	while cursor < len(template):
		if template[cursor] != "%":
			cursor += 1
			continue
		if template.startswith("%%", cursor):
			cursor += 2
			continue
		match = re.match(r"%[-+0 #]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[scdoxXfv]", template[cursor:])
		if match is None:
			return [_issue("format_placeholder", path, line, "Unsupported or incomplete percent placeholder in a diagnostic template.")]
		slots += 1 + match.group().count("*")
		cursor += len(match.group())
	arity: int | None = None
	if arguments and arguments[0].kind == "symbol" and arguments[0].value == "[" and _closing(arguments, 0) == len(arguments) - 1:
		values = _groups(arguments[1:-1], ",")
		if not values[-1]:
			values.pop()
		arity = len(values)
	elif (len(arguments) == 1 and arguments[0].kind == "string") or _numeric_literal(arguments):
		arity = 1
	if arity is not None and slots != arity:
		return [_issue("format_arity", path, line, "Diagnostic placeholders and literal arguments have different arity.")]
	return []


def _string_origins(tokens: list[Token], constants: dict[str, list[Token]], seen: set[str] | None = None) -> set[int]:
	"""Avoid treating a resolved template fragment or opaque argument as a producer."""
	if seen is None:
		seen = set()
	starts = {token.start for token in tokens if token.kind == "string"}
	for token in tokens:
		if token.kind == "identifier" and token.value in constants and token.value not in seen:
			if len(seen) >= MAX_DEPTH:
				raise SourceError("Constant origin budget exceeded.")
			seen.add(token.value)
			starts.update(_string_origins(constants[token.value], constants, seen))
	return starts


def _opaque_arguments(tokens: list[Token]) -> set[int]:
	"""Track argument occurrences, not shared constant identities."""
	indexes: set[int] = set()
	for index, token in enumerate(tokens):
		if token.kind == "symbol" and token.value == "%":
			indexes.update(range(index + 1, _operand_end(tokens, index + 1)))
		if token.kind == "symbol" and token.value == "." and index + 2 < len(tokens) and tokens[index + 1].kind == "identifier" and tokens[index + 1].value == "format" and tokens[index + 2].kind == "symbol" and tokens[index + 2].value == "(":
			indexes.update(range(index + 3, _closing(tokens, index + 2)))
	return indexes


def _function_contexts(tokens: list[Token], source: str) -> dict[int, str]:
	"""Bind forwarding sites to lexical bodies, never the last preceding method."""
	lines = source.split("\n")
	indents = [len(line) - len(line.lstrip(" \t")) for line in lines]
	headers: dict[int, tuple[str, int, int]] = {}
	for index, token in enumerate(tokens):
		if token.kind != "identifier" or token.value != "func" or index + 1 >= len(tokens):
			continue
		named = tokens[index + 1].kind == "identifier"
		opening = index + (2 if named else 1)
		if opening >= len(tokens) or tokens[opening].value != "(":
			continue
		cursor = _closing(tokens, opening) + 1
		while cursor < len(tokens) and tokens[cursor].value != ":":
			if tokens[cursor].line > tokens[cursor - 1].line:
				break
			cursor += 1
		if cursor < len(tokens) and tokens[cursor].value == ":":
			headers[cursor] = (tokens[index + 1].value if named else "<lambda>", indents[token.line - 1], tokens[cursor].line)
	active: list[tuple[str, int, int]] = []
	contexts: dict[int, str] = {}
	for index, token in enumerate(tokens):
		if not index or token.line != tokens[index - 1].line:
			while active and token.line > active[-1][2] and indents[token.line - 1] <= active[-1][1]:
				active.pop()
		if index in headers:
			active.append(headers[index])
		contexts[index] = active[-1][0] if active else "<initializer>"
	return contexts


def _issue(kind: str, path: str, line: int, message: str) -> dict[str, object]:
	return {"kind": "diagnostic." + kind, "path": path, "line": line, "message": message}


def scan_source(path: str, source: str) -> dict[str, object]:
	issues: list[dict[str, object]] = []
	calls: list[dict[str, object]] = []
	templates: list[dict[str, object]] = []
	try:
		tokens = tokenize(source)
		constants = _constant_values(tokens)
		contexts = _function_contexts(tokens, source)
		required_strings: set[int] = set()
		# Formatting parameters are opaque runtime data even when their text
		# happens to resemble a diagnostic code. The complete native expression
		# is still validated below; producers outside it are checked separately.
		opaque = _opaque_arguments(tokens)
		consumed_strings = _string_origins([tokens[index] for index in sorted(opaque)], constants)
		for index, token in enumerate(tokens):
			if token.kind != "identifier" or token.value not in OUTPUTS:
				continue
			if index and tokens[index - 1].value in {".", "func"}:
				continue
			if index + 1 >= len(tokens) or tokens[index + 1].value != "(":
				issues.append(_issue("indirect_builtin", path, token.line, "Native diagnostic builtins must be called directly, not aliased."))
				continue
			end = _closing(tokens, index + 1)
			arguments = tokens[index + 2:end]
			parts = _groups(arguments, ",")
			if len(parts) == 2 and not parts[-1]:
				parts.pop()
			if len(parts) != 1 or not parts[0]:
				issues.append(_issue("argument_count", path, token.line, "Use one diagnostic template with explicit formatting parameters."))
				continue
			issues.extend(_format_issues(path, token.line, parts[0], constants))
			template = _template(parts[0], constants)
			if template is not None:
				consumed_strings.update(_string_origins(arguments, constants))
			else:
				argument_indexes = _opaque_arguments(arguments)
				required_strings.update(_string_origins([token for index, token in enumerate(arguments) if index not in argument_indexes], constants))
			calls.append({"path": path, "line": token.line, "function": contexts[index], "callee": token.value, "argument": _expression(arguments), "template": template})
		for index, token in enumerate(tokens):
			if token.kind != "string" or (token.start in consumed_strings and token.start not in required_strings) or not CODED_LITERAL.match(token.value):
				continue
			value = token.value
			cursor = index + 1
			while cursor + 1 < len(tokens) and tokens[cursor].value == "+" and tokens[cursor + 1].kind == "string":
				value += tokens[cursor + 1].value
				cursor += 2
			if len(value.encode("utf-8")) > MAX_TEMPLATE_BYTES:
				raise SourceError("Diagnostic producer exceeds its byte budget.")
			templates.append({"path": path, "line": token.line, "template": value, "callee": ""})
	except (SourceError, UnicodeError) as error:
		issues.append(_issue("unreadable_syntax", path, 0, str(error)))
	return {"calls": calls, "templates": templates, "issues": issues}


def _validate_template(path: str, line: int, template: str, *, check_owner: bool = True) -> tuple[list[dict[str, object]], str]:
	issues: list[dict[str, object]] = []
	match = PREFIX.fullmatch(template)
	if match is None:
		return [_issue("template_shape", path, line, "Expected [GFOwner][namespace.reason] followed by an English explanation.")], ""
	code = match.group(2)
	body = match.group(3)
	# Ignore word separators here so acronym/numeric owners (UI, 3D, etc.)
	# retain their existing snake_case spelling without a special-name table.
	owner_identity = match.group(1)[2:].lower() or "gf"
	if check_owner and code.split(".", 1)[0].replace("_", "") != owner_identity:
		issues.append(_issue("owner_namespace", path, line, "The diagnostic namespace must name its GF owner."))
	if any(ord(character) > 126 or (ord(character) < 32 and character not in "\n\t") for character in template):
		issues.append(_issue("template_language", path, line, "Framework diagnostic templates use English and ASCII punctuation; runtime context is unrestricted."))
	if body != body.strip() or "  " in body.split("\n", 1)[0]:
		issues.append(_issue("template_spacing", path, line, "Diagnostic explanations must not contain surrounding or repeated spaces."))
	if not re.search(r"[A-Za-z]{2}", body):
		issues.append(_issue("template_explanation", path, line, "A diagnostic needs a readable explanation in addition to its code."))
	if not template.endswith((".", ".\n%s")):
		issues.append(_issue("template_termination", path, line, "End the English explanation with a period; a newline report placeholder may follow it."))
	return issues, code


def _forwarders(policy: object) -> list[dict[str, object]]:
	if not isinstance(policy, dict) or set(policy) != {"schema_version", "forwarders"} or type(policy["schema_version"]) is not int or policy["schema_version"] != SCHEMA_VERSION or not isinstance(policy["forwarders"], list):
		raise SourceError("Invalid forwarding policy schema.")
	if len(policy["forwarders"]) > 128:
		raise SourceError("Forwarding policy exceeds its site budget.")
	keys: set[tuple[object, ...]] = set()
	for entry in policy["forwarders"]:
		if not isinstance(entry, dict) or set(entry) != {"path", "function", "callee", "argument", "count", "kind", "reason"}:
			raise SourceError("Invalid forwarding site fields.")
		if any(not isinstance(entry[key], str) or not entry[key].strip() for key in ("path", "function", "callee", "argument", "kind", "reason")):
			raise SourceError("Forwarding site text must be explicit and non-empty.")
		path = entry["path"]
		if not path.startswith("addons/gf/") or not path.endswith(".gd") or "\\" in path or any(part in {"", ".", ".."} for part in path.split("/")):
			raise SourceError("Forwarding site must identify one framework script.")
		if entry["callee"] not in OUTPUTS or entry["kind"] not in {"project_message", "framework_message"} or type(entry["count"]) is not int or not 1 <= entry["count"] <= 32:
			raise SourceError("Invalid forwarding kind, callee or occurrence count.")
		key = tuple(entry[name] for name in ("path", "function", "callee", "argument"))
		if key in keys:
			raise SourceError("Duplicate forwarding site.")
		keys.add(key)
	return policy["forwarders"]


def audit_sources(sources: dict[str, str], policy: object) -> dict[str, object]:
	issues: list[dict[str, object]] = []
	calls: list[dict[str, object]] = []
	templates: list[dict[str, object]] = []
	try:
		forwarders = _forwarders(policy)
	except SourceError as error:
		return _result(len(sources), 0, 0, 0, [_issue("policy_invalid", POLICY_PATH, 0, str(error))])
	for path, source in sorted(sources.items()):
		scanned = scan_source(path, source)
		issues.extend(scanned["issues"])
		calls.extend(scanned["calls"])
		templates.extend(scanned["templates"])
	counts: Counter[tuple[object, ...]] = Counter()
	allowed = {tuple(entry[key] for key in ("path", "function", "callee", "argument")): entry for entry in forwarders}
	codes: dict[str, tuple[str, str, str]] = {}
	for call in calls:
		key = tuple(call[name] for name in ("path", "function", "callee", "argument"))
		template = call["template"]
		if template is None:
			if key not in allowed:
				issues.append(_issue("unreviewed_forwarder", call["path"], call["line"], "Dynamic native output requires an explicit reviewed forwarding site: " + call["function"] + " / " + call["argument"]))
			else:
				counts[key] += 1
			continue
		templates.append(call)
	for record in templates:
		template = record["template"]
		# Private forwarding producers may supply the code/body separately from
		# a project-owned warning_prefix; native literal calls still need an owner.
		without_owner = not template.startswith("[GF") and not record["callee"]
		validated = "[GFDiagnostic]" + template if without_owner else template
		template_issues, code = _validate_template(record["path"], record["line"], validated, check_owner=not without_owner)
		issues.extend(template_issues)
		if not code:
			continue
		match = PREFIX.fullmatch(validated)
		identity = (record["callee"], "" if without_owner else match.group(1), match.group(3))
		if code in codes:
			previous = codes[code]
			if any(old and new and old != new for old, new in zip(previous, identity)):
				issues.append(_issue("code_conflict", record["path"], record["line"], "A diagnostic code must retain one owner, severity and message template: " + code))
			identity = tuple(old or new for old, new in zip(previous, identity))
		codes[code] = identity
	for key, entry in allowed.items():
		if counts[key] != entry["count"]:
			issues.append(_issue("forwarder_drift", entry["path"], 0, "Reviewed forwarding expression/count changed or disappeared: " + entry["function"]))
	return _result(len(sources), len(calls), sum(counts.values()), len(codes), issues)


def _result(files: int, calls: int, forwarded: int, codes: int, issues: list[dict[str, object]]) -> dict[str, object]:
	return {"schema_version": SCHEMA_VERSION, "ok": not issues, "scanned_file_count": files, "native_call_count": calls, "forwarded_call_count": forwarded, "diagnostic_code_count": codes, "issue_count": len(issues), "issues_truncated": len(issues) > MAX_ISSUES, "issues": issues[:MAX_ISSUES]}


def audit_files(root: Path, paths: list[Path], read_text: Callable[[Path], str]) -> dict[str, object]:
	"""Use the maintenance invocation's inventory and strict text snapshot cache."""
	try:
		policy = json.loads(read_text(root / POLICY_PATH), object_pairs_hook=_unique_object)
		sources = {path.relative_to(root).as_posix(): read_text(path) for path in paths}
	except (OSError, ValueError, UnicodeError) as error:
		return _result(0, 0, 0, 0, [_issue("source_unreadable", POLICY_PATH, 0, "Diagnostic inputs could not be read: " + type(error).__name__)])
	return audit_sources(sources, policy)


def _unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
	result: dict[str, object] = {}
	for key, value in pairs:
		if key in result:
			raise SourceError("Duplicate forwarding policy JSON key.")
		result[key] = value
	return result
