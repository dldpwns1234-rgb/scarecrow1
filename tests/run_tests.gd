extends Node
## 헤드리스 테스트 러너.
##
##   godot --headless --path . res://tests/run_tests.tscn
##
## 메인 씬 대신 이 씬을 띄우면 오토로드(Balance, Num, Upgrades, Game, Night, Prefs, Save, Sfx)가 그대로 뜬다.
## --script 모드는 오토로드를 띄우지 않으므로 쓰지 않는다. 실패하면 종료 코드 1. 테스트 안의 SCRIPT ERROR는 CI가 로그를 grep한다.

## 테스트 중 저장은 전부 이 파일로 간다. 실제 저장 파일을 건드리면 다음 실행의 시작 상태가 오염된다
const TEST_SAVE_PATH: String = "user://test_run.json"

const SUITES: Array[GDScript] = [
	preload("res://tests/test_num.gd"),
	preload("res://tests/test_game.gd"),
	preload("res://tests/test_upgrades.gd"),
	preload("res://tests/test_night.gd"),
	preload("res://tests/test_winter.gd"),
	preload("res://tests/test_farmer.gd"),
	preload("res://tests/test_workers.gd"),
	preload("res://tests/test_branch_ends.gd"),
	preload("res://tests/test_save.gd"),
	preload("res://tests/test_sound.gd"),
	preload("res://tests/test_story.gd"),
	preload("res://tests/test_tree_layout.gd"),
	preload("res://tests/test_ui_text.gd"),
]


func _ready() -> void:
	print("")
	print("=== 허수아비는 쉬고 싶다 테스트 ===")
	Save.save_path = TEST_SAVE_PATH
	await get_tree().process_frame
	var passed := 0
	var failed := 0
	for suite_script in SUITES:
		var suite: Node = suite_script.new()
		add_child(suite)
		await suite.run()
		passed += suite.passed
		failed += suite.failed
	Save.blocked = true  # 종료 직전의 자동 저장이 파일을 다시 만들지 않도록
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	print("")
	print("통과 %d · 실패 %d" % [passed, failed])
	print("")
	get_tree().quit(1 if failed > 0 else 0)
