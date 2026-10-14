extends Node
## 저장과 불러오기 (CLAUDE.md 저장 규칙). user://save.json에 JSON으로 저장한다. 회귀 용사의 저장을 옮겨 오며 오프라인 보상은 뺐다 (밤 한 판 단위라 비운 시간은 진행이 아니다).
## 밤이 끝날 때, 30초마다, 창이나 탭의 포커스를 잃을 때 저장한다. 밤 한 판 안의 상태는 저장하지 않는다 (불러오면 낮)

signal saved()

const SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://save.json"
const AUTOSAVE_INTERVAL: float = 30.0  # 초. 게임 수치가 아니라 저장 주기
const BASE64_PATTERN: String = "^[A-Za-z0-9+/]+={0,2}$"
const WebHooks := preload("res://autoload/save/web_hooks.gd")

var save_path: String = DEFAULT_SAVE_PATH  # 테스트에서 다른 파일로 바꾼다
var blocked: bool = false  # 테스트와 시뮬레이션이 켠다
var _autosave_left: float = AUTOSAVE_INTERVAL
var _base64_regex := RegEx.create_from_string(BASE64_PATTERN)
var _web_hooks: WebHooks  # 브라우저 이벤트로 저장 (웹). 참조를 잃으면 콜백이 수거된다


func _ready() -> void:
	_web_hooks = WebHooks.new(save_game)
	load_game()


func _process(delta: float) -> void:
	if blocked:
		return
	_autosave_left -= minf(delta, Balance.MAX_DELTA)
	if _autosave_left <= 0.0:
		_autosave_left = AUTOSAVE_INTERVAL
		save_game()


## 창이나 탭의 포커스를 잃을 때, 창을 닫을 때, 모바일에서 앱이 뒤로 갈 때 저장한다
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED:
			save_game()


## 저장 데이터 전체. 새 오토로드를 저장에 넣으면 to_dict·from_dict·reset_data 세 곳을 함께 고친다
func to_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game": Game.to_dict(),
		"upgrades": Upgrades.to_dict(),
		"night": Night.to_dict(),
		"winter": Winter.to_dict(),
		"prefs": Prefs.to_dict(),
		"story": Story.to_dict(),
	}


## 없는 부분은 각 오토로드가 기본값으로 채운다
func from_dict(data: Dictionary) -> void:
	Upgrades.from_dict(_section(data, "upgrades"))
	Game.from_dict(_section(data, "game"))
	Winter.from_dict(_section(data, "winter"))
	Night.from_dict(_section(data, "night"))
	Prefs.from_dict(_section(data, "prefs"))
	Story.from_dict(_section(data, "story"))  # Game 뒤에 (옛 저장은 밤 수로 첫 장면을 정한다)


func save_game() -> void:
	if blocked:
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("저장 실패: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(to_dict()))
	file.close()
	saved.emit()


## 저장 파일이 있으면 불러온다. 없거나 깨졌으면 false를 주고 상태는 그대로 둔다
func load_game() -> bool:
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var data := _parse(file.get_as_text())
	file.close()
	if data.is_empty():
		return false
	from_dict(data)
	return true


## 내보내기 문자열: 저장 JSON을 base64로 인코딩한 것
func export_string() -> String:
	return Marshalls.utf8_to_base64(JSON.stringify(to_dict()))


## 내보내기 문자열을 적용하고 저장한다. 잘못된 문자열이면 false
func import_string(text: String) -> bool:
	var compact := text.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "")
	# base64가 아닌 문자열을 풀려고 하면 엔진이 오류를 찍으므로 먼저 거른다 (글자 종류와 4의 배수 길이)
	if compact.is_empty() or compact.length() % 4 != 0 or _base64_regex.search(compact) == null:
		return false
	var data := _parse(Marshalls.base64_to_utf8(compact))
	if data.is_empty():
		return false
	from_dict(data)
	save_game()
	return true


## 모든 데이터를 지우고 처음부터. 두 번 확인한 뒤에만 부른다
func reset_data() -> void:
	Upgrades.reset()
	Game.reset()
	Night.reset()
	Winter.reset()
	Prefs.reset()
	Story.reset()
	save_game()


## 저장 JSON을 딕셔너리로. 딕셔너리가 아니거나 save_version이 없으면 빈 딕셔너리
func _parse(text: String) -> Dictionary:
	var json := JSON.new()
	if text.is_empty() or json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var data: Dictionary = json.data
	return data if data.has("save_version") else {}


func _section(data: Dictionary, key: String) -> Dictionary:
	var part: Variant = data.get(key, {})
	return part if part is Dictionary else {}
