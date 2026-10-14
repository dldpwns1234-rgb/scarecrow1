extends Node
## Night 0부: 밭 단계 (GDD 4절). 고른 단계와 열린 단계, 정복하면 다음 단계 열기, 다음 밤 단계 고르기, 겨울잠 뒤 새 철의 시작 단계.
## 밭 자체(칸·심기)와 저장(to_dict·from_dict)은 night/field.gd가 상속해서 맡는다

signal field_level_changed(level: int, best: int)

var field_level: int = 1          # 이번 밤(또는 다음 밤)의 밭 단계
var best_level: int = 1           # 열린 가장 높은 밭 단계
var auto_advance: bool = false    # 정복하면 다음 밤을 새 단계로 (끄면 열리기만 하고 낮에 고른다. 방장 2026-10-14: 센 맛을 즐길 틈)


## 겨울잠 뒤 새 철: 겨울 씨앗만큼 열린 밭에서 시작한다. Winter.perform()이 부른다
func start_season(start_level: int) -> void:
	best_level = clampi(start_level, 1, Balance.MAX_FIELD_LEVEL)
	field_level = best_level
	field_level_changed.emit(field_level, best_level)


## 다음 밤의 밭 단계를 고른다 (열린 단계까지)
func choose_level(level: int) -> bool:
	if level < 1 or level > best_level:
		return false
	field_level = level
	field_level_changed.emit(field_level, best_level)
	return true


## 가장 높은 단계를 정복했으면 다음 단계를 연다. 다음 밤을 그리로 옮기는 건 auto_advance일 때만 (아니면 낮에 고른다)
func _unlock_next() -> void:
	if field_level == best_level and best_level < Balance.MAX_FIELD_LEVEL:
		best_level += 1
		if auto_advance:
			field_level = best_level
		field_level_changed.emit(field_level, best_level)


## 정복하면 다음 단계로 넘어갈지 (낮 화면의 스위치)
func set_auto_advance(on: bool) -> void:
	auto_advance = on
	field_level_changed.emit(field_level, best_level)
