# Lifecycle-aware SceneTree wrapper for command-line GUT runs.
extends SceneTree


# --- 常量 ---

const GF_GUT_LIFECYCLE_LOGGER_SCRIPT = preload(
	"res://tests/gf_core/support/gf_gut_lifecycle_logger.gd"
)
const GF_GUT_LIFECYCLE_STATE_SCRIPT = preload(
	"res://tests/gf_core/support/gf_gut_lifecycle_state.gd"
)
const GF_GUT_RUNNER_SCENE_PATH: String = "res://tests/gf_core/support/gf_gut_runner.tscn"
const GUT_VERSION_CONVERSION_SCRIPT_PATH: String = "res://addons/gut/version_conversion.gd"
const BOOTSTRAP_FIXTURE_ENVIRONMENT: String = "GF_GUT_LIFECYCLE_BOOTSTRAP_FIXTURE"
const BOOTSTRAP_WARNING_FIXTURE_PATH: String = (
	"res://tests/gf_core/fixtures/lifecycle_gate/"
	+ "lifecycle_gate_bootstrap_warning_fixture.gd"
)
const SENTINEL_PREFIX: String = "GF_TEST_LIFECYCLE_GATE="
const EXIT_FAILURE: int = 1
const MAIN_LOOP_WAIT_LIMIT: int = 20


# --- 私有变量 ---

var _raw_logger: Logger
var _cli: Node


# --- Godot 生命周期方法 ---

func _init() -> void:
	GF_GUT_LIFECYCLE_STATE_SCRIPT.begin_run()
	var raw_logger_value: Variant = GF_GUT_LIFECYCLE_LOGGER_SCRIPT.new()
	if not raw_logger_value is Logger:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"raw_logger_unavailable"
		)
		quit(EXIT_FAILURE)
		return

	_raw_logger = raw_logger_value
	OS.add_logger(_raw_logger)

	if not _load_requested_bootstrap_fixture():
		quit(EXIT_FAILURE)
		return

	var version_conversion_resource: Resource = load(
		GUT_VERSION_CONVERSION_SCRIPT_PATH
	)
	if not version_conversion_resource is GDScript:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"gut_version_conversion_unavailable"
		)
		quit(EXIT_FAILURE)
		return
	var version_conversion_script: GDScript = version_conversion_resource
	var conversion_error_value: Variant = version_conversion_script.call(
		&"error_if_not_all_classes_imported"
	)
	if not conversion_error_value is bool:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"gut_version_conversion_invalid"
		)
		quit(EXIT_FAILURE)
		return
	var conversion_has_error: bool = conversion_error_value
	if conversion_has_error:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"gut_classes_unavailable"
		)
		quit(EXIT_FAILURE)
		return

	var gut_loader_resource: Resource = load("res://addons/gut/gut_loader.gd")
	if gut_loader_resource == null:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"gut_loader_unavailable"
		)
		quit(EXIT_FAILURE)
		return

	var iteration: int = 0
	while Engine.get_main_loop() == null and iteration < MAIN_LOOP_WAIT_LIMIT:
		await create_timer(0.01).timeout
		iteration += 1
	if Engine.get_main_loop() == null:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"main_loop_start_timeout"
		)
		quit(EXIT_FAILURE)
		return

	var runner_scene_resource: Resource = load(GF_GUT_RUNNER_SCENE_PATH)
	if not runner_scene_resource is PackedScene:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"gut_runner_scene_unavailable"
		)
		quit(EXIT_FAILURE)
		return
	var runner_scene: PackedScene = runner_scene_resource

	var cli_resource: Resource = load("res://addons/gut/cli/gut_cli.gd")
	if not cli_resource is GDScript:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"gut_cli_unavailable"
		)
		quit(EXIT_FAILURE)
		return

	var cli_script: GDScript = cli_resource
	var cli_value: Variant = cli_script.new()
	if not cli_value is Node:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"gut_cli_instance_unavailable"
		)
		quit(EXIT_FAILURE)
		return

	_cli = cli_value
	_cli.set(&"GutRunner", runner_scene)
	get_root().add_child(_cli)
	var _main_result: Variant = _cli.call(&"main")


func _finalize() -> void:
	var report: Dictionary = GF_GUT_LIFECYCLE_STATE_SCRIPT.finalize_report()
	var report_ok_value: Variant = report.get("ok")
	if not report_ok_value is bool or not report_ok_value:
		quit(EXIT_FAILURE)
	if _raw_logger != null:
		OS.remove_logger(_raw_logger)
	print(SENTINEL_PREFIX + JSON.stringify(report))
	_cli = null
	_raw_logger = null


# --- 私有/辅助方法 ---

func _load_requested_bootstrap_fixture() -> bool:
	var fixture_path: String = OS.get_environment(
		BOOTSTRAP_FIXTURE_ENVIRONMENT
	)
	if fixture_path.is_empty():
		return true
	if fixture_path != BOOTSTRAP_WARNING_FIXTURE_PATH:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"bootstrap_fixture_not_allowed"
		)
		return false

	var fixture_resource: Resource = load(fixture_path)
	if not fixture_resource is GDScript:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"bootstrap_fixture_unavailable"
		)
		return false
	return true
