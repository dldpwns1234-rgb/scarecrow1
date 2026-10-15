extends "res://tests/test_case.gd"
## 이야기 조각: 처음 두 조각은 첫 장면이 보여 준다, 기록이 닿으면 앞에서부터 차례로 열린다, 겨울잠으로 밭 단계가 내려가도 닫히지 않는다, 저장과 옛 저장


func run() -> void:
	_fresh()
	Night.reset()
	Winter.reset()
	Story.reset()
	_equal(Story.unlocked_count, Balance.INTRO_FRAGMENTS, "처음에는 첫 장면의 두 조각만 열림")
	_equal(Story.next_unseen(), -1, "첫 장면 전에는 카드를 띄우지 않는다")
	Story.mark_intro_seen()
	_equal(Story.seen_count, Balance.INTRO_FRAGMENTS, "첫 장면을 보면 두 조각을 본 것으로")
	_equal(Story.next_unseen(), -1, "더 열린 조각이 없다")

	Game.nights = 4
	Game.start_night()
	Game.finish_night()
	_equal(Story.unlocked_count, 3, "밤 5번이면 '약속된 휴식'")
	_equal(Story.next_unseen(), 2, "새 조각은 카드로")
	Story.mark_seen(2)
	_equal(Story.next_unseen(), -1, "본 조각은 다시 띄우지 않는다")

	Night.best_level = 45
	Game.start_night()
	Game.finish_night()
	_equal(Story.unlocked_count, 6, "밭 단계 조각들이 열리고 겨울잠 조각에서 멈춘다 (건너뛰지 않는다)")
	_equal(Balance.FRAGMENTS[4]["title"], "다른 허수아비들", "10단계 조각은 첫 허수아비 일꾼과 함께")
	Game.offered = 1e12
	Game.start_night()
	Game.finish_night()
	_equal(Story.unlocked_count, 6, "겨울잠 전에는 바친 생기 1조가 닿아도 기다린다")
	Winter.sleeps = 1
	Winter.slept.emit(3.0)
	_equal(Story.unlocked_count, 8, "첫 겨울잠 → '겨울잠', 이미 닿은 '어둠의 배'까지")
	Night.best_level = 1
	Game.offered = 1e15
	Game.start_night()
	Game.finish_night()
	_equal(Story.unlocked_count, 9, "겨울잠으로 밭 단계가 내려가도 닫히지 않고, 바친 생기 1000조면 '농부의 한숨'")
	_equal(Balance.fragment_hint(9), "약속된 휴식 백 년", "다음 조각의 조건 글")

	var data := Save.to_dict()
	Story.reset()
	Save.from_dict(data)
	_equal(Story.unlocked_count, 9, "열린 수 저장")
	_equal(Story.seen_count, 3, "본 수 저장")
	_equal(Story.next_unseen(), 3, "불러와도 안 본 조각은 카드로")
	Save.from_dict({"save_version": 1, "game": {"nights": 6}})
	_equal(Story.intro_seen, true, "이야기 절 없는 옛 저장: 밤을 나갔으면 첫 장면은 본 것으로")
	_equal(Story.seen_count, Story.unlocked_count, "이야기 절 없는 옛 저장: 이미 닿은 조각은 본 것으로 (카드가 쏟아지지 않게)")

	Night.reset()
	Winter.reset()
	Story.reset()
	_fresh()
