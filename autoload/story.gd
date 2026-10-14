extends Node
## 이야기 (docs/STORY.md): 첫 실행 장면(까마귀 모습의 어둠이 계약을 건다)을 봤는지, 이야기 조각을 몇 장 봤는지.
## 게임 수치에는 영향이 없다. 데이터 초기화에서만 처음으로 돌아간다. 저장은 Save가 "story" 절로 한다. 화면은 scenes/ui/intro_card.gd

signal story_changed()

var intro_seen: bool = false  # 첫 실행 장면을 봤다
var seen_count: int = 0       # 본 이야기 조각 수 (조각 카드는 다음 단계)


func reset() -> void:
	intro_seen = false
	seen_count = 0
	story_changed.emit()


func to_dict() -> Dictionary:
	return {"intro_seen": intro_seen, "seen_count": seen_count}


## 없는 필드는 기본값으로. 이야기가 없던 옛 저장은 밤을 한 번이라도 나갔으면 첫 장면을 본 것으로 친다 (Game을 먼저 불러온 뒤에 부른다)
func from_dict(data: Dictionary) -> void:
	intro_seen = bool(data.get("intro_seen", Game.nights > 0))
	seen_count = maxi(int(data.get("seen_count", 0)), 0)
	story_changed.emit()


func mark_intro_seen() -> void:
	if intro_seen:
		return
	intro_seen = true
	story_changed.emit()
	Save.save_game()
