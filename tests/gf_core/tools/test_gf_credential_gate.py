#!/usr/bin/env python3
"""Focused tests for the tracked-source and release credential gate."""

from __future__ import annotations

import contextlib
import hashlib
import io
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_credential_gate as credential_gate  # noqa: E402
from gf_maintenance import create_directory_link_fixture  # noqa: E402


class CredentialGateTests(unittest.TestCase):
	def test_untracked_secret_is_outside_source_scope(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			(repository / "safe.txt").write_text("ordinary tracked content\n", encoding="utf-8")
			self._git(repository, "add", "safe.txt")
			secret = self._credential_value()
			(repository / "untracked.txt").write_text(
				f'api_key="{secret}"\n',
				encoding="utf-8",
			)

			result = credential_gate.scan_tracked_repository(repository)

			self.assertTrue(
				result["ok"],
				"Expected untracked content to remain outside the source scan.",
			)
			self.assertEqual(result["stats"]["tracked_file_count"], 1)
			self.assertFalse(
				secret in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed fixture content.",
			)

	def test_tracked_credential_is_reported_without_disclosure(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			secret = self._credential_value()
			(repository / "settings.txt").write_text(
				f'api_key="{secret}"\n',
				encoding="utf-8",
			)
			self._git(repository, "add", "settings.txt")

			result = credential_gate.scan_tracked_repository(repository)
			rendered = json.dumps(result, ensure_ascii=False)
			text_output = io.StringIO()
			with contextlib.redirect_stdout(text_output):
				credential_gate.print_result(result, False)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					issue["rule_id"] == "credential.assignment"
					for issue in result["issues"]
				),
				"Expected the tracked assignment to be reported.",
			)
			self.assertFalse(
				secret in rendered,
				"Credential gate JSON disclosed fixture content.",
			)
			self.assertFalse(
				secret in text_output.getvalue(),
				"Credential gate text output disclosed fixture content.",
			)
			for issue in result["issues"]:
				self.assertLessEqual(set(issue), {"rule_id", "path", "line"})

	def test_matched_generic_credential_value_is_removed_from_issue_path(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			secret = (
				self._credential_value()
				.replace("$", "C")
				.replace("!", "D")
				.replace("@", "E")
			)
			candidate = repository / f"fixture-{secret}.txt"
			candidate.write_text(f'api_key="{secret}"\n', encoding="utf-8")
			self._git(repository, "add", candidate.name)

			result = credential_gate.scan_tracked_repository(repository)
			rendered = json.dumps(result, ensure_ascii=False)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					issue["rule_id"] == "credential.assignment"
					and issue["path"] == "gate-entry"
					for issue in result["issues"]
				)
			)
			self.assertNotIn(secret, rendered)

	def test_explicit_suppression_is_rule_and_next_line_scoped(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			secret = self._credential_value()
			fixture = repository / "tests" / "redaction_fixture.txt"
			fixture.parent.mkdir()
			fixture.write_text(
				"# gf-credential-gate: allow-next=credential.assignment "
				"reason=redaction-fixture\n"
				f'api_key="{secret}"\n',
				encoding="utf-8",
			)
			self._git(repository, "add", "tests/redaction_fixture.txt")

			result = credential_gate.scan_tracked_repository(repository)

			self.assertTrue(
				result["ok"],
				"Expected a scoped fixture suppression to pass.",
			)

	def test_suppression_outside_test_scope_is_rejected(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			secret = self._credential_value()
			(repository / "runtime.txt").write_text(
				"# gf-credential-gate: allow-next=credential.assignment "
				"reason=not-a-fixture\n"
				f'api_key="{secret}"\n',
				encoding="utf-8",
			)
			self._git(repository, "add", "runtime.txt")

			result = credential_gate.scan_tracked_repository(repository)

			self.assertFalse(result["ok"])
			self.assertEqual(result["issues"][0]["rule_id"], "credential.assignment")

	def test_declared_text_with_utf16_nuls_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			secret = self._credential_value()
			(repository / "settings.txt").write_text(
				f'api_key="{secret}"\n',
				encoding="utf-16",
			)
			self._git(repository, "add", "settings.txt")

			result = credential_gate.scan_tracked_repository(repository)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.text_encoding_invalid",
			)
			self.assertFalse(
				secret in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed synthetic fixture content.",
			)

	def test_netrc_is_a_high_confidence_sensitive_file(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			(repository / ".netrc").write_text(
				"machine example.invalid login user password placeholder\n",
				encoding="utf-8",
			)
			self._git(repository, "add", ".netrc")

			result = credential_gate.scan_tracked_repository(repository)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential.sensitive_file_name",
			)

	def test_sensitive_file_names_are_not_exempt_in_fixture_ancestors(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			fixture_path = repository / "fixtures" / ".env"
			example_path = repository / "examples" / "credentials.json"
			fixture_path.parent.mkdir()
			example_path.parent.mkdir()
			fixture_path.write_text("ordinary fixture content\n", encoding="utf-8")
			example_path.write_text("{}\n", encoding="utf-8")
			self._git(repository, "add", "fixtures/.env", "examples/credentials.json")

			result = credential_gate.scan_tracked_repository(repository)

			self.assertFalse(result["ok"])
			self.assertEqual(
				{
					issue["path"]
					for issue in result["issues"]
					if issue["rule_id"] == "credential.sensitive_file_name"
				},
				{"examples/credentials.json", "fixtures/.env"},
			)

	def test_complete_private_key_block_is_high_confidence(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			body = "".join(
				"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"[
					(index * 13 + 5) % 64
				]
				for index in range(160)
			)
			begin_marker = "-----BEGIN " + "PRIVATE KEY-----\n"
			end_marker = "\n-----END " + "PRIVATE KEY-----\n"
			(repository / "identity.txt").write_text(
				begin_marker + body + end_marker,
				encoding="utf-8",
			)
			self._git(repository, "add", "identity.txt")

			result = credential_gate.scan_tracked_repository(repository)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential.private_key_material",
			)
			self.assertFalse(
				body in json.dumps(result, ensure_ascii=False),
				"Private-key fixture material appeared in the report.",
			)

	def test_release_zip_is_scanned_from_explicit_manifest(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			secret = self._known_token()
			with zipfile.ZipFile(
				archive_path,
				"w",
				compression=zipfile.ZIP_DEFLATED,
			) as archive:
				archive.writestr("config/settings.txt", f"access_token={secret}\n")
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)
			rendered = json.dumps(result, ensure_ascii=False)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					str(issue["path"]).endswith("!/config/settings.txt")
					for issue in result["issues"]
				),
				"Expected the release archive entry to be reported.",
			)
			self.assertFalse(
				secret in rendered,
				"Release credential report disclosed fixture content.",
			)

	def test_renamed_nested_zip_is_detected_by_magic(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			inner_buffer = io.BytesIO()
			secret = self._known_token()
			with zipfile.ZipFile(inner_buffer, "w") as inner:
				inner.writestr("settings.txt", f"access_token={secret}\n")
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(archive_path, "w") as archive:
				archive.writestr("payload.dat", inner_buffer.getvalue())
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					str(issue["path"]).endswith("!/payload.dat!/settings.txt")
					for issue in result["issues"]
				),
				"Expected a nested ZIP detected by magic to be scanned.",
			)
			self.assertFalse(
				secret in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed synthetic fixture content.",
			)

	def test_renamed_sfx_zip_is_detected_by_bounded_eocd_probe(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			inner_buffer = io.BytesIO()
			secret = self._known_token()
			with zipfile.ZipFile(inner_buffer, "w") as inner:
				inner.writestr("settings.txt", f"access_token={secret}\n")
			sfx_payload = b"MZ" + b"\0" * 30 + inner_buffer.getvalue()
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(archive_path, "w") as archive:
				archive.writestr("payload.dat", sfx_payload)
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					str(issue["path"]).endswith("!/payload.dat!/settings.txt")
					for issue in result["issues"]
				),
				"Expected an SFX ZIP detected by its EOCD to be scanned.",
			)
			self.assertFalse(
				secret in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed synthetic fixture content.",
			)

	def test_nested_sfx_leading_data_is_scanned_without_disclosure(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			safe_zip_buffer = io.BytesIO()
			with zipfile.ZipFile(safe_zip_buffer, "w") as safe_zip:
				safe_zip.writestr("safe.txt", "ordinary archive content\n")
			secret = self._known_token()
			sfx_payload = (
				f"access_token={secret}\n".encode("ascii")
				+ safe_zip_buffer.getvalue()
			)
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(archive_path, "w") as archive:
				archive.writestr("payload.dat", sfx_payload)
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)
			rendered = json.dumps(result, ensure_ascii=False)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					str(issue["path"]).endswith(
						"!/payload.dat!/leading-data"
					)
					for issue in result["issues"]
				),
				"Expected the bounded SFX prefix to be scanned.",
			)
			self.assertNotIn(secret, rendered)

	def test_release_suppression_is_disabled(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			secret = self._credential_value()
			with zipfile.ZipFile(archive_path, "w") as archive:
				archive.writestr(
					"tests/redaction_fixture.txt",
					"# gf-credential-gate: allow-next=credential.assignment "
					"reason=release-fixture\n"
					f'api_key="{secret}"\n',
				)
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(issue["rule_id"] == "credential.assignment" for issue in result["issues"]),
				"Expected release suppression to remain disabled.",
			)

	def test_zip_archive_and_entry_comments_are_scanned_without_disclosure(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			archive_secret = self._credential_value()
			entry_secret = self._known_token()
			with zipfile.ZipFile(archive_path, "w") as archive:
				entry = zipfile.ZipInfo("safe.txt")
				entry.comment = f"access_token={entry_secret}".encode("utf-8")
				archive.writestr(entry, "ordinary archive content\n")
				archive.comment = f'api_key="{archive_secret}"'.encode("utf-8")
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)
			rendered = json.dumps(result, ensure_ascii=False)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					str(issue["path"]).endswith("!/archive-comment")
					for issue in result["issues"]
				),
				"Expected the archive comment to be scanned.",
			)
			self.assertTrue(
				any(
					str(issue["path"]).endswith("!/safe.txt!/comment")
					for issue in result["issues"]
				),
				"Expected the entry comment to be scanned.",
			)
			self.assertFalse(
				archive_secret in rendered,
				"Archive-comment credential content appeared in the report.",
			)
			self.assertFalse(
				entry_secret in rendered,
				"Entry-comment credential content appeared in the report.",
			)

	def test_zip_central_and_local_extra_fields_are_scanned(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			secret = self._known_token()
			extra_payload = f"access_token={secret}\n".encode("ascii")
			entry = zipfile.ZipInfo("safe.txt")
			entry.extra = struct.pack("<HH", 0xCAFE, len(extra_payload)) + extra_payload
			with zipfile.ZipFile(archive_path, "w") as archive:
				archive.writestr(entry, "ordinary archive content\n")
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)
			rendered = json.dumps(result, ensure_ascii=False)
			issue_paths = {str(issue["path"]) for issue in result["issues"]}

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(path.endswith("!/safe.txt!/extra") for path in issue_paths)
			)
			self.assertTrue(
				any(path.endswith("!/safe.txt!/local-extra") for path in issue_paths)
			)
			self.assertNotIn(secret, rendered)

	def test_zip_trailing_local_gap_is_scanned_without_disclosure(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(
				archive_path,
				"w",
				compression=zipfile.ZIP_DEFLATED,
			) as archive:
				archive.writestr("safe.txt", "ordinary archive content\n")
			payload = bytearray(archive_path.read_bytes())
			eocd_offset = payload.rfind(b"PK\x05\x06")
			central_offset = struct.unpack_from(
				"<L",
				payload,
				eocd_offset + 16,
			)[0]
			secret = (
				"access_" + "token=" + self._known_token() + "\n"
			).encode("ascii")
			payload[central_offset:central_offset] = secret
			struct.pack_into(
				"<L",
				payload,
				eocd_offset + len(secret) + 16,
				central_offset + len(secret),
			)
			archive_path.write_bytes(payload)
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)
			rendered = json.dumps(result, ensure_ascii=False)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					"unreferenced-data" in str(issue["path"])
					for issue in result["issues"]
				),
				result,
			)
			self.assertNotIn(secret.decode("ascii").strip(), rendered)

	def test_zip_internal_local_gap_is_scanned_without_disclosure(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(
				archive_path,
				"w",
				compression=zipfile.ZIP_DEFLATED,
			) as archive:
				archive.writestr("first.txt", "ordinary first content\n")
				archive.writestr("second.txt", "ordinary second content\n")
			with zipfile.ZipFile(archive_path, "r") as archive:
				second_offset = archive.infolist()[1].header_offset
			payload = bytearray(archive_path.read_bytes())
			eocd_offset = payload.rfind(b"PK\x05\x06")
			central_size, central_offset = struct.unpack_from(
				"<2L",
				payload,
				eocd_offset + 12,
			)
			secret = (
				"access_" + "token=" + self._known_token() + "\n"
			).encode("ascii")
			payload[second_offset:second_offset] = secret
			new_central_offset = central_offset + len(secret)
			cursor = new_central_offset
			central_end = cursor + central_size
			while cursor < central_end:
				self.assertEqual(payload[cursor:cursor + 4], b"PK\x01\x02")
				local_offset = struct.unpack_from(
					"<L",
					payload,
					cursor + 42,
				)[0]
				if local_offset >= second_offset:
					struct.pack_into(
						"<L",
						payload,
						cursor + 42,
						local_offset + len(secret),
					)
				name_size, extra_size, comment_size = struct.unpack_from(
					"<3H",
					payload,
					cursor + 28,
				)
				cursor += 46 + name_size + extra_size + comment_size
			struct.pack_into(
				"<L",
				payload,
				eocd_offset + len(secret) + 16,
				new_central_offset,
			)
			archive_path.write_bytes(payload)
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)
			rendered = json.dumps(result, ensure_ascii=False)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					"unreferenced-data" in str(issue["path"])
					for issue in result["issues"]
				),
				result,
			)
			self.assertNotIn(secret.decode("ascii").strip(), rendered)

	def test_zip_deflate_unused_tail_fails_closed_without_disclosure(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(
				archive_path,
				"w",
				compression=zipfile.ZIP_DEFLATED,
			) as archive:
				archive.writestr("safe.txt", "ordinary archive content\n")
			payload = bytearray(archive_path.read_bytes())
			eocd_offset = payload.rfind(b"PK\x05\x06")
			central_offset = struct.unpack_from(
				"<L",
				payload,
				eocd_offset + 16,
			)[0]
			compressed_size = struct.unpack_from("<L", payload, 18)[0]
			name_size, extra_size = struct.unpack_from("<2H", payload, 26)
			data_end = (
				30 + name_size + extra_size + compressed_size
			)
			secret = (
				"access_" + "token=" + self._known_token() + "\n"
			).encode("ascii")
			payload[data_end:data_end] = secret
			new_central_offset = central_offset + len(secret)
			new_eocd_offset = eocd_offset + len(secret)
			struct.pack_into(
				"<L",
				payload,
				18,
				compressed_size + len(secret),
			)
			struct.pack_into(
				"<L",
				payload,
				new_central_offset + 20,
				compressed_size + len(secret),
			)
			struct.pack_into(
				"<L",
				payload,
				new_eocd_offset + 16,
				new_central_offset,
			)
			archive_path.write_bytes(payload)
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)
			rendered = json.dumps(result, ensure_ascii=False)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					issue["rule_id"]
					== "credential_gate.archive_layout_invalid"
					for issue in result["issues"]
				),
				result,
			)
			self.assertNotIn(secret.decode("ascii").strip(), rendered)

	def test_zip_unreferenced_ranges_share_archive_and_expanded_budgets(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			entry_payload = b"x"
			with zipfile.ZipFile(archive_path, "w") as archive:
				archive.writestr("safe.txt", entry_payload)
			payload = bytearray(archive_path.read_bytes())
			eocd_offset = payload.rfind(b"PK\x05\x06")
			central_offset = struct.unpack_from(
				"<L",
				payload,
				eocd_offset + 16,
			)[0]
			gap = b"bounded-gap"
			payload[central_offset:central_offset] = gap
			struct.pack_into(
				"<L",
				payload,
				eocd_offset + len(gap) + 16,
				central_offset + len(gap),
			)
			archive_path.write_bytes(payload)
			manifest_path = self._write_manifest(release_root, archive_path)

			range_limited = credential_gate.scan_release_manifest(
				manifest_path,
				credential_gate.GateLimits(
					max_zip_leading_bytes=len(gap) - 1,
				),
			)
			self.assertTrue(
				any(
					issue["rule_id"]
					== (
						"credential_gate."
						"archive_unreferenced_data_budget_exceeded"
					)
					for issue in range_limited["issues"]
				),
				range_limited,
			)

			expanded_limited = credential_gate.scan_release_manifest(
				manifest_path,
				credential_gate.GateLimits(
					max_zip_leading_bytes=len(gap),
					max_total_expanded_bytes=(
						len(entry_payload) + len(gap) - 1
					),
				),
			)
			self.assertTrue(
				any(
					issue["rule_id"]
					== "credential_gate.archive_total_expanded_budget_exceeded"
					for issue in expanded_limited["issues"]
				),
				expanded_limited,
			)

	def test_zip_comment_scan_is_bounded(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(archive_path, "w") as archive:
				archive.writestr("safe.txt", "ordinary archive content\n")
				archive.comment = b"bounded-comment"
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(
				manifest_path,
				credential_gate.GateLimits(max_zip_comment_bytes=4),
			)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.archive_comment_budget_exceeded",
			)

	def test_release_zip_rejects_traversal_before_entry_reads(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(archive_path, "w") as archive:
				archive.writestr("../outside.txt", "ordinary content\n")
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					issue["rule_id"] == "credential_gate.path_invalid"
					for issue in result["issues"]
				),
				"Expected traversal metadata to fail preflight.",
			)
			self.assertFalse(
				any("outside.txt" in str(issue["path"]) for issue in result["issues"]),
				"Traversal paths must not be echoed in issue metadata.",
			)

	def test_release_zip_rejects_entry_and_expansion_budgets(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(archive_path, "w") as archive:
				archive.writestr("one.txt", "one\n")
				archive.writestr("two.txt", "two\n")
			manifest_path = self._write_manifest(release_root, archive_path)

			entry_count_result = credential_gate.scan_release_manifest(
				manifest_path,
				credential_gate.GateLimits(max_zip_entries=1),
			)
			entry_size_result = credential_gate.scan_release_manifest(
				manifest_path,
				credential_gate.GateLimits(max_zip_entry_bytes=2),
			)

			self.assertFalse(entry_count_result["ok"])
			self.assertEqual(
				entry_count_result["issues"][0]["rule_id"],
				"credential_gate.archive_entry_count_exceeded",
			)
			self.assertFalse(entry_size_result["ok"])
			self.assertTrue(
				any(
					issue["rule_id"] == "credential_gate.archive_entry_budget_exceeded"
					for issue in entry_size_result["issues"]
				),
				"Expected the ZIP entry-size budget to be enforced.",
			)

	def test_release_zip_rejects_excessive_compression_ratio(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(
				archive_path,
				"w",
				compression=zipfile.ZIP_DEFLATED,
			) as archive:
				archive.writestr("repeated.txt", "A" * 8_192)
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(
				manifest_path,
				credential_gate.GateLimits(max_zip_compression_ratio=5.0),
			)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					issue["rule_id"] == "credential_gate.archive_compression_ratio_exceeded"
					for issue in result["issues"]
				),
				"Expected the ZIP compression-ratio budget to be enforced.",
			)

	def test_unsupported_release_archive_format_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			artifact_path = release_root / "release.gz"
			artifact_path.write_bytes(b"\x1f\x8b\x08\x00opaque")
			manifest_path = self._write_manifest(release_root, artifact_path)

			result = credential_gate.scan_release_manifest(manifest_path)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.archive_format_unsupported",
			)

	def test_global_nested_zip_entry_budget_is_enforced(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			inner_buffer = io.BytesIO()
			with zipfile.ZipFile(inner_buffer, "w") as inner:
				inner.writestr("one.txt", "one\n")
				inner.writestr("two.txt", "two\n")
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(archive_path, "w") as archive:
				archive.writestr("payload.dat", inner_buffer.getvalue())
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(
				manifest_path,
				credential_gate.GateLimits(max_total_zip_entries=2),
			)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					issue["rule_id"]
					== "credential_gate.archive_total_entry_count_exceeded"
					for issue in result["issues"]
				),
				"Expected the invocation-global ZIP entry budget to be enforced.",
			)

	def test_zip_eocd_entry_count_must_match_parsed_directory(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(archive_path, "w") as archive:
				archive.writestr("one.txt", "one\n")
				archive.writestr("two.txt", "two\n")
			payload = bytearray(archive_path.read_bytes())
			eocd_offset = payload.rfind(credential_gate.ZIP_EOCD_SIGNATURE)
			self.assertGreaterEqual(eocd_offset, 0)
			payload[eocd_offset + 8:eocd_offset + 10] = (1).to_bytes(2, "little")
			payload[eocd_offset + 10:eocd_offset + 12] = (1).to_bytes(2, "little")
			archive_path.write_bytes(payload)
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.archive_entry_count_mismatch",
			)

	def test_manifest_content_is_scanned(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			artifact_path = release_root / "release.txt"
			artifact_path.write_text("ordinary content\n", encoding="utf-8")
			secret = self._known_token()
			manifest_path = self._write_manifest(
				release_root,
				artifact_path,
				extra={"registry_token": secret},
			)

			result = credential_gate.scan_release_manifest(manifest_path)

			self.assertFalse(result["ok"])
			self.assertEqual(result["issues"][0]["path"], "manifest")
			self.assertFalse(
				secret in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed synthetic fixture content.",
			)

	def test_release_artifact_hash_is_required_and_verified(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			artifact_path = release_root / "release.txt"
			artifact_path.write_text("ordinary content\n", encoding="utf-8")
			manifest_path = self._write_manifest(
				release_root,
				artifact_path,
				sha256="0" * 64,
			)

			result = credential_gate.scan_release_manifest(manifest_path)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.release_artifact_hash_mismatch",
			)
			self.assertFalse(
				"0" * 64 in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed a synthetic digest fixture.",
			)

	def test_provider_token_with_placeholder_word_is_not_ignored(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			secret = "ghp_" + "Abexample9" * 4
			(repository / "settings.txt").write_text(secret + "\n", encoding="utf-8")
			self._git(repository, "add", "settings.txt")

			result = credential_gate.scan_tracked_repository(repository)

			self.assertFalse(result["ok"])
			self.assertEqual(result["issues"][0]["rule_id"], "credential.token.github")
			self.assertFalse(
				secret in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed synthetic fixture content.",
			)

	def test_fine_grained_github_pat_is_detected(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			secret = "github_" + "pat_" + "Ab9" * 16
			(repository / "settings.txt").write_text(secret + "\n", encoding="utf-8")
			self._git(repository, "add", "settings.txt")

			result = credential_gate.scan_tracked_repository(repository)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential.token.github_fine_grained",
			)
			self.assertFalse(
				secret in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed synthetic fixture content.",
			)

	def test_secret_shaped_file_name_is_redacted(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			secret = self._known_token()
			secret_path = repository / f"{secret}.txt"
			secret_path.write_text("ordinary tracked content\n", encoding="utf-8")
			self._git(repository, "add", secret_path.name)

			result = credential_gate.scan_tracked_repository(repository)
			rendered = json.dumps(result, ensure_ascii=False)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential.sensitive_path_value",
			)
			self.assertFalse(
				secret in rendered,
				"Credential gate report disclosed synthetic fixture content.",
			)
			self.assertTrue(
				all(issue["path"] == "tracked-entry-1" for issue in result["issues"]),
				"Expected every secret-shaped path to use its fallback label.",
			)

	def test_tracked_assignment_shaped_path_fails_without_disclosure(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			secret = self._credential_value()
			secret_path = repository / f"api_key={secret}.txt"
			secret_path.write_text("ordinary tracked content\n", encoding="utf-8")
			self._git(repository, "add", secret_path.name)

			result = credential_gate.scan_tracked_repository(repository)
			rendered = json.dumps(result, ensure_ascii=False)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential.sensitive_path_value",
			)
			self.assertTrue(
				result["issues"][0]["path"] == "tracked-entry-1",
				"Expected the tracked path to use its fallback label.",
			)
			self.assertFalse(
				secret in rendered,
				"Tracked path credential content appeared in the report.",
			)

	def test_release_artifact_secret_shaped_path_fails_without_disclosure(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			secret = self._credential_value()
			artifact_path = release_root / f"api_key={secret}.txt"
			artifact_path.write_text("ordinary release content\n", encoding="utf-8")
			manifest_path = self._write_manifest(release_root, artifact_path)
			manifest_path.write_text(
				manifest_path.read_text(encoding="utf-8").replace(
					"api_key=",
					"api_key\\u003d",
				),
				encoding="utf-8",
			)

			result = credential_gate.scan_release_manifest(manifest_path)
			rendered = json.dumps(result, ensure_ascii=False)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential.sensitive_path_value",
			)
			self.assertTrue(
				result["issues"][0]["path"] == "artifact-1",
				"Expected the release path to use its fallback label.",
			)
			self.assertFalse(
				secret in rendered,
				"Release path credential content appeared in the report.",
			)

	def test_release_zip_secret_shaped_entry_fails_without_disclosure(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			secret = self._credential_value()
			archive_path = release_root / "release.zip"
			with zipfile.ZipFile(archive_path, "w") as archive:
				archive.writestr(
					f"config/api_key={secret}.txt",
					"ordinary archive content\n",
				)
			manifest_path = self._write_manifest(release_root, archive_path)

			result = credential_gate.scan_release_manifest(manifest_path)
			rendered = json.dumps(result, ensure_ascii=False)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					issue["rule_id"] == "credential.sensitive_path_value"
					for issue in result["issues"]
				),
				"Expected the assignment-shaped ZIP path to be rejected.",
			)
			self.assertFalse(
				secret in rendered,
				"ZIP path credential content appeared in the report.",
			)

	def test_generic_assignment_shaped_path_label_is_redacted(self) -> None:
		secret = self._credential_value()
		raw_path = "api_key=" + secret + ".txt"

		label = credential_gate.safe_path_label(raw_path, "tracked-entry-1")

		self.assertTrue(
			label == "tracked-entry-1",
			"Expected the assignment-shaped path to use its fallback label.",
		)
		self.assertFalse(
			secret in label,
			"Path label disclosed synthetic fixture content.",
		)

	def test_release_evidence_binds_audit_artifact_identity_without_output(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			artifact_path = release_root / "release.txt"
			artifact_path.write_text("ordinary content\n", encoding="utf-8")
			manifest_path = self._write_manifest(release_root, artifact_path)
			manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

			result, evidence = credential_gate.run_release_gate_with_evidence(manifest_path)
			audit_result = {"artifacts": manifest["artifacts"]}

			self.assertTrue(
				result["ok"],
				"Expected the release evidence fixture to pass.",
			)
			self.assertIsNotNone(evidence)
			self.assertTrue(
				credential_gate.release_audit_matches_evidence(audit_result, evidence)
			)
			self.assertFalse(
				credential_gate.release_audit_matches_evidence(
					{"artifacts": [{**manifest["artifacts"][0], "size_bytes": 0}]},
					evidence,
				)
			)
			self.assertNotIn("evidence", result)

	def test_release_scan_rejects_manifest_replacement_before_success(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			artifact_path = release_root / "release.txt"
			artifact_path.write_text("ordinary content\n", encoding="utf-8")
			manifest_path = self._write_manifest(release_root, artifact_path)
			original_scan_path = credential_gate._scan_path
			replaced = False

			def scan_then_replace_manifest(*args: object, **kwargs: object) -> None:
				nonlocal replaced
				original_scan_path(*args, **kwargs)
				if replaced:
					return
				replaced = True
				replacement_path = release_root / "replacement.json"
				replacement_path.write_bytes(manifest_path.read_bytes())
				os.replace(replacement_path, manifest_path)

			evidence: list[credential_gate.ReleaseEvidence] = []
			with mock.patch.object(
				credential_gate,
				"_scan_path",
				side_effect=scan_then_replace_manifest,
			):
				result = credential_gate.scan_release_manifest(
					manifest_path,
					evidence_out=evidence,
				)

			self.assertTrue(replaced)
			self.assertFalse(result["ok"])
			self.assertEqual(evidence, [])
			self.assertEqual(
				result["issues"],
				[{
					"rule_id": "credential_gate.release_manifest_changed",
					"path": "manifest",
				}],
			)

	def test_materialized_release_snapshot_isolated_from_original_mutation(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			artifact_path = release_root / "release.txt"
			artifact_path.write_text("ordinary content\n", encoding="utf-8")
			manifest_path = self._write_manifest(release_root, artifact_path)

			with credential_gate.materialized_release_snapshot(manifest_path) as (
				snapshot,
				failure,
			):
				self.assertIsNone(failure)
				self.assertIsNotNone(snapshot)
				assert snapshot is not None
				artifact_path.write_text("changed original\n", encoding="utf-8")
				result, evidence = credential_gate.run_release_gate_with_evidence(
					snapshot.manifest_path
				)

				self.assertTrue(
					result["ok"],
					"Expected the materialized snapshot scan to pass.",
				)
				self.assertEqual(evidence, snapshot.evidence)

	def test_snapshot_parent_exchange_cannot_create_an_external_target(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			temporary_root = Path(temp_dir)
			release_root = temporary_root / "release"
			source_parent = release_root / "nested"
			source_parent.mkdir(parents=True)
			artifact_path = source_parent / "release.txt"
			artifact_payload = b"bounded snapshot payload\n"
			artifact_path.write_bytes(artifact_payload)
			manifest_path = release_root / "release-manifest.json"
			manifest_path.write_text(
				json.dumps({
					"artifacts": [{
						"path": "nested/release.txt",
						"size_bytes": len(artifact_payload),
						"sha256": hashlib.sha256(artifact_payload).hexdigest(),
					}],
				}),
				encoding="utf-8",
			)
			outside_root = temporary_root / "outside"
			outside_root.mkdir()
			outside_target = outside_root / artifact_path.name
			canary = outside_root / "canary.txt"
			canary_payload = b"outside canary remains unchanged\n"
			canary.write_bytes(canary_payload)
			attack_state = {"attempted": False, "exchanged": False}
			method_name = (
				"_create_windows_target"
				if os.name == "nt"
				else "_create_posix_target"
			)
			real_create = getattr(
				credential_gate._SnapshotRootBinding,
				method_name,
			)

			def exchange_after_parent_binding(
				binding: credential_gate._SnapshotRootBinding,
				target: Path,
			) -> object:
				if (
					not attack_state["attempted"]
					and target.name == artifact_path.name
					and target.parent != binding.root
				):
					attack_state["attempted"] = True
					if os.name == "nt":
						binding._ensure_windows_directory(target.parent)
					else:
						relative_parent = target.parent.relative_to(binding.root)
						binding._ensure_posix_directory(tuple(relative_parent.parts))
					held_parent = target.parent.with_name(
						target.parent.name + "-held"
					)
					try:
						os.replace(target.parent, held_parent)
						create_directory_link_fixture(outside_root, target.parent)
						attack_state["exchanged"] = True
					except OSError:
						pass
				return real_create(binding, target)

			with mock.patch.object(
				credential_gate._SnapshotRootBinding,
				method_name,
				new=exchange_after_parent_binding,
			):
				with credential_gate.materialized_release_snapshot(
					manifest_path
				) as (snapshot, failure):
					if attack_state["exchanged"]:
						self.assertIsNone(snapshot)
						self.assertIsNotNone(failure)
						assert failure is not None
						self.assertEqual(
							failure["issues"][0]["rule_id"],
							"credential_gate.snapshot_boundary_invalid",
						)
					else:
						self.assertIsNotNone(snapshot)
						self.assertIsNone(failure)

			self.assertTrue(attack_state["attempted"])
			self.assertFalse(
				outside_target.exists(),
				"Parent exchange created a target outside the private root.",
			)
			self.assertEqual(canary.read_bytes(), canary_payload)

	@unittest.skipUnless(os.name == "nt", "Windows parent-HANDLE regression")
	def test_windows_snapshot_target_uses_pinned_parent_handle(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			temporary_root = Path(temp_dir)
			release_root = temporary_root / "release"
			source_parent = release_root / "nested"
			source_parent.mkdir(parents=True)
			artifact_path = source_parent / "release.txt"
			artifact_payload = b"bounded snapshot payload\n"
			artifact_path.write_bytes(artifact_payload)
			manifest_path = release_root / "release-manifest.json"
			manifest_path.write_text(
				json.dumps({
					"artifacts": [{
						"path": "nested/release.txt",
						"size_bytes": len(artifact_payload),
						"sha256": hashlib.sha256(artifact_payload).hexdigest(),
					}],
				}),
				encoding="utf-8",
			)
			outside_root = temporary_root / "outside"
			outside_root.mkdir()
			outside_target = outside_root / artifact_path.name
			real_create = credential_gate._windows_create_pinned_file
			attack_state = {"attempted": False, "exchanged": False}

			def exchange_in_exact_create_window(
				parent_handle: int,
				leaf_name: str,
				expected_path: Path,
			) -> int:
				if (
					not attack_state["attempted"]
					and leaf_name == artifact_path.name
					and expected_path.parent != expected_path.parent.parent
				):
					attack_state["attempted"] = True
					held_parent = expected_path.parent.with_name(
						expected_path.parent.name + "-held"
					)
					try:
						os.replace(expected_path.parent, held_parent)
						create_directory_link_fixture(
							outside_root,
							expected_path.parent,
						)
						attack_state["exchanged"] = True
					except OSError:
						if os.path.lexists(expected_path.parent):
							self._remove_directory_link(expected_path.parent)
						if held_parent.exists():
							os.replace(held_parent, expected_path.parent)
				return real_create(parent_handle, leaf_name, expected_path)

			with mock.patch.object(
				credential_gate,
				"_windows_create_pinned_file",
				side_effect=exchange_in_exact_create_window,
			):
				with credential_gate.materialized_release_snapshot(
					manifest_path
				) as (snapshot, failure):
					if not attack_state["exchanged"]:
						self.assertIsNotNone(snapshot)
						self.assertIsNone(failure)
					else:
						self.assertIsNone(snapshot)
						self.assertIsNotNone(failure)
						assert failure is not None
						self.assertEqual(
							failure["issues"][0]["rule_id"],
							"credential_gate.snapshot_boundary_invalid",
						)

			self.assertTrue(attack_state["attempted"])
			if not attack_state["exchanged"]:
				self.skipTest("Windows did not permit the directory exchange fixture")
			self.assertFalse(
				outside_target.exists(),
				"Pinned-parent creation escaped through the replacement junction.",
			)

	def test_regular_file_budget_uses_unbuffered_physical_reads(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			candidate = Path(temp_dir) / "payload.bin"
			candidate.write_bytes(b"A" * (64 * 1024))
			limits = credential_gate.GateLimits(max_total_io_bytes=4)
			work_budget = credential_gate.WorkBudget()

			with credential_gate._open_regular_file(
				candidate,
				candidate.stat().st_size,
				"credential_gate.source_file_budget_exceeded",
				containment_root=candidate.parent,
				work_budget=work_budget,
				limits=limits,
			) as (reader, _size):
				self.assertEqual(reader.read(4), b"AAAA")
				self.assertIsInstance(reader._handle, io.FileIO)
				self.assertEqual(reader._handle.tell(), 4)

			self.assertEqual(work_budget.io_bytes, 4)

	def test_manifest_read_is_charged_to_the_total_io_budget(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			artifact_path = release_root / "release.txt"
			artifact_path.write_text("ordinary release content\n", encoding="utf-8")
			manifest_path = self._write_manifest(release_root, artifact_path)
			result = credential_gate.scan_release_manifest(
				manifest_path,
				credential_gate.GateLimits(
					max_total_io_bytes=manifest_path.stat().st_size - 1
				),
			)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.io_total_budget_exceeded",
			)

	def test_snapshot_copy_and_write_share_the_total_io_budget(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			artifact_path = release_root / "release.txt"
			payload = b"snapshot copy payload\n"
			artifact_path.write_bytes(payload)
			manifest_path = self._write_manifest(release_root, artifact_path)
			io_limit = manifest_path.stat().st_size * 2 + len(payload)

			with credential_gate.materialized_release_snapshot(
				manifest_path,
				credential_gate.GateLimits(max_total_io_bytes=io_limit),
			) as (snapshot, failure):
				self.assertIsNone(snapshot)
				self.assertIsNotNone(failure)
				assert failure is not None
				self.assertEqual(
					failure["issues"][0]["rule_id"],
					"credential_gate.io_total_budget_exceeded",
				)

	def test_repeated_hash_and_scan_passes_share_the_total_io_budget(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			release_root = Path(temp_dir)
			artifact_path = release_root / "release.txt"
			payload = b"ordinary release payload with repeated reads\n"
			artifact_path.write_bytes(payload)
			manifest_path = self._write_manifest(release_root, artifact_path)
			io_limit = manifest_path.stat().st_size + len(payload)
			work_budget = credential_gate.WorkBudget()
			result = credential_gate.scan_release_manifest(
				manifest_path,
				credential_gate.GateLimits(max_total_io_bytes=io_limit),
				work_budget,
			)

			self.assertFalse(result["ok"])
			self.assertTrue(work_budget.hard_exhausted)
			self.assertEqual(work_budget.io_bytes, io_limit)
			self.assertTrue(
				any(
					issue["rule_id"]
					== "credential_gate.io_total_budget_exceeded"
					for issue in result["issues"]
				)
			)

	def test_zip_metadata_and_entry_reads_share_the_total_io_budget(self) -> None:
		archive_buffer = io.BytesIO()
		entry_payload = b"entry payload counted after compressed reads\n"
		with zipfile.ZipFile(archive_buffer, "w") as archive:
			archive.writestr("entry.txt", entry_payload)
		archive_payload = archive_buffer.getvalue()
		metadata_budget = credential_gate.WorkBudget()
		metadata_limits = credential_gate.GateLimits(
			max_total_io_bytes=len(archive_payload) * 4
		)
		metadata_stream = credential_gate._BudgetedBinaryReader(
			io.BytesIO(archive_payload),
			len(archive_payload),
			metadata_budget,
			metadata_limits,
		)
		with zipfile.ZipFile(metadata_stream, "r") as archive:
			self.assertEqual(len(archive.infolist()), 1)
		metadata_io = metadata_budget.io_bytes
		self.assertGreater(metadata_io, 0)

		limited_budget = credential_gate.WorkBudget()
		limited_limits = credential_gate.GateLimits(
			max_total_io_bytes=metadata_io - 1
		)
		limited_stream = credential_gate._BudgetedBinaryReader(
			io.BytesIO(archive_payload),
			len(archive_payload),
			limited_budget,
			limited_limits,
		)
		with self.assertRaises(credential_gate.GateInputError) as metadata_error:
			with zipfile.ZipFile(limited_stream, "r"):
				pass
		self.assertEqual(
			metadata_error.exception.rule_id,
			"credential_gate.io_total_budget_exceeded",
		)

		with zipfile.ZipFile(io.BytesIO(archive_payload), "r") as archive:
			entry = archive.infolist()[0]
			entry_budget = credential_gate.WorkBudget()
			entry_limits = credential_gate.GateLimits(
				max_total_io_bytes=len(entry_payload) - 1
			)
			with self.assertRaises(credential_gate.GateInputError) as entry_error:
				credential_gate._read_zip_entry(
					archive,
					entry,
					entry_limits,
					entry_budget,
				)
		self.assertEqual(
			entry_error.exception.rule_id,
			"credential_gate.io_total_budget_exceeded",
		)

	def test_issue_budget_stops_repeated_match_collection(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			secret = self._known_token()
			(repository / "settings.txt").write_text(
				"\n".join(secret for _index in range(1000)),
				encoding="utf-8",
			)
			self._git(repository, "add", "settings.txt")

			result = credential_gate.scan_tracked_repository(
				repository,
				credential_gate.GateLimits(max_issues=2),
			)

			self.assertFalse(result["ok"])
			self.assertEqual(len(result["issues"]), 2)
			self.assertFalse(
				secret in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed synthetic fixture content.",
			)

	def test_binary_eocd_probe_is_charged_to_source_budget(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			(repository / "payload.bin").write_bytes(b"A" * 128)
			self._git(repository, "add", "payload.bin")

			result = credential_gate.scan_tracked_repository(
				repository,
				credential_gate.GateLimits(max_source_total_bytes=4),
			)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.source_total_budget_exceeded",
			)

	def test_git_tracked_output_is_bounded(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			(repository / "safe.txt").write_text("ordinary content\n", encoding="utf-8")
			self._git(repository, "add", "safe.txt")

			result = credential_gate.scan_tracked_repository(
				repository,
				credential_gate.GateLimits(max_git_index_output_bytes=4),
			)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0],
				{
					"rule_id": "credential_gate.git_index_output_budget_exceeded",
					"path": "git-index",
				},
			)

	def test_git_environment_cannot_redirect_repository_scope(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			repository = self._init_repository(root / "target")
			(repository / "safe.txt").write_text("ordinary content\n", encoding="utf-8")
			self._git(repository, "add", "safe.txt")
			outside = self._init_repository(root / "outside")
			secret = self._known_token()
			(outside / "settings.txt").write_text(secret + "\n", encoding="utf-8")
			self._git(outside, "add", "settings.txt")
			with mock.patch.dict(
				os.environ,
				{
					"GIT_DIR": str(outside / ".git"),
					"GIT_WORK_TREE": str(outside),
				},
				clear=False,
			):
				result = credential_gate.scan_tracked_repository(repository)

			self.assertTrue(
				result["ok"],
				"Expected isolated Git discovery to remain in the target repository.",
			)
			self.assertEqual(result["stats"]["tracked_file_count"], 1)
			self.assertFalse(
				secret in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed synthetic fixture content.",
			)

	def test_tracked_listing_rejects_parent_chain_identity_drift(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			(repository / "safe.txt").write_text("ordinary content\n", encoding="utf-8")
			self._git(repository, "add", "safe.txt")
			real_snapshot = credential_gate._snapshot_full_directory_chain
			snapshot_count = 0

			def drift_after_listing(
				directory: Path,
			) -> tuple[tuple[Path, os.stat_result], ...]:
				nonlocal snapshot_count
				snapshot_count += 1
				chain = real_snapshot(directory)
				if snapshot_count == 3:
					return self._drift_directory_chain(chain, 0)
				return chain

			with mock.patch.object(
				credential_gate,
				"_snapshot_full_directory_chain",
				side_effect=drift_after_listing,
			):
				result = credential_gate.scan_tracked_repository(repository)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.repository_changed",
			)

	def test_tracked_scan_rejects_repository_drift_at_scan_end(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			(repository / "safe.txt").write_text("ordinary content\n", encoding="utf-8")
			self._git(repository, "add", "safe.txt")
			real_snapshot = credential_gate._snapshot_full_directory_chain
			real_scan_path = credential_gate._scan_path
			scan_completed = False

			def scan_then_mark(*args: object, **kwargs: object) -> None:
				nonlocal scan_completed
				real_scan_path(*args, **kwargs)
				scan_completed = True

			def drift_at_end(
				directory: Path,
			) -> tuple[tuple[Path, os.stat_result], ...]:
				chain = real_snapshot(directory)
				if scan_completed:
					return self._drift_directory_chain(chain, len(chain) - 1)
				return chain

			with (
				mock.patch.object(
					credential_gate,
					"_scan_path",
					side_effect=scan_then_mark,
				),
				mock.patch.object(
					credential_gate,
					"_snapshot_full_directory_chain",
					side_effect=drift_at_end,
				),
			):
				result = credential_gate.scan_tracked_repository(repository)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.repository_changed",
			)

	def test_tracked_scan_rejects_git_index_content_drift(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			candidate = repository / "safe.txt"
			candidate.write_text("ordinary content\n", encoding="utf-8")
			self._git(repository, "add", candidate.name)
			secret = self._known_token()
			real_scan_path = credential_gate._scan_path
			index_changed = False

			def scan_then_change_index(*args: object, **kwargs: object) -> None:
				nonlocal index_changed
				real_scan_path(*args, **kwargs)
				if index_changed:
					return
				candidate.write_text(secret + "\n", encoding="utf-8")
				self._git(repository, "add", candidate.name)
				index_changed = True

			with mock.patch.object(
				credential_gate,
				"_scan_path",
				side_effect=scan_then_change_index,
			):
				result = credential_gate.scan_tracked_repository(repository)

			self.assertTrue(index_changed)
			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.repository_changed",
			)
			self.assertNotIn(secret, json.dumps(result, ensure_ascii=False))

	def test_dotted_assignment_key_is_scanned(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			secret = self._credential_value()
			(repository / "settings.txt").write_text(
				f'client.secret="{secret}"\n',
				encoding="utf-8",
			)
			self._git(repository, "add", "settings.txt")

			result = credential_gate.scan_tracked_repository(repository)

			self.assertFalse(result["ok"])
			self.assertEqual(result["issues"][0]["rule_id"], "credential.assignment")

	def test_source_validator_name_is_not_a_sensitive_file_false_positive(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			(repository / "gf_private_key_validator.gd").write_text(
				"extends RefCounted\n",
				encoding="utf-8",
			)
			self._git(repository, "add", "gf_private_key_validator.gd")

			result = credential_gate.scan_tracked_repository(repository)

			self.assertTrue(
				result["ok"],
				"Expected the source validator name to remain non-sensitive.",
			)

	def test_tracked_scan_rejects_real_linked_directory_without_disclosure(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			temporary_root = Path(temp_dir)
			repository = self._init_repository(temporary_root / "repository")
			tracked_root = repository / "linked"
			tracked_root.mkdir()
			(tracked_root / "settings.txt").write_text(
				"ordinary tracked content\n",
				encoding="utf-8",
			)
			self._git(repository, "add", "linked/settings.txt")
			shutil.rmtree(tracked_root)
			outside_root = temporary_root / "outside"
			outside_root.mkdir()
			secret = self._known_token()
			(outside_root / "settings.txt").write_text(
				secret + "\n",
				encoding="utf-8",
			)
			try:
				create_directory_link_fixture(outside_root, tracked_root)
			except OSError as exc:
				self.skipTest(
					"Directory link fixtures are unavailable: "
					f"{type(exc).__name__}"
				)
			try:
				result = credential_gate.scan_tracked_repository(repository)
			finally:
				self._remove_directory_link(tracked_root)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.path_boundary_violation",
			)
			self.assertFalse(
				secret in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed synthetic fixture content.",
			)

	def test_release_scan_rejects_real_linked_directory_without_disclosure(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			temporary_root = Path(temp_dir)
			release_root = temporary_root / "release"
			artifact_root = release_root / "artifacts"
			artifact_root.mkdir(parents=True)
			artifact_path = artifact_root / "release.txt"
			original_payload = b"ordinary release content\n"
			artifact_path.write_bytes(original_payload)
			manifest_path = release_root / "release-manifest.json"
			manifest_path.write_text(
				json.dumps({
					"artifacts": [{
						"path": "artifacts/release.txt",
						"size_bytes": len(original_payload),
						"sha256": hashlib.sha256(original_payload).hexdigest(),
					}],
				}),
				encoding="utf-8",
			)
			shutil.rmtree(artifact_root)
			outside_root = temporary_root / "outside"
			outside_root.mkdir()
			secret = self._known_token()
			(outside_root / "release.txt").write_text(
				secret + "\n",
				encoding="utf-8",
			)
			try:
				create_directory_link_fixture(outside_root, artifact_root)
			except OSError as exc:
				self.skipTest(
					"Directory link fixtures are unavailable: "
					f"{type(exc).__name__}"
				)
			try:
				result = credential_gate.scan_release_manifest(manifest_path)
			finally:
				self._remove_directory_link(artifact_root)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.path_boundary_violation",
			)
			self.assertFalse(
				secret in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed synthetic fixture content.",
			)

	def test_tracked_scan_rejects_open_time_replacement_without_reading_it(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			repository = self._init_repository(Path(temp_dir))
			candidate = repository / "settings.txt"
			replacement = repository / "replacement.txt"
			candidate.write_text("ordinary tracked content\n", encoding="utf-8")
			secret = self._known_token()
			replacement.write_text(secret + "\n", encoding="utf-8")
			self._git(repository, "add", "settings.txt")
			real_open = os.open
			replaced = False

			def replace_before_open(
				path: str | bytes | os.PathLike[str] | os.PathLike[bytes],
				flags: int,
				mode: int = 0o777,
			) -> int:
				nonlocal replaced
				if not replaced and Path(path) == candidate:
					replaced = True
					os.replace(replacement, candidate)
				return real_open(path, flags, mode)

			with mock.patch.object(
				credential_gate.os,
				"open",
				side_effect=replace_before_open,
			):
				result = credential_gate.scan_tracked_repository(repository)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"][0]["rule_id"],
				"credential_gate.file_changed",
			)
			self.assertFalse(
				secret in json.dumps(result, ensure_ascii=False),
				"Credential gate report disclosed synthetic fixture content.",
			)

	def test_controlled_read_rejects_parent_identity_drift_without_disclosure(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			containment_root = Path(temp_dir)
			candidate = containment_root / "settings.txt"
			secret = self._known_token()
			candidate.write_text(secret + "\n", encoding="utf-8")
			real_snapshot = credential_gate._snapshot_directory_chain
			snapshot_count = 0

			def drift_after_open(
				root: Path,
				directory: Path,
			) -> tuple[tuple[Path, os.stat_result], ...]:
				nonlocal snapshot_count
				snapshot_count += 1
				snapshot = real_snapshot(root, directory)
				if snapshot_count < 2:
					return snapshot
				parent_path, parent_stat = snapshot[-1]
				drifted_stat = mock.Mock(
					st_dev=parent_stat.st_dev,
					st_ino=parent_stat.st_ino + 1,
					st_mode=parent_stat.st_mode,
					st_file_attributes=int(
						getattr(parent_stat, "st_file_attributes", 0)
					),
				)
				return (*snapshot[:-1], (parent_path, drifted_stat))

			with mock.patch.object(
				credential_gate,
				"_snapshot_directory_chain",
				side_effect=drift_after_open,
			):
				with self.assertRaises(
					credential_gate.GateInputError
				) as raised:
					credential_gate._read_regular_file(
						candidate,
						1024,
						"credential_gate.source_file_budget_exceeded",
						containment_root=containment_root,
					)

			self.assertTrue(
				raised.exception.rule_id == "credential_gate.file_changed",
				"Controlled read did not report a stable identity-drift rule.",
			)
			self.assertFalse(
				secret in str(raised.exception),
				"Controlled-read failure disclosed synthetic fixture content.",
			)

	@staticmethod
	def _drift_directory_chain(
		chain: tuple[tuple[Path, os.stat_result], ...],
		index: int,
	) -> tuple[tuple[Path, os.stat_result], ...]:
		path, metadata = chain[index]
		drifted_metadata = mock.Mock(
			st_dev=metadata.st_dev,
			st_ino=metadata.st_ino + 1,
			st_mode=metadata.st_mode,
			st_file_attributes=int(
				getattr(metadata, "st_file_attributes", 0)
			),
		)
		items = list(chain)
		items[index] = (path, drifted_metadata)
		return tuple(items)

	@staticmethod
	def _init_repository(path: Path) -> Path:
		path.mkdir(parents=True, exist_ok=True)
		subprocess.run(
			["git", "init", "-q"],
			cwd=path,
			check=True,
			capture_output=True,
		)
		return path

	@staticmethod
	def _git(repository: Path, *arguments: str) -> None:
		subprocess.run(
			["git", *arguments],
			cwd=repository,
			check=True,
			capture_output=True,
		)

	@staticmethod
	def _remove_directory_link(link: Path) -> None:
		if not os.path.lexists(link):
			return
		if os.name == "nt":
			link.rmdir()
		else:
			link.unlink()

	@staticmethod
	def _credential_value() -> str:
		alphabet = "Ab3$xyZ9!mN7@qR5"
		return "".join(alphabet[(index * 7 + 3) % len(alphabet)] for index in range(40))

	@classmethod
	def _known_token(cls) -> str:
		return "ghp_" + cls._credential_value().replace("$", "A").replace("!", "B").replace("@", "C")

	@staticmethod
	def _write_manifest(
		release_root: Path,
		artifact_path: Path,
		*,
		sha256: str = "",
		extra: dict[str, object] | None = None,
	) -> Path:
		manifest_path = release_root / "release-manifest.json"
		data: dict[str, object] = {
			"artifacts": [{
				"path": artifact_path.name,
				"size_bytes": artifact_path.stat().st_size,
				"sha256": sha256 or hashlib.sha256(artifact_path.read_bytes()).hexdigest(),
			}],
		}
		if extra:
			data.update(extra)
		manifest_path.write_text(
			json.dumps(data),
			encoding="utf-8",
		)
		return manifest_path


if __name__ == "__main__":
	unittest.main()
