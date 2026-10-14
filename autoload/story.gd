extends Node
## 이야기 (docs/STORY.md): 첫 실행 장면(까마귀 모습의 어둠이 계약을 건다)과 이야기 조각 10개 (조건·문안은 Balance 4부 balance/story.gd).
## 조각은 기록이 목표에 닿고 앞 조각이 열려 있으면 열린다. 겨울잠이 밭 단계를 되돌려도 닫히지 않게 열린 수를 저장하고 늘리기만 한다.
## 아직 안 본 조각이 있으면 낮 화면의 카드(scenes/ui/story_card.gd)가 하나씩 띄우고 mark_seen()을 부른다. 다시 읽기는 scenes/ui/story_book.gd.
## 게임 수치에는 영향이 없다. 데이터 초기화에서만 처음으로 돌아간다. 저장은 Save가 "story" 절로 한다

signal story_changed()

var intro_seen: bool = false  # 첫 실행 장면을 봤다
var unlocked_count: int = 0   # 앞에서부터 열린 조각 수 (줄지 않는다)
var seen_count: int = 0       # 카드로 본 조각 수. 이보다 많이 열렸으면 카드를 띄운다


func _ready() -> void:
	Game.phase_changed.connect(_on_phase_changed.unbind(1))
	Winter.slept.connect(_on_slept.unbind(1))
	reset()


func reset() -> void:
	intro_seen = false
	unlocked_count = 0
	seen_count = 0
	_advance()
	story_changed.emit()


func to_dict() -> Dictionary:
	return {"intro_seen": intro_seen, "unlocked_count": unlocked_count, "seen_count": seen_count}


## Game·Night·Winter를 불러온 뒤에 부른다. 없는 필드는 기본값으로.
## 이야기가 없던 옛 저장은 밤을 한 번이라도 나갔으면 첫 장면을 본 것으로, 조각이 없던 저장은 이미 닿은 조각을 본 것으로 친다 (불러오자마자 카드가 쏟아지지 않게)
func from_dict(data: Dictionary) -> void:
	intro_seen = bool(data.get("intro_seen", Game.nights > 0))
	unlocked_count = clampi(int(data.get("unlocked_count", 0)), 0, Balance.FRAGMENTS.size())
	_advance()
	seen_count = clampi(int(data.get("seen_count", unlocked_count)), 0, unlocked_count)
	if intro_seen:
		seen_count = maxi(seen_count, mini(Balance.INTRO_FRAGMENTS, unlocked_count))
	story_changed.emit()


func mark_intro_seen() -> void:
	if intro_seen:
		return
	intro_seen = true
	seen_count = maxi(seen_count, mini(Balance.INTRO_FRAGMENTS, unlocked_count))
	story_changed.emit()
	Save.save_game()


func is_unlocked(index: int) -> bool:
	return index < unlocked_count


## 아직 카드로 안 본 다음 조각. 없으면 -1 (첫 장면을 보기 전에는 카드를 띄우지 않는다)
func next_unseen() -> int:
	return seen_count if intro_seen and seen_count < unlocked_count else -1


func mark_seen(index: int) -> void:
	if index == seen_count and index < unlocked_count:
		seen_count += 1
		story_changed.emit()


## 지금 기록이 목표에 닿은 조각까지 앞에서부터 연다 (줄이지 않는다)
func _advance() -> void:
	while unlocked_count < Balance.FRAGMENTS.size() \
			and stat_value(Balance.fragment_stat(unlocked_count)) >= Balance.fragment_goal(unlocked_count):
		unlocked_count += 1


func stat_value(stat: int) -> float:
	match stat:
		Balance.StoryStat.START:
			return 0.0
		Balance.StoryStat.NIGHTS:
			return float(Game.nights)
		Balance.StoryStat.FIELD:
			return float(Night.best_level)
		Balance.StoryStat.OFFERED:
			return Game.offered
		Balance.StoryStat.WINTERS:
			return float(Winter.sleeps)
		Balance.StoryStat.REST:
			return Game.promised_rest_seconds()
	return 0.0


## 밤이 끝나 낮이 되면 (기록이 바뀐 뒤) 다시 센다
func _on_phase_changed() -> void:
	if Game.is_night():
		return
	_recheck()


func _on_slept() -> void:
	_recheck()


func _recheck() -> void:
	var before := unlocked_count
	_advance()
	if unlocked_count != before:
		story_changed.emit()
