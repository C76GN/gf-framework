"""Fail-closed result/deadline regression tests for the optional native runner."""
import json
from pathlib import Path, PurePosixPath, PureWindowsPath
import sys
import tempfile
import time
from dataclasses import replace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import gf_native_acceptance as acceptance
import gf_native_distribution as distribution
import gf_native_platform_acceptance as platform_acceptance
import gf_extension_export_acceptance as extension_exports
from gf_extension_export_check import PASSED, REJECTED, RESULT, export_policy_error, policy_verdict
from gf_process_supervisor import SupervisedProcessCleanupError, SupervisedProcessResult


class NativeAcceptanceTests(unittest.TestCase):
    def setUp(self):
        logs = acceptance.ROOT / 'ai_analysis/godot_logs/gf_native'
        logs.mkdir(parents=True, exist_ok=True)
        temporary = tempfile.TemporaryDirectory(prefix='runner-test-', dir=logs)
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)

    def report(self):
        return {'ok': True, 'failures': [], 'samples': [
            {'source_rows': rows, 'selected_rows': rows // 2, 'int64_columns': 4,
             'script_usec': [3] * 10, 'native_usec': [2] * 10}
            for rows in (16, 1000, 100000)]}

    def marker(self, report):
        return 'GF_NATIVE_DATA_BATCH=' + json.dumps(report)

    def test_extension_policy_requires_one_completed_verdict_and_successful_godot_exit(self):
        self.assertEqual(export_policy_error(0, "WARNING: reference\n" + PASSED), "")
        self.assertEqual(policy_verdict(PASSED + "\n" + REJECTED), "")
        for code, output in [(1, PASSED), (0, ""), (0, REJECTED), (0, PASSED + "\n" + REJECTED),
                             (0, PASSED + "\n" + PASSED), (0, RESULT + "unknown")]:
            with self.subTest(code=code, output=output):
                self.assertTrue(export_policy_error(code, output))

    def test_extension_export_fixture_retains_unconfirmed_process_or_replaced_directory(self):
        with self.assertRaises(SupervisedProcessCleanupError):
            with extension_exports.owned_projects(self.directory) as retained:
                raise SupervisedProcessCleanupError("fixture process still active")
        self.assertTrue(retained.is_dir())
        with self.assertRaisesRegex(RuntimeError, "identity changed"):
            with extension_exports.owned_projects(self.directory) as replaced:
                replaced.rename(replaced.with_suffix(".original"))
                replaced.mkdir()
        self.assertTrue(replaced.is_dir())
        with self.assertRaisesRegex(ValueError, "quiescent failure"):
            with extension_exports.owned_projects(self.directory) as cleaned:
                raise ValueError("quiescent failure")
        self.assertFalse(cleaned.exists())

    def test_requires_one_complete_report(self):
        marker = self.marker(self.report())
        self.assertTrue(acceptance.parse_acceptance('engine startup\n' + marker)['ok'])
        for text in ('', marker + '\n' + marker, 'GF_NATIVE_DATA_BATCH=[]',
                     'GF_NATIVE_DATA_BATCH={"ok": true}'):
            with self.subTest(text=text), self.assertRaises((RuntimeError, ValueError)):
                acceptance.parse_acceptance(text)

    def test_rejects_missing_cases_failures_wrong_shape_and_invalid_samples(self):
        for mutation in (
            lambda r: r.update(ok=1),
            lambda r: r.update(failures=['wrong values']),
            lambda r: r['samples'].pop(),
            lambda r: r['samples'][0].update(int64_columns=2),
            lambda r: r['samples'][1]['native_usec'].pop(),
            lambda r: r['samples'][2]['native_usec'].__setitem__(0, True),
            lambda r: r['samples'][2]['native_usec'].__setitem__(0, -1),
        ):
            report = self.report()
            mutation(report)
            with self.assertRaises(RuntimeError):
                acceptance.parse_acceptance(self.marker(report))

    def test_expired_overall_deadline_never_dispatches(self):
        with patch.object(acceptance, 'run_supervised_process') as dispatch:
            with self.assertRaisesRegex(RuntimeError, 'deadline'):
                acceptance.run(['unused'], Path('.'), 'unused', 60, Path('.'), 0)
            dispatch.assert_not_called()

    def test_packaged_dll_cannot_require_a_separately_installed_vc_runtime(self):
        header = 'Dump of file gf_native.dll\n'
        self.assertEqual(acceptance.check_dependency_report(header + '    KERNEL32.dll\n'), ['KERNEL32.dll'])
        for row in ('', '    VCRUNTIME140_1.dll', '    MSVCP140.dll'):
            with self.subTest(row=row), self.assertRaisesRegex(ValueError, 'MSVC'):
                acceptance.check_dependency_report(header + row)

    def test_native_manifest_uses_identical_path_order_on_windows_and_posix(self):
        orders = []
        for flavor in (PureWindowsPath, PurePosixPath):
            root = flavor('native/gf_native')
            modules = [root / 'src/packed_gather.rs', root / 'src/lib.rs']
            with patch.object(distribution, 'CRATE', root), patch.object(flavor, 'glob', create=True, return_value=modules):
                orders.append([path.relative_to(root).as_posix() for path in distribution.native_inputs()])
        self.assertEqual(orders[0], orders[1])
        self.assertEqual(orders[0], sorted(orders[0]))

    def test_simulator_fails_on_a_diagnostic_reported_only_during_native_shutdown(self):
        engine = self.directory / 'godot.log'
        engine.write_text('GF_NATIVE_FINISHED=fixture\n', encoding='utf-8')
        stdout = self.directory / 'simulator.stdout.log'
        stderr = self.directory / 'simulator.stderr.log'
        for stream in (stdout, stderr):
            with self.subTest(stream=stream.name):
                stdout.write_text('', encoding='utf-8')
                stderr.write_text('', encoding='utf-8')
                stream.write_text("thread 'main' panicked at fixture", encoding='utf-8')
                with self.assertRaisesRegex(RuntimeError, stream.name):
                    platform_acceptance.check_simulator_diagnostics(engine, self.directory)

    def test_fresh_import_rejects_pre_registered_project_before_launch(self):
        cache = self.directory / '.godot'
        cache.mkdir()
        registry = cache / 'extension_list.cfg'
        original = b'res://addons/already_installed.gdextension\n'
        registry.write_bytes(original)
        with patch.object(acceptance, 'run') as launch:
            with self.assertRaisesRegex(RuntimeError, 'without a .godot cache'):
                acceptance.run_fresh_import('godot', self.directory, self.directory, time.monotonic() + 30)
            launch.assert_not_called()
        self.assertEqual(registry.read_bytes(), original)

    def test_fresh_import_requires_one_successful_engine_discovery(self):
        expected = 'res://' + acceptance.EXTENSION.as_posix()
        for index, (entry, crashed) in enumerate([
            (None, False), ('res://another.gdextension', False), (expected, True), (expected, False),
        ]):
            with self.subTest(entry=entry, crashed=crashed):
                workspace = self.directory / str(index)
                workspace.mkdir()

                def import_project(*_args):
                    cache = workspace / '.godot'
                    cache.mkdir()
                    if entry is not None:
                        (cache / 'extension_list.cfg').write_text(entry + '\n', encoding='utf-8')
                    if crashed:
                        raise RuntimeError('import process failed')

                deadline = time.monotonic() + 30
                with patch.object(acceptance, 'run', side_effect=import_project) as launch:
                    if entry == expected and not crashed:
                        acceptance.run_fresh_import('godot', workspace, self.directory, deadline)
                    else:
                        with self.assertRaises(RuntimeError):
                            acceptance.run_fresh_import('godot', workspace, self.directory, deadline)
                    launch.assert_called_once_with(['godot', '--headless', '--path', str(workspace), '--import'],
                                                   workspace, 'import', 120, self.directory, deadline)

    def test_supervision_failures_and_diagnostics_never_pass(self):
        clean = SupervisedProcessResult(0, 'accepted', '', False, 0.1, 1,
                                        process_boundary_quiescent=True)
        failures = [replace(clean, **change) for change in (
            {'return_code': 1}, {'cancelled': True}, {'timed_out': True},
            {'stdout_truncated': True}, {'stderr_truncated': True},
            {'process_boundary_quiescent': False}, {'stderr': 'WARNING: resource leaked'},
            {'stdout': 'SCRIPT ERROR: invalid source'},
        )]
        for result in failures:
            with patch.object(acceptance, 'run_supervised_process', return_value=result):
                with self.assertRaises(RuntimeError):
                    acceptance.run(['unused'], self.directory, 'failure', 60,
                                   self.directory, time.monotonic() + 30)
        with patch.object(acceptance, 'run_supervised_process', return_value=clean):
            self.assertEqual(acceptance.run(['unused'], self.directory, 'clean', 60,
                                           self.directory, time.monotonic() + 30), 'accepted')

    def test_source_digest_excludes_cargo_build_cache_and_has_deadline(self):
        crate = self.directory / 'native/gf_native'
        (crate / 'src').mkdir(parents=True)
        (crate / 'src/lib.rs').write_text('// source', encoding='utf-8')
        (crate / 'target').mkdir()
        (crate / 'target/cache.bin').write_bytes(b'not source')
        with patch.object(acceptance, 'ROOT', self.directory), patch.object(acceptance, 'CRATE', crate):
            with patch.object(acceptance, 'file_digest', return_value='a' * 64) as read:
                acceptance.source_digest(time.monotonic() + 30)
                paths = [call.args[0] for call in read.call_args_list]
                self.assertIn(crate / 'src/lib.rs', paths)
                self.assertFalse(any('target' in path.parts for path in paths))
        with self.assertRaisesRegex(RuntimeError, 'deadline'):
            acceptance.file_digest(crate / 'src/lib.rs', 0)


if __name__ == '__main__':
    unittest.main()
